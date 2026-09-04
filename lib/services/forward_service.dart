import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/forward_status.dart';
import '../models/queued_sms.dart';
import 'connectivity_service.dart';
import 'payload_builder.dart';
import 'settings_service.dart';

class RetryPolicy {
  static const maxAttempts = 12;
  static const maxBackoff = Duration(minutes: 30);

  static Duration backoffFor(int attempts) {
    final seconds = (1 << attempts.clamp(1, 12)).clamp(2, maxBackoff.inSeconds);
    return Duration(seconds: seconds);
  }

  static bool isExhausted(QueuedSms sms) => sms.attempts >= maxAttempts;
}

class ForwardService {
  static final ForwardService _instance = ForwardService._internal();
  factory ForwardService() => _instance;
  ForwardService._internal();

  static const boxName = 'sms_queue';

  Box<QueuedSms> get _box => Hive.box<QueuedSms>(boxName);

  bool _flushing = false;
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  /// O(1) duplicate checks — rebuilt lazily after clears/restarts.
  Set<String>? _hashIndex;

  Set<String> get _hashes {
    return _hashIndex ??= _box.values.map((e) => e.payloadHash).toSet();
  }

  void _invalidateIndex() => _hashIndex = null;

  Future<void> enqueue(QueuedSms sms, {bool triggerFlush = true}) async {
    if (_hashes.contains(sms.payloadHash)) {
      developer.log('Duplicate SMS skipped: ${sms.payloadHash}', name: 'forward');
      return;
    }

    // Near-duplicate: same sender+body already pending/failed recently.
    final nearDup = _box.values.any(
      (e) =>
          e.payloadHash != sms.payloadHash &&
          e.sender == sms.sender &&
          e.body == sms.body &&
          e.receivedAt.difference(sms.receivedAt).abs() <=
              const Duration(minutes: 2),
    );
    if (nearDup) {
      developer.log('Near-duplicate SMS skipped', name: 'forward');
      return;
    }

    await _box.add(sms);
    _hashes.add(sms.payloadHash);
    // Force durable write before process can be killed.
    await _box.flush();

    if (triggerFlush) {
      unawaited(flushPending());
    }
  }

  /// Recover crash leftovers + flush — safe from any isolate after Hive ready.
  Future<void> recoverAndFlush({bool forceAll = false}) async {
    await recoverStuckSending();
    await flushPending(forceAll: forceAll);
  }

  /// SMS left as `sending` after kill/crash must be retried.
  Future<void> recoverStuckSending() async {
    var recovered = 0;
    for (final sms in _box.values) {
      if (sms.status != ForwardStatus.sending) continue;
      sms.status = ForwardStatus.pending;
      sms.lastError = 'Recovered after interrupt (device/app restart)';
      sms.nextRetryAt = null;
      await sms.save();
      recovered++;
    }
    if (recovered > 0) {
      await _box.flush();
      developer.log('Recovered $recovered stuck sending SMS', name: 'forward');
    }
  }

  Future<void> flushPending({bool forceAll = false}) async {
    if (_flushing) return;
    if (!SettingsService.forwardingEnabled) return;
    if (!SettingsService.isApiConfigured) return;

    // Stay queued while offline — do not burn retry budget.
    if (!forceAll && !ConnectivityService().isOnline.value) {
      developer.log('Skip flush: offline', name: 'forward');
      return;
    }

    _flushing = true;
    isSyncing.value = true;

    try {
      final now = DateTime.now();
      final pending = _box.values.where((s) {
        if (s.status == ForwardStatus.sent) return false;
        if (s.status == ForwardStatus.sending) return false;
        if (RetryPolicy.isExhausted(s) && !forceAll) return false;
        if (s.status == ForwardStatus.pending) {
          final next = s.nextRetryAt;
          return forceAll || next == null || !next.isAfter(now);
        }
        if (s.status == ForwardStatus.failed) {
          if (forceAll) return true;
          final next = s.nextRetryAt;
          return next == null || !next.isAfter(now);
        }
        return false;
      }).toList()
        ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

      for (final sms in pending) {
        // Re-check connectivity between items.
        if (!forceAll && !ConnectivityService().isOnline.value) break;
        await _sendOne(sms);
      }
      await _box.flush();
    } finally {
      _flushing = false;
      isSyncing.value = false;
    }
  }

  Future<bool> retry(QueuedSms sms) async {
    sms.status = ForwardStatus.pending;
    sms.lastError = null;
    sms.nextRetryAt = null;
    if (RetryPolicy.isExhausted(sms)) {
      sms.attempts = 0;
    }
    await sms.save();
    return _sendOne(sms);
  }

  Future<bool> _sendOne(QueuedSms sms) async {
    final url = SettingsService.apiUrl.trim();
    if (url.isEmpty) {
      sms.status = ForwardStatus.failed;
      sms.lastError = 'API URL not configured';
      await sms.save();
      return false;
    }

    if (!ConnectivityService().isOnline.value) {
      sms.status = ForwardStatus.pending;
      sms.lastError = 'Waiting for network';
      sms.nextRetryAt = DateTime.now().add(const Duration(seconds: 30));
      await sms.save();
      return false;
    }

    sms.status = ForwardStatus.sending;
    sms.nextRetryAt = null;
    await sms.save();

    try {
      final uri = Uri.parse(url);
      final headers = PayloadBuilder.buildHeaders();
      final body = PayloadBuilder.buildBodyForSms(sms);

      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      sms.attempts += 1;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        sms.status = ForwardStatus.sent;
        sms.forwardedAt = DateTime.now();
        sms.lastError = null;
        sms.nextRetryAt = null;
        await sms.save();
        developer.log('Forwarded SMS ${sms.id}', name: 'forward');
        return true;
      }

      // 5xx / 429 → transient; 4xx (except 408/429) → count toward exhaust
      final transient = response.statusCode >= 500 ||
          response.statusCode == 408 ||
          response.statusCode == 429;
      await _markFailed(
        sms,
        'HTTP ${response.statusCode}: ${response.body}',
        transient: transient,
      );
      return false;
    } catch (e) {
      sms.attempts += 1;
      final transient = _isTransientNetworkError(e);
      if (transient) {
        // Don't burn permanent budget on airplane mode / DNS blips.
        sms.attempts = (sms.attempts - 1).clamp(0, RetryPolicy.maxAttempts);
        sms.status = ForwardStatus.pending;
        sms.lastError = 'Network: $e';
        sms.nextRetryAt = DateTime.now().add(const Duration(seconds: 20));
        await sms.save();
        return false;
      }
      await _markFailed(sms, e.toString(), transient: false);
      developer.log('Forward failed: $e', name: 'forward');
      return false;
    }
  }

  bool _isTransientNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return e is SocketException ||
        e is TimeoutException ||
        e is http.ClientException ||
        s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('timed out') ||
        s.contains('host lookup');
  }

  Future<void> _markFailed(
    QueuedSms sms,
    String error, {
    required bool transient,
  }) async {
    if (!transient && RetryPolicy.isExhausted(sms)) {
      sms.status = ForwardStatus.failed;
      sms.lastError = '$error (max ${RetryPolicy.maxAttempts} attempts)';
      sms.nextRetryAt = null;
    } else {
      final delay = RetryPolicy.backoffFor(sms.attempts.clamp(1, 12));
      sms.status = transient ? ForwardStatus.pending : ForwardStatus.failed;
      sms.nextRetryAt = DateTime.now().add(delay);
      sms.lastError =
          '$error — retry in ${delay.inSeconds}s (attempt ${sms.attempts}/${RetryPolicy.maxAttempts})';
    }
    await sms.save();
  }

  Future<String> testConnection() async {
    final url = SettingsService.apiUrl.trim();
    if (url.isEmpty) return 'Set an API URL first';

    try {
      final headers = PayloadBuilder.buildHeaders();
      final body = PayloadBuilder.buildBody(
        sender: 'SMS-Forwarder',
        body: 'Connection test from SMS Forwarder',
        receivedAt: DateTime.now(),
        test: true,
      );

      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      final preview = response.body.length > 120
          ? '${response.body.substring(0, 120)}…'
          : response.body;
      return 'HTTP ${response.statusCode}: $preview';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Map<String, int> counts() {
    var pending = 0, sent = 0, failed = 0;
    for (final s in _box.values) {
      switch (s.status) {
        case ForwardStatus.pending:
        case ForwardStatus.sending:
          pending++;
          break;
        case ForwardStatus.sent:
          sent++;
          break;
        case ForwardStatus.failed:
          failed++;
          break;
      }
    }
    return {'pending': pending, 'sent': sent, 'failed': failed};
  }

  Future<int> clearSent() async {
    final keys = _box.keys.where((k) {
      final sms = _box.get(k);
      return sms?.status == ForwardStatus.sent;
    }).toList();
    await _box.deleteAll(keys);
    _invalidateIndex();
    await _box.flush();
    return keys.length;
  }

  Future<int> clearFailed() async {
    final keys = _box.keys.where((k) {
      final sms = _box.get(k);
      return sms?.status == ForwardStatus.failed;
    }).toList();
    await _box.deleteAll(keys);
    _invalidateIndex();
    await _box.flush();
    return keys.length;
  }

  Future<int> clearAll() async {
    final count = _box.length;
    await _box.clear();
    _invalidateIndex();
    await _box.flush();
    return count;
  }

  String exportJson({ForwardStatus? onlyStatus}) {
    final items = _box.values.where((s) {
      if (onlyStatus == null) return true;
      return s.status == onlyStatus;
    }).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return const JsonEncoder.withIndent('  ').convert({
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'device_id': SettingsService.deviceId,
      'count': items.length,
      'messages': items.map((e) => e.toExportJson()).toList(),
    });
  }
}

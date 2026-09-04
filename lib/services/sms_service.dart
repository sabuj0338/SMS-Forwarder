import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:another_telephony/telephony.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/forward_status.dart';
import '../models/queued_sms.dart';
import 'connectivity_service.dart';
import 'forward_service.dart';
import 'hive_bootstrap.dart';
import 'settings_service.dart';
import 'sms_filter.dart';
import 'sms_parser.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony telephony = Telephony.instance;
  final ValueNotifier<bool> isListening = ValueNotifier(false);
  final ValueNotifier<bool> isBackfilling = ValueNotifier(false);
  static const _uuid = Uuid();

  bool _listening = false;

  Future<void> init() async {
    final granted = await telephony.requestSmsPermissions;
    if (granted != true) {
      isListening.value = false;
      developer.log('SMS permission denied', name: 'sms');
      return;
    }

    _ensureListener();
    isListening.value = true;
    unawaited(backfillRecentInbox());
  }

  void _ensureListener() {
    if (_listening) return;
    _listening = true;
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage sms) {
        unawaited(_handleSms(sms));
      },
      onBackgroundMessage: backgroundSmsHandler,
      listenInBackground: true,
    );
  }

  Future<void> _handleSms(SmsMessage sms, {bool triggerFlush = true}) async {
    final queued = _toQueued(sms);
    if (queued == null) return;
    await ForwardService().enqueue(queued, triggerFlush: triggerFlush);
  }

  /// Prefer TxnID uniqueness; else sender+body+minute so redeliveries dedupe
  /// but two real payments a minute apart still enqueue.
  static String contentHash(
    String sender,
    String body, {
    String? txnId,
    DateTime? receivedAt,
  }) {
    if (txnId != null && txnId.isNotEmpty) {
      return sha256.convert(utf8.encode('$sender|txn|$txnId')).toString();
    }
    final minute =
        (receivedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 60000;
    return sha256.convert(utf8.encode('$sender|$body|$minute')).toString();
  }

  QueuedSms? _toQueued(SmsMessage sms) {
    final sender = sms.address ?? '';
    final body = sms.body ?? '';
    if (sender.isEmpty || body.isEmpty) return null;

    if (!MessageFilter.matches(sender: sender, body: body)) {
      return null;
    }

    final receivedAt = DateTime.fromMillisecondsSinceEpoch(
      sms.date ?? DateTime.now().millisecondsSinceEpoch,
    );

    final parsed = SettingsService.structuredParseEnabled
        ? SmsParser.parse(body)
        : null;

    return QueuedSms(
      id: _uuid.v4(),
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      status: ForwardStatus.pending,
      payloadHash: contentHash(
        sender,
        body,
        txnId: parsed?.txnId,
        receivedAt: receivedAt,
      ),
      amount: parsed?.amount,
      txnId: parsed?.txnId,
      txnType: parsed?.type,
      counterparty: parsed?.counterparty,
    );
  }

  /// Catch SMS received while the process was dead (reboot / force-stop).
  Future<void> backfillRecentInbox({
    Duration lookback = const Duration(hours: 72),
    int maxMessages = 400,
  }) async {
    if (isBackfilling.value) return;
    isBackfilling.value = true;
    try {
      final granted = await telephony.requestSmsPermissions;
      if (granted != true) return;

      final sinceMs =
          DateTime.now().subtract(lookback).millisecondsSinceEpoch;

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      var scanned = 0;
      for (final sms in messages) {
        scanned++;
        if (scanned > maxMessages) break;
        final date = sms.date ?? 0;
        if (date < sinceMs) break;
        await _handleSms(sms, triggerFlush: false);
      }

      developer.log('Inbox backfill scanned=$scanned', name: 'sms');
      await ForwardService().recoverAndFlush();
    } catch (e, st) {
      developer.log('Inbox backfill error: $e', name: 'sms', stackTrace: st);
    } finally {
      isBackfilling.value = false;
    }
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundSmsHandler(SmsMessage sms) async {
    try {
      await HiveBootstrap.ensureReady();
      // Ensure settings keys exist in this isolate's box view.
      await SettingsService.init();
      await ConnectivityService().refresh();

      final service = SmsService();
      final queued = service._toQueued(sms);
      if (queued == null) return;
      await ForwardService().enqueue(queued, triggerFlush: true);
    } catch (e, st) {
      developer.log(
        'Background SMS handler error: $e',
        name: 'sms',
        stackTrace: st,
      );
    }
  }
}

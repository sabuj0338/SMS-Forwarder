import 'dart:convert';

import '../models/queued_sms.dart';
import 'settings_service.dart';
import 'sms_parser.dart';

class PayloadBuilder {
  /// Headers sent on every forward / test request.
  /// Order: built-ins → auth → user fixed headers (user can override built-ins).
  static Map<String, String> buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Device-Id': SettingsService.deviceId,
      'X-Client': 'SMS-Forwarder',
    };

    final token = SettingsService.apiToken;
    switch (SettingsService.authType) {
      case AuthType.none:
        break;
      case AuthType.bearer:
        if (token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        break;
      case AuthType.apiKey:
        if (token.isNotEmpty) {
          headers[SettingsService.apiKeyHeader] = token;
        }
        break;
      case AuthType.basic:
        if (token.isNotEmpty) {
          headers['Authorization'] =
              'Basic ${base64Encode(utf8.encode(token))}';
        }
        break;
    }

    for (final entry in _parseHeaderLines(SettingsService.customHeaders).entries) {
      headers[entry.key] = _resolveHeaderValue(entry.value);
    }

    return headers;
  }

  static Map<String, String> _parseHeaderLines(List<String> lines) {
    final map = <String, String>{};
    for (final line in lines) {
      final parsed = parseHeaderLine(line);
      if (parsed == null) continue;
      map[parsed.key] = parsed.value;
    }
    return map;
  }

  /// Parse a single `Name: Value` line. Returns null if invalid.
  static MapEntry<String, String>? parseHeaderLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final idx = trimmed.indexOf(':');
    if (idx <= 0) return null;
    final key = trimmed.substring(0, idx).trim();
    final value = trimmed.substring(idx + 1).trim();
    if (key.isEmpty) return null;
    return MapEntry(key, value);
  }

  /// Support `{{device_id}}` (and future placeholders) in header values.
  static String _resolveHeaderValue(String value) {
    return value.replaceAll('{{device_id}}', SettingsService.deviceId);
  }

  /// Normalize multiline / list input into clean `Name: Value` lines.
  static List<String> normalizeHeaderLines(String raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final line in raw.split('\n')) {
      final parsed = parseHeaderLine(line);
      if (parsed == null) continue;
      final normalized = '${parsed.key}: ${parsed.value}';
      final keyLower = parsed.key.toLowerCase();
      if (seen.contains(keyLower)) {
        out.removeWhere(
          (e) => e.split(':').first.trim().toLowerCase() == keyLower,
        );
      }
      seen.add(keyLower);
      out.add(normalized);
    }
    return out;
  }

  static String buildBody({
    required String sender,
    required String body,
    required DateTime receivedAt,
    double? amount,
    String? txnId,
    String? type,
    String? counterparty,
    String? currency,
    bool test = false,
  }) {
    ParsedSms? parsed;
    if (SettingsService.structuredParseEnabled) {
      parsed = SmsParser.parse(body);
    }

    final values = <String, String>{
      'device_id': SettingsService.deviceId,
      'sender': sender,
      'body': body,
      'received_at': receivedAt.toUtc().toIso8601String(),
      'amount': _numOrEmpty(amount ?? parsed?.amount),
      'txn_id': txnId ?? parsed?.txnId ?? '',
      'type': type ?? parsed?.type ?? '',
      'counterparty': counterparty ?? parsed?.counterparty ?? '',
      'currency': currency ?? parsed?.currency ?? '',
    };

    try {
      final decoded = jsonDecode(SettingsService.payloadTemplate);
      final resolved = _resolve(decoded, values);
      var normalized = _coerceTypes(resolved);
      if (normalized is Map) {
        normalized = _mergeStructured(
          Map<String, dynamic>.from(normalized),
          values,
        );
      }
      if (test && normalized is Map<String, dynamic>) {
        normalized['test'] = true;
      } else if (test && normalized is Map) {
        final map = Map<String, dynamic>.from(normalized);
        map['test'] = true;
        return jsonEncode(map);
      }
      return jsonEncode(normalized);
    } catch (_) {
      return jsonEncode({
        'device_id': values['device_id'],
        'sender': values['sender'],
        'body': values['body'],
        'received_at': values['received_at'],
        if (values['amount']!.isNotEmpty)
          'amount': double.tryParse(values['amount']!) ?? values['amount'],
        if (values['txn_id']!.isNotEmpty) 'txn_id': values['txn_id'],
        if (values['type']!.isNotEmpty) 'type': values['type'],
        if (values['counterparty']!.isNotEmpty)
          'counterparty': values['counterparty'],
        if (values['currency']!.isNotEmpty) 'currency': values['currency'],
        if (test) 'test': true,
      });
    }
  }

  static Map<String, dynamic> _mergeStructured(
    Map<String, dynamic> map,
    Map<String, String> values,
  ) {
    if (!SettingsService.structuredParseEnabled) return map;
    void put(String key, String raw, {bool asNumber = false}) {
      if (raw.isEmpty) return;
      if (map.containsKey(key) && map[key] != null && map[key] != '') return;
      if (asNumber) {
        final n = double.tryParse(raw);
        if (n != null) {
          map[key] = n;
          return;
        }
      }
      map[key] = raw;
    }

    put('amount', values['amount'] ?? '', asNumber: true);
    put('txn_id', values['txn_id'] ?? '');
    put('type', values['type'] ?? '');
    put('counterparty', values['counterparty'] ?? '');
    put('currency', values['currency'] ?? '');
    return map;
  }

  static String _numOrEmpty(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static dynamic _coerceTypes(dynamic node) {
    if (node is Map) {
      final map = <String, dynamic>{
        for (final e in node.entries)
          e.key.toString(): _coerceTypes(e.value),
      };
      final amount = map['amount'];
      if (amount is String && amount.isNotEmpty) {
        final n = double.tryParse(amount);
        if (n != null) map['amount'] = n;
      }
      for (final key in [
        'txn_id',
        'type',
        'counterparty',
        'currency',
        'amount',
      ]) {
        final v = map[key];
        if (v == null || v == '') map.remove(key);
      }
      return map;
    }
    if (node is List) {
      return [for (final item in node) _coerceTypes(item)];
    }
    return node;
  }

  static dynamic _resolve(dynamic node, Map<String, String> values) {
    if (node is String) {
      var s = node;
      for (final entry in values.entries) {
        s = s.replaceAll('{{${entry.key}}}', entry.value);
      }
      return s;
    }
    if (node is Map) {
      return <String, dynamic>{
        for (final entry in node.entries)
          entry.key.toString(): _resolve(entry.value, values),
      };
    }
    if (node is List) {
      return [for (final item in node) _resolve(item, values)];
    }
    return node;
  }

  static String buildBodyForSms(QueuedSms sms, {bool test = false}) {
    return buildBody(
      sender: sms.sender,
      body: sms.body,
      receivedAt: sms.receivedAt,
      amount: sms.amount,
      txnId: sms.txnId,
      type: sms.txnType,
      counterparty: sms.counterparty,
      currency: sms.amount != null ? 'BDT' : null,
      test: test,
    );
  }
}

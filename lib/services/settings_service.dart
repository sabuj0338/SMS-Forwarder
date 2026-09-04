import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

enum AuthType {
  none,
  bearer,
  apiKey,
  basic,
}

extension AuthTypeX on AuthType {
  String get label {
    switch (this) {
      case AuthType.none:
        return 'None';
      case AuthType.bearer:
        return 'Bearer token';
      case AuthType.apiKey:
        return 'API key header';
      case AuthType.basic:
        return 'Basic auth';
    }
  }
}

class SettingsService {
  static const boxName = 'settings';
  static const _uuid = Uuid();

  static const defaultPayloadTemplate = '''{
  "device_id": "{{device_id}}",
  "sender": "{{sender}}",
  "body": "{{body}}",
  "received_at": "{{received_at}}",
  "amount": "{{amount}}",
  "txn_id": "{{txn_id}}",
  "type": "{{type}}",
  "counterparty": "{{counterparty}}",
  "currency": "{{currency}}"
}''';

  static Box get _box => Hive.box(boxName);

  static bool _initialized = false;

  static Future<void> init() async {
    await Hive.openBox(boxName);
    if (_initialized) return;
    _initialized = true;
    if (!_box.containsKey('device_id')) {
      await _box.put('device_id', _uuid.v4());
    }
    if (!_box.containsKey('allowed_senders')) {
      await _box.put('allowed_senders', <String>['bKash', '16216', 'Nagad']);
    }
    if (!_box.containsKey('theme_mode')) {
      await _box.put('theme_mode', ThemeMode.system.index);
    }
    if (!_box.containsKey('forwarding_enabled')) {
      await _box.put('forwarding_enabled', true);
    }
    if (!_box.containsKey('api_url')) {
      await _box.put('api_url', '');
    }
    if (!_box.containsKey('api_token')) {
      await _box.put('api_token', '');
    }
    if (!_box.containsKey('auth_type')) {
      await _box.put('auth_type', AuthType.bearer.index);
    }
    if (!_box.containsKey('api_key_header')) {
      await _box.put('api_key_header', 'X-API-Key');
    }
    if (!_box.containsKey('custom_headers')) {
      await _box.put('custom_headers', <String>[]);
    }
    if (!_box.containsKey('payload_template')) {
      await _box.put('payload_template', defaultPayloadTemplate);
    }
    if (!_box.containsKey('include_keywords')) {
      await _box.put('include_keywords', <String>[]);
    }
    if (!_box.containsKey('exclude_keywords')) {
      await _box.put('exclude_keywords', <String>[]);
    }
    if (!_box.containsKey('filters_use_regex')) {
      await _box.put('filters_use_regex', false);
    }
    if (!_box.containsKey('battery_prompt_dismissed')) {
      await _box.put('battery_prompt_dismissed', false);
    }
    if (!_box.containsKey('app_lock_enabled')) {
      await _box.put('app_lock_enabled', false);
    }
    if (!_box.containsKey('pin_hash')) {
      await _box.put('pin_hash', '');
    }
    if (!_box.containsKey('structured_parse_enabled')) {
      await _box.put('structured_parse_enabled', true);
    }
  }

  static String get deviceId =>
      _box.get('device_id', defaultValue: '') as String;

  static String get apiUrl => _box.get('api_url', defaultValue: '') as String;

  static Future<void> setApiUrl(String value) =>
      _box.put('api_url', value.trim());

  static String get apiToken =>
      _box.get('api_token', defaultValue: '') as String;

  static Future<void> setApiToken(String value) =>
      _box.put('api_token', value.trim());

  static AuthType get authType {
    final index = _box.get('auth_type', defaultValue: AuthType.bearer.index)
        as int;
    return AuthType.values[index.clamp(0, AuthType.values.length - 1)];
  }

  static Future<void> setAuthType(AuthType type) =>
      _box.put('auth_type', type.index);

  static String get apiKeyHeader =>
      _box.get('api_key_header', defaultValue: 'X-API-Key') as String;

  static Future<void> setApiKeyHeader(String value) =>
      _box.put('api_key_header', value.trim().isEmpty ? 'X-API-Key' : value.trim());

  static List<String> get customHeaders => _stringList('custom_headers');

  static Future<void> setCustomHeaders(List<String> value) =>
      _box.put('custom_headers', value);

  static String get payloadTemplate {
    final raw = _box.get('payload_template', defaultValue: defaultPayloadTemplate)
        as String;
    return raw.trim().isEmpty ? defaultPayloadTemplate : raw;
  }

  static Future<void> setPayloadTemplate(String value) =>
      _box.put('payload_template', value);

  static List<String> get allowedSenders => _stringList('allowed_senders');

  static Future<void> setAllowedSenders(List<String> value) =>
      _box.put('allowed_senders', value);

  static List<String> get includeKeywords => _stringList('include_keywords');

  static Future<void> setIncludeKeywords(List<String> value) =>
      _box.put('include_keywords', value);

  static List<String> get excludeKeywords => _stringList('exclude_keywords');

  static Future<void> setExcludeKeywords(List<String> value) =>
      _box.put('exclude_keywords', value);

  static bool get filtersUseRegex =>
      _box.get('filters_use_regex', defaultValue: false) as bool;

  static Future<void> setFiltersUseRegex(bool value) =>
      _box.put('filters_use_regex', value);

  static bool get forwardingEnabled =>
      _box.get('forwarding_enabled', defaultValue: true) as bool;

  static Future<void> setForwardingEnabled(bool value) =>
      _box.put('forwarding_enabled', value);

  static ThemeMode get themeMode {
    final index =
        _box.get('theme_mode', defaultValue: ThemeMode.system.index) as int;
    return ThemeMode.values[index.clamp(0, ThemeMode.values.length - 1)];
  }

  static Future<void> setThemeMode(ThemeMode mode) =>
      _box.put('theme_mode', mode.index);

  static bool get isApiConfigured => apiUrl.trim().isNotEmpty;

  static bool get batteryPromptDismissed =>
      _box.get('battery_prompt_dismissed', defaultValue: false) as bool;

  static Future<void> setBatteryPromptDismissed(bool value) =>
      _box.put('battery_prompt_dismissed', value);

  static bool get appLockEnabled =>
      _box.get('app_lock_enabled', defaultValue: false) as bool;

  static Future<void> setAppLockEnabled(bool value) =>
      _box.put('app_lock_enabled', value);

  static String get pinHash =>
      _box.get('pin_hash', defaultValue: '') as String;

  static bool get hasPin => pinHash.isNotEmpty;

  static String hashPin(String pin) {
    final bytes = utf8.encode('$deviceId|$pin');
    return sha256.convert(bytes).toString();
  }

  static Future<void> setPin(String pin) async {
    await _box.put('pin_hash', hashPin(pin));
    await _box.put('app_lock_enabled', true);
  }

  static Future<void> clearPin() async {
    await _box.put('pin_hash', '');
    await _box.put('app_lock_enabled', false);
  }

  static bool verifyPin(String pin) =>
      hasPin && hashPin(pin) == pinHash;

  static bool get structuredParseEnabled =>
      _box.get('structured_parse_enabled', defaultValue: true) as bool;

  static Future<void> setStructuredParseEnabled(bool value) =>
      _box.put('structured_parse_enabled', value);

  static List<String> _stringList(String key) {
    final raw = _box.get(key, defaultValue: <String>[]);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  static ValueListenable listenable() => _box.listenable();
}

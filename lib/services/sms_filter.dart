import 'dart:developer' as developer;

import 'settings_service.dart';

class MessageFilter {
  /// Returns true if this SMS should be queued/forwarded.
  static bool matches({
    required String sender,
    required String body,
  }) {
    final allowList = SettingsService.allowedSenders;
    if (allowList.isNotEmpty) {
      final senderOk = allowList.any(
        (a) => sender.toLowerCase().contains(a.toLowerCase()),
      );
      if (!senderOk) {
        developer.log('Sender filtered out: $sender', name: 'filter');
        return false;
      }
    }

    final useRegex = SettingsService.filtersUseRegex;
    final include = SettingsService.includeKeywords;
    final exclude = SettingsService.excludeKeywords;

    if (include.isNotEmpty) {
      final ok = include.any((rule) => _matchesRule(body, rule, useRegex));
      if (!ok) {
        developer.log('Include keyword miss: $sender', name: 'filter');
        return false;
      }
    }

    for (final rule in exclude) {
      if (_matchesRule(body, rule, useRegex)) {
        developer.log('Exclude keyword hit: $rule', name: 'filter');
        return false;
      }
    }

    return true;
  }

  static bool _matchesRule(String body, String rule, bool useRegex) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return false;
    if (!useRegex) {
      return body.toLowerCase().contains(trimmed.toLowerCase());
    }
    try {
      return RegExp(trimmed, caseSensitive: false).hasMatch(body);
    } catch (e) {
      developer.log('Invalid regex "$trimmed": $e', name: 'filter');
      return false;
    }
  }
}

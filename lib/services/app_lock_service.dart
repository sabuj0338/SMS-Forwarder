import 'package:flutter/foundation.dart';

import 'settings_service.dart';

/// UI-only PIN gate. Does **not** pause SMS listening, Hive queue, or forwarding.
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final ValueNotifier<bool> isLocked = ValueNotifier(false);

  void init() {
    isLocked.value =
        SettingsService.appLockEnabled && SettingsService.hasPin;
  }

  void lockIfEnabled() {
    if (SettingsService.appLockEnabled && SettingsService.hasPin) {
      isLocked.value = true;
    }
  }

  bool unlock(String pin) {
    if (!SettingsService.verifyPin(pin)) return false;
    isLocked.value = false;
    return true;
  }

  void unlockWithoutPin() {
    // Used only when lock is disabled.
    isLocked.value = false;
  }
}

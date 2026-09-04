import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'settings_service.dart';

class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final ValueNotifier<bool> isOptimizedAway = ValueNotifier(true);

  Future<void> refresh() async {
    if (!Platform.isAndroid) {
      isOptimizedAway.value = true;
      return;
    }
    try {
      final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      final pluginDisabled =
          await DisableBatteryOptimization.isBatteryOptimizationDisabled ??
              false;
      isOptimizedAway.value = ignoring || pluginDisabled;
    } catch (_) {
      isOptimizedAway.value = false;
    }
  }

  bool get shouldShowBanner {
    if (!Platform.isAndroid) return false;
    if (SettingsService.batteryPromptDismissed) return false;
    return !isOptimizedAway.value;
  }

  Future<void> requestIgnoreOptimization() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }
    await refresh();
  }

  Future<void> openOptimizationSettings() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    await refresh();
  }

  Future<void> showManufacturerGuide() async {
    if (!Platform.isAndroid) return;
    await DisableBatteryOptimization
        .showDisableManufacturerBatteryOptimizationSettings(
      'Extra battery settings',
      'Some phones (Xiaomi, Oppo, Vivo, Samsung, Huawei) need extra steps so SMS Forwarder stays alive. Follow the steps on the next screen.',
    );
  }

  Future<void> showAutoStartGuide() async {
    if (!Platform.isAndroid) return;
    await DisableBatteryOptimization.showEnableAutoStartSettings(
      'Enable Auto-start',
      'Allow SMS Forwarder to start after reboot so messages keep forwarding.',
    );
  }

  Future<void> showAllGuides() async {
    if (!Platform.isAndroid) return;
    await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
      'Enable Auto-start',
      'Allow SMS Forwarder to start after reboot so messages keep forwarding.',
      'Extra battery settings',
      'Follow device-specific steps (Xiaomi, Oppo, Vivo, Samsung, Huawei) so listening stays alive.',
    );
    await refresh();
  }
}

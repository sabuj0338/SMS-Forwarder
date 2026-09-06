import 'package:hive_flutter/hive_flutter.dart';

import '../models/forward_status.dart';
import '../models/queued_sms.dart';
import 'forward_service.dart';
import 'settings_service.dart';

/// Safe Hive bootstrap for main, SMS background, and foreground-task isolates.
class HiveBootstrap {
  static bool _adaptersRegistered = false;

  static Future<void> ensureReady() async {
    await Hive.initFlutter();
    if (!_adaptersRegistered) {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ForwardStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(QueuedSmsAdapter());
      }
      _adaptersRegistered = true;
    }
    if (!Hive.isBoxOpen(SettingsService.boxName)) {
      await Hive.openBox(SettingsService.boxName);
    }
    if (!Hive.isBoxOpen(ForwardService.boxName)) {
      await Hive.openBox<QueuedSms>(ForwardService.boxName);
    }
    if (!Hive.isBoxOpen(ForwardService.dedupeBoxName)) {
      await Hive.openBox(ForwardService.dedupeBoxName);
    }
  }
}

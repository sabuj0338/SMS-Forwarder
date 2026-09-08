import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'services/app_lock_service.dart';
import 'services/battery_service.dart';
import 'services/connectivity_service.dart';
import 'services/foreground_service.dart';
import 'services/forward_service.dart';
import 'services/hive_bootstrap.dart';
import 'services/settings_service.dart';
import 'services/sms_service.dart';
import 'services/sync_scheduler.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final fg = ForegroundService();
  fg.initCommunication();

  await HiveBootstrap.ensureReady();
  await SettingsService.init();
  AppLockService().init();

  await ConnectivityService().init();
  await ForwardService().recoverStuckSending();
  await SmsService().init();
  await fg.init();
  fg.bindCallbacks();
  await SyncScheduler.init();

  unawaited(ForwardService().recoverAndFlush());
  unawaited(BatteryService().refresh());

  runApp(const SmsForwarderApp());
}

class SmsForwarderApp extends StatefulWidget {
  const SmsForwarderApp({super.key});

  @override
  State<SmsForwarderApp> createState() => _SmsForwarderAppState();
}

class _SmsForwarderAppState extends State<SmsForwarderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SyncScheduler.applyFromSettings();
      await BatteryService().refresh();
      // Second-chance backfill after UI is up (permissions dialogs settled).
      unawaited(SmsService().backfillRecentInbox());
      unawaited(ForwardService().recoverAndFlush());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App lock is UI-only — SMS receiver + sync keep running.
    if (state == AppLifecycleState.paused) {
      AppLockService().lockIfEnabled();
      // Persist any in-flight Hive writes before process may be frozen.
      unawaited(ForwardService().recoverStuckSending());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    }
  }

  Future<void> _onResume() async {
    await BatteryService().refresh();
    await ConnectivityService().refresh();
    // Re-apply FGS vs AlarmManager so a lost alarm / stale FGS is corrected.
    await SyncScheduler.applyFromSettings();
    await ForwardService().recoverStuckSending();
    unawaited(SmsService().backfillRecentInbox());
    unawaited(ForwardService().recoverAndFlush());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.listenable(),
      builder: (context, box, child) {
        return MaterialApp(
          title: 'SMS Forwarder',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: SettingsService.themeMode,
          home: WithForegroundTask(
            child: ValueListenableBuilder<bool>(
              valueListenable: AppLockService().isLocked,
              builder: (context, locked, child) {
                // Lock only covers the UI. Background SMS + queue continue.
                if (locked) return const LockScreen();
                return const HomeScreen();
              },
            ),
          ),
        );
      },
    );
  }
}

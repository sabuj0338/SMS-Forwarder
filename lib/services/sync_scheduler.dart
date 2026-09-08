import 'dart:developer' as developer;
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'connectivity_service.dart';
import 'foreground_service.dart';
import 'forward_service.dart';
import 'hive_bootstrap.dart';
import 'settings_service.dart';
import 'sms_service.dart';

/// Periodic background sync when the foreground keepalive service is off.
class SyncScheduler {
  static const alarmId = 42001;

  /// Allowed AlarmManager intervals (minutes).
  static const allowedIntervals = [5, 15, 30, 60];

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
  }

  /// Start FGS **or** schedule AlarmManager — never leave the user with neither.
  static Future<void> applyFromSettings() async {
    if (!Platform.isAndroid) return;

    // Keep boot auto-start in sync with the toggle (avoids FGS flash when off).
    await ForegroundService().init(
      autoRunOnBoot: SettingsService.realtimeKeepAliveEnabled,
    );

    if (SettingsService.realtimeKeepAliveEnabled) {
      final ok = await ForegroundService().start();
      if (ok) {
        await cancelAlarm();
        developer.log('Realtime keepalive ON (FGS)', name: 'sync');
        return;
      }
      // FGS failed (e.g. notification permission) — keep AlarmManager so sync continues.
      developer.log(
        'FGS start failed — falling back to AlarmManager',
        name: 'sync',
      );
      await scheduleAlarm();
      return;
    }

    await ForegroundService().stop();
    await scheduleAlarm();
    developer.log(
      'Realtime keepalive OFF — alarm every '
      '${SettingsService.syncIntervalMinutes}m',
      name: 'sync',
    );
  }

  /// Schedules the next sync tick.
  ///
  /// Uses exact one-shot + self-reschedule so intervals like 5 minutes actually
  /// fire (inexact [periodic] is typically batched to ≥15 minutes on Android).
  static Future<void> scheduleAlarm() async {
    if (!Platform.isAndroid) return;

    await init();
    final minutes = SettingsService.syncIntervalMinutes;
    await AndroidAlarmManager.cancel(alarmId);

    var ok = await AndroidAlarmManager.oneShot(
      Duration(minutes: minutes),
      alarmId,
      alarmSyncCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );

    if (!ok) {
      // Exact alarm may be blocked (Android 14+). Fall back to inexact repeating.
      developer.log(
        'Exact one-shot failed — falling back to inexact periodic',
        name: 'sync',
      );
      ok = await AndroidAlarmManager.periodic(
        Duration(minutes: minutes),
        alarmId,
        alarmSyncCallback,
        exact: false,
        wakeup: true,
        allowWhileIdle: false,
        rescheduleOnReboot: true,
      );
    }

    developer.log(
      'Alarm scheduled every ${minutes}m ok=$ok',
      name: 'sync',
    );
  }

  static Future<void> cancelAlarm() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// Pull-to-refresh / Sync now: inbox backfill + forced queue flush.
  static Future<ManualSyncResult> runManualSync() async {
    final added = await SmsService().backfillRecentInbox();
    // Always flush after (backfill may early-return if already running / no SMS perm).
    await ForwardService().recoverAndFlush(forceAll: true);
    await ForegroundService().updateNotificationFromCounts();
    return ManualSyncResult(addedFromInbox: added);
  }
}

class ManualSyncResult {
  final int addedFromInbox;
  const ManualSyncResult({required this.addedFromInbox});
}

/// Alarm isolate entry — must stay top-level.
@pragma('vm:entry-point')
Future<void> alarmSyncCallback() async {
  try {
    await HiveBootstrap.ensureReady();
    await SettingsService.init();
    if (SettingsService.realtimeKeepAliveEnabled) {
      // FGS mode owns sync; ignore stray alarms.
      return;
    }
    await ConnectivityService().refresh();
    await SmsService().backfillRecentInbox();
    // Backfill already flushes; call again in case backfill early-returned.
    await ForwardService().recoverAndFlush();
    developer.log('Alarm sync tick done', name: 'sync');
  } catch (e, st) {
    developer.log('Alarm sync error: $e', name: 'sync', stackTrace: st);
  } finally {
    // oneShot does not repeat — chain the next tick while still in alarm mode.
    try {
      await HiveBootstrap.ensureReady();
      await SettingsService.init();
      if (!SettingsService.realtimeKeepAliveEnabled) {
        await SyncScheduler.scheduleAlarm();
      }
    } catch (e, st) {
      developer.log(
        'Failed to reschedule alarm: $e',
        name: 'sync',
        stackTrace: st,
      );
    }
  }
}

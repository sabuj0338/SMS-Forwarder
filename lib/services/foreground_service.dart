import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'connectivity_service.dart';
import 'forward_service.dart';
import 'hive_bootstrap.dart';
import 'settings_service.dart';

/// Top-level entry for the foreground task isolate.
@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(ForwardTaskHandler());
}

class ForwardTaskHandler extends TaskHandler {
  bool _busy = false;

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      await HiveBootstrap.ensureReady();
      await SettingsService.init();
      await ConnectivityService().refresh();
      // Flush here — works even when UI/main isolate is dead (app swiped away).
      await ForwardService().recoverAndFlush();
      final counts = ForwardService().counts();
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SMS Forwarder listening',
        notificationText:
            'Pending ${counts['pending']} · Failed ${counts['failed']} · Tap to open',
      );
      // Also nudge UI isolate if alive.
      FlutterForegroundTask.sendDataToMain({'action': 'flush_done'});
    } catch (e, st) {
      developer.log('FG tick error: $e', name: 'fg', stackTrace: st);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    developer.log('Foreground task started (${starter.name})', name: 'fg');
    await _tick();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_tick());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    developer.log('Foreground task destroyed', name: 'fg');
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['action'] == 'flush') {
      unawaited(_tick());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'sync') {
      unawaited(_tick());
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}

class ForegroundService {
  static final ForegroundService _instance = ForegroundService._internal();
  factory ForegroundService() => _instance;
  ForegroundService._internal();

  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  bool _callbackBound = false;

  void initCommunication() {
    FlutterForegroundTask.initCommunicationPort();
  }

  void bindCallbacks() {
    if (_callbackBound) return;
    _callbackBound = true;
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  void _onTaskData(Object data) {
    if (data is Map && data['action'] == 'flush') {
      unawaited(ForwardService().recoverAndFlush());
      unawaited(updateNotificationFromCounts());
    }
    // flush_done from FG isolate — refresh counts in UI only
    if (data is Map && data['action'] == 'flush_done') {
      unawaited(updateNotificationFromCounts());
    }
  }

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sms_forwarder_listening',
        channelName: 'SMS Forwarder',
        channelDescription:
            'Shows while SMS Forwarder is listening in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Faster sync loop while keeping battery reasonable.
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> ensurePermissions() async {
    if (!Platform.isAndroid) return;

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    await ensurePermissions();

    final counts = ForwardService().counts();
    final text =
        'Pending ${counts['pending']} · Failed ${counts['failed']} · Tap to open';

    final ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'SMS Forwarder listening',
        notificationText: text,
        notificationButtons: [
          const NotificationButton(id: 'sync', text: 'Sync'),
        ],
        callback: startForegroundCallback,
      );
    }

    final running = await FlutterForegroundTask.isRunningService;
    isRunning.value = running;
    developer.log('Foreground start: $result running=$running', name: 'fg');
    return running;
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
    isRunning.value = false;
  }

  Future<void> refreshRunningState() async {
    if (!Platform.isAndroid) {
      isRunning.value = false;
      return;
    }
    isRunning.value = await FlutterForegroundTask.isRunningService;
  }

  Future<void> updateNotificationFromCounts() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    final counts = ForwardService().counts();
    await FlutterForegroundTask.updateService(
      notificationTitle: 'SMS Forwarder listening',
      notificationText:
          'Pending ${counts['pending']} · Failed ${counts['failed']} · Tap to open',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/queued_sms.dart';
import '../models/forward_status.dart';
import '../services/battery_service.dart';
import '../services/connectivity_service.dart';
import '../services/export_service.dart';
import '../services/foreground_service.dart';
import '../services/forward_service.dart';
import '../services/settings_service.dart';
import '../services/sms_service.dart';
import '../widgets/message_tile.dart';
import 'message_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<QueuedSms>(ForwardService.boxName);
    final smsService = SmsService();
    final forward = ForwardService();
    final connectivity = ConnectivityService();
    final fg = ForegroundService();
    final battery = BatteryService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Forwarder'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: forward.isSyncing,
            builder: (context, syncing, child) {
              if (!syncing) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () async {
              await forward.flushPending();
              await fg.updateNotificationFromCounts();
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final messenger = ScaffoldMessenger.of(context);
              switch (value) {
                case 'export_all':
                  await ExportService.shareLog();
                  break;
                case 'export_failed':
                  await ExportService.shareLog(onlyStatus: ForwardStatus.failed);
                  break;
                case 'clear_sent':
                  final n = await forward.clearSent();
                  await fg.updateNotificationFromCounts();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Cleared $n sent messages')),
                  );
                  break;
                case 'clear_failed':
                  final n = await forward.clearFailed();
                  await fg.updateNotificationFromCounts();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Cleared $n failed messages')),
                  );
                  break;
                case 'clear_all':
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear all messages?'),
                      content: const Text(
                        'This deletes the entire local queue and cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final n = await forward.clearAll();
                    await fg.updateNotificationFromCounts();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Cleared $n messages')),
                    );
                  }
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export_all', child: Text('Export all (JSON)')),
              PopupMenuItem(
                value: 'export_failed',
                child: Text('Export failed (JSON)'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear_sent', child: Text('Clear sent')),
              PopupMenuItem(value: 'clear_failed', child: Text('Clear failed')),
              PopupMenuItem(value: 'clear_all', child: Text('Clear all…')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _BatteryBanner(battery: battery),
          _StatusBar(
            smsService: smsService,
            connectivity: connectivity,
            foreground: fg,
            box: box,
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<QueuedSms> queue, _) {
                final items = queue.values.toList()
                  ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sms_outlined,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Matching SMS will appear here and forward to your API when online.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final sms = items[i];
                    return MessageTile(
                      sms: sms,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessageDetailScreen(sms: sms),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryBanner extends StatelessWidget {
  final BatteryService battery;

  const _BatteryBanner({required this.battery});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.listenable(),
      builder: (context, _, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: battery.isOptimizedAway,
          builder: (context, optimizedAway, child) {
            if (!battery.shouldShowBanner) {
              return const SizedBox.shrink();
            }
            final scheme = Theme.of(context).colorScheme;
            return Material(
              color: scheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.battery_alert, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allow unrestricted battery use',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                          Text(
                            'OEM power saving can stop SMS listening. Disable battery optimization for reliable forwarding.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () =>
                                    battery.requestIgnoreOptimization(),
                                child: const Text('Fix now'),
                              ),
                              TextButton(
                                onPressed: () => battery.showAllGuides(),
                                child: const Text('Device guide'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () =>
                          SettingsService.setBatteryPromptDismissed(true),
                      icon: Icon(
                        Icons.close,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  final SmsService smsService;
  final ConnectivityService connectivity;
  final ForegroundService foreground;
  final Box<QueuedSms> box;

  const _StatusBar({
    required this.smsService,
    required this.connectivity,
    required this.foreground,
    required this.box,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.listenable(),
      builder: (context, settingsBox, child) {
        return ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<QueuedSms> queueBox, child) {
            final counts = ForwardService().counts();
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: smsService.isListening,
                          builder: (context, listening, child) => _Chip(
                            icon: listening
                                ? Icons.sensors
                                : Icons.sensors_off,
                            label: listening ? 'Listening' : 'No SMS access',
                            ok: listening,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: foreground.isRunning,
                          builder: (context, running, child) => _Chip(
                            icon: running
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            label: running ? 'Service on' : 'Service off',
                            ok: running,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: connectivity.isOnline,
                          builder: (context, online, child) => _Chip(
                            icon: online ? Icons.wifi : Icons.wifi_off,
                            label: online ? 'Online' : 'Offline',
                            ok: online,
                          ),
                        ),
                        _Chip(
                          icon: SettingsService.forwardingEnabled
                              ? Icons.play_arrow
                              : Icons.pause,
                          label: SettingsService.forwardingEnabled
                              ? 'Forwarding'
                              : 'Paused',
                          ok: SettingsService.forwardingEnabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Count(label: 'Pending', value: counts['pending']!),
                        _Count(label: 'Sent', value: counts['sent']!),
                        _Count(label: 'Failed', value: counts['failed']!),
                        if (!SettingsService.isApiConfigured)
                          Expanded(
                            child: Text(
                              'Set API URL in Settings',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;

  const _Chip({required this.icon, required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;

  const _Count({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

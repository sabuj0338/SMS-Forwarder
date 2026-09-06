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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Forwarder'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: forward.isSyncing,
            builder: (context, syncing, child) {
              if (!syncing) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.only(right: 4),
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
          IconButton.filledTonal(
            tooltip: 'Sync now',
            onPressed: () async {
              await forward.flushPending();
              await fg.updateNotificationFromCounts();
            },
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'More',
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
              PopupMenuItem(
                value: 'export_all',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share_outlined),
                  title: Text('Export all'),
                ),
              ),
              PopupMenuItem(
                value: 'export_failed',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.report_gmailerrorred_outlined),
                  title: Text('Export failed'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear_sent',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.done_all_outlined),
                  title: Text('Clear sent'),
                ),
              ),
              PopupMenuItem(
                value: 'clear_failed',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Clear failed'),
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined),
                  title: Text('Clear all…'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                Text(
                  'Pull to re-scan inbox',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<QueuedSms> queue, _) {
                final items = queue.values.toList()
                  ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

                Future<void> onRefresh() async {
                  final added = await smsService.backfillRecentInbox();
                  await fg.updateNotificationFromCounts();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added > 0
                            ? 'Found $added new matching message${added == 1 ? '' : 's'}'
                            : 'Inbox re-scanned — no new matching messages',
                      ),
                    ),
                  );
                }

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.48,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: scheme.primaryContainer
                                          .withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sms_outlined,
                                      size: 40,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'No messages yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Matching SMS will show up here.\nPull down to re-scan allowed senders.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
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
                  ),
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
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.battery_alert_rounded,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allow unrestricted battery use',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OEM power saving can stop SMS listening. Disable battery optimization for reliable forwarding.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: scheme.onTertiaryContainer
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
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
            final scheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: smsService.isListening,
                            builder: (context, listening, child) => _StatusChip(
                              icon: listening
                                  ? Icons.sensors
                                  : Icons.sensors_off,
                              label: listening ? 'Listening' : 'No SMS access',
                              ok: listening,
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: foreground.isRunning,
                            builder: (context, running, child) => _StatusChip(
                              icon: running
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              label: running ? 'Service on' : 'Service off',
                              ok: running,
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: connectivity.isOnline,
                            builder: (context, online, child) => _StatusChip(
                              icon: online ? Icons.wifi : Icons.wifi_off,
                              label: online ? 'Online' : 'Offline',
                              ok: online,
                            ),
                          ),
                          _StatusChip(
                            icon: SettingsService.forwardingEnabled
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            label: SettingsService.forwardingEnabled
                                ? 'Forwarding'
                                : 'Paused',
                            ok: SettingsService.forwardingEnabled,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _CountCard(
                              label: 'Pending',
                              value: counts['pending']!,
                              color: scheme.tertiary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CountCard(
                              label: 'Sent',
                              value: counts['sent']!,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CountCard(
                              label: 'Failed',
                              value: counts['failed']!,
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ),
                      if (!SettingsService.isApiConfigured) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: scheme.error,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Set API URL in Settings to start forwarding',
                                style: TextStyle(
                                  color: scheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? scheme.primary : scheme.outline;
    final bg = ok
        ? scheme.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

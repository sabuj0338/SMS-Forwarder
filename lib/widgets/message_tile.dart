import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/forward_status.dart';
import '../models/queued_sms.dart';

class StatusBadge extends StatelessWidget {
  final ForwardStatus status;

  const StatusBadge({super.key, required this.status});

  (IconData, Color) _style(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case ForwardStatus.pending:
        return (Icons.schedule, scheme.tertiary);
      case ForwardStatus.sending:
        return (Icons.sync, scheme.tertiary);
      case ForwardStatus.sent:
        return (Icons.check_circle_outline, scheme.primary);
      case ForwardStatus.failed:
        return (Icons.error_outline, scheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MessageTile extends StatelessWidget {
  final QueuedSms sms;
  final VoidCallback? onTap;

  const MessageTile({super.key, required this.sms, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('dd MMM · HH:mm').format(sms.receivedAt);
    final amountLabel = sms.amount == null
        ? null
        : '৳${sms.amount == sms.amount!.roundToDouble() ? sms.amount!.toInt() : sms.amount}';
    final trimmedSender = sms.sender.trim();
    final initial = trimmedSender.isEmpty
        ? '?'
        : trimmedSender.substring(0, 1).toUpperCase();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sms.sender,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: sms.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sms.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.35,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (amountLabel != null)
                          _MetaChip(
                            icon: Icons.payments_outlined,
                            label: amountLabel,
                            emphasize: true,
                          ),
                        if (sms.txnType != null && sms.txnType != 'unknown')
                          _MetaChip(
                            icon: Icons.swap_vert,
                            label: sms.txnType!,
                          ),
                        if (sms.txnId != null)
                          _MetaChip(
                            icon: Icons.tag,
                            label: sms.txnId!,
                          ),
                        _MetaChip(
                          icon: Icons.schedule,
                          label: time,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasize;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasize
            ? scheme.primary.withValues(alpha: 0.1)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

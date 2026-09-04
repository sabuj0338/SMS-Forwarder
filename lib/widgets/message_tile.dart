import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/forward_status.dart';
import '../models/queued_sms.dart';

class StatusBadge extends StatelessWidget {
  final ForwardStatus status;

  const StatusBadge({super.key, required this.status});

  Color _color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case ForwardStatus.pending:
      case ForwardStatus.sending:
        return scheme.tertiary;
      case ForwardStatus.sent:
        return scheme.primary;
      case ForwardStatus.failed:
        return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
    final time = DateFormat('dd MMM, HH:mm').format(sms.receivedAt);
    final amountLabel = sms.amount == null
        ? null
        : '৳${sms.amount == sms.amount!.roundToDouble() ? sms.amount!.toInt() : sms.amount}';
    final meta = [
      if (amountLabel != null) amountLabel,
      if (sms.txnType != null && sms.txnType != 'unknown') sms.txnType!,
      if (sms.txnId != null) 'Txn ${sms.txnId}',
      time,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                sms.sender,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusBadge(status: sms.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sms.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

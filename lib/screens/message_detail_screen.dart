import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/forward_status.dart';
import '../models/queued_sms.dart';
import '../services/forward_service.dart';
import '../services/sms_parser.dart';
import '../widgets/message_tile.dart';

class MessageDetailScreen extends StatefulWidget {
  final QueuedSms sms;

  const MessageDetailScreen({super.key, required this.sms});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final ok = await ForwardService().retry(widget.sms);
    if (!mounted) return;
    setState(() => _retrying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Forwarded successfully' : 'Forward failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sms = widget.sms;
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final parsed = (sms.amount == null && sms.txnId == null)
        ? SmsParser.parse(sms.body)
        : null;
    final amount = sms.amount ?? parsed?.amount;
    final txnId = sms.txnId ?? parsed?.txnId;
    final type = sms.txnType ?? parsed?.type;
    final counterparty = sms.counterparty ?? parsed?.counterparty;

    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sms.sender,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusBadge(status: sms.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Received: ${fmt.format(sms.receivedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sms.forwardedAt != null)
            Text(
              'Forwarded: ${fmt.format(sms.forwardedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Text(
            'Attempts: ${sms.attempts} / ${RetryPolicy.maxAttempts}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (sms.nextRetryAt != null)
            Text(
              'Next auto-retry: ${fmt.format(sms.nextRetryAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (amount != null || txnId != null || type != null) ...[
            const SizedBox(height: 16),
            Text('Parsed', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (amount != null) Text('Amount: ৳$amount'),
            if (type != null) Text('Type: $type'),
            if (txnId != null) Text('TxnID: $txnId'),
            if (counterparty != null) Text('Counterparty: $counterparty'),
          ],
          const SizedBox(height: 16),
          SelectableText(sms.body),
          if (sms.lastError != null) ...[
            const SizedBox(height: 16),
            Text(
              'Last error',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              sms.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (sms.status == ForwardStatus.failed ||
                  sms.status == ForwardStatus.pending)
                FilledButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: '${sms.sender}\n${sms.body}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

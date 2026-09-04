import 'package:hive/hive.dart';
import 'forward_status.dart';

part 'queued_sms.g.dart';

@HiveType(typeId: 2)
class QueuedSms extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sender;

  @HiveField(2)
  String body;

  @HiveField(3)
  DateTime receivedAt;

  @HiveField(4)
  ForwardStatus status;

  @HiveField(5)
  int attempts;

  @HiveField(6)
  String? lastError;

  @HiveField(7)
  DateTime? forwardedAt;

  @HiveField(8)
  String payloadHash;

  /// When set, auto-retry is deferred until this time.
  @HiveField(9)
  DateTime? nextRetryAt;

  @HiveField(10)
  double? amount;

  @HiveField(11)
  String? txnId;

  /// credit | debit | unknown
  @HiveField(12)
  String? txnType;

  @HiveField(13)
  String? counterparty;

  QueuedSms({
    required this.id,
    required this.sender,
    required this.body,
    required this.receivedAt,
    this.status = ForwardStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.forwardedAt,
    required this.payloadHash,
    this.nextRetryAt,
    this.amount,
    this.txnId,
    this.txnType,
    this.counterparty,
  });

  Map<String, dynamic> toExportJson() => {
        'id': id,
        'sender': sender,
        'body': body,
        'received_at': receivedAt.toUtc().toIso8601String(),
        'status': status.name,
        'attempts': attempts,
        'last_error': lastError,
        'forwarded_at': forwardedAt?.toUtc().toIso8601String(),
        'amount': amount,
        'txn_id': txnId,
        'type': txnType,
        'counterparty': counterparty,
      };
}

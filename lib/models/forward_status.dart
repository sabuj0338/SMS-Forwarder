import 'package:hive/hive.dart';

part 'forward_status.g.dart';

@HiveType(typeId: 1)
enum ForwardStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  sending,

  @HiveField(2)
  sent,

  @HiveField(3)
  failed,
}

extension ForwardStatusX on ForwardStatus {
  String get label {
    switch (this) {
      case ForwardStatus.pending:
        return 'Pending';
      case ForwardStatus.sending:
        return 'Sending';
      case ForwardStatus.sent:
        return 'Sent';
      case ForwardStatus.failed:
        return 'Failed';
    }
  }
}

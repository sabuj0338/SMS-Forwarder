import 'package:hive/hive.dart';
part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  double amount;

  @HiveField(1)
  bool isCredit; // true=credit, false=debit

  @HiveField(2)
  String source; // bank, bkash, nexuspay

  @HiveField(3)
  DateTime time;

  Transaction({
    required this.amount,
    required this.isCredit,
    required this.source,
    required this.time,
  });
}

import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("বিস্তারিত")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("${tx.amount}", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text(tx.isCredit ? "ক্রেডিট" : "ডেবিট", style: TextStyle(fontSize: 32)),
            SizedBox(height: 20),
            Text(tx.source, style: TextStyle(fontSize: 28)),
            SizedBox(height: 20),
            Text("${tx.time}", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

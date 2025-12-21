import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';

class FullScreenNotification extends StatelessWidget {
  final Transaction tx;
  const FullScreenNotification({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 5), () {
      Navigator.pop(context);
    });

    return Scaffold(
      backgroundColor: tx.isCredit ? Colors.green : Colors.red,
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(tx: tx),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${tx.amount}",
                style: TextStyle(
                  fontSize: 60,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                tx.isCredit ? "ক্রেডিট" : "ডেবিট",
                style: TextStyle(fontSize: 32, color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(
                tx.source,
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

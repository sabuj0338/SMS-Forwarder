import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../screens/transaction_detail_screen.dart';

class TransactionCard extends StatelessWidget {
  final Transaction tx;

  const TransactionCard({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final color = tx.isCredit ? Colors.green.shade700 : Colors.red.shade700;
    final bgColor = tx.isCredit ? Colors.green.shade50 : Colors.red.shade50;
    final icon = tx.isCredit
        ? Icons.arrow_downward
        : Icons
              .arrow_upward; // In banking, Credit is usually money coming in (down into account?), Debit is going out (up?).
    // Start with simplistic: Credit = Received (Arrow Down/In), Debit = Sent (Arrow Up/Out).
    // Actually, usually Arrow Down = Download/Receive, Arrow Up = Upload/Send.
    // Let's stick to the User's "Green -> Money Received", "Red -> Money Sent".

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Banner(
            message: tx.source.toUpperCase(),
            location: BannerLocation.topEnd,
            color: color,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tx.isCredit ? Icons.add : Icons.remove,
                      color: color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Amount and Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '৳').format(tx.amount),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(tx.time),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

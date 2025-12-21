import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../services/sms_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box<Transaction> box = Hive.box<Transaction>('transactions');
  final SmsService smsService = SmsService();

  // Filters
  final List<String> _filters = ["NexusPay", "bKash", "Bank"];
  final Set<String> _selectedFilters = {"NexusPay", "bKash", "Bank"};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "TakaDekho",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilters.contains(filter);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFilters.add(filter);
                          } else {
                            _selectedFilters.remove(filter);
                          }
                        });
                      },
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade700,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.green.shade900
                            : Colors.black,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: smsService.isLoading,
              builder: (context, isLoading, _) {
                if (isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Reading SMS...",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ValueListenableBuilder(
                  valueListenable: box.listenable(),
                  builder: (context, Box<Transaction> transactions, _) {
                    var txList = transactions.values.toList();

                    // Sort descending by time
                    txList.sort((a, b) => b.time.compareTo(a.time));

                    // Filter
                    txList = txList.where((tx) {
                      // Simple mapping for now (real app would need robust source mapping)
                      // Current logic: source is "NexusPay" or "Unknown"
                      // If filter contains "NexusPay" and tx.source is "NexusPay", show.
                      // Matches leniently

                      // If user selects "Bank", we should show "Bank" or "Unknown" for now?
                      // Or strictly what we have.
                      // Let's matching against source string content.

                      bool matches = false;
                      for (final filter in _selectedFilters) {
                        if (tx.source.toUpperCase().contains(
                          filter.toUpperCase(),
                        )) {
                          matches = true;
                          break;
                        }
                        // Fallback: If source is "Unknown", maybe show it if "Bank" is selected? (Assumption)
                        if (tx.source == "Unknown" && filter == "Bank") {
                          // matches = true;
                        }
                      }
                      return matches;
                    }).toList();

                    if (txList.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 60,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No transactions found",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      itemCount: txList.length,
                      itemBuilder: (_, index) =>
                          TransactionCard(tx: txList[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

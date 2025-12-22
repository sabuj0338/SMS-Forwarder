import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../widgets/transaction_card.dart';
import '../services/sms_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box<Transaction> box = Hive.box<Transaction>('transactions');
  final SmsService smsService = SmsService();

  // Filters

  final Set<String> _selectedFilters = {"NexusPay", "bKash", "Nagad"};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "TakaDekho",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
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

              // Get unique sources for filters
              final allSources = txList.map((e) => e.source).toSet().toList()
                ..sort();

              // If _selectedFilters is empty and we have sources, maybe select all by default?
              // Or just ensure we respect the user's toggle.
              // For now, let's just keep _selectedFilters as the source of truth for visibility.
              // Note: If a new source appears, it won't be in _selectedFilters automatically unless we add it.

              // Filter the list
              var filteredTxList = txList.where((tx) {
                return _selectedFilters.contains(tx.source);
              }).toList();

              return Column(
                children: [
                  // Filter Section
                  if (allSources.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      // color: Colors.white,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: allSources.map((filter) {
                            final isSelected = _selectedFilters.contains(
                              filter,
                            );
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
                    child: filteredTxList.isEmpty
                        ? Center(
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
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: filteredTxList.length,
                            itemBuilder: (_, index) =>
                                TransactionCard(tx: filteredTxList[index]),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

import 'dart:developer' as developer;

import 'package:another_telephony/telephony.dart';
import '../models/transaction.dart';
import 'notification_service.dart';
import 'tts_service.dart';
import 'package:hive/hive.dart';
import '../screens/full_screen_notification.dart';
import 'package:flutter/material.dart';

// This class handles SMS related operations
// Primary focus is to read SMS and parse it to Transaction object
// and save it to Hive box
// and listen for new SMS and parse it to Transaction object
class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony telephony = Telephony.instance;
  final Box<Transaction> box = Hive.box<Transaction>('transactions');
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  /// CALL THIS ON APP START
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    final granted = await telephony.requestSmsPermissions;
    if (granted != true) return;

    // Listen for new SMS
    initSmsListener(navigatorKey);

    // Read old SMS in background
    _readOldSms();
  }

  /// 1️⃣ READ EXISTING SMS
  Future<void> _readOldSms() async {
    isLoading.value = true;
    try {
      final messages = await telephony.getInboxSms(
        // columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        // filter: SmsFilter.where(SmsColumn.ADDRESS).equals("16216"), // Removed strict filter to allow broad scanning
      );

      for (final sms in messages) {
        final tx = parseTransactionSms(sms);

        if (tx != null && !_exists(tx)) {
          box.add(tx);
        }
      }
    } catch (e) {
      developer.log("Error reading SMS: $e", name: "sms_service");
    } finally {
      isLoading.value = false;
    }
  }

  void initSmsListener(GlobalKey<NavigatorState> navigatorKey) async {
    bool? granted = await telephony.requestSmsPermissions;
    if (granted != true) return;

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage sms) {
        Transaction? tx = parseTransactionSms(sms);
        if (tx == null) return;

        // add to hive but top of the list
        box.add(tx);

        // Navigate to full-screen notification
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => FullScreenNotification(tx: tx)),
        );

        // Speak transaction
        TtsService.speakTransaction(tx);
      },
      onBackgroundMessage: backgroundSmsHandler,
    );
  }

  /// BACKGROUND (APP CLOSED)
  @pragma('vm:entry-point')
  static void backgroundSmsHandler(SmsMessage sms) async {
    final service = SmsService();
    final tx = service.parseTransactionSms(sms);
    if (tx == null) return;

    final box = await Hive.openBox<Transaction>('transactions');
    // add to hive but top of the list
    box.add(tx);
    NotificationService.show(tx);
    TtsService.speakTransaction(tx);
  }

  /// PARSE TRANSACTION SMS
  Transaction? parseTransactionSms(SmsMessage sms) {
    final sender = sms.address?.toLowerCase() ?? "";
    final body = sms.body?.toLowerCase() ?? "";

    if (!sender.contains("16216")) {
      return null;
    }

    // log the found sms
    developer.log(
      "Found sms: ${sms.address} - ${sms.body}",
      name: "sms_service",
    );

    final amountMatch = RegExp(r'tk\s?([\d,]+(?:\.\d+)?)').firstMatch(body);

    if (amountMatch == null) {
      developer.log("Amount not found", name: "sms_service");
      return null;
    }

    final amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));

    final isCredit =
        body.contains("received") ||
        body.contains("credited") ||
        body.contains("পেয়েছেন");

    final isDebit =
        body.contains("sent") ||
        body.contains("debited") ||
        body.contains("পাঠানো");

    if (!isCredit && !isDebit) {
      developer.log("Not credit or debit", name: "sms_service");
      return null;
    }

    return Transaction(
      amount: amount,
      isCredit: isCredit,
      source: sender.contains("16216") ? "NexusPay" : "Unknown",
      time: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
    );
  }

  bool _exists(Transaction tx) {
    return box.values.any((e) => e.amount == tx.amount && e.time == tx.time);
  }
}

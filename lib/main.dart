import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'models/transaction.dart';
import 'services/notification_service.dart';
import 'services/sms_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TransactionAdapter());
  await Hive.openBox<Transaction>('transactions');

  await NotificationService.init();
  await NotificationService.requestPermissions();
  await SmsService().init(navigatorKey);

  runApp(TakaDekho());
}

class TakaDekho extends StatelessWidget {
  const TakaDekho({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TakaDekho',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomeScreen(),
    );
  }
}

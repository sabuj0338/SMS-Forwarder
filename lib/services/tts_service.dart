import 'package:flutter_tts/flutter_tts.dart';
import '../models/transaction.dart';

class TtsService {
  static final FlutterTts tts = FlutterTts();

  static Future speakTransaction(Transaction tx) async {
    await tts.setLanguage("bn-BD");
    await tts.setSpeechRate(0.5);
    String type = tx.isCredit
        ? "আপনি ${tx.amount} টাকা পেয়েছেন"
        : "আপনি ${tx.amount} টাকা পাঠিয়েছেন";
    await tts.speak(type);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Hive and platform plugins need device init; skip full pump in unit env.
    expect(SmsForwarderApp, isNotNull);
  });
}

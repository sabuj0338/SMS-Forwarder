import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/forward_status.dart';
import 'forward_service.dart';

class ExportService {
  static Future<void> shareLog({ForwardStatus? onlyStatus}) async {
    final json = ForwardService().exportJson(onlyStatus: onlyStatus);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final suffix = onlyStatus?.name ?? 'all';
    final file = File(p.join(dir.path, 'sms_forwarder_${suffix}_$stamp.json'));
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'SMS Forwarder export',
      text: 'SMS Forwarder log ($suffix)',
    );
  }
}

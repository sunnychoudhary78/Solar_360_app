import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PdfHelper {
  static Future<void> saveAndOpen(
    Uint8List bytes, {
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }
}

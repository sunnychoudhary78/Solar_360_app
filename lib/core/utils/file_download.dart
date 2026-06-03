import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/token_storage.dart';
import 'upload_url.dart';

const _downloadChannel = MethodChannel('solar_sales/downloads');

/// Downloads a remote upload to device-visible storage and optionally opens it.
Future<String> downloadRemoteFile({
  required String url,
  required String fileName,
  bool openAfterSave = false,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || url.trim().isEmpty) {
    throw Exception('Invalid file URL');
  }

  final safeName = fileDisplayName(fileName);
  final dio = Dio();
  final token = TokenStorage.token;

  final response = await dio.get<List<int>>(
    url,
    options: Options(
      headers: token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null,
      responseType: ResponseType.bytes,
      followRedirects: true,
    ),
  );

  final bytes = Uint8List.fromList(response.data ?? const []);
  if (bytes.isEmpty) {
    throw Exception('Downloaded file is empty');
  }

  final savedPath = !kIsWeb && Platform.isAndroid
      ? await _saveAndroidDownload(
          bytes: bytes,
          fileName: safeName,
          openAfterSave: openAfterSave,
        )
      : await _saveFileFallback(
          bytes: bytes,
          fileName: safeName,
          openAfterSave: openAfterSave,
        );

  return savedPath;
}

Future<String> _saveAndroidDownload({
  required Uint8List bytes,
  required String fileName,
  required bool openAfterSave,
}) async {
  final storage = await Permission.storage.request();
  if (storage.isDenied || storage.isPermanentlyDenied) {
    // Android 10+ uses MediaStore and does not need legacy storage permission.
    // Older devices will return a native write error if the permission is needed.
  }

  final result = await _downloadChannel.invokeMethod<String>(
    'saveToDownloads',
    {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': _mimeTypeForName(fileName),
      'openAfterSave': openAfterSave,
    },
  );

  if (result == null || result.trim().isEmpty) {
    throw Exception('Download failed');
  }

  return result;
}

Future<String> _saveFileFallback({
  required Uint8List bytes,
  required String fileName,
  required bool openAfterSave,
}) async {
  final downloads = await getDownloadsDirectory();
  final dir = downloads ?? await getApplicationDocumentsDirectory();
  final target = File('${dir.path}/$fileName');

  await target.writeAsBytes(bytes, flush: true);

  if (openAfterSave) {
    final result = await OpenFilex.open(target.path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  return target.path;
}

String _mimeTypeForName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'application/octet-stream';
}

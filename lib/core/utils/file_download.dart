import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/token_storage.dart';
import 'upload_url.dart';

/// Downloads a remote upload to app storage and optionally opens it.
Future<String> downloadRemoteFile({
  required String url,
  required String fileName,
  bool openAfterSave = false,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || url.trim().isEmpty) {
    throw Exception('Invalid file URL');
  }

  if (!kIsWeb && Platform.isAndroid) {
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();
    if (!photos.isGranted && !storage.isGranted) {
      throw Exception('Storage permission denied');
    }
  }

  final safeName = fileDisplayName(fileName);
  final dir = await getApplicationDocumentsDirectory();
  final target = File('${dir.path}/$safeName');

  final dio = Dio();
  final token = TokenStorage.token;
  await dio.download(
    url,
    target.path,
    options: Options(
      headers: token != null && token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null,
      responseType: ResponseType.bytes,
      followRedirects: true,
    ),
  );

  if (openAfterSave) {
    final result = await OpenFilex.open(target.path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  return target.path;
}

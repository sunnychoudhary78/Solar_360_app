import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.load();

        if (token != null && token.trim().isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${token.trim()}';
        } else {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
      onError: (error, handler) {
        // Yahan token clear mat karo.
        // Session clear ka decision AuthRepository.restoreSession/logout karega.
        handler.next(error);
      },
    ),
  );

  return dio;
});
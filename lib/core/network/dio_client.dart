import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'api_constants.dart';

class DioClient {
  final Dio dio;
  final TokenStorage tokenStorage;
  final void Function()? onUnauthorized;

  DioClient({required this.tokenStorage, this.onUnauthorized})
    : dio = Dio(
        BaseOptions(
          baseUrl: '${ApiConstants.baseUrl}/',
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
          contentType: 'application/json',
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            debugPrint('REQUEST ${options.method} ${options.uri}');
            debugPrint('BODY: ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              'RESPONSE ${response.statusCode} ${response.requestOptions.uri}',
            );
          }
          handler.next(response);
        },
        onError: (e, handler) {
          if (kDebugMode) {
            debugPrint('DIO ERROR ${e.requestOptions.uri}: ${e.message}');
          }
          handler.next(e);
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.getActiveToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final path = e.requestOptions.path.toLowerCase();
          final isCredentialValidation =
              path.endsWith('auth/login') ||
              path.endsWith('auth/change-password') ||
              path.endsWith('customers/login') ||
              path.endsWith('customers/change-password');

          if (e.response?.statusCode == 401 && !isCredentialValidation) {
            await tokenStorage.clear();
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/app/navigator.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/network/dio_client.dart';
import 'package:solar_sales/core/storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final dioClientProvider = Provider<DioClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return DioClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    },
  );
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ApiService(dioClient.dio);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';

import '../../data/models/whatsapp_models.dart';
import '../../data/whatsapp_api_service.dart';
import '../../data/whatsapp_repository.dart';

final whatsappApiServiceProvider = Provider<WhatsappApiService>((ref) {
  return WhatsappApiService(ref.watch(apiServiceProvider));
});

final whatsappRepositoryProvider = Provider<WhatsappRepository>((ref) {
  return WhatsappRepository(ref.watch(whatsappApiServiceProvider));
});

final whatsappMessagesProvider = FutureProvider.autoDispose
    .family<List<WhatsappMessageModel>, WhatsappEntityKey>((ref, key) {
  return ref.watch(whatsappRepositoryProvider).messages(
        entityType: key.entityType,
        entityId: key.entityId,
      );
});

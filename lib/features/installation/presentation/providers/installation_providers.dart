import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';

import 'package:solar_sales/features/installation/data/installation_api_service.dart';
import 'package:solar_sales/features/installation/data/installation_repository.dart';

final installationApiServiceProvider = Provider<InstallationApiService>((ref) {
  return InstallationApiService(
    ref.watch(apiServiceProvider),
    ref.watch(dioClientProvider).dio,
  );
});

final installationRepositoryProvider = Provider<InstallationRepository>((ref) {
  return InstallationRepository(ref.watch(installationApiServiceProvider));
});

final installationByLeadProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, leadId) async {
      return ref.watch(installationRepositoryProvider).getByLeadId(leadId);
    });

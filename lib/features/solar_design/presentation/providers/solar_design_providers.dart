import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/solar_design/data/models/solar_design_models.dart';
import 'package:solar_sales/features/solar_design/data/solar_design_api_service.dart';

final solarDesignApiProvider = Provider<SolarDesignApiService>((ref) {
  return SolarDesignApiService(ref.watch(apiServiceProvider));
});

final customerSolarDesignsProvider = FutureProvider.autoDispose
    .family<CustomerSolarDesignsResult, String>((ref, customerId) async {
  return ref.watch(solarDesignApiProvider).listForCustomer(customerId);
});

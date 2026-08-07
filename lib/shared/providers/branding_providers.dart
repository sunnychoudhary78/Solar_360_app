import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/data/branding_api_service.dart';
import 'package:solar_sales/shared/models/solar_branding_model.dart';

final brandingApiServiceProvider = Provider<BrandingApiService>((ref) {
  return BrandingApiService(ref.watch(apiServiceProvider));
});

final solarBrandingProvider = FutureProvider<SolarBrandingModel>((ref) async {
  return ref.watch(brandingApiServiceProvider).getSolarBranding();
});

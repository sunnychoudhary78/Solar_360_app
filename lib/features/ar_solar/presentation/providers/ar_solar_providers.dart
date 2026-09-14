import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';

import '../../data/ar_solar_native_service.dart';
import '../../data/models/solar_panel_model.dart';
import '../../data/solar_panel_api_service.dart';

final solarPanelApiServiceProvider = Provider<SolarPanelApiService>((ref) {
  return SolarPanelApiService(ref.watch(apiServiceProvider));
});

final arSolarNativeServiceProvider = Provider<ArSolarNativeService>((ref) {
  return ArSolarNativeService();
});

final enabledSolarPanelsProvider =
    FutureProvider.autoDispose<List<SolarPanelModel>>((ref) async {
  return ref.watch(solarPanelApiServiceProvider).listEnabled();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';

import '../../data/ar_solar_native_service.dart';
import '../../data/models/solar_panel_model.dart';
import '../../data/solar_panel_api_service.dart';

/// Permission names from login / `/auth/permissions` / switch-role.
const arSolarPanelReadPermission = 'ar_solar_panel.read';
const arSolarPanelCreatePermission = 'ar_solar_panel.create';
const arSolarPanelUpdatePermission = 'ar_solar_panel.update';

final solarPanelApiServiceProvider = Provider<SolarPanelApiService>((ref) {
  return SolarPanelApiService(ref.watch(apiServiceProvider));
});

final arSolarNativeServiceProvider = Provider<ArSolarNativeService>((ref) {
  return ArSolarNativeService();
});

final enabledSolarPanelsProvider =
    FutureProvider.autoDispose<List<SolarPanelModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.hasPermission(arSolarPanelReadPermission)) {
    return const [];
  }
  return ref.watch(solarPanelApiServiceProvider).listEnabled();
});

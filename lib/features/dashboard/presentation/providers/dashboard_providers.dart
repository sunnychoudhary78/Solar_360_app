import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';

import '../../data/dashboard_api_service.dart';
import '../../data/dashboard_repository.dart';
import '../../data/models/dashboard_model.dart';

final dashboardApiServiceProvider = Provider<DashboardApiService>((ref) {
  return DashboardApiService(ref.watch(apiServiceProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dashboardApiServiceProvider));
});

final dashboardProvider = FutureProvider<DashboardModel>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.hasPermission('stats.read')) {
    return const DashboardModel();
  }
  try {
    return await ref.watch(dashboardRepositoryProvider).load();
  } catch (_) {
    // Still show shell/quick actions if stats API fails
    return const DashboardModel();
  }
});

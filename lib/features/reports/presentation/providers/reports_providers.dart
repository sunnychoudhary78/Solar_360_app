import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';

import '../../data/models/report_models.dart';
import '../../data/reports_api_service.dart';
import '../../data/reports_repository.dart';

final reportsApiServiceProvider = Provider<ReportsApiService>((ref) {
  return ReportsApiService(ref.watch(apiServiceProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(reportsApiServiceProvider));
});

final reportsProvider = FutureProvider<ReportsBundle>((ref) async {
  return ref.watch(reportsRepositoryProvider).loadAll();
});

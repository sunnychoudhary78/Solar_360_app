import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/dashboard_model.dart';

class DashboardApiService {
  final ApiService _api;

  DashboardApiService(this._api);

  Future<DashboardModel> getDashboard() async {
    final res = await _api.get(ApiEndpoints.dashboard);
    return DashboardModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<SalesPoint>> getSalesReport() async {
    final res = await _api.get(ApiEndpoints.salesReport);
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => SalesPoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

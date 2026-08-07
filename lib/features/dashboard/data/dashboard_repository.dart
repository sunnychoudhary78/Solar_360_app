import 'dashboard_api_service.dart';
import 'models/dashboard_model.dart';

class DashboardRepository {
  final DashboardApiService _api;

  DashboardRepository(this._api);

  Future<DashboardModel> load() async {
    final dashboard = await _api.getDashboard();
    try {
      final sales = await _api.getSalesReport();
      // API returns newest first; chart left-to-right oldest→newest
      final trend = sales.reversed.toList();
      return dashboard.copyWith(salesTrend: trend);
    } catch (_) {
      return dashboard;
    }
  }
}

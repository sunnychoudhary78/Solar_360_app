import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/report_models.dart';

class ReportsApiService {
  final ApiService _api;

  ReportsApiService(this._api);

  Future<ReportsBundle> loadAll() async {
    final results = await Future.wait([
      _api.get(ApiEndpoints.salesReport),
      _api.get(ApiEndpoints.stockReport),
      _api.get(ApiEndpoints.quotationsReport),
      _api.get(ApiEndpoints.invoicesReport),
    ]);
    return parseReportsBundle(
      salesRes: results[0],
      stockRes: results[1],
      quotationsRes: results[2],
      invoicesRes: results[3],
    );
  }
}

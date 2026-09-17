import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import 'models/solar_panel_model.dart';

class SolarPanelApiService {
  SolarPanelApiService(this._api);

  final ApiService _api;

  Future<List<SolarPanelModel>> listEnabled() async {
    final res = await _api.get(ApiEndpoints.solarPanelsEnabled);
    final list = res is List
        ? res
        : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => SolarPanelModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String errorMessage(Object e) => cleanError(e);
}

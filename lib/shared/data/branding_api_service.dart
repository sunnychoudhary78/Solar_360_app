import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/solar_branding_model.dart';

class BrandingApiService {
  final ApiService _api;

  BrandingApiService(this._api);

  Future<SolarBrandingModel> getSolarBranding() async {
    final res = await _api.get(ApiEndpoints.solarBranding);
    return SolarBrandingModel.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

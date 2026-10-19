import 'dart:typed_data';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/costing_model.dart';

class CostingApiService {
  final ApiService _api;

  CostingApiService(this._api);

  Future<CostingSheet> getForCustomer(String customerId) async {
    final response = await _api.get(ApiEndpoints.customerCosting(customerId));
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> addLine(
    String customerId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post(
      ApiEndpoints.customerCostingLines(customerId),
      body,
    );
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> removeLine(String costingId, String lineId) async {
    final response = await _api.delete(
      ApiEndpoints.costingLine(costingId, lineId),
    );
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> clear(String costingId) async {
    final response = await _api.post(ApiEndpoints.costingClear(costingId));
    return CostingSheet.fromJson(response);
  }

  Future<Uint8List> downloadPdf(String costingId) {
    return _api.getBytes(ApiEndpoints.costingPdf(costingId));
  }
}

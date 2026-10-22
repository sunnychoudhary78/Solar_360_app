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

  Future<CostingSheet> getForLead(String leadId) async {
    final response = await _api.get(ApiEndpoints.leadCosting(leadId));
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

  Future<CostingSheet> addLeadLine(
    String leadId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post(
      ApiEndpoints.leadCostingLines(leadId),
      body,
    );
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> setVendor(String costingId, String? vendorId) async {
    final response = await _api.put(ApiEndpoints.costingVendor(costingId), {
      'vendor_id': vendorId,
    });
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> removeLine(String costingId, String lineId) async {
    final response = await _api.delete(
      ApiEndpoints.costingLine(costingId, lineId),
    );
    return CostingSheet.fromJson(response);
  }

  Future<CostingSheet> clear(String costingId) async {
    final response = await _api.postWithoutBody(
      ApiEndpoints.costingClear(costingId),
    );
    return CostingSheet.fromJson(response);
  }

  Future<Uint8List> downloadPdf(String costingId) {
    return _api.getBytes(
      ApiEndpoints.costingPdf(costingId),
      headers: {'Accept': 'application/pdf'},
    );
  }

  Future<List<CostingVendor>> listVendors() async {
    final response = await _api.get(ApiEndpoints.vendors);
    if (response is! List) {
      throw const FormatException('Invalid vendors response');
    }
    return response
        .whereType<Map>()
        .map((vendor) => CostingVendor.fromJson(
              Map<String, dynamic>.from(vendor),
            ))
        .toList();
  }

  Future<CostingVendor> createVendor(Map<String, dynamic> body) async {
    final response = await _api.post(ApiEndpoints.vendors, body);
    if (response is! Map) {
      throw const FormatException('Invalid vendor response');
    }
    return CostingVendor.fromJson(Map<String, dynamic>.from(response));
  }

  Future<CostingVendor> updateVendor(
    String vendorId,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.put(ApiEndpoints.vendor(vendorId), body);
    if (response is! Map) {
      throw const FormatException('Invalid vendor response');
    }
    return CostingVendor.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> deleteVendor(String vendorId) async {
    await _api.delete(ApiEndpoints.vendor(vendorId));
  }

  Future<List<CostingLead>> listLeads() async {
    final response = await _api.get(ApiEndpoints.leads);
    final data = response is List
        ? response
        : response is Map
        ? response['data']
        : null;
    if (data is! List) {
      throw const FormatException('Invalid leads response');
    }
    return data
        .whereType<Map>()
        .map((lead) => CostingLead.fromJson(Map<String, dynamic>.from(lead)))
        .toList();
  }
}

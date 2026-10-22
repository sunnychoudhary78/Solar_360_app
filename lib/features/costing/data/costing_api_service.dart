import 'dart:typed_data';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/costing_model.dart';

class CostingApiService {
  final ApiService _api;

  CostingApiService(this._api);

  /// All Costings table. `party` is `customer` or `lead`.
  Future<PaginatedResult<CostingListRow>> listCostings({
    required String party,
    String? search,
    String? vendorId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.costings,
      queryParams: {
        'party': party,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (vendorId != null && vendorId.isNotEmpty) 'vendorId': vendorId,
        if (dateFrom != null) 'dateFrom': _dateParam(dateFrom),
        if (dateTo != null) 'dateTo': _dateParam(dateTo),
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(response, CostingListRow.fromJson);
  }

  /// Full sheet for the bill dialog. Does **not** create a sheet.
  Future<CostingSheet> getById(String costingId) async {
    final response = await _api.get(ApiEndpoints.costing(costingId));
    return CostingSheet.fromJson(response);
  }

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

  /// `YYYY-MM-DD` for the `dateFrom` / `dateTo` list filters.
  static String _dateParam(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }
}

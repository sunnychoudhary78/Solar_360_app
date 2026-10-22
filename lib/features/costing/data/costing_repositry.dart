import 'dart:typed_data';

import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/costing_model.dart';
import 'costing_api_service.dart';

class CostingRepository {
  final CostingApiService _api;

  CostingRepository(this._api);

  Future<PaginatedResult<CostingListRow>> listCostings({
    required String party,
    String? search,
    String? vendorId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) => _api.listCostings(
    party: party,
    search: search,
    vendorId: vendorId,
    dateFrom: dateFrom,
    dateTo: dateTo,
    page: page,
    limit: limit,
  );

  Future<CostingSheet> getById(String costingId) => _api.getById(costingId);

  Future<CostingSheet> getForCustomer(String customerId) =>
      _api.getForCustomer(customerId);

  Future<CostingSheet> getForLead(String leadId) => _api.getForLead(leadId);

  Future<CostingSheet> addLine(String customerId, Map<String, dynamic> body) =>
      _api.addLine(customerId, body);

  Future<CostingSheet> addLeadLine(String leadId, Map<String, dynamic> body) =>
      _api.addLeadLine(leadId, body);

  Future<CostingSheet> setVendor(String costingId, String? vendorId) =>
      _api.setVendor(costingId, vendorId);

  Future<CostingSheet> removeLine(String costingId, String lineId) =>
      _api.removeLine(costingId, lineId);

  Future<CostingSheet> clear(String costingId) => _api.clear(costingId);

  Future<Uint8List> downloadPdf(String costingId) =>
      _api.downloadPdf(costingId);

  Future<List<CostingVendor>> listVendors() => _api.listVendors();

  Future<CostingVendor> createVendor(Map<String, dynamic> body) =>
      _api.createVendor(body);

  Future<CostingVendor> updateVendor(
    String vendorId,
    Map<String, dynamic> body,
  ) => _api.updateVendor(vendorId, body);

  Future<void> deleteVendor(String vendorId) => _api.deleteVendor(vendorId);

  Future<List<CostingLead>> listLeads() => _api.listLeads();
}

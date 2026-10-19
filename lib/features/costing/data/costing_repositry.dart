import 'dart:typed_data';

import 'models/costing_model.dart';
import 'costing_api_service.dart';

class CostingRepository {
  final CostingApiService _api;

  CostingRepository(this._api);

  Future<CostingSheet> getForCustomer(String customerId) =>
      _api.getForCustomer(customerId);

  Future<CostingSheet> addLine(String customerId, Map<String, dynamic> body) =>
      _api.addLine(customerId, body);

  Future<CostingSheet> removeLine(String costingId, String lineId) =>
      _api.removeLine(costingId, lineId);

  Future<CostingSheet> clear(String costingId) => _api.clear(costingId);

  Future<Uint8List> downloadPdf(String costingId) =>
      _api.downloadPdf(costingId);
}

import 'dart:typed_data';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/quotation_model.dart';

class QuotationApiService {
  final ApiService _api;

  QuotationApiService(this._api);

  Future<PaginatedResult<QuotationModel>> list({
    String? status,
    String? customerId,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.quotations,
      queryParams: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (customerId != null) 'customerId': customerId,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, QuotationModel.fromJson);
  }

  Future<QuotationModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.quotation(id));
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<QuotationModel>> listInvoiceable() async {
    final res = await _api.get(ApiEndpoints.quotationsInvoiceable);
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => QuotationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<QuotationModel>> pendingApprovals() async {
    final res = await _api.get(ApiEndpoints.quotationsPending);
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => QuotationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<QuotationModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.quotations, body);
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<QuotationModel> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.quotation(id), body);
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<QuotationModel> submit(String id) async {
    final res = await _api.post(ApiEndpoints.quotationSubmit(id));
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<QuotationModel> approve(String id) async {
    final res = await _api.post(ApiEndpoints.quotationApprove(id));
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<QuotationModel> reject(String id, String reason) async {
    final res =
        await _api.post(ApiEndpoints.quotationReject(id), {'reason': reason});
    return QuotationModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Uint8List> downloadPdf(String id) =>
      _api.getBytes(ApiEndpoints.quotationPdf(id));

  Future<void> sendEmail(String id, {String? email}) async {
    await _api.post(
      ApiEndpoints.quotationEmail(id),
      {if (email != null && email.isNotEmpty) 'email': email},
    );
  }
}

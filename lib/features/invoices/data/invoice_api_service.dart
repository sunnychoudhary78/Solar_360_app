import 'dart:typed_data';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';

import 'models/invoice_model.dart';

class InvoiceApiService {
  final ApiService _api;

  InvoiceApiService(this._api);

  Future<PaginatedResult<InvoiceModel>> list({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.invoices,
      queryParams: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, InvoiceModel.fromJson);
  }

  Future<InvoiceModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.invoice(id));
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<InvoiceModel>> pendingApprovals() async {
    final res = await _api.get(ApiEndpoints.invoicesPending);
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<InvoiceModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.invoices, body);
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<InvoiceModel> createFromQuotation({
    required String quotationId,
    String? notes,
    String? invoiceNumber,
    String? paymentMode,
    String? motorVehicleNo,
    String? ewayBillNo,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
    List<InvoiceItemModel>? items,
    String? marketingTemplateId,
  }) async {
    final resolvedShip = shipSameAsBill ? billTo : shipTo;
    final res = await _api.post(ApiEndpoints.invoiceFromQuotation, {
      'quotationId': quotationId,
      if (notes != null) 'notes': notes,
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      if (paymentMode != null) 'paymentMode': paymentMode,
      if (motorVehicleNo != null) 'motorVehicleNo': motorVehicleNo,
      if (ewayBillNo != null) 'ewayBillNo': ewayBillNo,
      if (billTo != null) 'billTo': billTo.toJson(),
      if (resolvedShip != null) 'shipTo': resolvedShip.toJson(),
      'shipSameAsBill': shipSameAsBill,
      if (fromParty != null && fromParty.isNotEmpty) 'fromParty': fromParty,
      if (items != null && items.isNotEmpty)
        'items': items.map((e) => e.toUpdateJson()).toList(),
      'marketing_template_id':
          (marketingTemplateId ?? '').trim().isEmpty ? null : marketingTemplateId,
    });
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<InvoiceModel> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put(ApiEndpoints.invoice(id), body);
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<InvoiceModel> submit(String id) async {
    final res = await _api.post(ApiEndpoints.invoiceSubmit(id));
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<InvoiceModel> approve(String id, {String? warehouseId}) async {
    final res = await _api.post(
      ApiEndpoints.invoiceApprove(id),
      warehouseId != null && warehouseId.isNotEmpty
          ? {'warehouseId': warehouseId}
          : <String, dynamic>{},
    );
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<InvoiceModel> reject(String id, String reason) async {
    final res =
        await _api.post(ApiEndpoints.invoiceReject(id), {'reason': reason});
    return InvoiceModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<StockCheckResult> stockCheck(String id, {String? warehouseId}) async {
    final res = await _api.get(
      ApiEndpoints.invoiceStockCheck(id),
      queryParams: {
        if (warehouseId != null && warehouseId.isNotEmpty)
          'warehouseId': warehouseId,
      },
    );
    return StockCheckResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Uint8List> downloadPdf(String id) =>
      _api.getBytes(ApiEndpoints.invoicePdf(id));

  Future<void> sendEmail(String id, {String? email}) async {
    await _api.post(
      ApiEndpoints.invoiceEmail(id),
      {if (email != null && email.isNotEmpty) 'email': email},
    );
  }
}

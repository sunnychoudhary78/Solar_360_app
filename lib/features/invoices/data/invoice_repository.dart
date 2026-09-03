import 'dart:typed_data';

import 'package:solar_sales/shared/models/paginated_result.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';

import 'invoice_api_service.dart';
import 'models/invoice_model.dart';

class InvoiceRepository {
  final InvoiceApiService _api;

  InvoiceRepository(this._api);

  Future<PaginatedResult<InvoiceModel>> list({
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      _api.list(status: status, page: page, limit: limit);

  Future<InvoiceModel> getById(String id) => _api.getById(id);

  Future<List<InvoiceModel>> pendingApprovals() => _api.pendingApprovals();

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
  }) =>
      _api.createFromQuotation(
        quotationId: quotationId,
        notes: notes,
        invoiceNumber: invoiceNumber,
        paymentMode: paymentMode,
        motorVehicleNo: motorVehicleNo,
        ewayBillNo: ewayBillNo,
        billTo: billTo,
        shipTo: shipTo,
        shipSameAsBill: shipSameAsBill,
        fromParty: fromParty,
        items: items,
        marketingTemplateId: marketingTemplateId,
      );

  Future<InvoiceModel> createDirect({
    required String customerId,
    required List<InvoiceItemModel> items,
    String? notes,
    String? invoiceNumber,
    String? paymentMode,
    String? motorVehicleNo,
    String? ewayBillNo,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
    String? marketingTemplateId,
  }) {
    final resolvedShip = shipSameAsBill ? billTo : shipTo;
    return _api.create({
      'customerId': customerId,
      'items': items.map((e) => e.toUpdateJson()).toList(),
      if (notes != null) 'notes': notes,
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      if (paymentMode != null && paymentMode.isNotEmpty)
        'paymentMode': paymentMode,
      if (motorVehicleNo != null && motorVehicleNo.isNotEmpty)
        'motorVehicleNo': motorVehicleNo,
      if (ewayBillNo != null && ewayBillNo.isNotEmpty)
        'ewayBillNo': ewayBillNo,
      if (billTo != null) 'billTo': billTo.toJson(),
      if (resolvedShip != null) 'shipTo': resolvedShip.toJson(),
      'shipSameAsBill': shipSameAsBill,
      if (fromParty != null && fromParty.isNotEmpty) 'fromParty': fromParty,
      'marketing_template_id':
          (marketingTemplateId ?? '').trim().isEmpty ? null : marketingTemplateId,
    });
  }

  Future<InvoiceModel> update({
    required String id,
    required List<InvoiceItemModel> items,
    String? notes,
    String? invoiceNumber,
    String? paymentMode,
    String? motorVehicleNo,
    String? ewayBillNo,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
    String? marketingTemplateId,
  }) {
    final resolvedShip = shipSameAsBill ? billTo : shipTo;
    return _api.update(id, {
      'items': items.map((e) => e.toUpdateJson()).toList(),
      'notes': notes?.trim() ?? '',
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      if (paymentMode != null) 'paymentMode': paymentMode,
      if (motorVehicleNo != null) 'motorVehicleNo': motorVehicleNo,
      if (ewayBillNo != null) 'ewayBillNo': ewayBillNo,
      if (billTo != null) 'billTo': billTo.toJson(),
      if (resolvedShip != null) 'shipTo': resolvedShip.toJson(),
      'shipSameAsBill': shipSameAsBill,
      if (fromParty != null && fromParty.isNotEmpty) 'fromParty': fromParty,
      'marketing_template_id':
          (marketingTemplateId ?? '').trim().isEmpty ? null : marketingTemplateId,
    });
  }

  Future<InvoiceModel> submit(String id) => _api.submit(id);

  Future<InvoiceModel> approve(String id, {String? warehouseId}) =>
      _api.approve(id, warehouseId: warehouseId);

  Future<InvoiceModel> reject(String id, String reason) =>
      _api.reject(id, reason);

  Future<StockCheckResult> stockCheck(String id, {String? warehouseId}) =>
      _api.stockCheck(id, warehouseId: warehouseId);

  Future<Uint8List> downloadPdf(String id) => _api.downloadPdf(id);

  Future<void> sendEmail(String id, {String? email}) =>
      _api.sendEmail(id, email: email);
}

import 'dart:typed_data';

import 'package:solar_sales/shared/models/paginated_result.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';

import 'models/quotation_model.dart';
import 'quotation_api_service.dart';

class QuotationRepository {
  final QuotationApiService _api;

  QuotationRepository(this._api);

  Future<PaginatedResult<QuotationModel>> list({
    String? status,
    String? customerId,
    int page = 1,
    int limit = 20,
  }) =>
      _api.list(
        status: status,
        customerId: customerId,
        page: page,
        limit: limit,
      );

  Future<QuotationModel> getById(String id) => _api.getById(id);

  Future<List<QuotationModel>> listInvoiceable() => _api.listInvoiceable();

  Future<List<QuotationModel>> pendingApprovals() => _api.pendingApprovals();

  Map<String, dynamic> _payload({
    required String customerId,
    required List<QuotationItemModel> items,
    String? notes,
    String? quotationNumber,
    DateTime? validUntil,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
    required bool clearNotesIfEmpty,
  }) {
    final resolvedShip = shipSameAsBill ? billTo : shipTo;
    final trimmedNotes = notes?.trim() ?? '';
    return {
      'customerId': customerId,
      'items': items.map((e) => e.toCreateJson()).toList(),
      if (clearNotesIfEmpty || trimmedNotes.isNotEmpty) 'notes': trimmedNotes,
      if (quotationNumber != null && quotationNumber.trim().isNotEmpty)
        'quotationNumber': quotationNumber.trim(),
      if (validUntil != null)
        'validUntil': validUntil.toIso8601String().split('T').first,
      if (billTo != null) 'billTo': billTo.toJson(),
      if (resolvedShip != null) 'shipTo': resolvedShip.toJson(),
      'shipSameAsBill': shipSameAsBill,
      if (fromParty != null && fromParty.isNotEmpty) 'fromParty': fromParty,
    };
  }

  Future<QuotationModel> create({
    required String customerId,
    required List<QuotationItemModel> items,
    String? notes,
    String? quotationNumber,
    DateTime? validUntil,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
  }) {
    return _api.create(
      _payload(
        customerId: customerId,
        items: items,
        notes: notes,
        quotationNumber: quotationNumber,
        validUntil: validUntil,
        billTo: billTo,
        shipTo: shipTo,
        shipSameAsBill: shipSameAsBill,
        fromParty: fromParty,
        clearNotesIfEmpty: false,
      ),
    );
  }

  Future<QuotationModel> update({
    required String id,
    required String customerId,
    required List<QuotationItemModel> items,
    String? notes,
    String? quotationNumber,
    DateTime? validUntil,
    PartyAddressModel? billTo,
    PartyAddressModel? shipTo,
    bool shipSameAsBill = true,
    Map<String, dynamic>? fromParty,
  }) {
    return _api.update(
      id,
      _payload(
        customerId: customerId,
        items: items,
        notes: notes,
        quotationNumber: quotationNumber,
        validUntil: validUntil,
        billTo: billTo,
        shipTo: shipTo,
        shipSameAsBill: shipSameAsBill,
        fromParty: fromParty,
        clearNotesIfEmpty: true,
      ),
    );
  }

  Future<QuotationModel> submit(String id) => _api.submit(id);

  Future<QuotationModel> approve(String id) => _api.approve(id);

  Future<QuotationModel> reject(String id, String reason) =>
      _api.reject(id, reason);

  Future<Uint8List> downloadPdf(String id) => _api.downloadPdf(id);

  Future<void> sendEmail(String id, {String? email}) =>
      _api.sendEmail(id, email: email);
}

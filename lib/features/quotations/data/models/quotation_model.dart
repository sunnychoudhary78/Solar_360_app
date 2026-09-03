import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class QuotationItemModel {
  final String? id;
  final String itemId;
  final String? warehouseId;
  final String? warehouseName;
  final int quantity;
  final String? description;
  final double unitPrice;
  final double gstPercent;
  final double gstAmount;
  final double lineTotal;
  final ItemModel? item;

  const QuotationItemModel({
    this.id,
    required this.itemId,
    this.warehouseId,
    this.warehouseName,
    required this.quantity,
    this.description,
    required this.unitPrice,
    required this.gstPercent,
    this.gstAmount = 0,
    this.lineTotal = 0,
    this.item,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    final warehouseRaw = json['warehouse'];
    return QuotationItemModel(
      id: json['id']?.toString(),
      itemId: asString(json['item_id']),
      warehouseId: json['warehouse_id']?.toString(),
      warehouseName: warehouseRaw is Map
          ? warehouseRaw['name']?.toString()
          : null,
      quantity: asInt(json['quantity'], 1),
      description: json['description']?.toString(),
      unitPrice: asDouble(json['unit_price']),
      gstPercent: asDouble(json['gst_percent']),
      gstAmount: asDouble(json['gst_amount']),
      lineTotal: asDouble(json['line_total']),
      item: itemRaw is Map
          ? ItemModel.fromJson(Map<String, dynamic>.from(itemRaw))
          : null,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'item_id': itemId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'gst_percent': gstPercent,
      if (description != null) 'description': description,
    };
  }

  String get displayName => item?.name ?? description ?? itemId;
}

class QuotationModel {
  final String id;
  final String quotationNumber;
  final String customerId;
  final CustomerModel? customer;
  final String status;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String? notes;
  final DateTime? validUntil;
  final String? rejectionReason;
  final List<QuotationItemModel> items;
  final String? invoiceId;
  final String? invoiceNumber;
  final PartyAddressModel? billTo;
  final PartyAddressModel? shipTo;
  final PartyAddressModel? fromParty;
  final String? fromBranchId;
  final String? marketingTemplateId;

  const QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.customerId,
    this.customer,
    required this.status,
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.notes,
    this.validUntil,
    this.rejectionReason,
    this.items = const [],
    this.invoiceId,
    this.invoiceNumber,
    this.billTo,
    this.shipTo,
    this.fromParty,
    this.fromBranchId,
    this.marketingTemplateId,
  });

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    final itemsRaw = json['items'];
    final invoiceRaw = json['invoice'];
    final fromPartyRaw = json['from_party'];

    return QuotationModel(
      id: asString(json['id']),
      quotationNumber: asString(json['quotation_number']),
      customerId: asString(json['customer_id']),
      customer: customerRaw is Map
          ? CustomerModel.fromJson(Map<String, dynamic>.from(customerRaw))
          : null,
      status: asString(json['status'], 'draft'),
      subtotal: asDouble(json['subtotal']),
      gstAmount: asDouble(json['gst_amount']),
      totalAmount: asDouble(json['total_amount']),
      notes: json['notes']?.toString(),
      validUntil: parseDate(json['valid_until']),
      rejectionReason: json['rejection_reason']?.toString(),
      items: itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map(
                  (e) =>
                      QuotationItemModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      invoiceId: invoiceRaw is Map ? invoiceRaw['id']?.toString() : null,
      invoiceNumber: invoiceRaw is Map
          ? invoiceRaw['invoice_number']?.toString()
          : null,
      billTo: json['bill_to'] is Map
          ? PartyAddressModel.fromJson(
              Map<String, dynamic>.from(json['bill_to'] as Map),
            )
          : null,
      shipTo: json['ship_to'] is Map
          ? PartyAddressModel.fromJson(
              Map<String, dynamic>.from(json['ship_to'] as Map),
            )
          : null,
      fromParty: fromPartyRaw is Map
          ? PartyAddressModel.fromJson(Map<String, dynamic>.from(fromPartyRaw))
          : null,
      fromBranchId: fromPartyRaw is Map
          ? fromPartyRaw['branch_id']?.toString() ??
                fromPartyRaw['branchId']?.toString()
          : null,
      marketingTemplateId: json['marketing_template_id']?.toString() ??
          json['marketingTemplateId']?.toString() ??
          (json['marketingTemplate'] is Map
              ? (json['marketingTemplate'] as Map)['id']?.toString()
              : null),
    );
  }

  String get customerName => customer?.name ?? 'Customer';
}

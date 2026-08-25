import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class InvoiceItemModel {
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

  const InvoiceItemModel({
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

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    final warehouseRaw = json['warehouse'];
    return InvoiceItemModel(
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

  String get displayName => item?.name ?? description ?? itemId;

  Map<String, dynamic> toUpdateJson() {
    return {
      'item_id': itemId,
      'warehouse_id': warehouseId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'gst_percent': gstPercent,
      if (description != null) 'description': description,
    };
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String? quotationId;
  final String? quotationNumber;
  final String customerId;
  final CustomerModel? customer;
  final String status;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String? notes;
  final String? rejectionReason;
  final String? warehouseId;
  final String? warehouseName;
  final bool stockDeducted;
  final String? paymentMode;
  final String? motorVehicleNo;
  final String? ewayBillNo;
  final List<InvoiceItemModel> items;
  final PartyAddressModel? billTo;
  final PartyAddressModel? shipTo;
  final PartyAddressModel? fromParty;
  final String? fromBranchId;

  const InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.quotationId,
    this.quotationNumber,
    required this.customerId,
    this.customer,
    required this.status,
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.notes,
    this.rejectionReason,
    this.warehouseId,
    this.warehouseName,
    this.stockDeducted = false,
    this.paymentMode,
    this.motorVehicleNo,
    this.ewayBillNo,
    this.items = const [],
    this.billTo,
    this.shipTo,
    this.fromParty,
    this.fromBranchId,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    final quotationRaw = json['quotation'];
    final itemsRaw = json['items'];
    final fromPartyRaw = json['from_party'];
    final warehouseRaw = json['warehouse'];

    return InvoiceModel(
      id: asString(json['id']),
      invoiceNumber: asString(json['invoice_number']),
      quotationId:
          json['quotation_id']?.toString() ??
          (quotationRaw is Map ? quotationRaw['id']?.toString() : null),
      quotationNumber: quotationRaw is Map
          ? quotationRaw['quotation_number']?.toString()
          : null,
      customerId: asString(json['customer_id']),
      customer: customerRaw is Map
          ? CustomerModel.fromJson(Map<String, dynamic>.from(customerRaw))
          : null,
      status: asString(json['status'], 'draft'),
      subtotal: asDouble(json['subtotal']),
      gstAmount: asDouble(json['gst_amount']),
      totalAmount: asDouble(json['total_amount']),
      notes: json['notes']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      warehouseId:
          json['warehouse_id']?.toString() ??
          (warehouseRaw is Map ? warehouseRaw['id']?.toString() : null),
      warehouseName: warehouseRaw is Map
          ? warehouseRaw['name']?.toString()
          : null,
      stockDeducted: asBool(json['stock_deducted']),
      paymentMode: json['payment_mode']?.toString(),
      motorVehicleNo: json['motor_vehicle_no']?.toString(),
      ewayBillNo: json['eway_bill_no']?.toString(),
      items: itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map(
                  (e) =>
                      InvoiceItemModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
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
    );
  }

  String get customerName => customer?.name ?? 'Customer';
}

class StockCheckResult {
  final bool ok;
  final List<StockCheckLine> lines;
  final List<StockAllocationLine> allocations;
  final String? message;

  const StockCheckResult({
    required this.ok,
    this.lines = const [],
    this.allocations = const [],
    this.message,
  });

  factory StockCheckResult.fromJson(Map<String, dynamic> json) {
    final shortageRaw = json['shortages'] ?? json['lines'] ?? json['items'];
    final lines = shortageRaw is List
        ? shortageRaw
              .whereType<Map>()
              .map((e) => StockCheckLine.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <StockCheckLine>[];

    final allocationRaw = json['allocations'];
    final allocations = allocationRaw is List
        ? allocationRaw
              .whereType<Map>()
              .map(
                (e) =>
                    StockAllocationLine.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <StockAllocationLine>[];

    final okFlag = json['ok'] ?? json['sufficient'] ?? json['success'];
    final ok = okFlag != null
        ? asBool(okFlag)
        : lines.isEmpty && (allocations.isNotEmpty || shortageRaw == null);

    return StockCheckResult(
      ok: ok,
      message: json['message']?.toString(),
      lines: lines,
      allocations: allocations,
    );
  }
}

class WarehouseStockInfo {
  final String? warehouseId;
  final String? warehouseName;
  final int available;

  const WarehouseStockInfo({
    this.warehouseId,
    this.warehouseName,
    this.available = 0,
  });

  factory WarehouseStockInfo.fromJson(Map<String, dynamic> json) {
    return WarehouseStockInfo(
      warehouseId: json['warehouse_id']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
      available: asInt(json['available'] ?? json['quantity']),
    );
  }
}

class StockAllocationLine {
  final String? itemId;
  final String? itemName;
  final String? warehouseId;
  final String? warehouseName;
  final int quantity;
  final int? availableAtWarehouse;

  const StockAllocationLine({
    this.itemId,
    this.itemName,
    this.warehouseId,
    this.warehouseName,
    this.quantity = 0,
    this.availableAtWarehouse,
  });

  factory StockAllocationLine.fromJson(Map<String, dynamic> json) {
    return StockAllocationLine(
      itemId: json['item_id']?.toString(),
      itemName:
          json['item_name']?.toString() ??
          (json['item'] is Map ? json['item']['name']?.toString() : null),
      warehouseId: json['warehouse_id']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
      quantity: asInt(json['quantity'] ?? json['qty']),
      availableAtWarehouse: json['available'] == null
          ? null
          : asInt(json['available']),
    );
  }
}

class StockCheckLine {
  final String? itemName;
  final int requiredQty;
  final int availableQty;
  final bool ok;
  final List<WarehouseStockInfo> byWarehouse;

  const StockCheckLine({
    this.itemName,
    this.requiredQty = 0,
    this.availableQty = 0,
    this.ok = true,
    this.byWarehouse = const [],
  });

  factory StockCheckLine.fromJson(Map<String, dynamic> json) {
    final requiredQty = asInt(
      json['required'] ?? json['required_qty'] ?? json['quantity'],
    );
    final availableQty = asInt(
      json['available'] ?? json['available_qty'] ?? json['current_quantity'],
    );
    final ok = json['ok'] != null
        ? asBool(json['ok'])
        : availableQty >= requiredQty;
    final byRaw = json['by_warehouse'];
    final byWarehouse = byRaw is List
        ? byRaw
              .whereType<Map>()
              .map(
                (e) =>
                    WarehouseStockInfo.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <WarehouseStockInfo>[];
    return StockCheckLine(
      itemName:
          json['item_name']?.toString() ??
          (json['item'] is Map ? json['item']['name']?.toString() : null),
      requiredQty: requiredQty,
      availableQty: availableQty,
      ok: ok,
      byWarehouse: byWarehouse,
    );
  }
}

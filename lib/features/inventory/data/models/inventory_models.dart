import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class WarehouseModel {
  final String id;
  final String name;
  final String? location;

  const WarehouseModel({
    required this.id,
    required this.name,
    this.location,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: asString(json['id']),
      name: asString(json['name']),
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
      };
}

class StockModel {
  final String id;
  final String itemId;
  final String warehouseId;
  final int currentQuantity;
  final int totalQuantity;
  final bool isLowStock;
  final ItemModel? item;
  final WarehouseModel? warehouse;

  const StockModel({
    required this.id,
    required this.itemId,
    required this.warehouseId,
    required this.currentQuantity,
    this.totalQuantity = 0,
    this.isLowStock = false,
    this.item,
    this.warehouse,
  });

  factory StockModel.fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    final warehouseRaw = json['warehouse'];
    return StockModel(
      id: asString(json['id']),
      itemId: asString(json['item_id']),
      warehouseId: asString(json['warehouse_id']),
      currentQuantity: asInt(json['current_quantity']),
      totalQuantity: asInt(json['total_quantity']),
      isLowStock: asBool(json['is_low_stock']),
      item: itemRaw is Map
          ? ItemModel.fromJson(Map<String, dynamic>.from(itemRaw))
          : null,
      warehouse: warehouseRaw is Map
          ? WarehouseModel.fromJson(Map<String, dynamic>.from(warehouseRaw))
          : null,
    );
  }

  String get itemName => item?.name ?? itemId;
  String get warehouseName => warehouse?.name ?? warehouseId;
  int get minStock => item?.minStockLevel ?? 0;
}

class StockTransactionModel {
  final String id;
  final String itemId;
  final String warehouseId;
  final String transType;
  final int quantity;
  final int balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String? referenceNumber;
  final String? notes;
  final DateTime? createdAt;
  final ItemModel? item;
  final WarehouseModel? warehouse;

  const StockTransactionModel({
    required this.id,
    required this.itemId,
    required this.warehouseId,
    required this.transType,
    required this.quantity,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    this.referenceNumber,
    this.notes,
    this.createdAt,
    this.item,
    this.warehouse,
  });

  factory StockTransactionModel.fromJson(Map<String, dynamic> json) {
    final itemRaw = json['item'];
    final warehouseRaw = json['warehouse'];
    return StockTransactionModel(
      id: asString(json['id']),
      itemId: asString(json['item_id']),
      warehouseId: asString(json['warehouse_id']),
      transType: asString(json['trans_type']),
      quantity: asInt(json['quantity']),
      balanceAfter: asInt(json['balance_after']),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at']),
      item: itemRaw is Map
          ? ItemModel.fromJson(Map<String, dynamic>.from(itemRaw))
          : null,
      warehouse: warehouseRaw is Map
          ? WarehouseModel.fromJson(Map<String, dynamic>.from(warehouseRaw))
          : null,
    );
  }

  String get itemName => item?.name ?? itemId;
  String get warehouseName => warehouse?.name ?? warehouseId;

  bool get isInvoiceReference =>
      referenceType == 'invoice' &&
      referenceId != null &&
      referenceId!.isNotEmpty;
}

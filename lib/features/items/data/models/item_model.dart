import 'package:solar_sales/shared/utils/formatters.dart';

class StockLevelModel {
  final String id;
  final String itemId;
  final String warehouseId;
  final int currentQuantity;
  final String? warehouseName;

  const StockLevelModel({
    required this.id,
    required this.itemId,
    required this.warehouseId,
    required this.currentQuantity,
    this.warehouseName,
  });

  factory StockLevelModel.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'];
    return StockLevelModel(
      id: asString(json['id']),
      itemId: asString(json['item_id']),
      warehouseId: asString(json['warehouse_id']),
      currentQuantity: asInt(json['current_quantity']),
      warehouseName: warehouse is Map
          ? asString(warehouse['name'])
          : json['warehouse_name']?.toString(),
    );
  }
}

class ItemModel {
  final String id;
  final String name;
  final String? description;
  final String? sku;
  final String? category;
  final String? hsnCode;
  final String? sacCode;
  final String unit;
  final double gstPercent;
  final double sellingPrice;
  final int minStockLevel;
  final String status;
  final String? rejectionReason;
  final List<StockLevelModel> stockLevels;
  final int? totalQuantity;
  final bool? isLowStock;

  const ItemModel({
    required this.id,
    required this.name,
    this.description,
    this.sku,
    this.category,
    this.hsnCode,
    this.sacCode,
    this.unit = 'pcs',
    this.gstPercent = 18,
    this.sellingPrice = 0,
    this.minStockLevel = 10,
    this.status = 'pending',
    this.rejectionReason,
    this.stockLevels = const [],
    this.totalQuantity,
    this.isLowStock,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    final levelsRaw = json['stock_levels'];
    final levels = levelsRaw is List
        ? levelsRaw
            .whereType<Map>()
            .map((e) => StockLevelModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <StockLevelModel>[];

    return ItemModel(
      id: asString(json['id']),
      name: asString(json['name']),
      description: json['description']?.toString(),
      sku: json['sku']?.toString(),
      category: json['category']?.toString(),
      hsnCode: json['hsn_code']?.toString(),
      sacCode: json['sac_code']?.toString(),
      unit: asString(json['unit'], 'pcs'),
      gstPercent: asDouble(json['gst_percent'], 18),
      sellingPrice: asDouble(json['selling_price']),
      minStockLevel: asInt(json['min_stock_level'], 10),
      status: asString(json['status'], 'pending'),
      rejectionReason: json['rejection_reason']?.toString(),
      stockLevels: levels,
      totalQuantity: json['total_quantity'] == null
          ? null
          : asInt(json['total_quantity']),
      isLowStock: json['is_low_stock'] == null
          ? null
          : asBool(json['is_low_stock']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'sku': sku,
      'category': category,
      'hsn_code': hsnCode,
      'sac_code': sacCode ?? '',
      'unit': unit,
      'gst_percent': gstPercent,
      'selling_price': sellingPrice,
      'min_stock_level': minStockLevel,
    };
  }
}

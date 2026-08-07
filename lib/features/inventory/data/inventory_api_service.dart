import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/inventory_models.dart';

class InventoryApiService {
  final ApiService _api;

  InventoryApiService(this._api);

  Future<List<StockModel>> getStock({
    String? warehouseId,
    bool approvedOnly = true,
    bool? lowStockOnly,
  }) async {
    final res = await _api.get(
      ApiEndpoints.stock,
      queryParams: {
        if (warehouseId != null) 'warehouseId': warehouseId,
        'approvedOnly': approvedOnly.toString(),
        if (lowStockOnly != null) 'lowStockOnly': lowStockOnly.toString(),
      },
    );
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => StockModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PaginatedResult<StockTransactionModel>> getLedger({
    String? itemId,
    String? warehouseId,
    String? transType,
    String? invoiceNumber,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _api.get(
      ApiEndpoints.ledger,
      queryParams: {
        if (itemId != null && itemId.isNotEmpty) 'itemId': itemId,
        if (warehouseId != null && warehouseId.isNotEmpty)
          'warehouseId': warehouseId,
        if (transType != null && transType.isNotEmpty) 'transType': transType,
        if (invoiceNumber != null && invoiceNumber.isNotEmpty)
          'invoiceNumber': invoiceNumber,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, StockTransactionModel.fromJson);
  }

  Future<List<StockModel>> getLowStock() async {
    final res = await _api.get(ApiEndpoints.lowStock);
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => StockModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> stockIn(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.stockIn, body);
  }

  Future<void> stockOut(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.stockOut, body);
  }

  Future<void> stockTransfer(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.stockTransfer, body);
  }

  Future<void> stockAdjustment(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.stockAdjustment, body);
  }

  Future<List<WarehouseModel>> listWarehouses() async {
    final res = await _api.get(ApiEndpoints.warehouses);
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => WarehouseModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<WarehouseModel> createWarehouse(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.warehouses, body);
    return WarehouseModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<WarehouseModel> updateWarehouse(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.patch(ApiEndpoints.warehouse(id), body);
    return WarehouseModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> deactivateWarehouse(String id) async {
    await _api.post(ApiEndpoints.warehouseDeactivate(id));
  }
}

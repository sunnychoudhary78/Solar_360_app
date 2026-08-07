import 'package:solar_sales/shared/models/paginated_result.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';

import 'inventory_api_service.dart';
import 'models/inventory_models.dart';

class InventoryRepository {
  final InventoryApiService _api;

  InventoryRepository(this._api);

  Future<List<StockModel>> getStock({
    String? warehouseId,
    bool approvedOnly = true,
    bool? lowStockOnly,
  }) =>
      _api.getStock(
        warehouseId: warehouseId,
        approvedOnly: approvedOnly,
        lowStockOnly: lowStockOnly,
      );

  Future<PaginatedResult<StockTransactionModel>> getLedger({
    String? itemId,
    String? warehouseId,
    String? transType,
    String? invoiceNumber,
    int page = 1,
    int limit = 50,
  }) =>
      _api.getLedger(
        itemId: itemId,
        warehouseId: warehouseId,
        transType: transType,
        invoiceNumber: invoiceNumber,
        page: page,
        limit: limit,
      );

  Future<List<StockModel>> getLowStock() => _api.getLowStock();

  Future<void> stockIn({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
    String? referenceNumber,
  }) =>
      _api.stockIn(
        InventoryPayloads.stockIn(
          itemId: itemId,
          warehouseId: warehouseId,
          quantity: quantity,
          notes: notes,
          referenceNumber: referenceNumber,
        ),
      );

  Future<void> stockOut({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
    String? referenceNumber,
  }) =>
      _api.stockOut(
        InventoryPayloads.stockOut(
          itemId: itemId,
          warehouseId: warehouseId,
          quantity: quantity,
          notes: notes,
          referenceNumber: referenceNumber,
        ),
      );

  Future<void> stockTransfer({
    required String itemId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required int quantity,
    String? notes,
  }) =>
      _api.stockTransfer(
        InventoryPayloads.stockTransfer(
          itemId: itemId,
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          quantity: quantity,
          notes: notes,
        ),
      );

  Future<void> stockAdjustment({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
  }) =>
      _api.stockAdjustment(
        InventoryPayloads.stockAdjustment(
          itemId: itemId,
          warehouseId: warehouseId,
          quantity: quantity,
          notes: notes,
        ),
      );

  Future<List<WarehouseModel>> listWarehouses() => _api.listWarehouses();

  Future<WarehouseModel> createWarehouse({
    required String name,
    String? location,
  }) =>
      _api.createWarehouse({'name': name, 'location': location});

  Future<WarehouseModel> updateWarehouse({
    required String id,
    required String name,
    String? location,
  }) =>
      _api.updateWarehouse(id, {'name': name, 'location': location});

  Future<void> deactivateWarehouse(String id) =>
      _api.deactivateWarehouse(id);
}

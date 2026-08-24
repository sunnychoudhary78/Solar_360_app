import '../../data/models/inventory_models.dart';

/// Warehouses where [itemId] already has a stock record (item assignment).
List<WarehouseModel> warehousesAssignedToItem(
  String? itemId,
  List<WarehouseModel> allWarehouses,
  List<StockModel> stockLevels,
) {
  if (itemId == null || itemId.isEmpty) return const [];

  final assignedIds = stockLevels
      .where((row) => row.itemId == itemId)
      .map((row) => row.warehouseId)
      .toSet();

  return allWarehouses.where((w) => assignedIds.contains(w.id)).toList();
}

/// Active warehouses where [itemId] is assigned. When [restrictToItem] is false
/// or [itemId] is empty, returns all [allWarehouses].
List<WarehouseModel> warehousesForItemSelection({
  required String? itemId,
  required List<WarehouseModel> allWarehouses,
  required List<StockModel> stockRows,
  Iterable<String>? itemWarehouseIds,
  bool restrictToItem = true,
}) {
  if (!restrictToItem || itemId == null || itemId.isEmpty) {
    return allWarehouses;
  }

  final assignedIds = <String>{
    for (final id in itemWarehouseIds ?? const <String>[])
      if (id.isNotEmpty) id,
  };
  for (final row in stockRows) {
    if (row.itemId == itemId) assignedIds.add(row.warehouseId);
  }

  if (assignedIds.isEmpty) return const [];
  return allWarehouses.where((w) => assignedIds.contains(w.id)).toList();
}

/// Warehouses where [itemId] currently has actual stock (> 0).
List<WarehouseModel> warehousesWithStockForItem(
  String? itemId,
  List<WarehouseModel> allWarehouses,
  List<StockModel> stockLevels,
) {
  if (itemId == null || itemId.isEmpty) return const [];

  final warehouseIds = stockLevels
      .where((row) => row.itemId == itemId && row.currentQuantity > 0)
      .map((row) => row.warehouseId)
      .toSet();

  if (warehouseIds.isEmpty) return const [];
  return allWarehouses.where((w) => warehouseIds.contains(w.id)).toList();
}

int availableQtyAtWarehouse(
  String? itemId,
  String? warehouseId,
  List<StockModel> stockLevels,
) {
  if (itemId == null || warehouseId == null) return 0;
  for (final row in stockLevels) {
    if (row.itemId == itemId && row.warehouseId == warehouseId) {
      return row.currentQuantity;
    }
  }
  return 0;
}

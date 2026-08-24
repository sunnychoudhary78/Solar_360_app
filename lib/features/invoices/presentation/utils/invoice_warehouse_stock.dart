import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/utils/stock_movement_utils.dart';
import 'package:solar_sales/features/invoices/data/models/invoice_model.dart';

/// Build a multi-warehouse deduction plan for invoice lines from live stock.
StockCheckResult buildInvoiceDeductionPlan({
  required List<InvoiceItemModel> items,
  required List<StockModel> stockRows,
  required List<WarehouseModel> warehouses,
  String? preferredWarehouseId,
}) {
  final nameById = {
    for (final w in warehouses) w.id: w.name,
  };
  final remaining = <String, int>{};
  for (final row in stockRows) {
    final key = '${row.itemId}:${row.warehouseId}';
    remaining[key] = (remaining[key] ?? 0) + row.currentQuantity;
  }

  final allocations = <StockAllocationLine>[];
  final shortages = <StockCheckLine>[];

  for (final item in items) {
    if (item.itemId.isEmpty || item.quantity <= 0) continue;

    final warehouseIds = <String>{
      for (final row in stockRows)
        if (row.itemId == item.itemId) row.warehouseId,
    };

    final orderedIds = warehouseIds.toList()
      ..sort((a, b) {
        if (preferredWarehouseId != null) {
          final aPref = a == preferredWarehouseId ? 1 : 0;
          final bPref = b == preferredWarehouseId ? 1 : 0;
          if (aPref != bPref) return bPref - aPref;
        }
        final aQty = remaining['${item.itemId}:$a'] ?? 0;
        final bQty = remaining['${item.itemId}:$b'] ?? 0;
        return bQty.compareTo(aQty);
      });

    final byWarehouse = orderedIds
        .map(
          (id) => WarehouseStockInfo(
            warehouseId: id,
            warehouseName: nameById[id] ?? id,
            available: remaining['${item.itemId}:$id'] ?? 0,
          ),
        )
        .toList();

    var need = item.quantity;
    final lineAllocs = <StockAllocationLine>[];
    for (final warehouseId in orderedIds) {
      if (need <= 0) break;
      final key = '${item.itemId}:$warehouseId';
      final avail = remaining[key] ?? 0;
      if (avail <= 0) continue;
      final take = avail < need ? avail : need;
      remaining[key] = avail - take;
      need -= take;
      lineAllocs.add(
        StockAllocationLine(
          itemId: item.itemId,
          itemName: item.displayName,
          warehouseId: warehouseId,
          warehouseName: nameById[warehouseId] ?? warehouseId,
          quantity: take,
          availableAtWarehouse: avail,
        ),
      );
    }

    if (need > 0) {
      final totalAvailable = byWarehouse.fold<int>(
        0,
        (sum, row) => sum + row.available,
      );
      shortages.add(
        StockCheckLine(
          itemName: item.displayName,
          requiredQty: item.quantity,
          availableQty: totalAvailable,
          ok: false,
          byWarehouse: byWarehouse,
        ),
      );
    } else {
      allocations.addAll(lineAllocs);
    }
  }

  final ok = shortages.isEmpty;
  return StockCheckResult(
    ok: ok,
    lines: shortages,
    allocations: allocations,
    message: ok ? null : 'Insufficient stock across warehouses',
  );
}

/// Prefer API plan when it includes allocations; otherwise use local plan.
StockCheckResult mergeDeductionPlans({
  required StockCheckResult local,
  required StockCheckResult api,
  required List<StockModel> stockRows,
}) {
  final StockCheckResult base;
  if (api.allocations.isNotEmpty ||
      api.lines.isNotEmpty ||
      api.message != null) {
    base = StockCheckResult(
      ok: api.ok,
      lines: api.lines.isNotEmpty ? api.lines : local.lines,
      allocations:
          api.allocations.isNotEmpty ? api.allocations : local.allocations,
      message: api.message ?? local.message,
    );
  } else if (api.ok && local.ok) {
    base = local;
  } else if (!api.ok) {
    base = StockCheckResult(
      ok: false,
      lines: api.lines.isNotEmpty ? api.lines : local.lines,
      allocations: const [],
      message: api.message ?? local.message,
    );
  } else {
    base = local;
  }
  return enrichAllocationAvailability(base, stockRows);
}

StockCheckResult enrichAllocationAvailability(
  StockCheckResult result,
  List<StockModel> stockRows,
) {
  if (result.allocations.isEmpty || stockRows.isEmpty) return result;
  return StockCheckResult(
    ok: result.ok,
    lines: result.lines,
    message: result.message,
    allocations: [
      for (final line in result.allocations)
        StockAllocationLine(
          itemId: line.itemId,
          itemName: line.itemName,
          warehouseId: line.warehouseId,
          warehouseName: line.warehouseName,
          quantity: line.quantity,
          availableAtWarehouse: line.availableAtWarehouse ??
              availableQtyAtWarehouse(
                line.itemId,
                line.warehouseId,
                stockRows,
              ),
        ),
    ],
  );
}

String allocationPlanLabel(StockAllocationLine line) {
  final name = line.itemName?.trim().isNotEmpty == true
      ? line.itemName!
      : 'Item';
  final warehouse = line.warehouseName?.trim().isNotEmpty == true
      ? line.warehouseName!
      : (line.warehouseId ?? 'warehouse');
  final available = line.availableAtWarehouse;
  if (available != null) {
    return '$name: ${line.quantity} from $warehouse (available $available)';
  }
  return '$name: ${line.quantity} from $warehouse';
}

String shortagePlanLabel(StockCheckLine line) {
  final name = line.itemName?.trim().isNotEmpty == true
      ? line.itemName!
      : 'Item';
  final base = '$name: need ${line.requiredQty}, have ${line.availableQty}';
  if (line.byWarehouse.isEmpty) return base;
  final parts = line.byWarehouse
      .map(
        (w) =>
            '${w.warehouseName ?? w.warehouseId ?? 'Warehouse'}: ${w.available}',
      )
      .join(', ');
  return '$base ($parts)';
}

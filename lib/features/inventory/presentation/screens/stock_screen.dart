import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

import '../../data/models/inventory_models.dart';
import '../providers/inventory_providers.dart';
import '../utils/stock_movement_utils.dart';

enum _MoveType { stockIn, stockOut, transfer, adjustment }

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockListProvider);
    final warehouses = ref.watch(warehousesProvider);
    final canUpdate = ref.watch(authProvider).hasPermission('inventory.update');
    final theme = Theme.of(context);
    final groupedStock = state.warehouseId == null
        ? _groupStockByItem(state.items)
        : const <_GroupedStockEntry>[];

    return Scaffold(
      appBar: AppAppBar(
        title: 'Stock Management',
        actions: [
          if (canUpdate)
            PopupMenuButton<_MoveType>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (type) => _showMoveSheet(context, ref, type),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _MoveType.stockIn,
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Text('Stock In'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MoveType.stockOut,
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.orange, size: 20),
                      SizedBox(width: 12),
                      Text('Stock Out'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MoveType.transfer,
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Text('Transfer'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MoveType.adjustment,
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.purple, size: 20),
                      SizedBox(width: 12),
                      Text('Adjustment'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: canUpdate
          ? FloatingActionButton.extended(
              onPressed: () => _showMoveSheet(context, ref, _MoveType.stockIn),
              icon: const Icon(Icons.add),
              label: const Text('Stock In'),
            )
          : null,
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: warehouses.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => TextButton(
                      onPressed: () => ref.invalidate(warehousesProvider),
                      child: Text(
                        'Warehouses failed — Retry',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    data: (list) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha(50),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: state.warehouseId,
                          isExpanded: true,
                          hint: const Text('Select Warehouse'),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.storefront_outlined,
                                      size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'All Warehouses',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            ...list.map(
                              (w) => DropdownMenuItem<String?>(
                                value: w.id,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warehouse_outlined, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          w.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => ref
                              .read(stockListProvider.notifier)
                              .setWarehouse(v),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  avatar: Icon(
                    state.lowStockOnly ? Icons.warning_rounded : Icons.filter_alt_outlined,
                    size: 16,
                    color: state.lowStockOnly
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: const Text('Low Stock'),
                  selected: state.lowStockOnly,
                  showCheckmark: false,
                  selectedColor: theme.colorScheme.errorContainer,
                  labelStyle: TextStyle(
                    color: state.lowStockOnly
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        state.lowStockOnly ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (v) =>
                      ref.read(stockListProvider.notifier).setLowStockOnly(v),
                ),
              ],
            ),
          ),

          // Main List View
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () =>
                            ref.read(stockListProvider.notifier).refresh(),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(stockListProvider.notifier).refresh(),
                        child: state.items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  EmptyState(
                                    title: 'No stock records found',
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                ],
                              )
                            : state.warehouseId == null
                                ? ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      80,
                                    ),
                                    itemCount: groupedStock.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _GroupedStockCard(
                                        entry: groupedStock[index],
                                      );
                                    },
                                  )
                                : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                                itemCount: state.items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final s = state.items[index];
                                  final isLow = s.isLowStock;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isLow
                                            ? Colors.orange.withAlpha(150)
                                            : theme.colorScheme.outline.withAlpha(30),
                                        width: isLow ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(8),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isLow
                                                ? Colors.orange.withAlpha(30)
                                                : theme.colorScheme.primaryContainer,
                                            child: Icon(
                                              isLow
                                                  ? Icons.warning_amber_rounded
                                                  : Icons.inventory_2_outlined,
                                              color: isLow
                                                  ? Colors.orange.shade800
                                                  : theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.itemName,
                                                  style: theme
                                                      .textTheme.titleMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.warehouse_outlined,
                                                      size: 14,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      s.warehouseName,
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const Text(' • '),
                                                    Text(
                                                      'Min: ${s.minStock}',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const Text(' • '),
                                                    Text(
                                                      'Total: ${s.totalQuantity}',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color: theme.colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${s.currentQuantity}',
                                                style: theme
                                                    .textTheme.titleLarge
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isLow
                                                      ? Colors.orange.shade800
                                                      : theme.colorScheme.onSurface,
                                                ),
                                              ),
                                              if (isLow)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 4),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Low Stock',
                                                    style: TextStyle(
                                                      color: Colors.orange.shade900,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showMoveSheet(
  BuildContext context,
  WidgetRef ref,
  _MoveType type,
) async {
  List<ItemModel> stockableItems;
  List<ItemModel> approvedItems;
  List<WarehouseModel> warehouses;
  try {
    stockableItems = await ref.read(stockableItemsProvider.future);
    approvedItems = await ref.read(approvedItemsProvider.future);
    warehouses = await ref.read(warehousesProvider.future);
  } catch (e) {
    if (!context.mounted) return;
    ref.read(globalLoadingProvider.notifier).showApiError(e);
    return;
  }
  if (!context.mounted) return;

  final moveItems = (type == _MoveType.stockIn || type == _MoveType.adjustment)
      ? stockableItems
      : approvedItems;

  if (moveItems.isEmpty) {
    ref.read(globalLoadingProvider.notifier).showError(
          type == _MoveType.stockIn || type == _MoveType.adjustment
              ? 'No stockable items available'
              : 'No approved items available',
        );
    return;
  }
  if (warehouses.isEmpty) {
    await showWarehouseUnavailableDialog(
      context,
      message:
          'No active warehouses are available. Create or activate a warehouse before recording stock movements.',
    );
    return;
  }

  final stockLevels = await ref
      .read(inventoryRepositoryProvider)
      .getStock(approvedOnly: false);
  if (!context.mounted) return;

  int availableQty(String? iId, String? wId) =>
      availableQtyAtWarehouse(iId, wId, stockLevels);

  final formKey = GlobalKey<FormState>();
  // Strict item-specific warehouses for stockOut / transfer-from / adjustment.
  List<WarehouseModel> itemSourceWarehouses(String? iId) {
    return warehousesWithStockForItem(iId, warehouses, stockLevels);
  }

  // Auto-select warehouse only when exactly one has stock.
  String? autoSelect(String? iId) {
    final opts = itemSourceWarehouses(iId);
    return opts.length == 1 ? opts.first.id : null;
  }

  String? itemId = moveItems.first.id;
  String? warehouseId;
  if (type == _MoveType.stockIn) {
    final assigned = warehousesAssignedToItem(itemId, warehouses, stockLevels);
    warehouseId = assigned.isNotEmpty ? assigned.first.id : null;
  } else {
    // stockOut / adjustment: auto-select only when exactly one warehouse
    warehouseId = autoSelect(itemId);
  }
  // transfer fromWarehouse: same item-based auto-select logic
  String? fromWarehouseId = autoSelect(itemId);
  // toWarehouse: never auto-select
  String? toWarehouseId;
  final qty = TextEditingController();
  final notes = TextEditingController();

  final title = switch (type) {
    _MoveType.stockIn => 'Stock In',
    _MoveType.stockOut => 'Stock Out',
    _MoveType.transfer => 'Transfer Stock',
    _MoveType.adjustment => 'Adjust Stock',
  };

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final fromAvailable = availableQty(itemId, fromWarehouseId);
          final warehouseAvailable = availableQty(itemId, warehouseId);

          // Warehouse options filtered by item:
          // stockIn  → only warehouses the item is assigned to
          // stockOut / adjustment / transfer-from → warehouses with qty > 0
          // toWarehouse (transfer) → all warehouses, no restriction
          final warehouseOptions = switch (type) {
            _MoveType.stockIn =>
              warehousesAssignedToItem(itemId, warehouses, stockLevels),
            _MoveType.stockOut ||
            _MoveType.adjustment =>
              itemSourceWarehouses(itemId),
            _ => warehouses, // transfer uses fromWarehouseOptions below
          };
          // transfer From Warehouse uses item-based options
          final fromWarehouseOptions = type == _MoveType.transfer
              ? itemSourceWarehouses(itemId)
              : warehouses;
          final available = type == _MoveType.stockOut
              ? warehouseAvailable
              : type == _MoveType.transfer
                  ? fromAvailable
                  : 0;
          final totalAcrossWarehouses = () {
            if (itemId == null) return 0;
            var sum = 0;
            for (final w in warehouses) {
              sum += availableQty(itemId, w.id);
            }
            return sum;
          }();
          final warehouseStockLines = warehouses
              .map(
                (w) => (
                  id: w.id,
                  name: w.name,
                  qty: availableQty(itemId, w.id),
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: itemId,
                      decoration: InputDecoration(
                        labelText: 'Select Item *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: moveItems
                          .map(
                            (ItemModel i) => DropdownMenuItem(
                              value: i.id,
                              child: Text(
                                i.status == 'pending'
                                    ? '${i.name} (pending)'
                                    : i.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setModalState(() {
                        itemId = v;
                        if (type == _MoveType.stockIn) {
                          final assigned = warehousesAssignedToItem(
                            v,
                            warehouses,
                            stockLevels,
                          );
                          warehouseId =
                              assigned.isNotEmpty ? assigned.first.id : null;
                        } else if (type == _MoveType.transfer) {
                          // from: auto-select only when exactly one has stock
                          fromWarehouseId = autoSelect(v);
                          toWarehouseId = null; // reset to destination
                        } else {
                          // stockOut / adjustment
                          warehouseId = autoSelect(v);
                        }
                      }),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Select an item' : null,
                    ),
                    const SizedBox(height: 12),
                    if (type == _MoveType.transfer) ...[
                      if (fromWarehouseOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'This item is not available in any warehouse.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        // null when multiple options — user must pick
                        value: fromWarehouseOptions
                                .any((w) => w.id == fromWarehouseId)
                            ? fromWarehouseId
                            : (fromWarehouseOptions.length == 1
                                ? fromWarehouseOptions.first.id
                                : null),
                        decoration: InputDecoration(
                          labelText: 'From Warehouse *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: fromWarehouseOptions
                            .map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => fromWarehouseId = v),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Select source warehouse'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: toWarehouseId,
                        decoration: InputDecoration(
                          labelText: 'To Warehouse *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: warehouses
                            .map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(w.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => toWarehouseId = v),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Select destination warehouse';
                          }
                          if (v == fromWarehouseId) {
                            return 'Source and destination must differ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Warehouse Stock',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            ...warehouseStockLines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _warehouseDotColor(line.id),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(line.name)),
                                    Text(
                                      '${line.qty} units',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Available',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  '$totalAcrossWarehouses units',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      if (type == _MoveType.stockIn &&
                          warehouseOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'This item is not assigned to any warehouse yet.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else if (warehouseOptions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'This item is not available in any warehouse.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          // null when multiple options — user must pick
                          value: warehouseOptions
                                  .any((w) => w.id == warehouseId)
                              ? warehouseId
                              : (warehouseOptions.length == 1
                                  ? warehouseOptions.first.id
                                  : null),
                          decoration: InputDecoration(
                            labelText: 'Warehouse *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: warehouseOptions
                              .map(
                                (WarehouseModel w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setModalState(() => warehouseId = v),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Select a warehouse'
                              : null,
                        ),
                    ],
                    if (type == _MoveType.stockIn &&
                        warehouseId != null &&
                        warehouseOptions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Available Stock: $warehouseAvailable',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                    if (type == _MoveType.stockOut) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          'Available Stock: $available',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qty,
                      decoration: InputDecoration(
                        labelText: type == _MoveType.adjustment
                            ? 'New Quantity *'
                            : 'Quantity *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (v) {
                        if (type == _MoveType.adjustment) {
                          return AppValidators.nonNegativeNumber(v, 'Quantity');
                        }
                        final base = AppValidators.positiveNumber(v, 'Quantity');
                        if (base != null) return base;
                        if (type == _MoveType.stockOut ||
                            type == _MoveType.transfer) {
                          final q = int.tryParse(v?.trim() ?? '') ?? 0;
                          if (q > available) {
                            return 'Quantity exceeds available stock ($available)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(250),
                      ],
                      validator: (v) => AppValidators.maxLength(
                        v,
                        max: 250,
                        field: 'Notes',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          if (type == _MoveType.transfer &&
                              fromWarehouseId == toWarehouseId) {
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        child: const Text(
                          'Submit Transaction',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (saved != true) return;

  if (type == _MoveType.transfer && fromWarehouseId == toWarehouseId) {
    ref.read(globalLoadingProvider.notifier).showError(
          'Source and destination warehouses must differ',
        );
    return;
  }

  final quantity = int.parse(qty.text.trim());
  final note = notes.text.trim().isEmpty ? null : notes.text.trim();
  final repo = ref.read(inventoryRepositoryProvider);

  ref.read(globalLoadingProvider.notifier).showLoading('Updating stock...');
  try {
    switch (type) {
      case _MoveType.stockIn:
        await repo.stockIn(
          itemId: itemId!,
          warehouseId: warehouseId!,
          quantity: quantity,
          notes: note,
        );
      case _MoveType.stockOut:
        await repo.stockOut(
          itemId: itemId!,
          warehouseId: warehouseId!,
          quantity: quantity,
          notes: note,
        );
      case _MoveType.transfer:
        await repo.stockTransfer(
          itemId: itemId!,
          fromWarehouseId: fromWarehouseId!,
          toWarehouseId: toWarehouseId!,
          quantity: quantity,
          notes: note,
        );
      case _MoveType.adjustment:
        await repo.stockAdjustment(
          itemId: itemId!,
          warehouseId: warehouseId!,
          quantity: quantity,
          notes: note,
        );
    }
    ref.read(globalLoadingProvider.notifier).hide();
    ref.read(globalLoadingProvider.notifier).showSuccess('Stock updated');
    ref.read(stockListProvider.notifier).refresh();
    ref.invalidate(lowStockProvider);
    ref.invalidate(ledgerListProvider);
  } catch (e) {
    ref.read(globalLoadingProvider.notifier).hide();
    ref.read(globalLoadingProvider.notifier).showApiError(e);
  }
}

class _GroupedStockEntry {
  const _GroupedStockEntry({
    required this.itemName,
    required this.minStock,
    required this.totalQuantity,
    required this.isLowStock,
    required this.warehouses,
  });

  final String itemName;
  final int minStock;
  final int totalQuantity;
  final bool isLowStock;
  final List<StockModel> warehouses;
}

List<_GroupedStockEntry> _groupStockByItem(List<StockModel> items) {
  final grouped = <String, List<StockModel>>{};
  for (final row in items) {
    grouped.putIfAbsent(row.itemId, () => []).add(row);
  }

  final entries = grouped.entries.map((entry) {
    final rows = entry.value
      ..sort((a, b) => a.warehouseName.compareTo(b.warehouseName));
    final first = rows.first;
    return _GroupedStockEntry(
      itemName: first.itemName,
      minStock: first.minStock,
      totalQuantity: first.totalQuantity,
      isLowStock: first.isLowStock,
      warehouses: rows,
    );
  }).toList()
    ..sort((a, b) => a.itemName.compareTo(b.itemName));

  return entries;
}

Color _warehouseDotColor(String warehouseId) {
  const palette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFEA580C),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
    Color(0xFFCA8A04),
  ];
  return palette[warehouseId.hashCode.abs() % palette.length];
}

class _GroupedStockCard extends StatelessWidget {
  const _GroupedStockCard({required this.entry});

  final _GroupedStockEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor =
        entry.isLowStock ? Colors.orange.shade800 : Colors.green.shade700;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isLowStock
              ? Colors.orange.withAlpha(150)
              : scheme.outline.withAlpha(30),
          width: entry.isLowStock ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.itemName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Stock by warehouse',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...entry.warehouses.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _warehouseDotColor(row.warehouseId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.warehouseName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${row.currentQuantity}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StockSummaryChip(label: 'Total Qty', value: '${entry.totalQuantity}'),
                const SizedBox(width: 8),
                _StockSummaryChip(label: 'Min', value: '${entry.minStock}'),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.isLowStock ? 'Low Stock' : 'OK',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSummaryChip extends StatelessWidget {
  const _StockSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
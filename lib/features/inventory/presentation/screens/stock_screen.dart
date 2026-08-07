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

enum _MoveType { stockIn, stockOut, transfer, adjustment }

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockListProvider);
    final warehouses = ref.watch(warehousesProvider);
    final canUpdate = ref.watch(authProvider).hasPermission('inventory.update');
    final theme = Theme.of(context);

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

  final stockLevels = await ref.read(inventoryRepositoryProvider).getStock();
  if (!context.mounted) return;

  int availableQty(String? iId, String? wId) {
    if (iId == null || wId == null) return 0;
    for (final s in stockLevels) {
      if (s.itemId == iId && s.warehouseId == wId) {
        return s.currentQuantity;
      }
    }
    return 0;
  }

  final formKey = GlobalKey<FormState>();
  String? itemId = moveItems.first.id;
  String? warehouseId = warehouses.first.id;
  String? fromWarehouseId = warehouses.first.id;
  String? toWarehouseId =
      warehouses.length > 1 ? warehouses[1].id : warehouses.first.id;
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
          final available = type == _MoveType.stockOut
              ? availableQty(itemId, warehouseId)
              : 0;

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
                      onChanged: (v) => setModalState(() => itemId = v),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Select an item' : null,
                    ),
                    const SizedBox(height: 12),
                    if (type == _MoveType.transfer) ...[
                      DropdownButtonFormField<String>(
                        value: fromWarehouseId,
                        decoration: InputDecoration(
                          labelText: 'From Warehouse *',
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
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: warehouseId,
                        decoration: InputDecoration(
                          labelText: 'Warehouse *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: warehouses
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
                        if (type == _MoveType.stockOut) {
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
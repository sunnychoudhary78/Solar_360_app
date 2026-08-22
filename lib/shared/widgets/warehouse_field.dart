import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/features/inventory/presentation/utils/stock_movement_utils.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

/// Dropdown for selecting an active warehouse, with optional manage link.
class WarehouseField extends ConsumerWidget {
  final String? warehouseId;
  final String? warehouseName;
  final String? itemId;
  final Iterable<String>? itemWarehouseIds;
  final bool restrictToItemWarehouses;
  final bool readOnly;
  final bool requiredField;
  final ValueChanged<String?> onChanged;

  const WarehouseField({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    this.itemId,
    this.itemWarehouseIds,
    this.restrictToItemWarehouses = true,
    required this.readOnly,
    required this.requiredField,
    required this.onChanged,
  });

  Future<void> _openWarehouses(BuildContext context, WidgetRef ref) async {
    await Navigator.pushNamed(context, '/inventory/warehouses');
    invalidateWarehouseProviders(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehousesProvider);
    final stockRows = ref.watch(stockListProvider).items;
    final canManage = ref.watch(authProvider).hasPermission('inventory.create') ||
        ref.watch(authProvider).hasPermission('inventory.update') ||
        ref.watch(authProvider).hasPermission('inventory.read');

    if (readOnly) {
      final label = warehouseName?.isNotEmpty == true
          ? warehouseName!
          : (warehouseId == null || warehouseId!.isEmpty ? '—' : warehouseId!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Warehouse',
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
            child: Text(label),
          ),
          if (!requiredField)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Warehouse is set when the item is created.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      );
    }

    return warehousesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Could not load warehouses.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => invalidateWarehouseProviders(ref),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (warehouses) {
        final options = warehousesForItemSelection(
          itemId: itemId,
          allWarehouses: warehouses,
          stockRows: stockRows,
          itemWarehouseIds: itemWarehouseIds,
          restrictToItem: restrictToItemWarehouses,
        );

        if (options.isEmpty) {
          final message = itemId != null &&
                  itemId!.isNotEmpty &&
                  restrictToItemWarehouses
              ? 'This item is not assigned to any warehouse yet.'
              : 'No active warehouses yet. Create one before continuing.';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: itemId != null && itemId!.isNotEmpty
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
              ),
              if (itemId == null || itemId!.isEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final opened = await showWarehouseUnavailableDialog(
                      context,
                      message:
                          'Create a warehouse first, then come back to assign it.',
                    );
                    if (opened) invalidateWarehouseProviders(ref);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Warehouse'),
                ),
              ],
            ],
          );
        }

        final ids = options.map((w) => w.id).toSet();
        final selected = ids.contains(warehouseId) ? warehouseId : null;
        final effectiveSelected = selected ?? options.first.id;

        if (selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(options.first.id);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('${itemId ?? 'all'}-$effectiveSelected'),
              initialValue: effectiveSelected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: requiredField ? 'Warehouse *' : 'Warehouse',
                prefixIcon: const Icon(Icons.warehouse_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: options
                  .map(
                    (WarehouseModel w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        w.displayLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              validator: requiredField
                  ? (v) => v == null || v.isEmpty ? 'Select a warehouse' : null
                  : null,
            ),
            if (itemId != null &&
                itemId!.isNotEmpty &&
                effectiveSelected.isNotEmpty)
              _AvailableStockHint(
                itemId: itemId!,
                warehouseId: effectiveSelected,
              ),
            if (canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openWarehouses(context, ref),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Manage warehouses'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AvailableStockHint extends ConsumerWidget {
  const _AvailableStockHint({
    required this.itemId,
    required this.warehouseId,
  });

  final String itemId;
  final String warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stockState = ref.watch(stockListProvider);

    if (stockState.isLoading && stockState.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(
          'Checking available stock…',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final available = availableQtyAtWarehouse(
      itemId,
      warehouseId,
      stockState.items,
    );
    final isLow = available <= 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: isLow ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Available: $available units',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isLow ? scheme.error : scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

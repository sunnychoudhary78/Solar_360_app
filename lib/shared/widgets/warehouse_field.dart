import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

/// Dropdown for selecting an active warehouse, with optional manage link.
class WarehouseField extends ConsumerWidget {
  final String? warehouseId;
  final String? warehouseName;
  final bool readOnly;
  final bool requiredField;
  final ValueChanged<String?> onChanged;

  const WarehouseField({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
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
        if (warehouses.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No active warehouses yet. Create one before continuing.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
          );
        }

        final ids = warehouses.map((w) => w.id).toSet();
        final selected = ids.contains(warehouseId) ? warehouseId : null;

        if (selected == null && warehouses.length == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(warehouses.first.id);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(selected ?? 'warehouse-none'),
              initialValue: selected,
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
              items: warehouses
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

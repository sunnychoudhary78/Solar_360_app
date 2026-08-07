import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';

import '../../data/models/inventory_models.dart';
import '../providers/inventory_providers.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(warehousesProvider);
    final canCreate =
        ref.watch(authProvider).hasPermission('inventory.create');
    final canUpdate =
        ref.watch(authProvider).hasPermission('inventory.update');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(title: 'Warehouses'),
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Warehouse'),
              elevation: 3,
            )
          : null,
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(warehousesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(warehousesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    title: 'No warehouses found',
                    icon: Icons.warehouse_outlined,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(warehousesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final warehouse = items[index];
                return _WarehouseCard(
                  warehouse: warehouse,
                  canUpdate: canUpdate,
                  onEdit: () => _showForm(context, ref, warehouse: warehouse),
                  onDeactivate: () =>
                      _deactivateWarehouse(context, ref, warehouse),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _deactivateWarehouse(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Deactivate warehouse',
      message:
          'Are you sure you want to deactivate ${warehouse.name}? This action can be reversed by an administrator.',
      confirmLabel: 'Deactivate',
      isDestructive: true,
    );
    if (!ok) return;

    ref.read(globalLoadingProvider.notifier).showLoading('Deactivating...');
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .deactivateWarehouse(warehouse.id);
      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Warehouse deactivated');
      ref.invalidate(warehousesProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    WarehouseModel? warehouse,
  }) async {
    final result = await showModalBottomSheet<_WarehouseFormData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _WarehouseFormBottomSheet(warehouse: warehouse),
    );

    if (result == null) return;

    ref.read(globalLoadingProvider.notifier).showLoading(
          warehouse == null ? 'Creating...' : 'Updating...',
        );
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      if (warehouse == null) {
        await repo.createWarehouse(
          name: result.name,
          location: result.location,
        );
      } else {
        await repo.updateWarehouse(
          id: warehouse.id,
          name: result.name,
          location: result.location,
        );
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            warehouse == null ? 'Warehouse created' : 'Warehouse updated',
          );
      ref.invalidate(warehousesProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

/// Styled Material 3 Warehouse Card Component
class _WarehouseCard extends StatelessWidget {
  final WarehouseModel warehouse;
  final bool canUpdate;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _WarehouseCard({
    required this.warehouse,
    required this.canUpdate,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation =
        warehouse.location != null && warehouse.location!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(128),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(128),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.warehouse_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      warehouse.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hasLocation
                                ? warehouse.location!
                                : 'No location specified',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: hasLocation
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurfaceVariant
                                      .withAlpha(140),
                              fontStyle: hasLocation
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions Menu
              if (canUpdate)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'deactivate') onDeactivate();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Edit details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Deactivate',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data transport object for form result
class _WarehouseFormData {
  final String name;
  final String? location;

  _WarehouseFormData({required this.name, this.location});
}

/// Encapsulated Bottom Sheet Form
class _WarehouseFormBottomSheet extends StatefulWidget {
  final WarehouseModel? warehouse;

  const _WarehouseFormBottomSheet({this.warehouse});

  @override
  State<_WarehouseFormBottomSheet> createState() =>
      __WarehouseFormBottomSheetState();
}

class __WarehouseFormBottomSheetState
    extends State<_WarehouseFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.warehouse?.name ?? '');
    _locationController =
        TextEditingController(text: widget.warehouse?.location ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final locationRaw = _locationController.text.trim();
    final location = locationRaw.isEmpty ? null : locationRaw;

    Navigator.pop(
      context,
      _WarehouseFormData(name: name, location: location),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.warehouse != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Header Title
            Text(
              isEditing ? 'Edit Warehouse' : 'New Warehouse',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Form Fields
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Warehouse Name *',
                hintText: 'Hub Name',
                prefixIcon: const Icon(Icons.warehouse_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (v) => AppValidators.entityName(v, 'Name'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location / Address',
                hintText: 'Address',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(150)],
              validator: (v) => AppValidators.maxLength(
                v,
                max: 150,
                field: 'Location',
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            FilledButton.icon(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(isEditing ? Icons.check_rounded : Icons.add_rounded),
              label: Text(
                isEditing ? 'Save Changes' : 'Create Warehouse',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
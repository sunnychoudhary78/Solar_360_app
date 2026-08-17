import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/shared/constants/item_categories.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/item_model.dart';
import '../providers/item_providers.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const ItemFormScreen({super.key, this.itemId});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _sku = TextEditingController();
  final _hsn = TextEditingController();
  final _sac = TextEditingController();
  final _gst = TextEditingController(text: '18');
  final _price = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '10');

  String _unit = 'pcs';
  String? _category;
  String? _warehouseId;
  String? _warehouseName;
  bool _loading = false;
  bool _initialized = false;
  String? _status;

  bool get isEdit => widget.itemId != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sku.dispose();
    _hsn.dispose();
    _sac.dispose();
    _gst.dispose();
    _price.dispose();
    _minStock.dispose();
    super.dispose();
  }

  void _fill(ItemModel item) {
    _name.text = item.name;
    _description.text = item.description ?? '';
    _sku.text = item.sku ?? '';
    _category = item.category;
    _hsn.text = item.hsnCode ?? '';
    _sac.text = item.sacCode ?? '';
    _gst.text = item.gstPercent.toString();
    _price.text = item.sellingPrice.toString();
    _minStock.text = item.minStockLevel.toString();
    _unit = ItemUnits.normalize(item.unit);
    _status = item.status;
    if (item.stockLevels.isNotEmpty) {
      _warehouseId = item.stockLevels.first.warehouseId;
      _warehouseName = item.stockLevels.first.warehouseName;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_status == 'approved') return;

    if (_category == null || _category!.isEmpty) {
      ref.read(globalLoadingProvider.notifier).showError('Select a category');
      return;
    }

    if (!isEdit && (_warehouseId == null || _warehouseId!.isEmpty)) {
      ref.read(globalLoadingProvider.notifier).showError('Select a warehouse');
      return;
    }

    final model = ItemModel(
      id: widget.itemId ?? '',
      name: _name.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      category: _category,
      hsnCode: _hsn.text.trim().isEmpty ? null : _hsn.text.trim(),
      sacCode: _sac.text.trim().isEmpty ? null : _sac.text.trim(),
      unit: _unit,
      gstPercent: double.parse(_gst.text.trim()),
      sellingPrice: double.parse(_price.text.trim()),
      minStockLevel: int.parse(_minStock.text.trim()),
    );

    setState(() => _loading = true);
    ref.read(globalLoadingProvider.notifier).showLoading(
          isEdit ? 'Updating item...' : 'Creating item...',
        );

    try {
      final repo = ref.read(itemRepositoryProvider);
      if (isEdit) {
        await repo.update(widget.itemId!, model);
      } else {
        await repo.create(model, warehouseId: _warehouseId);
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            isEdit ? 'Item updated' : 'Item created',
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && !_initialized) {
      final async = ref.watch(itemDetailProvider(widget.itemId!));
      return async.when(
        loading: () => const Scaffold(body: LoadingState()),
        error: (e, _) => Scaffold(
          appBar: const AppAppBar(title: 'Edit Item'),
          body: ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(itemDetailProvider(widget.itemId!)),
          ),
        ),
        data: (item) {
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _initialized) return;
              _fill(item);
              setState(() => _initialized = true);
            });
          }
          return _buildForm();
        },
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final canSave = isEdit
        ? (auth.hasPermission('item.update') ||
            auth.hasPermission('item.approve'))
        : auth.hasPermission('item.create');
    final readOnly = _status == 'approved';

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(title: isEdit ? 'Edit Item' : 'New Item'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          // Added extra bottom padding so the action button isn't cut off on lower screen bounds
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.xl + MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            if (readOnly)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.tertiary.withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: scheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Approved items cannot be edited.',
                        style: TextStyle(
                          color: scheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const PremiumSectionTitle(
              title: 'Identity',
              subtitle: 'Name, SKU and classification',
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Replaced PremiumCard with padded Container structure
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !readOnly,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    validator: (v) => AppValidators.entityName(v, 'Name'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _description,
                    enabled: !readOnly,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    inputFormatters: [LengthLimitingTextInputFormatter(500)],
                    validator: (v) => AppValidators.maxLength(
                      v,
                      max: 500,
                      field: 'Description',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category *'),
                    items: ItemCategories.options
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.value,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: readOnly
                        ? null
                        : (v) => setState(() => _category = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Select a category' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _sku,
                    enabled: !readOnly,
                    decoration: const InputDecoration(labelText: 'SKU'),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\-_]'),
                      ),
                      LengthLimitingTextInputFormatter(40),
                    ],
                    validator: AppValidators.optionalSku,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _hsn,
                    enabled: !readOnly,
                    decoration: const InputDecoration(
                      labelText: 'HSN Code',
                      hintText: '4–8 digits',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: AppValidators.hsnCode,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _sac,
                    enabled: !readOnly,
                    decoration: const InputDecoration(
                      labelText: 'SAC Code',
                      hintText: '998314',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: AppValidators.hsnCode,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: ItemUnits.allValues.contains(_unit)
                        ? _unit
                        : 'pcs',
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: ItemUnits.dropdownItems(),
                    onChanged: readOnly
                        ? null
                        : (v) {
                            if (v != null && !v.startsWith('__group_')) {
                              setState(() => _unit = v);
                            }
                          },
                  ),
                ],
              ),
            ),

            const PremiumSectionTitle(
              title: 'Warehouse',
              subtitle: 'Stock location for this item',
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _WarehouseField(
                warehouseId: _warehouseId,
                warehouseName: _warehouseName,
                readOnly: readOnly || isEdit,
                requiredField: !isEdit,
                onChanged: (id) {
                  if (mounted) setState(() => _warehouseId = id);
                },
              ),
            ),
            
            const PremiumSectionTitle(
              title: 'Pricing',
              subtitle: 'Tax and stock thresholds',
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Replaced PremiumCard with padded Container structure
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _gst,
                    enabled: !readOnly,
                    decoration: const InputDecoration(labelText: 'GST %'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: AppValidators.gstPercent,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _price,
                    enabled: !readOnly,
                    decoration:
                        const InputDecoration(labelText: 'Selling Price'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: (v) =>
                        AppValidators.nonNegativeNumber(v, 'Selling price'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _minStock,
                    enabled: !readOnly,
                    decoration:
                        const InputDecoration(labelText: 'Min Stock Level'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: (v) =>
                        AppValidators.nonNegativeNumber(v, 'Min stock'),
                  ),
                ],
              ),
            ),
            
            if (canSave && !readOnly)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  child: Text(isEdit ? 'Update' : 'Create'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseField extends ConsumerWidget {
  final String? warehouseId;
  final String? warehouseName;
  final bool readOnly;
  final bool requiredField;
  final ValueChanged<String?> onChanged;

  const _WarehouseField({
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
                'No active warehouses yet. Create one before adding this item.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final opened = await showWarehouseUnavailableDialog(
                    context,
                    message:
                        'Create a warehouse first, then come back to assign this item.',
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
              decoration: InputDecoration(
                labelText: requiredField ? 'Warehouse *' : 'Warehouse',
                prefixIcon: const Icon(Icons.warehouse_outlined),
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
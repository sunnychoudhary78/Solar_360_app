import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/warehouse_field.dart';

import '../../data/models/item_model.dart';
import '../providers/item_category_providers.dart';
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
  final _initialQty = TextEditingController(text: '0');

  String _unit = 'pcs';
  String? _category;
  String? _warehouseId;
  String? _warehouseName;
  bool _loading = false;
  bool _initialized = false;
  String? _status;

  bool get isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    // Pick up categories added/edited elsewhere (web or Item Categories screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      invalidateItemCategories(ref);
    });
  }

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
    _initialQty.dispose();
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
        final initialQty = int.tryParse(_initialQty.text.trim()) ?? 0;
        await repo.create(
          model,
          warehouseId: _warehouseId,
          initialQuantity: initialQty,
        );
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
            // Wait until saved fields (including category) are applied so
            // DropdownButtonFormField initialValue is not null on first paint.
            return const Scaffold(body: LoadingState());
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
                  _CategoryField(
                    value: _category,
                    readOnly: readOnly,
                    onChanged: (v) => setState(() => _category = v),
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
              child: WarehouseField(
                warehouseId: _warehouseId,
                warehouseName: _warehouseName,
                readOnly: readOnly || isEdit,
                requiredField: !isEdit,
                onChanged: (id) {
                  if (mounted) setState(() => _warehouseId = id);
                },
              ),
            ),
            if (!isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  controller: _initialQty,
                  enabled: !readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Opening quantity',
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  validator: (v) =>
                      AppValidators.nonNegativeNumber(v, 'Opening quantity'),
                ),
              ),
            ],
            
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

class _CategoryField extends ConsumerWidget {
  final String? value;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const _CategoryField({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(itemCategoriesProvider);

    return categoriesAsync.when(
      loading: () => InputDecorator(
        decoration: const InputDecoration(labelText: 'Category *'),
        child: Text(
          (value != null && value!.isNotEmpty) ? value! : 'Loading…',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      error: (e, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: 'Category *',
          errorText: e.toString(),
          suffixIcon: IconButton(
            tooltip: 'Retry',
            onPressed: () => invalidateItemCategories(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        child: Text(
          'Could not load categories',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      data: (allCategories) {
        // Hidden (inactive) categories are excluded from create/edit dropdowns.
        final options = selectableItemCategories(
          allCategories,
          currentValue: value,
        );
        final matched = matchItemCategory(options, value);
        final effectiveValue = matched?.value;
        if (effectiveValue != null &&
            value != null &&
            value != effectiveValue) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(effectiveValue);
          });
        }
        return DropdownButtonFormField<String>(
          key: ValueKey('item-category-$effectiveValue'),
          initialValue: effectiveValue,
          decoration: const InputDecoration(labelText: 'Category *'),
          items: options
              .map(
                (c) => DropdownMenuItem(
                  value: c.value,
                  child: Text(
                    c.isActive ? c.label : '${c.label} (hidden)',
                  ),
                ),
              )
              .toList(),
          onChanged: readOnly ? null : onChanged,
          validator: (v) =>
              v == null || v.isEmpty ? 'Select a category' : null,
        );
      },
    );
  }
}
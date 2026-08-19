import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';

import 'package:solar_sales/shared/utils/document_workflow.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';

import '../providers/inventory_providers.dart';

class StockLedgerScreen extends ConsumerStatefulWidget {
  const StockLedgerScreen({super.key});

  @override
  ConsumerState<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends ConsumerState<StockLedgerScreen> {
  final _invoiceSearch = TextEditingController();

  @override
  void dispose() {
    _invoiceSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(ledgerListProvider);
    final warehouses = ref.watch(warehousesProvider);
    final itemsAsync = ref.watch(approvedItemsProvider);

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.surfaceContainerLow,
      appBar: const AppAppBar(
        title: 'Stock Ledger',
      ),
      bottomNavigationBar:
          state.transType?.toLowerCase() == 'out' &&
                  ref.watch(authProvider).hasPermission('inventory.update')
              ? SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: () => _openStockOutForm(context),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Stock Out'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              : null,
      body: Column(
        children: [
          // Filter Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.5,
                  ),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  controller: _invoiceSearch,
                  decoration: InputDecoration(
                    hintText: 'Search invoice or reference...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: _invoiceSearch.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _invoiceSearch.clear();
                              ref
                                  .read(ledgerListProvider.notifier)
                                  .setInvoiceNumber('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                  ),
                  onSubmitted: (v) =>
                      ref.read(ledgerListProvider.notifier).setInvoiceNumber(v),
                ),
                const SizedBox(height: 12),

                // Warehouse & Item Selection Row
                Row(
                  children: [
                    // Warehouse Picker
                    Expanded(
                      child: warehouses.when(
                        loading: () => const SizedBox(
                          height: 48,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (e, _) => TextButton(
                          onPressed: () => ref.invalidate(warehousesProvider),
                          child: Text(
                            'Warehouses failed — Retry',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        data: (list) => _buildStyledDropdown<String?>(
                          context: context,
                          value: state.warehouseId,
                          hint: 'Warehouse',
                          icon: Icons.storefront,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Warehouses',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            ...list.map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  w.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => ref
                              .read(ledgerListProvider.notifier)
                              .setWarehouse(v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Item Picker
                    Expanded(
                      child: itemsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (items) => _buildStyledDropdown<String?>(
                          context: context,
                          value: state.itemId,
                          hint: 'Item',
                          icon: Icons.inventory_2_outlined,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Items',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            ...items.map(
                              (i) => DropdownMenuItem(
                                value: i.id,
                                child: Text(
                                  i.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              ref.read(ledgerListProvider.notifier).setItem(v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Transaction Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: state.transType == null,
                          label: const Text('All Types'),
                          onSelected: (_) => ref
                              .read(ledgerListProvider.notifier)
                              .setTransType(null),

                          showCheckmark: false,

                          backgroundColor: isDark
                              ? theme.colorScheme.surfaceContainerHigh
                              : theme.colorScheme.surfaceContainerHighest,

                          selectedColor: isDark
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),

                          side: BorderSide(
                            color: state.transType == null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),

                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: state.transType == null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      ...DocumentWorkflow.inventoryTransTypes.map((type) {
                        final isSelected = state.transType == type;
                        final config = _getTransConfig(type, theme);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(type.toUpperCase()),

                            onSelected: (selected) {
                              ref
                                  .read(ledgerListProvider.notifier)
                                  .setTransType(selected ? type : null);
                            },

                            showCheckmark: false,

                            backgroundColor: isDark
                                ? theme.colorScheme.surfaceContainerHigh
                                : theme.colorScheme.surfaceContainerHighest,

                            selectedColor: config.color.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),

                            side: BorderSide(
                              color: isSelected
                                  ? config.color
                                  : theme.colorScheme.outlineVariant,
                            ),

                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? config.color
                                  : theme.colorScheme.onSurfaceVariant,
                            ),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Ledger Transactions List
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                ? ErrorState(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(ledgerListProvider.notifier).refresh(),
                  )
                : PaginatedListView(
                    padding: const EdgeInsets.all(16),
                    items: state.items,
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    onRefresh: () =>
                        ref.read(ledgerListProvider.notifier).refresh(),
                    onLoadMore: () async {
                        await ref
                            .read(ledgerListProvider.notifier)
                            .loadMore();
                      },
                    empty: const EmptyState(
                      title: 'No Transactions Found',
                      icon: Icons.history_toggle_off,
                    ),
                    itemBuilder: (context, tx, _) {
                      final config = _getTransConfig(tx.transType, theme);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: isDark ? 0.3 : 0.7,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type Badge Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: config.color.withValues(
                                        alpha: isDark ? 0.15 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      config.icon,
                                      color: config.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Item Name and Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.itemName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.storefront,
                                              size: 14,
                                              color: theme.colorScheme.outline,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              tx.warehouseName,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Change
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${tx.quantity > 0 && tx.transType == 'in' ? '+' : ''}${tx.quantity}',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: config.color,
                                            ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? theme
                                                    .colorScheme
                                                    .surfaceContainer
                                              : theme
                                                    .colorScheme
                                                    .surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Bal: ${tx.balanceAfter}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1),
                              ),

                              // Footer Metadata (Type / Ref / Date)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: config.color.withValues(
                                        alpha: isDark ? 0.18 : 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tx.transType.toUpperCase(),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: config.color,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (tx.referenceNumber != null &&
                                      tx.referenceNumber!.isNotEmpty)
                                    InkWell(
                                      onTap: tx.isInvoiceReference
                                          ? () => Navigator.pushNamed(
                                              context,
                                              '/invoices/detail',
                                              arguments: tx.referenceId,
                                            )
                                          : null,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            size: 14,
                                            color: tx.isInvoiceReference
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.outline,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            tx.referenceNumber!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: tx.isInvoiceReference
                                                      ? theme
                                                            .colorScheme
                                                            .primary
                                                      : null,
                                                  decoration:
                                                      tx.isInvoiceReference
                                                      ? TextDecoration.underline
                                                      : null,
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(
                                      '—',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                    ),
                                  if (tx.createdAt != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      formatDateTime(tx.createdAt!),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }


  Future<void> _openStockOutForm(BuildContext context) async {
    List<ItemModel> currentItems;
    List<WarehouseModel> currentWarehouses;

    try {
      currentItems = await ref.read(approvedItemsProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load approved items: $e'),
        ),
      );
      return;
    }

    try {
      currentWarehouses = await ref.read(warehousesProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load warehouses: $e'),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved items are available.'),
        ),
      );
      return;
    }

    if (currentWarehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active warehouses are available.'),
        ),
      );
      return;
    }

    List<StockModel> stock;
    try {
      stock = await ref
          .read(inventoryRepositoryProvider)
          .getStock();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load current stock: $e'),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final result = await showModalBottomSheet<_StockOutFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return _StockOutSheet(
          items: currentItems,
          warehouses: currentWarehouses,
          stock: stock,
        );
      },
    );

    if (result == null) return;

    try {
      await ref
          .read(inventoryRepositoryProvider)
          .stockOut(
            itemId: result.itemId,
            warehouseId: result.warehouseId,
            quantity: result.quantity,
            notes: result.notes,
          );

      if (!mounted) return;

      ref.read(ledgerListProvider.notifier).refresh();
      ref.read(stockListProvider.notifier).refresh();
      ref.invalidate(lowStockProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stock Out completed successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock Out failed: $e'),
        ),
      );
    }
  }

  Widget _buildStyledDropdown<T>({
    required BuildContext context,
    required T value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Helper method to resolve transaction visual configuration
  _TransConfig _getTransConfig(String transType, ThemeData theme) {
    switch (transType.toLowerCase()) {
      case 'in':
        return _TransConfig(
          color: Colors.green,
          icon: Icons.arrow_downward_rounded,
        );
      case 'out':
        return _TransConfig(
          color: theme.colorScheme.error,
          icon: Icons.arrow_upward_rounded,
        );
      case 'transfer':
        return _TransConfig(
          color: theme.colorScheme.primary,
          icon: Icons.swap_horiz_rounded,
        );
      case 'adjustment':
      default:
        return _TransConfig(color: Colors.orange, icon: Icons.tune_rounded);
    }
  }
}


class _StockOutFormResult {
  final String itemId;
  final String warehouseId;
  final int quantity;
  final String? notes;

  const _StockOutFormResult({
    required this.itemId,
    required this.warehouseId,
    required this.quantity,
    this.notes,
  });
}

class _StockOutSheet extends StatefulWidget {
  final List<ItemModel> items;
  final List<WarehouseModel> warehouses;
  final List<StockModel> stock;

  const _StockOutSheet({
    required this.items,
    required this.warehouses,
    required this.stock,
  });

  @override
  State<_StockOutSheet> createState() => _StockOutSheetState();
}

class _StockOutSheetState extends State<_StockOutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  late String _itemId;
  late String _warehouseId;

  @override
  void initState() {
    super.initState();
    _itemId = widget.items.first.id;
    _warehouseId = widget.warehouses.first.id;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _availableQuantity {
    for (final stockItem in widget.stock) {
      if (stockItem.itemId == _itemId &&
          stockItem.warehouseId == _warehouseId) {
        return stockItem.currentQuantity;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
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
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Out',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Remove stock manually',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _itemId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Item *',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _itemId = value;
                    _quantityController.clear();
                  });
                },
                validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Select an item'
                        : null,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _warehouseId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Warehouse *',
                  prefixIcon: const Icon(Icons.warehouse_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.warehouses.map((warehouse) {
                  return DropdownMenuItem<String>(
                    value: warehouse.id,
                    child: Text(
                      warehouse.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _warehouseId = value;
                    _quantityController.clear();
                  });
                },
                validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Select a warehouse'
                        : null,
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.primaryContainer.withValues(alpha: 0.30)
                      : scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Available Stock',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$_availableQuantity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  hintText: 'Enter quantity',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final quantity =
                      int.tryParse(value?.trim() ?? '');

                  if (quantity == null || quantity <= 0) {
                    return 'Enter a valid quantity';
                  }

                  if (quantity > _availableQuantity) {
                    return 'Quantity cannot exceed available stock';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 250,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add a note or reason',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_outlined),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                      ),
                      label: const Text('Stock Out'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.parse(
      _quantityController.text.trim(),
    );

    final notes = _notesController.text.trim();

    Navigator.pop(
      context,
      _StockOutFormResult(
        itemId: _itemId,
        warehouseId: _warehouseId,
        quantity: quantity,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}

class _TransConfig {
  final Color color;
  final IconData icon;

  _TransConfig({required this.color, required this.icon});
}

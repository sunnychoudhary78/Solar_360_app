import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
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
    final scheme = theme.colorScheme;
    final state = ref.watch(ledgerListProvider);
    final warehouses = ref.watch(warehousesProvider);
    final itemsAsync = ref.watch(approvedItemsProvider);
    final canUpdate = ref.watch(authProvider).hasPermission('inventory.update');

    final selectedType = state.transType?.toLowerCase();
    final showAction = canUpdate && selectedType != null;
    final actionConfig = showAction
        ? _getTransConfig(selectedType!, theme)
        : null;

    return Scaffold(
      backgroundColor: isDark
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      appBar: const AppAppBar(title: 'Stock Ledger'),

      // The action is deliberately at the bottom-right and only appears
      // when one transaction type is selected.
      floatingActionButton: showAction
          ? SizedBox(
              height: 56,
              child: FloatingActionButton.extended(
                heroTag: 'stock-ledger-${selectedType ?? 'none'}',
                onPressed: () => _openMovementForm(context, selectedType!),
                icon: Icon(actionConfig!.icon),
                label: Text(
                  actionConfig.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                backgroundColor: actionConfig.color,
                foregroundColor: scheme.onPrimary,
                elevation: 5,
                extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(
                    alpha: isDark ? 0.2 : 0.5,
                  ),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _invoiceSearch,
                  decoration: InputDecoration(
                    hintText: 'Search invoice or reference...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    suffixIcon: _invoiceSearch.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _invoiceSearch.clear();
                              setState(() {});
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
                        ? scheme.surfaceContainerHigh
                        : scheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (value) => ref
                      .read(ledgerListProvider.notifier)
                      .setInvoiceNumber(value),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: warehouses.when(
                        loading: () => const SizedBox(
                          height: 48,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (error, _) => TextButton(
                          onPressed: () =>
                              ref.invalidate(warehousesProvider),
                          child: Text(
                            'Warehouses failed — Retry',
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                        data: (list) => _buildStyledDropdown<String?>(
                          context: context,
                          value: state.warehouseId,
                          hint: 'Warehouse',
                          icon: Icons.storefront,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All Warehouses',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            ...list.map(
                              (warehouse) => DropdownMenuItem<String?>(
                                value: warehouse.id,
                                child: Text(
                                  warehouse.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => ref
                              .read(ledgerListProvider.notifier)
                              .setWarehouse(value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: itemsAsync.when(
                        loading: () => const SizedBox(
                          height: 48,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (error, _) => TextButton(
                          onPressed: () =>
                              ref.invalidate(approvedItemsProvider),
                          child: Text(
                            'Items failed — Retry',
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                        data: (items) => _buildStyledDropdown<String?>(
                          context: context,
                          value: state.itemId,
                          hint: 'Item',
                          icon: Icons.inventory_2_outlined,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All Items',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            ...items.map(
                              (item) => DropdownMenuItem<String?>(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => ref
                              .read(ledgerListProvider.notifier)
                              .setItem(value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                              ? scheme.surfaceContainerHigh
                              : scheme.surfaceContainerHighest,
                          selectedColor: isDark
                              ? scheme.primaryContainer
                              : scheme.primary.withValues(alpha: 0.12),
                          side: BorderSide(
                            color: state.transType == null
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: state.transType == null
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      ...DocumentWorkflow.inventoryTransTypes.map((type) {
                        final isSelected =
                            state.transType?.toLowerCase() == type.toLowerCase();
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
                                ? scheme.surfaceContainerHigh
                                : scheme.surfaceContainerHighest,
                            selectedColor: config.color.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? config.color
                                  : scheme.outlineVariant,
                            ),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? config.color
                                  : scheme.onSurfaceVariant,
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

          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () => ref
                            .read(ledgerListProvider.notifier)
                            .refresh(),
                      )
                    : PaginatedListView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          showAction ? 92 : 16,
                        ),
                        items: state.items,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        onRefresh: () => ref
                            .read(ledgerListProvider.notifier)
                            .refresh(),
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
                          final config =
                              _getTransConfig(tx.transType, theme);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: config.color.withValues(
                                            alpha: isDark ? 0.15 : 0.12,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          config.icon,
                                          color: config.color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.itemName,
                                              style: theme
                                                  .textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.storefront,
                                                  size: 14,
                                                  color: scheme.outline,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    tx.warehouseName,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              scheme.outline,
                                                        ),
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
                                            '${tx.quantity > 0 && tx.transType.toLowerCase() == 'in' ? '+' : ''}${tx.quantity}',
                                            style: theme
                                                .textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: config.color,
                                                ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? scheme.surfaceContainer
                                                  : scheme
                                                      .surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Bal: ${tx.balanceAfter}',
                                              style: theme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(height: 1),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Transaction type chip keeps its natural
                                      // width and never competes with the
                                      // reference/date area for extra space.
                                      Flexible(
                                        flex: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: config.color.withValues(
                                              alpha: isDark ? 0.18 : 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tx.transType.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: config.color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Reference number gets the flexible
                                      // space. Long invoice/reference numbers
                                      // are ellipsized instead of overflowing.
                                      Expanded(
                                        child: tx.referenceNumber != null &&
                                                tx.referenceNumber!.isNotEmpty
                                            ? InkWell(
                                                onTap: tx.isInvoiceReference
                                                    ? () => Navigator.pushNamed(
                                                          context,
                                                          '/invoices/detail',
                                                          arguments:
                                                              tx.referenceId,
                                                        )
                                                    : null,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.receipt_long,
                                                      size: 14,
                                                      color:
                                                          tx.isInvoiceReference
                                                              ? scheme.primary
                                                              : scheme.outline,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        tx.referenceNumber!,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: theme.textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: tx
                                                                  .isInvoiceReference
                                                              ? scheme.primary
                                                              : null,
                                                          decoration: tx
                                                                  .isInvoiceReference
                                                              ? TextDecoration
                                                                  .underline
                                                              : null,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Text(
                                                '—',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: scheme.outline,
                                                ),
                                              ),
                                      ),

                                      // Date gets a bounded flexible area so
                                      // it remains visible without causing a
                                      // right-side overflow on small phones.
                                      if (tx.createdAt != null) ...[
                                        const SizedBox(width: 8),
                                        Flexible(
                                          flex: 0,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 125,
                                            ),
                                            child: Text(
                                              formatDateTime(tx.createdAt!),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: scheme.outline,
                                              ),
                                            ),
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

  Future<void> _openMovementForm(
    BuildContext context,
    String type,
  ) async {
    final normalized = type.toLowerCase();

    List<ItemModel> items;
    List<WarehouseModel> warehouses;

    try {
      items = await ref.read(approvedItemsProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load approved items: $e')),
      );
      return;
    }

    try {
      warehouses = await ref.read(warehousesProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load warehouses: $e')),
      );
      return;
    }

    if (!context.mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved items are available.'),
        ),
      );
      return;
    }

    if (warehouses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active warehouses are available.'),
        ),
      );
      return;
    }

    List<StockModel> stock = const [];
    if (normalized == 'out') {
      try {
        stock = await ref
            .read(inventoryRepositoryProvider)
            .getStock();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load current stock: $e')),
        );
        return;
      }
    }

    if (!context.mounted) return;

    final result = await showModalBottomSheet<_MovementFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => _MovementSheet(
        type: normalized,
        items: items,
        warehouses: warehouses,
        stock: stock,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repository = ref.read(inventoryRepositoryProvider);

      switch (normalized) {
        case 'in':
          await repository.stockIn(
            itemId: result.itemId,
            warehouseId: result.warehouseId,
            quantity: result.quantity,
            notes: result.notes,
          );
          break;

        case 'out':
          await repository.stockOut(
            itemId: result.itemId,
            warehouseId: result.warehouseId,
            quantity: result.quantity,
            notes: result.notes,
          );
          break;

        case 'transfer':
          if (result.toWarehouseId == null) {
            throw StateError('Destination warehouse is required.');
          }
          await repository.stockTransfer(
            itemId: result.itemId,
            fromWarehouseId: result.warehouseId,
            toWarehouseId: result.toWarehouseId!,
            quantity: result.quantity,
            notes: result.notes,
          );
          break;

        case 'adjustment':
          await repository.stockAdjustment(
            itemId: result.itemId,
            warehouseId: result.warehouseId,
            quantity: result.quantity,
            notes: result.notes,
          );
          break;

        default:
          return;
      }

      if (!mounted) return;

      await ref.read(ledgerListProvider.notifier).refresh();
      ref.read(stockListProvider.notifier).refresh();
      ref.invalidate(lowStockProvider);
      ref.invalidate(warehousesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_movementLabel(normalized)} completed successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_movementLabel(normalized)} failed: ${cleanError(e)}',
          ),
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: scheme.onSurfaceVariant,
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

  _TransConfig _getTransConfig(String transType, ThemeData theme) {
    switch (transType.toLowerCase()) {
      case 'in':
        return _TransConfig(
          label: 'Stock In',
          color: theme.colorScheme.primary,
          icon: Icons.arrow_downward_rounded,
        );
      case 'out':
        return _TransConfig(
          label: 'Stock Out',
          color: theme.colorScheme.error,
          icon: Icons.arrow_upward_rounded,
        );
      case 'transfer':
        return _TransConfig(
          label: 'Transfer',
          color: theme.colorScheme.primary,
          icon: Icons.swap_horiz_rounded,
        );
      case 'adjustment':
      default:
        return _TransConfig(
          label: 'Adjustment',
          color: theme.colorScheme.tertiary,
          icon: Icons.tune_rounded,
        );
    }
  }

  String _movementLabel(String type) {
    switch (type.toLowerCase()) {
      case 'in':
        return 'Stock In';
      case 'out':
        return 'Stock Out';
      case 'transfer':
        return 'Transfer';
      case 'adjustment':
        return 'Adjustment';
      default:
        return 'Stock movement';
    }
  }
}

class _MovementFormResult {
  final String itemId;
  final String warehouseId;
  final String? toWarehouseId;
  final int quantity;
  final String? notes;

  const _MovementFormResult({
    required this.itemId,
    required this.warehouseId,
    this.toWarehouseId,
    required this.quantity,
    this.notes,
  });
}

class _MovementSheet extends StatefulWidget {
  final String type;
  final List<ItemModel> items;
  final List<WarehouseModel> warehouses;
  final List<StockModel> stock;

  const _MovementSheet({
    required this.type,
    required this.items,
    required this.warehouses,
    this.stock = const [],
  });

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  late String _itemId;
  late String _warehouseId;
  String? _toWarehouseId;

  bool get _isTransfer => widget.type == 'transfer';
  bool get _isAdjustment => widget.type == 'adjustment';
  bool get _isStockOut => widget.type == 'out';

  @override
  void initState() {
    super.initState();

    _itemId = widget.items.first.id;
    _warehouseId = widget.warehouses.first.id;

    if (_isTransfer && widget.warehouses.length > 1) {
      _toWarehouseId = widget.warehouses[1].id;
    } else if (_isTransfer) {
      _toWarehouseId = widget.warehouses.first.id;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _availableQuantity {
    if (!_isStockOut) return 0;

    for (final stockItem in widget.stock) {
      if (stockItem.itemId == _itemId &&
          stockItem.warehouseId == _warehouseId) {
        return stockItem.currentQuantity;
      }
    }
    return 0;
  }

  String get _title {
    switch (widget.type) {
      case 'in':
        return 'Stock In';
      case 'out':
        return 'Stock Out';
      case 'transfer':
        return 'Stock Transfer';
      case 'adjustment':
        return 'Stock Adjustment';
      default:
        return 'Stock Movement';
    }
  }

  String get _subtitle {
    switch (widget.type) {
      case 'in':
        return 'Add stock to a warehouse.';
      case 'out':
        return 'Remove stock manually.';
      case 'transfer':
        return 'Move stock between warehouses.';
      case 'adjustment':
        return 'Set the exact quantity after physical count.';
      default:
        return 'Record a stock movement.';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case 'in':
        return Icons.arrow_downward_rounded;
      case 'out':
        return Icons.arrow_upward_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'adjustment':
        return Icons.tune_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Color _accent(ColorScheme scheme) {
    switch (widget.type) {
      case 'out':
        return scheme.error;
      case 'adjustment':
        return scheme.tertiary;
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(scheme);
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
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _icon,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
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

              _buildDropdown<String>(
                context: context,
                label: 'Item *',
                value: _itemId,
                icon: Icons.inventory_2_outlined,
                items: widget.items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _itemId = value;
                    _quantityController.clear();
                  });
                },
              ),

              const SizedBox(height: 12),

              _buildDropdown<String>(
                context: context,
                label: _isTransfer ? 'From *' : 'Warehouse *',
                value: _warehouseId,
                icon: Icons.warehouse_outlined,
                items: widget.warehouses
                    .map(
                      (warehouse) => DropdownMenuItem<String>(
                        value: warehouse.id,
                        child: Text(
                          warehouse.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _warehouseId = value;
                    _quantityController.clear();
                  });
                },
              ),

              if (_isTransfer) ...[
                const SizedBox(height: 12),
                _buildDropdown<String>(
                  context: context,
                  label: 'To *',
                  value: _toWarehouseId,
                  icon: Icons.warehouse_rounded,
                  items: widget.warehouses
                      .map(
                        (warehouse) => DropdownMenuItem<String>(
                          value: warehouse.id,
                          child: Text(
                            warehouse.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _toWarehouseId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select destination warehouse';
                    }
                    if (value == _warehouseId) {
                      return 'From and To warehouses must be different';
                    }
                    return null;
                  },
                ),
              ],

              if (_isStockOut) ...[
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
              ],

              const SizedBox(height: 12),

              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: _isAdjustment ? 'New quantity *' : 'Quantity *',
                  hintText: _isAdjustment
                      ? 'Enter exact current quantity'
                      : 'Enter quantity',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final quantity =
                      int.tryParse(value?.trim() ?? '');

                  if (quantity == null || quantity <= 0) {
                    if (_isAdjustment && value?.trim() == '0') {
                      return null;
                    }
                    return 'Enter a valid quantity';
                  }

                  if (_isStockOut && quantity > _availableQuantity) {
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
                      icon: Icon(_icon, size: 18),
                      label: Text(_title),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: accent,
                        foregroundColor: scheme.onPrimary,
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

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T? value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator ??
          (value) {
            if (value == null) {
              return 'Please select an option';
            }
            return null;
          },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rawQuantity = _quantityController.text.trim();
    final quantity = int.tryParse(rawQuantity);

    if (quantity == null || quantity < 0) return;

    if (_isTransfer && _toWarehouseId == null) {
      return;
    }

    if (_isTransfer && _toWarehouseId == _warehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('From and To warehouses must be different.'),
        ),
      );
      return;
    }

    final notes = _notesController.text.trim();

    Navigator.pop(
      context,
      _MovementFormResult(
        itemId: _itemId,
        warehouseId: _warehouseId,
        toWarehouseId: _toWarehouseId,
        quantity: quantity,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}

class _TransConfig {
  final String label;
  final Color color;
  final IconData icon;

  const _TransConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

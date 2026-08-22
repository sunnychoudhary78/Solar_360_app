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
import '../utils/stock_movement_utils.dart';


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
                        items: _buildDisplayItems(state.items),
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
                         itemBuilder: (context, display, _) {
                           return _buildLedgerCard(
                             context: context,
                             display: display,
                             allTransactions: state.items,
                             theme: theme,
                           );
                         },
                      ),
          ),
        ],
      ),
    );
  }


  /// Converts the raw ledger rows into UI rows.
  ///
  /// Transfers are stored as two ledger entries that share a reference:
  /// - source warehouse: `trans_type = transfer`
  /// - destination warehouse: `trans_type = in`
  /// We group those two entries so the card can show From / To warehouses.
  List<_LedgerDisplayItem> _buildDisplayItems(
    List<StockTransactionModel> transactions,
  ) {
    final result = <_LedgerDisplayItem>[];
    final consumedIds = <String>{};
    final consumedTransferKeys = <String>{};

    for (final tx in transactions) {
      if (consumedIds.contains(tx.id)) continue;

      final type = tx.transType.toLowerCase();
      final ref = tx.referenceNumber?.trim();

      if ((type == 'transfer' || type == 'in') &&
          ref != null &&
          ref.isNotEmpty) {
        final key = '${tx.itemId}|$ref';
        if (consumedTransferKeys.contains(key)) continue;

        StockTransactionModel? paired;
        for (final candidate in transactions) {
          if (candidate.id == tx.id) continue;
          if (consumedIds.contains(candidate.id)) continue;
          if (candidate.itemId != tx.itemId) continue;
          if (candidate.referenceNumber?.trim() != ref) continue;
          if (candidate.warehouseId == tx.warehouseId) continue;

          final candidateType = candidate.transType.toLowerCase();
          // Destination side is recorded as `in`; accept legacy transfer/transfer too.
          if (type == 'transfer' &&
              (candidateType == 'in' || candidateType == 'transfer')) {
            paired = candidate;
            if (candidateType == 'in') break;
          } else if (type == 'in' && candidateType == 'transfer') {
            paired = candidate;
            break;
          }
        }

        if (paired != null) {
          consumedTransferKeys.add(key);
          consumedIds.add(tx.id);
          consumedIds.add(paired.id);

          final primary =
              type == 'transfer' ? tx : paired;
          final secondary =
              type == 'transfer' ? paired : tx;

          result.add(
            _LedgerDisplayItem(
              primary: primary,
              paired: secondary,
              adjustmentDelta: null,
            ),
          );
          continue;
        }

        // Unpaired transfer still renders as a transfer card.
        if (type == 'transfer') {
          consumedTransferKeys.add(key);
          consumedIds.add(tx.id);
          result.add(
            _LedgerDisplayItem(
              primary: tx,
              paired: null,
              adjustmentDelta: null,
            ),
          );
          continue;
        }
      }

      consumedIds.add(tx.id);
      result.add(
        _LedgerDisplayItem(
          primary: tx,
          paired: null,
          adjustmentDelta: type == 'adjustment'
              ? _calculateAdjustmentDelta(tx, transactions)
              : null,
        ),
      );
    }

    return result;
  }

  /// Calculates the actual adjustment effect from the previous ledger
  /// balance for the same item + warehouse.
  ///
  /// Example:
  /// previous balance = 10
  /// new balance      = 20
  /// displayed delta  = +10
  ///
  /// If the previous balance cannot be found, the transaction quantity is
  /// used as the best available fallback.
  int _calculateAdjustmentDelta(
    StockTransactionModel tx,
    List<StockTransactionModel> transactions,
  ) {
    StockTransactionModel? previous;

    for (final candidate in transactions) {
      if (candidate.id == tx.id) continue;
      if (candidate.itemId != tx.itemId) continue;
      if (candidate.warehouseId != tx.warehouseId) continue;

      if (tx.createdAt != null && candidate.createdAt != null) {
        if (!candidate.createdAt!.isBefore(tx.createdAt!)) continue;

        if (previous == null ||
            (previous.createdAt != null &&
                candidate.createdAt!.isAfter(previous.createdAt!))) {
          previous = candidate;
        }
      }
    }

    if (previous != null) {
      return tx.balanceAfter - previous.balanceAfter;
    }

    return tx.quantity;
  }

  Widget _buildLedgerCard({
    required BuildContext context,
    required _LedgerDisplayItem display,
    required List<StockTransactionModel> allTransactions,
    required ThemeData theme,
  }) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tx = display.primary;
    final type = tx.transType.toLowerCase();
    final config = _getTransConfig(tx.transType, theme);

    final isTransfer = type == 'transfer';
    final isAdjustment = type == 'adjustment';

    final amount = isAdjustment
        ? (display.adjustmentDelta ?? tx.quantity)
        : tx.quantity.abs();

    final amountText = isAdjustment
        ? amount == 0
            ? '0'
            : '${amount > 0 ? '+' : ''}$amount'
        : '${type == 'in' ? '+' : type == 'out' ? '-' : ''}$amount';

    final amountColor = isAdjustment
        ? amount > 0
            ? scheme.primary
            : amount < 0
                ? scheme.error
                : scheme.onSurfaceVariant
        : config.color;

    final source = isTransfer
        ? _transferSource(display, allTransactions)
        : null;
    final destination = isTransfer
        ? _transferDestination(display, allTransactions)
        : null;

    if (isTransfer) {
      final transferSource = source ?? tx;
      final analysis = _analyzeTransfer(
        source: transferSource,
        destination: destination,
        allTransactions: allTransactions,
      );

      return _TransferLedgerCard(
        itemName: tx.itemName,
        fromWarehouse: analysis.fromWarehouse,
        toWarehouse: analysis.toWarehouse,
        quantity: amount,
        transferDate: tx.createdAt,
        config: config,
        analysisPanel: _buildTransferAnalysisPanel(
          context: context,
          theme: theme,
          analysis: analysis,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: isDark ? 0.3 : 0.7,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: config.color.withValues(
                      alpha: isDark ? 0.15 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    config.icon,
                    color: config.color,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 15,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              tx.warehouseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? scheme.surfaceContainer
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        'Bal: ${tx.balanceAfter}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isAdjustment) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      amount > 0
                          ? Icons.trending_up_rounded
                          : amount < 0
                              ? Icons.trending_down_rounded
                              : Icons.remove_rounded,
                      size: 18,
                      color: amountColor,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        amount > 0
                            ? 'Stock increased'
                            : amount < 0
                                ? 'Stock decreased'
                                : 'No stock change',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                    ),
                    Text(
                      'New: ${tx.balanceAfter}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 11),
              child: Divider(height: 1),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: config.color.withValues(
                      alpha: isDark ? 0.18 : 0.11,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    tx.transType.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: config.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: tx.referenceNumber != null &&
                          tx.referenceNumber!.isNotEmpty
                      ? InkWell(
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
                                Icons.receipt_long_outlined,
                                size: 15,
                                color: tx.isInvoiceReference
                                    ? scheme.primary
                                    : scheme.outline,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  tx.referenceNumber!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: tx.isInvoiceReference
                                        ? scheme.primary
                                        : null,
                                    decoration: tx.isInvoiceReference
                                        ? TextDecoration.underline
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
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                ),
                if (tx.createdAt != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 125),
                      child: Text(
                        formatDateTime(tx.createdAt!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
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
  }

  Widget _buildTransferAnalysisPanel({
    required BuildContext context,
    required ThemeData theme,
    required _TransferAnalysis analysis,
  }) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = analysis.isLowStock ? scheme.error : const Color(0xFF059669);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Transfer analysis',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _buildTransferMetricRow(
            context: context,
            label: 'Item / Product',
            value: analysis.itemName,
          ),
          _buildTransferDetailRow(
            context: context,
            icon: Icons.arrow_upward_rounded,
            label: 'From Warehouse',
            value: analysis.fromWarehouse,
            isSource: true,
          ),
          const SizedBox(height: 8),
          _buildTransferDetailRow(
            context: context,
            icon: Icons.arrow_downward_rounded,
            label: 'To Warehouse',
            value: analysis.toWarehouse,
            isSource: false,
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          _buildTransferMetricRow(
            context: context,
            label: 'Available (before transfer)',
            value: '${analysis.availableBeforeSource}',
            emphasize: true,
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Transferred Qty',
            value: '${analysis.transferredQty}',
            emphasize: true,
            valueColor: scheme.primary,
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Remaining (source warehouse)',
            value: '${analysis.remainingAtSource}',
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Remaining/Current Stock (destination)',
            value: '${analysis.destinationBalanceAfter}',
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Balanced Qty (total stock)',
            value: '${analysis.balancedQuantity}',
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Shared/Transferred (from source)',
            value: '${analysis.sharedTransferredQty}',
          ),
          _buildTransferMetricRow(
            context: context,
            label: 'Min Stock',
            value: '${analysis.minStock}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Status',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  analysis.statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (analysis.warehouseBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Stock by warehouse (after transfer)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.warehouseBreakdown.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _warehouseDotColor(entry.warehouseId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.warehouseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.quantity}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (analysis.transferDate != null ||
              (analysis.referenceNumber?.isNotEmpty ?? false) ||
              (analysis.notes?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            if (analysis.transferDate != null)
              _buildTransferMetricRow(
                context: context,
                label: 'Transfer Date',
                value: formatDateTime(analysis.transferDate),
              ),
            if (analysis.referenceNumber?.isNotEmpty ?? false)
              _buildTransferMetricRow(
                context: context,
                label: 'Reference',
                value: analysis.referenceNumber!,
              ),
            if (analysis.notes?.isNotEmpty ?? false)
              _buildTransferMetricRow(
                context: context,
                label: 'Notes',
                value: analysis.notes!,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferMetricRow({
    required BuildContext context,
    required String label,
    required String value,
    bool emphasize = false,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
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

  _TransferAnalysis _analyzeTransfer({
    required StockTransactionModel source,
    required StockTransactionModel? destination,
    required List<StockTransactionModel> allTransactions,
  }) {
    final transferredQty = source.quantity.abs();
    final remainingAtSource = source.balanceAfter;
    final availableBeforeSource = remainingAtSource + transferredQty;
    final minStock = source.item?.minStockLevel ?? 0;
    final at = source.createdAt;

    final breakdown = _warehouseBalancesAtTime(
      itemId: source.itemId,
      at: at,
      allTransactions: allTransactions,
    );

    final warehouseBreakdown = breakdown.entries
        .map(
          (entry) => _WarehouseBreakdownEntry(
            warehouseId: entry.key,
            warehouseName: entry.value.name,
            quantity: entry.value.qty,
          ),
        )
        .toList()
      ..sort((a, b) => a.warehouseName.compareTo(b.warehouseName));

    final balancedQuantity = warehouseBreakdown.fold<int>(
      0,
      (sum, entry) => sum + entry.quantity,
    );

    final sharedTransferredQty = allTransactions
        .where(
          (tx) =>
              tx.itemId == source.itemId &&
              tx.warehouseId == source.warehouseId &&
              tx.transType.toLowerCase() == 'transfer' &&
              _isOnOrBefore(tx.createdAt, at),
        )
        .fold<int>(0, (sum, tx) => sum + tx.quantity.abs());

    final isLowStock = balancedQuantity < minStock;

    return _TransferAnalysis(
      itemName: source.item?.name ?? source.itemName,
      fromWarehouse: source.warehouseName,
      toWarehouse: destination?.warehouseName ?? '—',
      availableBeforeSource: availableBeforeSource,
      transferredQty: transferredQty,
      remainingAtSource: remainingAtSource,
      destinationBalanceAfter: destination?.balanceAfter ?? 0,
      balancedQuantity: balancedQuantity,
      sharedTransferredQty: sharedTransferredQty,
      minStock: minStock,
      isLowStock: isLowStock,
      statusLabel: isLowStock ? 'Low Stock' : 'OK',
      warehouseBreakdown: warehouseBreakdown,
      transferDate: at,
      referenceNumber: source.referenceNumber,
      notes: source.notes,
    );
  }

  Map<String, ({String name, int qty})> _warehouseBalancesAtTime({
    required String itemId,
    required DateTime? at,
    required List<StockTransactionModel> allTransactions,
  }) {
    final latest = <String, StockTransactionModel>{};

    for (final tx in allTransactions) {
      if (tx.itemId != itemId) continue;
      if (!_isOnOrBefore(tx.createdAt, at)) continue;

      final existing = latest[tx.warehouseId];
      if (existing == null) {
        latest[tx.warehouseId] = tx;
        continue;
      }

      final txTime = tx.createdAt;
      final existingTime = existing.createdAt;
      if (txTime == null) continue;
      if (existingTime == null || txTime.isAfter(existingTime)) {
        latest[tx.warehouseId] = tx;
      }
    }

    return {
      for (final entry in latest.entries)
        entry.key: (name: entry.value.warehouseName, qty: entry.value.balanceAfter),
    };
  }

  bool _isOnOrBefore(DateTime? candidate, DateTime? cutoff) {
    if (cutoff == null) return true;
    if (candidate == null) return false;
    return !candidate.isAfter(cutoff);
  }

  Widget _buildTransferDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required bool isSource,
    String? secondaryValue,
    bool emphasizeValue = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = isSource ? scheme.error : scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasizeValue ? accent : scheme.onSurface,
                ),
              ),
              if (secondaryValue != null) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryValue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  StockTransactionModel? _transferSource(
    _LedgerDisplayItem display,
    List<StockTransactionModel> allTransactions,
  ) {
    final first = display.primary;
    final second = display.paired;
    if (second == null) return first;

    if (first.transType.toLowerCase() == 'transfer') return first;
    if (second.transType.toLowerCase() == 'transfer') return second;

    final firstNotes = first.notes?.toLowerCase() ?? '';
    final secondNotes = second.notes?.toLowerCase() ?? '';
    if (firstNotes.contains('(out)')) return first;
    if (secondNotes.contains('(out)')) return second;

    final firstDelta = _balanceChange(first, allTransactions);
    final secondDelta = _balanceChange(second, allTransactions);
    if (firstDelta < 0 && secondDelta >= 0) return first;
    if (secondDelta < 0 && firstDelta >= 0) return second;

    return first;
  }

  StockTransactionModel? _transferDestination(
    _LedgerDisplayItem display,
    List<StockTransactionModel> allTransactions,
  ) {
    final first = display.primary;
    final second = display.paired;
    if (second == null) return null;

    if (second.transType.toLowerCase() == 'in') return second;
    if (first.transType.toLowerCase() == 'in') return first;

    final firstNotes = first.notes?.toLowerCase() ?? '';
    final secondNotes = second.notes?.toLowerCase() ?? '';
    if (secondNotes.contains('(in)')) return second;
    if (firstNotes.contains('(in)')) return first;

    final firstDelta = _balanceChange(first, allTransactions);
    final secondDelta = _balanceChange(second, allTransactions);
    if (firstDelta < 0 && secondDelta >= 0) return second;
    if (secondDelta < 0 && firstDelta >= 0) return first;

    return second;
  }

  int _balanceChange(
    StockTransactionModel tx,
    List<StockTransactionModel> transactions,
  ) {
    StockTransactionModel? previous;

    for (final candidate in transactions) {
      if (candidate.id == tx.id) continue;
      if (candidate.itemId != tx.itemId) continue;
      if (candidate.warehouseId != tx.warehouseId) continue;

      if (tx.createdAt != null && candidate.createdAt != null) {
        if (!candidate.createdAt!.isBefore(tx.createdAt!)) continue;

        if (previous == null ||
            (previous.createdAt != null &&
                candidate.createdAt!.isAfter(previous.createdAt!))) {
          previous = candidate;
        }
      }
    }

    if (previous == null) {
      return 0;
    }

    return tx.balanceAfter - previous.balanceAfter;
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
    if (normalized == 'in' ||
        normalized == 'out' ||
        normalized == 'adjustment' ||
        normalized == 'transfer') {
      try {
        stock = await ref
            .read(inventoryRepositoryProvider)
            .getStock(approvedOnly: false);
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
  bool get _isStockIn => widget.type == 'in';

  List<WarehouseModel> get _warehouseOptions => _isStockIn
      ? warehousesAssignedToItem(_itemId, widget.warehouses, widget.stock)
      : widget.warehouses;

  @override
  void initState() {
    super.initState();

    _itemId = widget.items.first.id;
    final assigned = warehousesAssignedToItem(
      _itemId,
      widget.warehouses,
      widget.stock,
    );
    _warehouseId = _isStockIn
        ? (assigned.isNotEmpty ? assigned.first.id : widget.warehouses.first.id)
        : widget.warehouses.first.id;

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

  int _quantityAtWarehouse(String? warehouseId) {
    if (warehouseId == null || warehouseId.isEmpty) return 0;
    for (final stockItem in widget.stock) {
      if (stockItem.itemId == _itemId &&
          stockItem.warehouseId == warehouseId) {
        return stockItem.currentQuantity;
      }
    }
    return 0;
  }

  /// Warehouse-specific available stock at the selected From / source warehouse.
  int get _availableQuantity => _quantityAtWarehouse(_warehouseId);

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

  List<({String id, String name, int qty})> get _warehouseStockLines {
    final lines = widget.warehouses
        .map(
          (warehouse) => (
            id: warehouse.id,
            name: warehouse.name,
            qty: _quantityAtWarehouse(warehouse.id),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return lines;
  }

  int get _totalAvailableStock =>
      _warehouseStockLines.fold<int>(0, (sum, line) => sum + line.qty);

  Widget _buildWarehouseStockPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final lines = _warehouseStockLines;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Warehouse Stock',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text(
              'No stock in any warehouse',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...lines.map(
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
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${line.qty} units',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: line.qty > 0
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_totalAvailableStock} units',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int get _currentQuantity => _availableQuantity;

  String _warehouseName(String? warehouseId) {
    if (warehouseId == null) return '—';
    for (final warehouse in widget.warehouses) {
      if (warehouse.id == warehouseId) return warehouse.name;
    }
    return '—';
  }

  int get _enteredQuantity =>
      int.tryParse(_quantityController.text.trim()) ?? 0;

  int get _adjustmentDelta => _enteredQuantity - _currentQuantity;

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
        return 'Move stock from one warehouse to another.';
      case 'adjustment':
        return 'Enter the new physical stock quantity.';
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
                    if (_isStockIn) {
                      final assigned = warehousesAssignedToItem(
                        value,
                        widget.warehouses,
                        widget.stock,
                      );
                      _warehouseId = assigned.isNotEmpty
                          ? assigned.first.id
                          : widget.warehouses.first.id;
                    }
                  });
                },
              ),

              const SizedBox(height: 12),

              if (_isStockIn && _warehouseOptions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'This item is not assigned to any warehouse yet.',
                    style: TextStyle(color: scheme.error),
                  ),
                )
              else
                _buildDropdown<String>(
                  context: context,
                  label: _isTransfer ? 'From Warehouse *' : 'Warehouse *',
                  value: _warehouseOptions.any((w) => w.id == _warehouseId)
                      ? _warehouseId
                      : (_warehouseOptions.isNotEmpty
                          ? _warehouseOptions.first.id
                          : _warehouseId),
                  icon: Icons.warehouse_outlined,
                  items: _warehouseOptions
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
                  label: 'To Warehouse *',
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

              if (_isStockIn || _isStockOut || _isTransfer || _isAdjustment) ...[
                const SizedBox(height: 10),
                _isTransfer
                    ? _buildWarehouseStockPanel(context)
                    : Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? scheme.surfaceContainerHigh
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current stock · ${_warehouseName(_warehouseId)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '$_currentQuantity',
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
                onChanged: (_) => setState(() {}),
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

                  if ((_isStockOut || _isTransfer) &&
                      quantity > _availableQuantity) {
                    return 'Quantity cannot exceed available stock ($_availableQuantity)';
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


class _LedgerDisplayItem {
  final StockTransactionModel primary;
  final StockTransactionModel? paired;
  final int? adjustmentDelta;

  const _LedgerDisplayItem({
    required this.primary,
    required this.paired,
    required this.adjustmentDelta,
  });
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

class _TransferLedgerCard extends StatefulWidget {
  const _TransferLedgerCard({
    required this.itemName,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.quantity,
    required this.transferDate,
    required this.config,
    required this.analysisPanel,
  });

  final String itemName;
  final String fromWarehouse;
  final String toWarehouse;
  final int quantity;
  final DateTime? transferDate;
  final _TransConfig config;
  final Widget analysisPanel;

  @override
  State<_TransferLedgerCard> createState() => _TransferLedgerCardState();
}

class _TransferLedgerCardState extends State<_TransferLedgerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final compactLine =
        '${widget.fromWarehouse} → ${widget.toWarehouse}  |  ${widget.quantity} Units  |  ${formatDate(widget.transferDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? widget.config.color.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.55),
          width: _expanded ? 1.4 : 1,
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: widget.config.color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, _expanded ? 14 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.config.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.config.icon,
                        color: widget.config.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            compactLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  widget.analysisPanel,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferAnalysis {
  const _TransferAnalysis({
    required this.itemName,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.availableBeforeSource,
    required this.transferredQty,
    required this.remainingAtSource,
    required this.destinationBalanceAfter,
    required this.balancedQuantity,
    required this.sharedTransferredQty,
    required this.minStock,
    required this.isLowStock,
    required this.statusLabel,
    required this.warehouseBreakdown,
    required this.transferDate,
    required this.referenceNumber,
    required this.notes,
  });

  final String itemName;
  final String fromWarehouse;
  final String toWarehouse;
  final int availableBeforeSource;
  final int transferredQty;
  final int remainingAtSource;
  final int destinationBalanceAfter;
  final int balancedQuantity;
  final int sharedTransferredQty;
  final int minStock;
  final bool isLowStock;
  final String statusLabel;
  final List<_WarehouseBreakdownEntry> warehouseBreakdown;
  final DateTime? transferDate;
  final String? referenceNumber;
  final String? notes;
}

class _WarehouseBreakdownEntry {
  const _WarehouseBreakdownEntry({
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
  });

  final String warehouseId;
  final String warehouseName;
  final int quantity;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../../data/models/invoice_model.dart';
import '../providers/invoice_providers.dart';
import '../utils/invoice_warehouse_stock.dart';
import '../widgets/invoice_stock_plan_panel.dart';

class InvoiceApprovalsScreen extends ConsumerStatefulWidget {
  const InvoiceApprovalsScreen({super.key});

  @override
  ConsumerState<InvoiceApprovalsScreen> createState() =>
      _InvoiceApprovalsScreenState();
}

class _InvoiceApprovalsScreenState
    extends ConsumerState<InvoiceApprovalsScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingInvoicesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Invoice Approvals'),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(pendingInvoicesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(pendingInvoicesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  PremiumEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'No pending invoices',
                    subtitle: 'All invoices have been reviewed',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingInvoicesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.lg,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final inv = items[index];
                return PremiumCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inv.invoiceNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          PremiumStatusPill.forStatus(context, inv.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inv.customerName,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatInr(inv.totalAmount),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _approve(inv),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(inv.id),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/invoices/form',
                                arguments: inv.id,
                              );
                              if (result == true) {
                                ref.invalidate(pendingInvoicesProvider);
                                ref.invalidate(invoiceListProvider);
                              }
                            },
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/invoices/detail',
                              arguments: inv.id,
                            ),
                            child: const Text('View details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).appFadeSlide(index: index);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(InvoiceModel inv) async {
    InvoiceModel invoice = inv;
    if (invoice.items.isEmpty) {
      try {
        invoice = await ref.read(invoiceRepositoryProvider).getById(inv.id);
      } catch (e) {
        if (!mounted) return;
        ref.read(globalLoadingProvider.notifier).showApiError(e);
        return;
      }
    }
    late final List<WarehouseModel> warehouses;
    try {
      warehouses = await ref.read(warehousesProvider.future);
    } catch (e) {
      if (!mounted) return;
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      return;
    }
    if (!mounted) return;
    if (warehouses.isEmpty) {
      await showWarehouseUnavailableDialog(
        context,
        message:
            'No active warehouses are available. Create or activate a warehouse before approving this invoice and deducting stock.',
      );
      return;
    }

    String? preferredWarehouseId = warehouses.first.id;
    StockCheckResult? stockCheck;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runCheck(String? id) async {
              try {
                await ref.read(stockListProvider.notifier).refresh();
                final stockRows = ref.read(stockListProvider).items;
                final local = buildInvoiceDeductionPlan(
                  items: invoice.items,
                  stockRows: stockRows,
                  warehouses: warehouses,
                  preferredWarehouseId: id,
                );
                StockCheckResult result = local;
                try {
                  final api = await ref
                      .read(invoiceRepositoryProvider)
                      .stockCheck(invoice.id, warehouseId: id);
                  result = mergeDeductionPlans(
                    local: local,
                    api: api,
                    stockRows: stockRows,
                  );
                } catch (e) {
                  if (stockRows.isEmpty || invoice.items.isEmpty) {
                    result = StockCheckResult(
                      ok: false,
                      message: cleanError(e),
                    );
                  } else {
                    result = enrichAllocationAvailability(local, stockRows);
                  }
                }
                setModalState(() => stockCheck = result);
              } catch (e) {
                setModalState(
                  () => stockCheck = StockCheckResult(
                    ok: false,
                    message: cleanError(e),
                  ),
                );
              }
            }

            if (stockCheck == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                runCheck(preferredWarehouseId);
              });
            }

            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Approve ${invoice.invoiceNumber}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stock is deducted from the warehouse that holds each item. '
                      'Choose a preferred warehouse to use first when it has stock.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: preferredWarehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Preferred warehouse (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No preference'),
                        ),
                        ...warehouses.map(
                          (WarehouseModel w) => DropdownMenuItem<String?>(
                            value: w.id,
                            child: Text(w.name),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          preferredWarehouseId = v;
                          stockCheck = null;
                        });
                        runCheck(v);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (stockCheck == null)
                      const LinearProgressIndicator()
                    else
                      InvoiceStockPlanPanel(stockCheck: stockCheck!),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: stockCheck == null || !stockCheck!.ok
                          ? null
                          : () => Navigator.pop(context, true),
                      child: const Text(
                        'Approve & deduct stock',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    if (stockCheck == null || !stockCheck!.ok) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(stockCheck?.message ?? 'Insufficient stock');
      return;
    }

    final approveWarehouseId = preferredWarehouseId ??
        stockCheck!.allocations
            .map((a) => a.warehouseId)
            .whereType<String>()
            .firstOrNull ??
        warehouses.first.id;

    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .approve(invoice.id, approveWarehouseId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Approved');
      ref.invalidate(pendingInvoicesProvider);
      ref.invalidate(invoiceListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _reject(String id) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject invoice',
      hint: 'Reason for rejection',
    );
    if (!mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(invoiceRepositoryProvider).reject(id, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Rejected');
      ref.invalidate(pendingInvoicesProvider);
      ref.invalidate(invoiceListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

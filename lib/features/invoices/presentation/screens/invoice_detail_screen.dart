import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/shared/providers/branding_providers.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/company_letterhead_card.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/document_totals_summary.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';
import 'package:solar_sales/shared/widgets/rejection_banner.dart';

import '../../data/models/invoice_model.dart';
import '../providers/invoice_providers.dart';
import '../utils/invoice_warehouse_stock.dart';
import '../widgets/invoice_stock_plan_panel.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceDetailProvider(invoiceId));
    final brandingAsync = ref.watch(solarBrandingProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: const AppAppBar(title: 'Invoice'),
        body: ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
        ),
      ),
      data: (inv) {
        final canCreate = auth.hasPermission('invoice.create');
        final canApprove = auth.hasPermission('invoice.approve');
        final canSubmit = DocumentWorkflow.canSubmitInvoice(inv.status);
        final canEdit = DocumentWorkflow.canEditInvoice(
          inv.status,
          canCreate: canCreate,
          canApprove: canApprove,
          stockDeducted: inv.stockDeducted,
        );
        final isPending = DocumentWorkflow.canApproveOrRejectInvoice(
          inv.status,
        );
        final canDownload = DocumentWorkflow.canDownloadInvoice(inv.status);
        final canEmail = DocumentWorkflow.canEmailInvoice(inv.status);

        final meta = <String>[formatInr(inv.totalAmount)];
        if (inv.paymentMode != null && inv.paymentMode!.isNotEmpty) {
          meta.add(inv.paymentMode!);
        }
        if (inv.warehouseName != null && inv.warehouseName!.isNotEmpty) {
          meta.add(inv.warehouseName!);
        }
        if (inv.stockDeducted) {
          meta.add('Stock deducted');
        }

        final actionButtons = <Widget>[
          if (canEdit)
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/invoices/form',
                  arguments: inv.id,
                );
                if (result == true) {
                  ref.invalidate(invoiceDetailProvider(invoiceId));
                  ref.invalidate(invoiceListProvider);
                  ref.invalidate(pendingInvoicesProvider);
                }
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          if (canDownload)
            OutlinedButton.icon(
              onPressed: () => _downloadPdf(ref),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
            ),
          if (canEmail)
            OutlinedButton.icon(
              onPressed: () => _sendEmail(context, ref, inv.customer?.email),
              icon: const Icon(Icons.email_outlined, size: 18),
              label: const Text('Email'),
            ),
          if (canCreate && canSubmit)
            FilledButton(
              onPressed: () => _submit(context, ref),
              child: const Text('Submit for approval'),
            ),
          if (canApprove && isPending) ...[
            FilledButton(
              onPressed: () => _approve(context, ref, inv),
              child: const Text('Approve'),
            ),
            OutlinedButton(
              onPressed: () => _reject(context, ref),
              child: const Text('Reject'),
            ),
          ],
        ];

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          appBar: const AppAppBar(title: 'Invoice'),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(invoiceDetailProvider(invoiceId));
                    await ref.read(invoiceDetailProvider(invoiceId).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      DocumentDetailHeader(
                        title: inv.invoiceNumber,
                        subtitle: inv.customerName,
                        status: inv.status,
                        icon: Icons.receipt_long_outlined,
                        meta: meta,
                      ),
                      brandingAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (branding) => CompanyLetterheadCard(
                          branding: branding,
                          fromParty: inv.fromParty,
                        ),
                      ),
                      if (inv.rejectionReason != null &&
                          inv.rejectionReason!.isNotEmpty)
                        RejectionBanner(reason: inv.rejectionReason!),
                      const PremiumSectionTitle(title: 'Details'),
                      PremiumCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          children: [
                            if (inv.quotationNumber != null)
                              _InfoRow('Quotation', inv.quotationNumber!),
                            _InfoRow(
                              'Payment mode',
                              inv.paymentMode?.isNotEmpty == true
                                  ? inv.paymentMode!
                                  : '—',
                            ),
                            _InfoRow(
                              'Motor vehicle',
                              inv.motorVehicleNo?.isNotEmpty == true
                                  ? inv.motorVehicleNo!
                                  : '—',
                            ),
                            _InfoRow(
                              'E-way bill',
                              inv.ewayBillNo?.isNotEmpty == true
                                  ? inv.ewayBillNo!
                                  : '—',
                            ),
                            if (inv.warehouseName != null &&
                                inv.warehouseName!.isNotEmpty)
                              _InfoRow('Warehouse', inv.warehouseName!),
                            _InfoRow(
                              'Stock',
                              inv.stockDeducted ? 'Deducted' : 'Not deducted',
                            ),
                          ],
                        ),
                      ),
                      const PremiumSectionTitle(title: 'Items'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          children: inv.items
                              .map(
                                (line) => LineItemCard(
                                  name: line.displayName,
                                  hsnSac:
                                      line.item?.hsnCode ?? line.item?.sacCode,
                                  quantity: '${line.quantity}',
                                  rate: formatInr(line.unitPrice),
                                  gstRate: '${line.gstPercent}',
                                  amount: formatInr(line.lineTotal),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const PremiumSectionTitle(title: 'Totals'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: DocumentTotalsDisplay(
                          subtotal: inv.subtotal,
                          gstAmount: inv.gstAmount,
                          totalAmount: inv.totalAmount,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (actionButtons.isNotEmpty)
                SafeArea(
                  top: false,
                  child: StickyActionBar(children: actionButtons),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Submit invoice',
      message: 'Submit this invoice for approval?',
      confirmLabel: 'Submit',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Submitting...');
    try {
      await ref.read(invoiceRepositoryProvider).submit(invoiceId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Submitted');
      ref.invalidate(invoiceDetailProvider(invoiceId));
      ref.invalidate(invoiceListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<StockCheckResult> _stockCheckForPreferredWarehouse(
    WidgetRef ref,
    InvoiceModel invoice,
    List<WarehouseModel> warehouses,
    String? preferredWarehouseId,
  ) async {
    await ref.read(stockListProvider.notifier).refresh();
    final stockRows = ref.read(stockListProvider).items;
    final local = buildInvoiceDeductionPlan(
      items: invoice.items,
      stockRows: stockRows,
      warehouses: warehouses,
      preferredWarehouseId: preferredWarehouseId,
    );
    try {
      final api = await ref.read(invoiceRepositoryProvider).stockCheck(
            invoice.id,
            warehouseId: preferredWarehouseId,
          );
      return mergeDeductionPlans(
        local: local,
        api: api,
        stockRows: stockRows,
      );
    } catch (e) {
      if (stockRows.isNotEmpty && invoice.items.isNotEmpty) {
        return enrichAllocationAvailability(local, stockRows);
      }
      return StockCheckResult(ok: false, message: cleanError(e));
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    InvoiceModel invoice,
  ) async {
    late final List<WarehouseModel> warehouses;
    try {
      warehouses = await ref.read(warehousesProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      return;
    }
    if (!context.mounted) return;
    if (warehouses.isEmpty) {
      await showWarehouseUnavailableDialog(
        context,
        message:
            'No active warehouses are available. Create or activate a warehouse before approving this invoice and deducting stock.',
      );
      return;
    }

    String? preferredWarehouseId;
    StockCheckResult? stockCheck;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runCheck(String? id) async {
              try {
                final result = await _stockCheckForPreferredWarehouse(
                  ref,
                  invoice,
                  warehouses,
                  id,
                );
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
                      'Approve invoice',
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
                          (w) => DropdownMenuItem<String?>(
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
      try {
        stockCheck = await _stockCheckForPreferredWarehouse(
          ref,
          invoice,
          warehouses,
          preferredWarehouseId,
        );
      } catch (e) {
        ref.read(globalLoadingProvider.notifier).showApiError(e);
        return;
      }
      if (!stockCheck!.ok) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError(stockCheck!.message ?? 'Insufficient stock');
        return;
      }
    }

    // Preferred warehouse is optional — omit body when unset (web parity).
    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref.read(invoiceRepositoryProvider).approve(
            invoiceId,
            warehouseId: preferredWarehouseId,
          );
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Invoice approved');
      ref.invalidate(invoiceDetailProvider(invoiceId));
      ref.invalidate(pendingInvoicesProvider);
      ref.invalidate(invoiceListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject invoice',
      hint: 'Reason for rejection',
    );
    if (!context.mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(invoiceRepositoryProvider).reject(invoiceId, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Rejected');
      ref.invalidate(invoiceDetailProvider(invoiceId));
      ref.invalidate(pendingInvoicesProvider);
      ref.invalidate(invoiceListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _downloadPdf(WidgetRef ref) async {
    ref.read(globalLoadingProvider.notifier).showLoading('Downloading PDF...');
    try {
      final bytes = await ref
          .read(invoiceRepositoryProvider)
          .downloadPdf(invoiceId);
      await PdfHelper.saveAndOpen(bytes, filename: 'invoice-$invoiceId.pdf');
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('PDF opened');
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _sendEmail(
    BuildContext context,
    WidgetRef ref,
    String? defaultEmail,
  ) async {
    final controller = TextEditingController(text: defaultEmail ?? '');
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Send invoice email',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Email (optional override)',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty &&
                      AppValidators.optionalEmail(value) != null) {
                    return;
                  }
                  Navigator.pop(context, value);
                },
                child: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
    if (email == null) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Sending email...');
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .sendEmail(invoiceId, email: email.isEmpty ? null : email);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Email sent');
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
    
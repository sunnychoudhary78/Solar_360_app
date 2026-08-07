import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/providers/branding_providers.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/company_letterhead_card.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/document_totals_summary.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';
import 'package:solar_sales/shared/widgets/rejection_banner.dart';

import '../providers/quotation_providers.dart';

class QuotationDetailScreen extends ConsumerWidget {
  final String quotationId;

  const QuotationDetailScreen({super.key, required this.quotationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quotationDetailProvider(quotationId));
    final brandingAsync = ref.watch(solarBrandingProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: const AppAppBar(title: 'Quotation'),
        body: ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(quotationDetailProvider(quotationId)),
        ),
      ),
      data: (q) {
        final canCreate = auth.hasPermission('quotation.create');
        final canApprove = auth.hasPermission('quotation.approve');
        final canSubmit = DocumentWorkflow.canSubmitQuotation(q.status);
        final canEdit = DocumentWorkflow.canEditQuotation(
          q.status,
          canCreate: canCreate,
          canApprove: canApprove,
        );
        final isPending = DocumentWorkflow.canApproveOrRejectQuotation(
          q.status,
        );
        final canCreateInvoice = DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: q.status,
          invoiceId: q.invoiceId,
        );
        final canDownload = DocumentWorkflow.canDownloadQuotation(q.status);
        final canEmail = DocumentWorkflow.canEmailQuotation(q.status);

        final actionButtons = <Widget>[
          if (canEdit)
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/quotations/form',
                  arguments: q.id,
                );
                if (result == true) {
                  ref.invalidate(quotationDetailProvider(quotationId));
                  ref.invalidate(quotationListProvider);
                  ref.invalidate(pendingQuotationsProvider);
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
              onPressed: () => _sendEmail(context, ref, q.customer?.email),
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
              onPressed: () => _approve(context, ref),
              child: const Text('Approve'),
            ),
            OutlinedButton(
              onPressed: () => _reject(context, ref),
              child: const Text('Reject'),
            ),
          ],
          if (canCreateInvoice && auth.hasPermission('invoice.create'))
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/invoices/create',
                arguments: {'quotationId': q.id},
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Create invoice'),
            ),
        ];

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          appBar: const AppAppBar(title: 'Quotation'),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(quotationDetailProvider(quotationId));
                    await ref.read(quotationDetailProvider(quotationId).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    children: [
                      DocumentDetailHeader(
                        title: q.quotationNumber,
                        subtitle: q.customerName,
                        status: q.status,
                        icon: Icons.request_quote_outlined,
                        meta: [
                          'Valid until ${formatDate(q.validUntil)}',
                          formatInr(q.totalAmount),
                        ],
                      ),
                      brandingAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (branding) => CompanyLetterheadCard(
                          branding: branding,
                          fromParty: q.fromParty,
                        ),
                      ),
                      if (q.rejectionReason != null &&
                          q.rejectionReason!.isNotEmpty)
                        RejectionBanner(reason: q.rejectionReason!),
                      if ((q.notes != null && q.notes!.isNotEmpty) ||
                          (q.customer?.aadharNumber != null &&
                              q.customer!.aadharNumber!.isNotEmpty)) ...[
                        const PremiumSectionTitle(title: 'Details'),
                        PremiumCard(
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (q.notes != null && q.notes!.isNotEmpty)
                                Text('Notes: ${q.notes}'),
                              if (q.customer?.aadharNumber != null &&
                                  q.customer!.aadharNumber!.isNotEmpty)
                                Text('Aadhar: ${q.customer!.aadharNumber}'),
                            ],
                          ),
                        ),
                      ],
                      const PremiumSectionTitle(title: 'Items'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          children: q.items
                              .map(
                                (line) => LineItemCard(
                                  name: line.displayName,
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
                          subtotal: q.subtotal,
                          gstAmount: q.gstAmount,
                          totalAmount: q.totalAmount,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (actionButtons.isNotEmpty)
                StickyActionBar(children: actionButtons),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Submit quotation',
      message: 'Submit this quotation for approval?',
      confirmLabel: 'Submit',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Submitting...');
    try {
      await ref.read(quotationRepositoryProvider).submit(quotationId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Submitted');
      ref.invalidate(quotationDetailProvider(quotationId));
      ref.invalidate(quotationListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve quotation',
      message: 'Approve this quotation?',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref.read(quotationRepositoryProvider).approve(quotationId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Approved');
      ref.invalidate(quotationDetailProvider(quotationId));
      ref.invalidate(pendingQuotationsProvider);
      ref.invalidate(quotationListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject quotation',
      hint: 'Reason for rejection',
    );
    if (!context.mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(quotationRepositoryProvider).reject(quotationId, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Rejected');
      ref.invalidate(quotationDetailProvider(quotationId));
      ref.invalidate(pendingQuotationsProvider);
      ref.invalidate(quotationListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _downloadPdf(WidgetRef ref) async {
    ref.read(globalLoadingProvider.notifier).showLoading('Downloading PDF...');
    try {
      final bytes = await ref
          .read(quotationRepositoryProvider)
          .downloadPdf(quotationId);
      await PdfHelper.saveAndOpen(
        bytes,
        filename: 'quotation-$quotationId.pdf',
      );
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
                'Send quotation email',
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
          .read(quotationRepositoryProvider)
          .sendEmail(quotationId, email: email.isEmpty ? null : email);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Email sent');
      ref.invalidate(quotationDetailProvider(quotationId));
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

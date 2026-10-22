import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/whatsapp/presentation/widgets/whatsapp_share_dialog.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/payment_models.dart';
import '../payment_format.dart';
import '../providers/payment_providers.dart';
import 'milestone_sheet.dart';
import 'payment_tiles.dart';
import 'record_payment_sheet.dart';

/// Payments block under an invoice — milestones, receipts and Record (§6.6).
/// Mirrors the web `PaymentSchedulePanel`.
class InvoicePaymentPanel extends ConsumerWidget {
  const InvoicePaymentPanel({
    super.key,
    required this.invoiceId,
    required this.invoiceTotal,
  });

  final String invoiceId;

  /// Fallback total when the summary is not returned by the API.
  final double invoiceTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoicePaymentProvider(invoiceId));
    final auth = ref.watch(authProvider);
    final canWrite = auth.hasAny(paymentWritePermissions);
    final canDelete = auth.hasAny(paymentDeletePermissions);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingState(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(invoicePaymentProvider(invoiceId)),
        ),
      ),
      data: (bundle) {
        final summary = bundle.effectiveSummary;
        final total = summary.amount > 0 ? summary.amount : invoiceTotal;
        final paid = summary.paidAmount;
        final balance = summary.amount > 0 ? summary.balance : total - paid;
        final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PremiumSectionTitle(title: 'Payments'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Collection status',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill.forStatus(context, summary.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBlock(
                            label: 'Invoiced',
                            value: formatInr(total),
                          ),
                        ),
                        Expanded(
                          child: _SummaryBlock(
                            label: 'Received',
                            value: formatInr(paid),
                          ),
                        ),
                        Expanded(
                          child: _SummaryBlock(
                            label: 'Balance',
                            value: formatInr(balance),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          summary.isOverdue
                              ? Icons.error_outline
                              : Icons.event_outlined,
                          size: 15,
                          color: summary.isOverdue
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Due ${dueDateLabel(summary.dueDate)}'
                            '${summary.overdueCount > 0 ? ' · ${summary.overdueCount} overdue' : ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: summary.isOverdue
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight:
                                  summary.isOverdue ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (bundle.schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  'No milestone found for this invoice yet.',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              ...bundle.schedules.map(
                (schedule) => _MilestoneCard(
                  invoiceId: invoiceId,
                  schedule: schedule,
                  canWrite: canWrite,
                  canDelete: canDelete,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                4,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canWrite)
                    OutlinedButton.icon(
                      onPressed: () => showMilestoneSheet(
                        context,
                        ref,
                        invoiceId: invoiceId,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add milestone'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => showWhatsAppShareDialog(
                      context,
                      entityType: 'invoice',
                      entityId: invoiceId,
                      title: 'Send payment reminder',
                      initialTemplateKey: 'invoice_payment_reminder',
                    ),
                    icon: const Icon(
                      Icons.chat_rounded,
                      size: 18,
                      color: Color(0xFF25D366),
                    ),
                    label: const Text('WhatsApp reminder'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MilestoneCard extends ConsumerWidget {
  const _MilestoneCard({
    required this.invoiceId,
    required this.schedule,
    required this.canWrite,
    required this.canDelete,
  });

  final String invoiceId;
  final PaymentScheduleModel schedule;
  final bool canWrite;
  final bool canDelete;

  Future<void> _remind(BuildContext context, WidgetRef ref) async {
    ref.read(globalLoadingProvider.notifier).showLoading('Sending reminder...');
    try {
      await ref.read(paymentRepositoryProvider).remind(schedule.id);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            'Reminder sent to the milestone owner',
          );
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _voidReceipt(
    BuildContext context,
    WidgetRef ref,
    PaymentReceiptModel receipt,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Void receipt',
      message:
          'Void ${formatInr(receipt.amount)} received on '
          '${formatDateTimeShort(receipt.paidAt)}? The milestone balance is '
          'recalculated.',
      confirmLabel: 'Void',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Voiding receipt...');
    try {
      await ref.read(paymentRepositoryProvider).voidReceipt(receipt.id);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Receipt voided');
      invalidatePaymentSurfaces(ref, invoiceId: invoiceId);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PremiumCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  schedule.displayTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill.forStatus(context, schedule.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryBlock(
                  label: 'Amount',
                  value: formatInr(schedule.amount),
                ),
              ),
              Expanded(
                child: _SummaryBlock(
                  label: 'Received',
                  value: formatInr(schedule.paidAmount),
                ),
              ),
              Expanded(
                child: _SummaryBlock(
                  label: 'Balance',
                  value: formatInr(schedule.balance),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                schedule.isOverdue ? Icons.error_outline : Icons.event_outlined,
                size: 15,
                color:
                    schedule.isOverdue ? scheme.error : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  schedule.isOverdue && schedule.daysOverdue > 0
                      ? 'Due ${dueDateLabel(schedule.dueDate)} · '
                          '${schedule.daysOverdue}d overdue'
                      : 'Due ${dueDateLabel(schedule.dueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: schedule.isOverdue
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    fontWeight: schedule.isOverdue ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
          if (schedule.receipts.isNotEmpty) ...[
            const Divider(height: 20),
            Text(
              'Receipts',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final receipt in schedule.receipts)
              PaymentReceiptTile(
                receipt: receipt,
                onDelete: canDelete
                    ? () => _voidReceipt(context, ref, receipt)
                    : null,
              ),
          ],
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (canWrite && schedule.canRecord)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => showRecordPaymentSheet(
                    context,
                    ref,
                    schedule,
                    invoiceId: invoiceId,
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Record'),
                ),
              if (canWrite)
                TextButton.icon(
                  onPressed: () => showMilestoneSheet(
                    context,
                    ref,
                    invoiceId: invoiceId,
                    schedule: schedule,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit / due date'),
                ),
              TextButton.icon(
                onPressed: () => _remind(context, ref),
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('Remind'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

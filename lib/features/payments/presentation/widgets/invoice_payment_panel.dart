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

/// Each milestone gets its own accent so the user can tell blocks apart at a
/// glance. Red is intentionally NOT used here (reserved for overdue/error).
const List<Color> _milestoneAccentsLight = [
  Color(0xFF0E7490), // teal
  Color(0xFF7C3AED), // violet
  Color(0xFFEA580C), // orange
  Color(0xFF2563EB), // blue
  Color(0xFFDB2777), // pink
  Color(0xFF65A30D), // lime
];

/// Lighter, slightly softer shades so accents stay readable on dark surfaces.
const List<Color> _milestoneAccentsDark = [
  Color(0xFF2DD4BF), // teal
  Color.fromARGB(255, 69, 23, 209), // violet
  Color(0xFFFB923C), // orange
  Color(0xFF60A5FA), // blue
  Color(0xFFF472B6), // pink
  Color(0xFFA3E635), // lime
];

Color milestoneAccent(int index, Brightness brightness) {
  final list = brightness == Brightness.dark
      ? _milestoneAccentsDark
      : _milestoneAccentsLight;
  return list[index % list.length];
}

/// Readable text/icon colour to place on top of a solid [accent] fill.
Color onAccent(Color accent) =>
    ThemeData.estimateBrightnessForColor(accent) == Brightness.light
        ? const Color(0xFF111827)
        : Colors.white;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
        final schedules = bundle.schedules;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PremiumSectionTitle(title: 'Payments'),

            // ── Overall collection status (neutral card) ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Collection status · Overall',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
                        backgroundColor: scheme.surfaceContainerHighest,
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
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Due ${dueDateLabel(summary.dueDate)}'
                            '${summary.overdueCount > 0 ? ' · ${summary.overdueCount} overdue' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: summary.isOverdue
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
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

            // ── Milestones ────────────────────────────────────────────────
            if (schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'No milestone found for this invoice yet.',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'MILESTONES (${schedules.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (var i = 0; i < schedules.length; i++)
                _MilestoneCard(
                  invoiceId: invoiceId,
                  schedule: schedules[i],
                  canWrite: canWrite,
                  index: i,
                  total: schedules.length,
                ),
            ],

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
    required this.index,
    required this.total,
  });

  final String invoiceId;
  final PaymentScheduleModel schedule;
  final bool canWrite;
  final int index;
  final int total;

  Future<void> _remind(BuildContext context, WidgetRef ref) async {
    await showWhatsAppShareDialog(
      context,
      entityType: schedule.sourceType,
      entityId: schedule.sourceId,
      title: 'Send payment reminder',
      initialTemplateKey: 'invoice_payment_reminder',
    );
  }

  // Kept from the original — wire `onDelete` in PaymentReceiptTile to this
  // when you want receipts voidable from here.
  // ignore: unused_element
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
    final isDark = theme.brightness == Brightness.dark;
    final accent = milestoneAccent(index, theme.brightness);
    final fg = onAccent(accent);
    final radius = BorderRadius.circular(AppRadius.lg);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.10 : 0.05),
          isDark ? scheme.surfaceContainerLow : scheme.surface,
        ),
        borderRadius: radius,
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured left strip
              Container(width: 6, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag: MILESTONE 1 OF 2
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'MILESTONE ${index + 1} OF $total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              schedule.displayTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill.forStatus(context, schedule.status),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                              highlightColor: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            schedule.isOverdue
                                ? Icons.error_outline
                                : Icons.event_outlined,
                            size: 15,
                            color: schedule.isOverdue
                                ? scheme.error
                                : scheme.onSurfaceVariant,
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
                                fontWeight: schedule.isOverdue
                                    ? FontWeight.w700
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (schedule.receipts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? scheme.surfaceContainerLowest
                                : scheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: isDark ? 0.6 : 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipts (${schedule.receipts.length})',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              for (final receipt in schedule.receipts)
                                PaymentReceiptTile(
                                  receipt: receipt,
                                  onDelete: null,
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Divider(
                        height: 16,
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.25),
                      ),
                      Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (canWrite && schedule.canRecord)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: fg,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => showRecordPaymentSheet(
                                context,
                                ref,
                                schedule,
                                invoiceId: invoiceId,
                                accent: accent,
                                index: index,
                                total: total,
                              ),
                              icon: const Icon(
                                Icons.payments_outlined,
                                size: 16,
                              ),
                              label: const Text('Record'),
                            ),
                          if (canWrite)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                              ),
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
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                            ),
                            onPressed: () => _remind(context, ref),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                            ),
                            label: const Text('Remind'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;

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
            color: highlight ? (highlightColor ?? scheme.primary) : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
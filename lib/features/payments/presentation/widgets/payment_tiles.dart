import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/payment_models.dart';
import '../payment_format.dart';

/// Four-up KPI tile used on the Payments overview (§6.2, §8).
class PaymentKpiCard extends StatelessWidget {
  const PaymentKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    return PremiumCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Overdue-outstanding aging buckets (§7.1).
class PaymentAgingBars extends StatelessWidget {
  const PaymentAgingBars({super.key, required this.aging});

  final PaymentAgingModel aging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final buckets = aging.buckets;
    final max = buckets.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    final accent = scheme.error;

    return PremiumCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overdue aging',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatInr(aging.total),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final bucket in buckets) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      bucket.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: max <= 0 ? 0 : bucket.amount / max,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          bucket.amount <= 0
                              ? scheme.outlineVariant
                              : accent.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: Text(
                      formatInr(bucket.amount),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PaymentMilestoneTile extends StatelessWidget {
  const PaymentMilestoneTile({
    super.key,
    required this.schedule,
    this.showParty = false,
    this.onTap,
    this.onRecord,
    this.onEdit,
    this.trailing,
  });

  final PaymentScheduleModel schedule;

  /// List mode shows the party/invoice; invoice mode already has the context.
  final bool showParty;
  final VoidCallback? onTap;
  final VoidCallback? onRecord;
  final VoidCallback? onEdit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = schedule.isOverdue || schedule.status == 'overdue';

    return PremiumCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.displayTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showParty) ...[
                      const SizedBox(height: 3),
                      Text(
                        schedule.displayParty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
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
                child: _AmountBlock(
                  label: 'Amount',
                  value: formatInr(schedule.amount),
                ),
              ),
              Expanded(
                child: _AmountBlock(
                  label: 'Received',
                  value: formatInr(schedule.paidAmount),
                ),
              ),
              Expanded(
                child: _AmountBlock(
                  label: 'Balance',
                  value: formatInr(schedule.balance),
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                overdue ? Icons.error_outline : Icons.event_outlined,
                size: 15,
                color: overdue ? scheme.error : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  overdue && schedule.daysOverdue > 0
                      ? 'Due ${dueDateLabel(schedule.dueDate)} · '
                          '${schedule.daysOverdue}d overdue'
                      : 'Due ${dueDateLabel(schedule.dueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: overdue ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: overdue ? FontWeight.w700 : null,
                  ),
                ),
              ),
              ?trailing,
              if (onRecord != null && schedule.canRecord)
                TextButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Record'),
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit milestone',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PaymentReceiptTile extends StatelessWidget {
  const PaymentReceiptTile({super.key, required this.receipt, this.onDelete});

  final PaymentReceiptModel receipt;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reference = receipt.referenceNo?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              size: 16,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatInr(receipt.amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${formatDateTimeShort(receipt.paidAt)} · '
                  '${paymentModeLabel(receipt.mode)}'
                  '${reference != null && reference.isNotEmpty ? ' · $reference' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Void receipt',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
        ],
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
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

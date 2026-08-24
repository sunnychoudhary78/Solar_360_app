import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/invoices/data/models/invoice_model.dart';
import 'package:solar_sales/features/invoices/presentation/utils/invoice_warehouse_stock.dart';

/// Shows stock availability / shortages with per-item warehouse mapping.
class InvoiceStockPlanPanel extends StatelessWidget {
  const InvoiceStockPlanPanel({super.key, required this.stockCheck});

  final StockCheckResult stockCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = stockCheck.ok;
    final borderColor = ok
        ? AppStatusColors.forStatus(context, 'approved').withValues(alpha: 0.45)
        : scheme.error.withValues(alpha: 0.45);
    final fillColor = ok
        ? AppStatusColors.forStatus(context, 'approved').withValues(alpha: 0.08)
        : scheme.error.withValues(alpha: 0.08);
    final titleColor = ok
        ? AppStatusColors.forStatus(context, 'approved')
        : scheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok
                ? 'Stock available — deduction plan:'
                : (stockCheck.message ?? 'Insufficient stock'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ok && stockCheck.allocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...stockCheck.allocations.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${allocationPlanLabel(line)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (!ok && stockCheck.lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...stockCheck.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${shortagePlanLabel(line)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

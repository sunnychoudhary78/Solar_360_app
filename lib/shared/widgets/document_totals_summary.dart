import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/gst_breakdown.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class DocumentTotalsSummary extends StatelessWidget {
  final List<LineTotalsInput> lines;

  const DocumentTotalsSummary({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final totals = calcDocumentTotals(lines);
    final b = totals.breakdown;
    final scheme = Theme.of(context).colorScheme;

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _row(context, 'Subtotal', formatInr(totals.subtotal)),
          _row(context, 'CGST (${b.cgstRate}%)', formatInr(b.cgstAmount)),
          _row(context, 'SGST (${b.sgstRate}%)', formatInr(b.sgstAmount)),
          _row(context, 'Total GST', formatInr(totals.gstAmount)),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          _row(
            context,
            'Grand Total',
            formatInr(totals.totalAmount),
            bold: true,
            color: scheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color,
      fontSize: bold ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Read-only totals from server amounts.
class DocumentTotalsDisplay extends StatelessWidget {
  final double subtotal;
  final double gstAmount;
  final double totalAmount;

  const DocumentTotalsDisplay({
    super.key,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final b = splitCgstSgst(gstAmount, subtotal);
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          _AmountRow('Subtotal', formatInr(subtotal)),
          _AmountRow('CGST (${b.cgstRate}%)', formatInr(b.cgstAmount)),
          _AmountRow('SGST (${b.sgstRate}%)', formatInr(b.sgstAmount)),
          _AmountRow('Total GST', formatInr(gstAmount)),
          Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          _AmountRow(
            'Grand Total',
            formatInr(totalAmount),
            bold: true,
            color: scheme.primary,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _AmountRow(
    this.label,
    this.value, {
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color,
      fontSize: bold ? 15 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}

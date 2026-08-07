import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';

/// Rose rejection banner matching web QuotationDetail / InvoiceDetail.
class RejectionBanner extends StatelessWidget {
  final String reason;
  final EdgeInsetsGeometry margin;

  const RejectionBanner({
    super.key,
    required this.reason,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_outlined, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Rejection reason: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: trimmed,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

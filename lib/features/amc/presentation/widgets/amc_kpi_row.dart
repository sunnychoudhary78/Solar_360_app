import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';

const _amcOverdueRose = Color(0xFFE11D48);

class AmcKpiRow extends StatelessWidget {
  const AmcKpiRow({super.key, required this.summary});

  final AmcSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      _Kpi('Plants', summary.plants, scheme.primary),
      _Kpi('AMC active', summary.amcActive, Colors.teal.shade700),
      _Kpi('Overdue', summary.overdue, _amcOverdueRose),
      _Kpi('Due this month', summary.dueThisMonth, Colors.amber.shade800),
      _Kpi(
        'Done this month',
        summary.completedThisMonth,
        Colors.green.shade700,
      ),
    ];

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: .5),
              ),
              boxShadow: AppShadows.card(scheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  '${item.value}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: item.color,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

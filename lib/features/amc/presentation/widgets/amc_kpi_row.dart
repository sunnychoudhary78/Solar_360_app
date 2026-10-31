import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';

const _amcOverdueRose = Color(0xFFE11D48);

class AmcKpiRow extends StatelessWidget {
  const AmcKpiRow({
    super.key,
    required this.summary,
    this.onPlants,
    this.onActiveAmc,
    this.onOverdue,
    this.onDueToday,
    this.onThisMonth,
    this.onDoneMonth,
  });

  final AmcSummary summary;
  final VoidCallback? onPlants;
  final VoidCallback? onActiveAmc;
  final VoidCallback? onOverdue;
  final VoidCallback? onDueToday;
  final VoidCallback? onThisMonth;
  final VoidCallback? onDoneMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      _Kpi('Plants', summary.plants, 'Installed sites', false, onPlants),
      _Kpi(
        'Active AMC',
        summary.amcActive,
        'Contracts running',
        false,
        onActiveAmc,
      ),
      _Kpi(
        'Overdue',
        summary.overdue,
        'Past the visit date',
        summary.overdue > 0,
        onOverdue,
      ),
      _Kpi(
        'Due today',
        summary.dueToday,
        "On today's calendar",
        false,
        onDueToday,
      ),
      _Kpi(
        'This month',
        summary.dueThisMonth,
        'Still to visit',
        false,
        onThisMonth,
      ),
      _Kpi(
        'Done this month',
        summary.completedThisMonth,
        'Completed visits',
        false,
        onDoneMonth,
      ),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Ink(
                width: 128,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            fontSize: 10,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${item.value}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: item.alert
                                ? _amcOverdueRose
                                : scheme.onSurface,
                          ),
                    ),
                    Text(
                      item.hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.hint, this.alert, this.onTap);
  final String label;
  final int value;
  final String hint;
  final bool alert;
  final VoidCallback? onTap;
}

import 'package:flutter/material.dart';

import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_status_chip.dart';

const _amcOverdueRose = Color(0xFFE11D48);

class AmcPlantCard extends StatelessWidget {
  const AmcPlantCard({
    super.key,
    required this.plant,
    this.canCreate = false,
    this.onOpenHistory,
    this.onStartAmc,
    this.onExtraVisit,
    this.onRenew,
  });

  final AmcPlant plant;
  final bool canCreate;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onStartAmc;
  final VoidCallback? onExtraVisit;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contract = plant.contract;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpenHistory,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.plantLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    plant.locationLabel,
                    if (plant.mobile.isNotEmpty) plant.mobile,
                    plant.systemSummary,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (contract != null) ...[
            AmcStatusChip(status: contract.status),
            const SizedBox(height: 4),
            Text(
              '${amcVisitStatusLabel(contract.status)} · ${contract.visitsPerYear}/year',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '${formatAmcDate(contract.startDate)} – ${formatAmcDate(contract.endDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (plant.visitTotal > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: plant.visitPercent / 100,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${plant.completedVisits}/${plant.visitTotal}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              plant.overdueVisits > 0
                  ? '${plant.overdueVisits} overdue'
                  : 'Next ${formatAmcDate(plant.nextVisitDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: plant.overdueVisits > 0
                        ? _amcOverdueRose
                        : scheme.onSurfaceVariant,
                    fontWeight: plant.overdueVisits > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
            ),
          ] else
            Text(
              'Not enrolled',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (contract != null) ...[
                if (canCreate && onExtraVisit != null)
                  OutlinedButton(
                    onPressed: onExtraVisit,
                    child: const Text('Extra visit'),
                  ),
                if (canCreate && onRenew != null)
                  OutlinedButton(
                    onPressed: onRenew,
                    child: const Text('Renew year'),
                  ),
                if (onOpenHistory != null)
                  OutlinedButton(
                    onPressed: onOpenHistory,
                    child: const Text('History'),
                  ),
              ] else if (canCreate && onStartAmc != null)
                FilledButton(
                  onPressed: onStartAmc,
                  child: const Text('Start AMC'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';

class AmcPlantCard extends StatelessWidget {
  const AmcPlantCard({
    super.key,
    required this.plant,
    this.canManage = false,
    this.onOpenLead,
    this.onStartAmc,
    this.onExtraVisit,
    this.onRenew,
  });

  final AmcPlant plant;
  final bool canManage;
  final VoidCallback? onOpenLead;
  final VoidCallback? onStartAmc;
  final VoidCallback? onExtraVisit;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = [
      plant.city,
      plant.district,
      plant.state,
    ].where((e) => e.trim().isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .45),
        ),
        boxShadow: AppShadows.card(scheme),
      ),
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
                      plant.fullName.isEmpty ? 'Plant' : plant.fullName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (plant.leadCode.isNotEmpty) plant.leadCode,
                        if (plant.capacity.isNotEmpty) plant.capacity,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              _AmcBadge(hasAmc: plant.hasActiveAmc),
            ],
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              location,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (plant.inverterSerialNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Inverter: ${plant.inverterSerialNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MetaChip(
                label: 'Open ${plant.openVisits}',
                color: scheme.primary,
              ),
              if (plant.overdueVisits > 0)
                const _MetaChip(
                  label: 'Overdue',
                  color: Color(0xFFE11D48),
                ),
              if (plant.nextVisitDate.isNotEmpty)
                _MetaChip(
                  label: 'Next ${formatAmcDate(plant.nextVisitDate)}',
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onOpenLead != null)
                OutlinedButton(
                  onPressed: onOpenLead,
                  child: const Text('Open lead'),
                ),
              if (canManage && !plant.hasActiveAmc && onStartAmc != null)
                FilledButton(
                  onPressed: onStartAmc,
                  child: const Text('Start AMC'),
                ),
              if (canManage && plant.hasActiveAmc && onExtraVisit != null)
                OutlinedButton(
                  onPressed: onExtraVisit,
                  child: const Text('Extra visit'),
                ),
              if (canManage && plant.hasActiveAmc && onRenew != null)
                OutlinedButton(
                  onPressed: onRenew,
                  child: const Text('Renew year'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmcBadge extends StatelessWidget {
  const _AmcBadge({required this.hasAmc});
  final bool hasAmc;

  @override
  Widget build(BuildContext context) {
    final color = hasAmc ? const Color(0xFF059669) : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        hasAmc ? 'AMC' : 'No AMC',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

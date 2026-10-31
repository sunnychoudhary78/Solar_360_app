import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_status_chip.dart';

const _amcOverdueRose = Color(0xFFE11D48);
const _amcEmerald = Color(0xFF059669);
const _amcSky = Color(0xFF0284C7);

class AmcVisitCard extends StatelessWidget {
  const AmcVisitCard({
    super.key,
    required this.visit,
    required this.onTap,
  });

  final AmcVisit visit;
  final VoidCallback onTap;

  Color get _dotColor {
    if (visit.isOverdue) return _amcOverdueRose;
    switch (visit.status) {
      case 'in_progress':
        return Colors.amber.shade600;
      case 'completed':
        return _amcEmerald;
      case 'scheduled':
        return _amcSky;
      default:
        return Colors.blueGrey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = amcChecklistProgress(visit.checklist);
    final tech = visit.assignee?.name.trim();
    final mobile = visit.plant?.mobile.trim() ?? '';

    return Material(
      color: scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          visit.title.isEmpty
                              ? 'AMC visit ${visit.visitNo}'
                              : visit.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        AmcStatusChip(status: visit.status),
                        if (visit.isOverdue)
                          const AmcStatusChip(
                            status: 'scheduled',
                            forceOverdueLabel: true,
                          ),
                        if (visit.customerSignoff)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _amcEmerald.withValues(alpha: .08),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: _amcEmerald.withValues(alpha: .25),
                              ),
                            ),
                            child: const Text(
                              'Signed off',
                              style: TextStyle(
                                color: _amcEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      visit.plantLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${formatAmcDate(visit.scheduledDate)} · ${amcRelativeDue(visit.scheduledDate)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: visit.isOverdue
                                        ? _amcOverdueRose
                                        : scheme.onSurfaceVariant,
                                    fontWeight: visit.isOverdue
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                        ),
                        Text(
                          (tech != null && tech.isNotEmpty)
                              ? tech
                              : 'Unassigned',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (mobile.isNotEmpty)
                          Text(
                            mobile,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (progress.total > 0)
                          Text(
                            '${progress.done}/${progress.total} checklist',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (visit.photos.isNotEmpty)
                          Text(
                            '${visit.photos.length} photo${visit.photos.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({super.key, required this.currentStatus});

  int _currentIndex() {
    return LeadWorkflow.pipelineIndexForStatus(
      currentStatus.trim().isEmpty ? 'New Lead' : currentStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final steps = LeadWorkflow.pipelineSteps;
    final current = _currentIndex();
    final displayStatus = currentStatus.trim().isEmpty
        ? 'No status'
        : currentStatus.trim();
    final trackColor = scheme.surfaceContainerHighest;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow progress',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            displayStatus,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length, (i) {
                final done = i < current;
                final active = i == current;

                return Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: done ? scheme.primary : trackColor,
                          child: active
                              ? Icon(
                                  Icons.check,
                                  color: scheme.primary,
                                  size: 15,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: done
                                        ? scheme.onPrimary
                                        : scheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SizedBox(
                          width: 96,
                          child: Text(
                            steps[i],
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.normal,
                              color: active
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 18,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 28),
                        color: i < current ? scheme.primary : trackColor,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

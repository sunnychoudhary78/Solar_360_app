import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

/// Distinct colour for each pipeline stage so previous vs current is obvious.
const workflowStageColors = <String, Color>{
  'Sales': Color(0xFF0EA5E9),
  'Sales Manager': Color(0xFF8B5CF6),
  'Finance Manager': Color(0xFFF59E0B),
  'Document Administrator': Color(0xFF06B6D4),
  'Bank Process': Color(0xFF6366F1),
  'Finance User': Color(0xFFEC4899),
  'Installation Manager': Color(0xFFF97316),
  'Material Engineer': Color(0xFF14B8A6),
  'Electrical Engineer': Color(0xFF3B82F6),
  'Completed': Color(0xFF10B981),
  'Subsidy': Color(0xFFA855F7),
  'Final Complete': Color(0xFF0F766E),
};

Color workflowStageColor(String stage, [int index = 0]) {
  return workflowStageColors[stage] ??
      workflowStageColors.values.elementAt(
        index % workflowStageColors.length,
      );
}

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({super.key, required this.currentStatus});

  int _currentIndex() {
    return LeadWorkflow.pipelineIndexForStatus(
      currentStatus.trim().isEmpty ? 'New Lead' : currentStatus,
    );
  }

  bool get _isRejected {
    final status = currentStatus.trim();
    return status == 'Rejected' || status == 'Rejected By Sales Manager';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final steps = LeadWorkflow.pipelineSteps;
    final current = _currentIndex();
    final displayStatus = currentStatus.trim().isEmpty
        ? 'No status'
        : LeadWorkflow.getStatusDisplayLabel(currentStatus);
    final hint = LeadWorkflow.nextActorHint(currentStatus);
    final trackColor = scheme.surfaceContainerHighest;
    final rejected = _isRejected;

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
              color: rejected ? const Color(0xFFDC2626) : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length, (i) {
                final done = i < current;
                final active = i == current;
                final stageColor = rejected && active
                    ? const Color(0xFFEF4444)
                    : workflowStageColor(steps[i], i);
                final labelColor = active || done
                    ? stageColor
                    : scheme.onSurfaceVariant;

                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active
                                  ? stageColor.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: active || done
                                ? stageColor
                                : trackColor,
                            child: done
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 15,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : scheme.onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              fontWeight: active
                                  ? FontWeight.w800
                                  : done
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                              color: labelColor,
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
                        color: i < current
                            ? workflowStageColor(steps[i], i)
                            : trackColor,
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

import 'package:flutter/material.dart';

import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';
import 'package:solar_sales/features/solar_tasks/data/solar_task_constants.dart';
import 'package:solar_sales/features/solar_tasks/presentation/widgets/solar_task_badge.dart';

Future<void> showSolarTaskPreviewSheet({
  required BuildContext context,
  required SolarTaskModel task,
  required List<SolarTaskPhase> phases,
  required bool canUpdate,
  required VoidCallback onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          String? phaseLabel = task.phaseLabel.isNotEmpty
              ? task.phaseLabel
              : null;
          if (phaseLabel == null) {
            for (final phase in phases) {
              if (phase.key == task.phaseKey) {
                phaseLabel = phase.label;
                break;
              }
            }
          }
          final leadLine = task.project == null
              ? ''
              : ' · ${task.project!.leadCode}';

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${phaseLabel ?? task.phaseKey}$leadLine',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SolarTaskBadge.status(task.status),
                  SolarTaskBadge.priority(task.priority),
                  if (task.isBlocked) SolarTaskBadge.waiting(),
                  if (task.isOverdue) SolarTaskBadge.overdue(),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _InfoTile(
                    label: 'Assignee',
                    value: task.assignee?.name ?? 'Unassigned',
                  ),
                  _InfoTile(
                    label: 'Deadline',
                    value: task.dueDate == null
                        ? 'None'
                        : SolarTaskConstants.formatDate(task.dueDate),
                    valueColor: task.isOverdue ? const Color(0xFFE11D48) : null,
                  ),
                  _InfoTile(
                    label: 'Starts',
                    value: task.startDate == null
                        ? 'None'
                        : SolarTaskConstants.formatDate(task.startDate),
                  ),
                  _InfoTile(
                    label: 'Lead',
                    value: task.project == null
                        ? '—'
                        : '${task.project!.leadCode} · ${task.project!.fullName}',
                  ),
                ],
              ),
              if (task.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  task.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
              ],
              if (task.dependencies.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'DEPENDS ON',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                ...task.dependencies.map(
                  (dep) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dep.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          SolarTaskConstants.statusLabel(dep.status ?? ''),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (canUpdate) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit task'),
                  ),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

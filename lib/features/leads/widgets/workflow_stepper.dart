import 'package:flutter/material.dart';

import '../../../core/workflow/lead_workflow.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({super.key, required this.currentStatus});

  static const Color primaryColor = Color(0xFF5663A0);

  int _currentIndex() {
    return LeadWorkflow.pipelineIndexForStatus(
      currentStatus.trim().isEmpty ? 'New Lead' : currentStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = LeadWorkflow.pipelineSteps;
    final current = _currentIndex();
    final displayStatus = currentStatus.trim().isEmpty
        ? 'No status'
        : currentStatus.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workflow progress',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            displayStatus,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
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
                          backgroundColor: done
                              ? primaryColor
                              : const Color(0xFFE4E1EA),
                          child: active
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: done ? Colors.white : Colors.black45,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
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
                              color: active ? primaryColor : Colors.black54,
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
                            ? primaryColor
                            : const Color(0xFFE4E1EA),
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

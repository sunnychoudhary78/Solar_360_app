import 'package:flutter/material.dart';

import '../../../core/workflow/lead_workflow.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({
    super.key,
    required this.currentStatus,
  });

  static const _milestones = [
    'New Lead',
    'KYC Collected',
    'Sent To Support',
    'Documents Submitted',
    'Liaison Completed',
    'Loan Approved',
    'Installation Done',
    'Government Approval Completed',
    'Lead Completed',
    'Lead Closed',
  ];

  int _currentIndex() {
    final milestoneIndex = _milestones.indexOf(currentStatus);

    if (milestoneIndex >= 0) {
      return milestoneIndex;
    }

    final allStatuses = [
      ...LeadWorkflow.nextStatus.keys,
      'Lead Closed',
    ];

    final statusIndex = allStatuses.indexOf(currentStatus);

    if (statusIndex < 0) {
      return 0;
    }

    return (statusIndex *
            (_milestones.length - 1) /
            (allStatuses.length - 1))
        .round();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex();

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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5663A0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_milestones.length, (i) {
                final done = i <= current;
                final active = i == current;

                return Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: done
                              ? const Color(0xFF5663A0)
                              : const Color(0xFFE4E1EA),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: done ? Colors.white : Colors.black45,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 72,
                          child: Text(
                            _milestones[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.normal,
                              color: active
                                  ? const Color(0xFF5663A0)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < _milestones.length - 1)
                      Container(
                        width: 24,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 20),
                        color: i < current
                            ? const Color(0xFF5663A0)
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
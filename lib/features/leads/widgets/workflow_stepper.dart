import 'package:flutter/material.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({
    super.key,
    required this.currentStatus,
  });

  static const Color primaryColor = Color(0xFF5663A0);

  static const List<String> _steps = [
    'New Lead',
    'KYC Collected',
    'Documents Verification Started',
    'Documents Verified',
    'Sent To Support',
    'Registration Completed',
    'Documents Submitted',
    'Liaison Started',
    'Liaison Completed',
    'Loan Processing Started',
    'Loan Approved',
    'Ready For Installation',
    'Installation Started',
    'Installation Done',
    'Inspection Scheduled',
    'Inspection Completed',
    'Government Approval Started',
    'Government Approval Completed',
    'Subsidy Process Started',
    'Subsidy Released',
    'Lead Completed',
    'Lead Closed',
  ];

  int _currentIndex() {
    final normalizedCurrent = currentStatus.trim().toLowerCase();

    final index = _steps.indexWhere(
      (step) => step.trim().toLowerCase() == normalizedCurrent,
    );

    if (index >= 0) return index;

    return 0;
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
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currentStatus.trim().isEmpty ? 'No status' : currentStatus,
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
              children: List.generate(_steps.length, (i) {
                final done = i <= current;
                final active = i == current;

                return Row(
                  children: [
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              done ? primaryColor : const Color(0xFFE4E1EA),
                          child: active
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color:
                                        done ? Colors.white : Colors.black45,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 82,
                          child: Text(
                            _steps[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
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
                    if (i < _steps.length - 1)
                      Container(
                        width: 22,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 20),
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
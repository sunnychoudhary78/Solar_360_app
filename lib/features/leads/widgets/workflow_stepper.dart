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
    'Sent To Portal',
    'Portal Processing Started',
    'Loan Application Initiated',
    'Documents Submitted',
    'Liaison Process Started',
    'Bank Coordination',
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

  static const Map<String, String> _aliases = {
    'start loan application': 'Loan Application Initiated',
    'loan application started': 'Loan Application Initiated',
    'loan application initiated': 'Loan Application Initiated',

    'liaison started': 'Liaison Process Started',
    'liaison process started': 'Liaison Process Started',
    'liaison process': 'Liaison Process Started',

    'bank coordination': 'Bank Coordination',

    'send to portal': 'Sent To Portal',
    'sent to portal': 'Sent To Portal',

    'portal processing': 'Portal Processing Started',
    'portal processing started': 'Portal Processing Started',

    'documents submitted': 'Documents Submitted',
    'document submitted': 'Documents Submitted',

    'kyc collected': 'KYC Collected',

    'government approval completed': 'Government Approval Completed',
    'govt approval completed': 'Government Approval Completed',

    'installation done': 'Installation Done',
    'lead completed': 'Lead Completed',
    'lead closed': 'Lead Closed',
  };

  String _clean(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _displayStepName(String status) {
    final cleaned = _clean(status);
    return _aliases[cleaned] ?? status.trim();
  }

  int _currentIndex() {
    final normalizedStatus = _clean(_displayStepName(currentStatus));

    final index = _steps.indexWhere(
      (step) => _clean(step) == normalizedStatus,
    );

    if (index >= 0) return index;

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex();
    final displayStatus = currentStatus.trim().isEmpty
        ? 'No status'
        : _displayStepName(currentStatus);

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
                          width: 88,
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
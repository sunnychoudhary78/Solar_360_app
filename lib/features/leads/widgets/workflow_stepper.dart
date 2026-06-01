import 'package:flutter/material.dart';

class WorkflowStepper extends StatelessWidget {
  final String currentStatus;

  const WorkflowStepper({super.key, required this.currentStatus});

  static const Color primaryColor = Color(0xFF5663A0);

  static const List<String> _steps = [
    'New Lead',
    'KYC Collected',
    'Sent To Support',
    'Documents Verification Started',
    'Portal Processing Started',
    'Loan Application Initiated',
    'Documents Submitted',
    'Liaison Process Started',
    'Bank Coordination In Progress',
    'Liaison Completed',
    'Finance Verification Started',
    'Loan Approved',
    'Installation In Progress',
    'Installation Done',
    'Final Verification Started',
    'Sent For Final Liaison',
    'Meter Process Started',
    'Government Approval Completed',
    'Lead Completed',
    'Lead Closed',
  ];

  static String _clean(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeStatus(String status) {
    final s = _clean(status);

    const aliases = {
      'bank coordination': 'bank coordination in progress',
      'start installation': 'installation in progress',
      'installation started': 'installation in progress',
      'installation complete': 'installation done',
      'mark installation complete': 'installation done',
      'state meter process': 'meter process started',
      'government approval done': 'government approval completed',
      'final liaison': 'sent for final liaison',
      'send for final liaison': 'sent for final liaison',
      'complete liaison': 'liaison completed',
      'start final verification': 'final verification started',
      'start portal processing': 'portal processing started',
      'start loan application': 'loan application initiated',
      'start document verification': 'documents verification started',
      'approve loan': 'loan approved',
      'support intake': 'sent to support',
      'liaison process': 'liaison process started',
      'finance intake': 'finance verification started',
      'installation': 'installation in progress',
      'support final': 'final verification started',
      'liaison meter': 'meter process started',
      'support completion': 'government approval completed',
      'completed': 'lead completed',
      'closed': 'lead closed',
    };

    return aliases[s] ?? s;
  }

  int _currentIndex() {
    final normalized = _normalizeStatus(currentStatus);

    var index = _steps.indexWhere((step) => _clean(step) == normalized);

    if (index >= 0) return index;

    // Some backend workflow step codes may reach this widget.
    const workflowAliases = {
      'support_intake': 'sent to support',
      'liaison_process': 'liaison process started',
      'finance_intake': 'finance verification started',
      'installation': 'installation in progress',
      'support_final': 'final verification started',
      'liaison_meter': 'meter process started',
      'support_completion': 'government approval completed',
      'completed': 'lead completed',
      'closed': 'lead closed',
    };

    final fallback = workflowAliases[normalized];
    if (fallback != null) {
      index = _steps.indexWhere((step) => _clean(step) == fallback);
    }

    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
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
              children: List.generate(_steps.length, (i) {
                final done = i <= current;
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
                          width: 88,
                          child: Text(
                            _steps[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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

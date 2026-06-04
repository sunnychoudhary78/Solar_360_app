class LeadWorkflow {
  LeadWorkflow._();

  static const pipelineSteps = [
    'Lead Created (Basic)',
    'Support Approval / Rejection',
    'Lead Approved (Complete Details)',
    'KYC Collected',
    'Support Team Processing',
    'Liaison Process',
    'Finance',
    'Installation',
    'Final Verification',
    'Completed',
  ];

  static const statusFlow = <String, List<String>>{
    'Sales': [
      'New Lead',
      'KYC Collected',
      'Sent To Support',
    ],
    'Support': [
      'Support Approved',
      'Support Rejected',
      'Documents Verification Started',
      'Portal Processing Started',
      'Loan Application Initiated',
      'Documents Submitted',
      'Final Verification Started',
      'Sent For Final Liaison',
      'Support Closure Pending',
      'Lead Completed',
      'Lead Closed',
    ],
    'Liaising': [
      'Liaison Process Started',
      'Bank Coordination In Progress',
      'Liaison Completed',
      'Meter Process Started',
      'Government Approval Completed',
    ],
    'Finance': [
      'Finance Verification Started',
      'Amount Received',
    ],
    'Installation': [
      'Installation In Progress',
      'Installation Done',
    ],
  };

  static const nextStatus = <String, List<String>>{
    'New Lead': ['Support Approved', 'Support Rejected'],

    'Support Approved': ['KYC Collected'],
    'Support Rejected': [],

    'KYC Collected': ['Sent To Support'],
    'Sent To Support': ['Documents Verification Started'],

    'Documents Verification Started': ['Portal Processing Started'],
    'Portal Processing Started': ['Loan Application Initiated'],
    'Loan Application Initiated': ['Documents Submitted'],

    'Documents Submitted': ['Liaison Process Started'],
    'Liaison Process Started': ['Bank Coordination In Progress'],
    'Bank Coordination In Progress': ['Liaison Completed'],

    'Liaison Completed': ['Finance Verification Started'],
    'Finance Verification Started': ['Amount Received'],

    'Amount Received': ['Installation In Progress'],
    'Installation In Progress': ['Installation Done'],

    'Installation Done': ['Final Verification Started'],
    'Final Verification Started': ['Sent For Final Liaison'],

    'Sent For Final Liaison': ['Meter Process Started'],
    'Meter Process Started': ['Government Approval Completed'],

    'Government Approval Completed': ['Support Closure Pending'],
    'Support Closure Pending': ['Lead Completed'],
    'Lead Completed': ['Lead Closed'],

    'Lead Closed': [],
  };

  static const finalStatuses = <String>{
    'Lead Closed',
    'Support Rejected',
  };

  static bool isFinalStatus(String? status) {
    return finalStatuses.contains((status ?? '').trim());
  }

  static bool canSalesCompleteDetails(String? status) {
    return (status ?? '').trim() == 'Support Approved';
  }

  static int pipelineIndexForStatus(String status) {
    final s = status.trim();

    const map = {
      'New Lead': 0,

      'Support Approved': 2,
      'Support Rejected': 1,

      'KYC Collected': 3,
      'Sent To Support': 4,

      'Documents Verification Started': 4,
      'Portal Processing Started': 4,
      'Loan Application Initiated': 4,
      'Documents Submitted': 4,

      'Liaison Process Started': 5,
      'Bank Coordination In Progress': 5,
      'Liaison Completed': 5,

      'Finance Verification Started': 6,
      'Amount Received': 6,

      'Installation In Progress': 7,
      'Installation Done': 7,

      'Final Verification Started': 8,
      'Sent For Final Liaison': 8,
      'Meter Process Started': 8,
      'Government Approval Completed': 8,
      'Support Closure Pending': 8,

      'Lead Completed': 9,
      'Lead Closed': 9,
    };

    return map[s] ?? 0;
  }

  static String resolveRoleKey(String? role) {
    final r = (role ?? '').trim();
    final lower = r.toLowerCase();

    if (lower == 'liaison officer' ||
        lower == 'liaison' ||
        lower == 'liaising' ||
        lower == 'leasing') {
      return 'Liaising';
    }

    if (lower == 'installation team' || lower == 'installation') {
      return 'Installation';
    }

    if (lower == 'sales') return 'Sales';
    if (lower == 'support') return 'Support';
    if (lower == 'finance') return 'Finance';

    return r;
  }

  static bool isAdminRole(String? role) {
    final r = (role ?? '').toLowerCase();
    return r.contains('admin') || r.contains('super');
  }

  static List<String> getAllowedNextStatuses(
    String currentStatus,
    String userRole,
  ) {
    final cleanStatus = currentStatus.trim();

    if (isFinalStatus(cleanStatus)) {
      return [];
    }

    final sequential = nextStatus[cleanStatus] ?? [];

    if (sequential.isEmpty) {
      return [];
    }

    if (isAdminRole(userRole)) {
      return sequential;
    }

    final roleKey = resolveRoleKey(userRole);
    final roleStatuses = statusFlow[roleKey] ?? [];

    return sequential.where(roleStatuses.contains).toList();
  }

  static String nextActionLabel(String currentStatus) {
    final cleanStatus = currentStatus.trim();

    const labels = {
      'New Lead': 'Approve / Reject Lead',

      'Support Approved': 'Mark KYC Collected',
      'KYC Collected': 'Send to Support',

      'Sent To Support': 'Start Document Verification',
      'Documents Verification Started': 'Start Portal Processing',
      'Portal Processing Started': 'Start Loan Application',
      'Loan Application Initiated': 'Submit Documents',

      'Documents Submitted': 'Start Liaison Process',
      'Liaison Process Started': 'Bank Coordination',
      'Bank Coordination In Progress': 'Complete Liaison',

      'Liaison Completed': 'Start Finance Verification',
      'Finance Verification Started': 'Amount Received',

      'Amount Received': 'Start Installation',
      'Installation In Progress': 'Mark Installation Done',

      'Installation Done': 'Start Final Verification',
      'Final Verification Started': 'Send for Final Liaison',

      'Sent For Final Liaison': 'Start Meter Process',
      'Meter Process Started': 'Government Approval Done',

      'Government Approval Completed': 'Send to Support Closure',
      'Support Closure Pending': 'Complete Lead',
      'Lead Completed': 'Close Lead',
    };

    return labels[cleanStatus] ?? 'Advance status';
  }
}
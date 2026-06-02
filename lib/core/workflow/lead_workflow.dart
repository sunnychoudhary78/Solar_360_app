class LeadWorkflow {
  LeadWorkflow._();

  static const statusFlow = <String, List<String>>{
    'Sales': [
      'New Lead',
      'KYC Collected',
      'Sent To Support',
    ],

    'Support': [
      'Documents Verification Started',
      'Portal Processing Started',
      'Loan Application Initiated',
      'Documents Submitted',
      'Final Verification Started',
      'Sent For Final Liaison',
      'Lead Completed',
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
      'Loan Approved',
    ],

    'Installation': [
      'Installation In Progress',
      'Installation Done',
    ],
  };

  static const nextStatus = <String, List<String>>{
    'New Lead': ['KYC Collected'],
    'KYC Collected': ['Sent To Support'],
    'Sent To Support': ['Documents Verification Started'],

    'Documents Verification Started': ['Portal Processing Started'],
    'Portal Processing Started': ['Loan Application Initiated'],
    'Loan Application Initiated': ['Documents Submitted'],

    'Documents Submitted': ['Liaison Process Started'],
    'Liaison Process Started': ['Bank Coordination In Progress'],
    'Bank Coordination In Progress': ['Liaison Completed'],

    'Liaison Completed': ['Finance Verification Started'],
    'Finance Verification Started': ['Loan Approved'],

    'Loan Approved': ['Installation In Progress'],
    'Installation In Progress': ['Installation Done'],

    'Installation Done': ['Final Verification Started'],
    'Final Verification Started': ['Sent For Final Liaison'],

    'Sent For Final Liaison': ['Meter Process Started'],
    'Meter Process Started': ['Government Approval Completed'],

    'Government Approval Completed': ['Lead Completed'],

    // Final status: no action button after this.
    'Lead Completed': [],
    'Lead Closed': [],
  };

  static const finalStatuses = <String>{
    'Lead Completed',
    'Lead Closed',
  };

  static bool isFinalStatus(String? status) {
    return finalStatuses.contains((status ?? '').trim());
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
      'New Lead': 'Mark KYC Collected',
      'KYC Collected': 'Send to Support',
      'Sent To Support': 'Start Document Verification',
      'Documents Verification Started': 'Start Portal Processing',
      'Portal Processing Started': 'Start Loan Application',
      'Loan Application Initiated': 'Submit Documents',
      'Documents Submitted': 'Start Liaison Process',
      'Liaison Process Started': 'Bank Coordination',
      'Bank Coordination In Progress': 'Complete Liaison',
      'Liaison Completed': 'Start Finance Verification',
      'Finance Verification Started': 'Approve Loan',
      'Loan Approved': 'Start Installation',
      'Installation In Progress': 'Mark Installation Done',
      'Installation Done': 'Start Final Verification',
      'Final Verification Started': 'Send for Final Liaison',
      'Sent For Final Liaison': 'Start Meter Process',
      'Meter Process Started': 'Government Approval Done',
      'Government Approval Completed': 'Complete Lead',
    };

    return labels[cleanStatus] ?? 'Advance status';
  }
}
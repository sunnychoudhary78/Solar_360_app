class LeadWorkflow {
  LeadWorkflow._();

  static const _roleExcludedVisibleStatuses = <String, List<String>>{
    'Document Administrator': ['Documents Submitted'],
  };

  /// Mirrors Solar360Backend/config/leadWorkflow.js.
  static const pipelineSteps = [
    'Sales',
    'Sales Manager',
    'Finance Manager',
    'Document Administrator',
    'Bank Process',
    'Finance User',
    'Installation Manager',
    'Material Engineer',
    'Electrical Engineer',
    'Completed',
  ];

  static const statusFlow = <String, List<String>>{
    'Sales': [
      'New Lead',
      'Rejected',
      'Follow Up',
      'Converted',
      'KYC Collected',
      'Sent To Sales Manager',
    ],
    'Sales Manager': ['Approved By Sales Manager', 'Rejected By Sales Manager'],
    'Finance Manager': [
      'Approved By Sales Manager',
      'Assigned To Document Administrator',
    ],
    'Document Administrator': [
      'Documents Verification Started',
      'Portal Processing Started',
      'Loan Application Initiated',
      'Documents Submitted',
      'Installation Done',
      'Lead Closed',
      'DCR Reports Completed',
      'Discom Status',
      'Final Complete',
    ],
    'Bank Process': [
      'Banking Process Start',
      'Bank Coordination In Progress',
      'Bank Process Complete',
    ],
    'Finance User': ['Finance Verification Started', 'Amount Received'],
    'Installation Manager': [
      'Amount Received',
      'Assigned To Material Engineer',
      'Installation Done',
    ],
    'Material Engineer': [
      'Material Verification Started',
      'Material Completed',
    ],
    'Electrical Engineer': ['Installation Started', 'Installation Completed'],
    'Company Admin': [],
  };

  static const nextStatus = <String, List<String>>{
    'New Lead': ['Rejected', 'Follow Up', 'Converted'],
    // After Follow Up, Sales can only reject or convert (no second Follow Up).
    'Follow Up': ['Rejected', 'Converted'],
    'Converted': ['KYC Collected'],
    'KYC Collected': ['Sent To Sales Manager'],
    'Rejected By Sales Manager': ['Converted'],
    'Sent To Sales Manager': [
      'Approved By Sales Manager',
      'Rejected By Sales Manager',
    ],
    'Approved By Sales Manager': ['Assigned To Document Administrator'],
    'Assigned To Document Administrator': ['Documents Verification Started'],
    'Documents Verification Started': ['Portal Processing Started'],
    'Portal Processing Started': ['Loan Application Initiated'],
    'Loan Application Initiated': ['Documents Submitted'],
    'Documents Submitted': ['Banking Process Start'],
    'Banking Process Start': ['Bank Coordination In Progress'],
    'Bank Coordination In Progress': ['Bank Process Complete'],
    'Bank Process Complete': ['Finance Verification Started'],
    'Finance Verification Started': ['Amount Received'],
    'Amount Received': ['Assigned To Material Engineer'],
    'Assigned To Material Engineer': ['Material Verification Started'],
    'Material Verification Started': ['Material Completed'],
    'Material Completed': ['Installation Started'],
    'Installation Started': ['Installation Completed'],
    'Installation Completed': ['Installation Done'],
    'Installation Done': ['DCR Reports Completed'],
    'Lead Closed': ['DCR Reports Completed'],
    'DCR Reports Completed': ['Discom Status'],
    'Discom Status': ['Final Complete'],
    'Final Complete': [],
  };

  static const finalStatuses = <String>{'Rejected', 'Final Complete'};

  static bool isFinalStatus(String? status) {
    return finalStatuses.contains((status ?? '').trim());
  }

  static bool canSalesCompleteDetails(String? status) {
    return (status ?? '').trim() == 'Converted';
  }

  static int pipelineIndexForStatus(String status) {
    const map = <String, int>{
      'New Lead': 0,
      'Rejected': 0,
      'Follow Up': 0,
      'Converted': 0,
      'KYC Collected': 0,
      'Sent To Sales Manager': 1,
      'Approved By Sales Manager': 2,
      'Rejected By Sales Manager': 1,
      'Assigned To Document Administrator': 3,
      'Documents Verification Started': 3,
      'Portal Processing Started': 3,
      'Loan Application Initiated': 3,
      'Documents Submitted': 4,
      'Banking Process Start': 4,
      'Bank Coordination In Progress': 4,
      'Bank Process Complete': 5,
      'Finance Verification Started': 5,
      'Amount Received': 6,
      'Assigned To Material Engineer': 7,
      'Material Verification Started': 7,
      'Material Completed': 8,
      'Installation Started': 8,
      'Installation Completed': 6,
      'Installation Done': 3,
      'Lead Closed': 3,
      'DCR Reports Completed': 3,
      'Discom Status': 3,
      'Final Complete': 9,
    };
    return map[status.trim()] ?? 0;
  }

  static String resolveRoleKey(String? role) {
    final value = (role ?? '').trim();
    final lower = value.toLowerCase();

    if (lower == 'sales' || lower == 'solarsales') return 'Sales';
    if (lower == 'sales manager') return 'Sales Manager';
    if (lower == 'finance manager' || lower == 'finance') {
      return 'Finance Manager';
    }
    if (lower == 'document administrator' || lower == 'support') {
      return 'Document Administrator';
    }
    if (lower == 'bank process' ||
        lower == 'liaison officer' ||
        lower == 'liaison' ||
        lower == 'liaising' ||
        lower == 'leasing') {
      return 'Bank Process';
    }
    if (lower == 'finance user') return 'Finance User';
    if (lower == 'installation manager' ||
        lower == 'installation team' ||
        lower == 'installation') {
      return 'Installation Manager';
    }
    if (lower == 'material engineer') return 'Material Engineer';
    if (lower == 'electrical engineer') return 'Electrical Engineer';
    if (lower == 'company admin' || lower == 'companyadmin') {
      return 'Company Admin';
    }
    return value;
  }

  static bool isAdminRole(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    return value == 'admin' ||
        value == 'company admin' ||
        value == 'companyadmin' ||
        value == 'superadmin' ||
        value == 'super admin';
  }

  static bool isSuperAdminRole(String? role) {
    final value = (role ?? '').trim().toLowerCase();
    return value == 'superadmin' || value == 'super admin';
  }

  static List<String> getRoleStatuses(String? role) {
    final roleKey = resolveRoleKey(role);
    return statusFlow[roleKey] ?? const <String>[];
  }

  static List<String> getVisibleStatusesForRole(String? role) {
    final roleKey = resolveRoleKey(role);
    final ownedStatuses = getRoleStatuses(roleKey);
    if (ownedStatuses.isEmpty) return [];

    final excludedStatuses =
        _roleExcludedVisibleStatuses[roleKey] ?? const <String>[];
    final activeOwnedStatuses = ownedStatuses
        .where((status) => !excludedStatuses.contains(status))
        .toList();

    final handoffStatuses = <String>[];
    nextStatus.forEach((currentStatus, sequentialStatuses) {
      if (activeOwnedStatuses.contains(currentStatus) ||
          excludedStatuses.contains(currentStatus)) {
        return;
      }

      if (sequentialStatuses.any(activeOwnedStatuses.contains)) {
        handoffStatuses.add(currentStatus);
      }
    });

    return {...activeOwnedStatuses, ...handoffStatuses}.toList();
  }

  static List<String> getAllowedNextStatuses(
    String currentStatus,
    String userRole,
  ) {
    final cleanStatus = currentStatus.trim();
    final sequential = nextStatus[cleanStatus] ?? const <String>[];
    if (sequential.isEmpty || isFinalStatus(cleanStatus)) return [];
    if (isSuperAdminRole(userRole)) return sequential;

    final roleKey = resolveRoleKey(userRole);
    final roleStatuses = statusFlow[roleKey] ?? const <String>[];
    return sequential.where(roleStatuses.contains).toList();
  }

  static String nextActionLabel(String currentStatus) {
    const labels = <String, String>{
      'New Lead': 'Reject, follow up, or convert',
      'Follow Up': 'Reject or convert',
      'Converted': 'Mark KYC collected',
      'KYC Collected': 'Send to Sales Manager',
      'Sent To Sales Manager': 'Review lead',
      'Approved By Sales Manager': 'Assign Document Administrator',
      'Rejected By Sales Manager': 'Convert lead',
      'Assigned To Document Administrator': 'Start document verification',
      'Documents Verification Started': 'Start portal processing',
      'Portal Processing Started': 'Initiate loan application',
      'Loan Application Initiated': 'Submit documents',
      'Documents Submitted': 'Start banking process',
      'Banking Process Start': 'Start bank coordination',
      'Bank Coordination In Progress': 'Complete bank process',
      'Bank Process Complete': 'Start finance verification',
      'Finance Verification Started': 'Mark amount received',
      'Amount Received': 'Assign engineers',
      'Assigned To Material Engineer': 'Start material verification',
      'Material Verification Started': 'Complete material verification',
      'Material Completed': 'Start installation',
      'Installation Started': 'Complete installation',
      'Installation Completed': 'Mark installation done',
      'Installation Done': 'Complete DCR reports',
      'Lead Closed': 'Complete DCR reports',
      'DCR Reports Completed': 'Update DISCOM status',
      'Discom Status': 'Mark final complete',
    };
    return labels[currentStatus.trim()] ?? 'Advance status';
  }
}

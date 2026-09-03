import 'dart:convert';

class LeadWorkflow {
  LeadWorkflow._();

  static const _roleExcludedVisibleStatuses = <String, List<String>>{
    'Document Administrator': ['Documents Submitted'],
  };

  /// Mirrors web `WORKFLOW_STAGES` in LeadWorkflowStepper.jsx (12 stages).
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
    'Subsidy',
    'Final Complete',
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
      'DCR Reports Completed',
      'Discom Status',
      'Final Complete',
      'Lead Closed',
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

  static const convertedPipelineStatuses = <String>{
    'Converted',
    'KYC Collected',
    'Sent To Sales Manager',
    'Approved By Sales Manager',
    'Rejected By Sales Manager',
    'Assigned To Document Administrator',
    'Documents Verification Started',
    'Portal Processing Started',
    'Loan Application Initiated',
    'Documents Submitted',
    'Banking Process Start',
    'Bank Coordination In Progress',
    'Bank Process Complete',
    'Finance Verification Started',
    'Amount Received',
    'Assigned To Material Engineer',
    'Material Verification Started',
    'Material Completed',
    'Assigned To Electrical Engineer',
    'Installation Started',
    'Installation Completed',
    'Installation Done',
    'DCR Reports Completed',
    'Discom Status',
  };

  static const rejectedStatuses = <String>{
    'Rejected',
    'Rejected By Sales Manager',
    'Support Rejected',
  };

  static const remarksRequiredStatuses = <String>{
    'Follow Up',
    'Rejected',
    'Rejected By Sales Manager',
    'Support Rejected',
  };

  static const completedStatuses = <String>{
    'Final Complete',
    'Lead Completed',
    'Lead Closed',
  };

  static const finalStatuses = <String>{'Rejected', 'Final Complete'};

  static const kycRequiredTextFields = <Map<String, String>>[
    {'key': 'full_name', 'label': 'Full name'},
    {'key': 'mobile', 'label': 'Mobile'},
    {'key': 'ca_number', 'label': 'Consumer number'},
    {'key': 'discom', 'label': 'DISCOM'},
    {'key': 'load_section_kw', 'label': 'Load Section (KW)'},
    {'key': 'address', 'label': 'Address'},
    {'key': 'city', 'label': 'City'},
    {'key': 'state', 'label': 'State'},
    {'key': 'pincode', 'label': 'Pincode'},
    {'key': 'bank_account_name', 'label': 'Account holder name'},
    {'key': 'bank_name', 'label': 'Bank name'},
    {'key': 'account_number', 'label': 'Account number'},
    {'key': 'account_type', 'label': 'Account type'},
    {'key': 'ifsc_code', 'label': 'IFSC code'},
  ];

  static const kycRequiredDocTitles = [
    'Aadhaar Front',
    'Aadhaar Back',
    'PAN Card',
    'Electricity Bill',
  ];

  static const _statusDisplayLabels = <String, String>{
    'New Lead': 'New Lead',
    'Follow Up': 'Follow Up',
    'Rejected': 'Rejected (Sales)',
    'Converted': 'Converted',
    'KYC Collected': 'KYC Collected',
    'Sent To Sales Manager': 'Sent To Sales Manager',
    'Approved By Sales Manager': 'Approved',
    'Rejected By Sales Manager': 'Rejected (Sales Manager)',
    'Assigned To Document Administrator': 'Assigned to Doc Admin',
    'Documents Verification Started': 'Doc verification started',
    'Portal Processing Started': 'Portal processing',
    'Loan Application Initiated': 'Loan application',
    'Documents Submitted': 'Documents submitted',
    'Banking Process Start': 'Banking started',
    'Bank Coordination In Progress': 'Bank coordination',
    'Bank Process Complete': 'Bank complete',
    'Finance Verification Started': 'Finance verification',
    'Amount Received': 'Amount received',
    'Assigned To Material Engineer': 'Assigned to Material Eng.',
    'Material Verification Started': 'Material verification',
    'Material Completed': 'Material completed',
    'Assigned To Electrical Engineer': 'Assigned to Electrical Eng.',
    'Installation Started': 'Installation started',
    'Installation Completed': 'Installation completed',
    'Installation Done': 'Installation done',
    'Lead Completed': 'Lead completed',
    'Lead Closed': 'Lead closed',
    'DCR Reports Completed': 'DCR reports done',
    'Discom Status': 'Discom status',
    'Final Complete': 'Final complete',
  };

  static const convertedLeadLockMessage =
      'This lead is converted. Details can no longer be filled or updated.';

  static bool isFinalStatus(String? status) {
    return finalStatuses.contains((status ?? '').trim());
  }

  static bool canSalesCompleteDetails(String? status) {
    return (status ?? '').trim() == 'Converted';
  }

  static bool isConvertedPipelineStatus(String? status) {
    return convertedPipelineStatuses.contains((status ?? '').trim());
  }

  static bool isRejectedStatus(String? status) {
    return rejectedStatuses.contains((status ?? '').trim());
  }

  static bool isCompletedStatus(String? status, {String? department}) {
    final clean = (status ?? '').trim();
    final dept = (department ?? '').trim();
    return completedStatuses.contains(clean) || dept == 'Completed';
  }

  static bool requiresStatusRemarks(String? status) {
    return remarksRequiredStatuses.contains((status ?? '').trim());
  }

  /// Rejected tab + rejected leads: Sales, Sales Manager, Company Admin only.
  static bool canViewRejectedLeads(String? role) {
    final roleKey = resolveRoleKey(role);
    return roleKey == 'Sales' ||
        roleKey == 'Sales Manager' ||
        roleKey == 'Company Admin' ||
        isSuperAdminRole(roleKey);
  }

  static String getStatusDisplayLabel(String? status) {
    final clean = (status ?? '').trim();
    if (clean.isEmpty || clean == 'All') return 'All';
    return _statusDisplayLabels[clean] ?? clean;
  }

  static String nextActorHint(String? status) {
    const map = <String, String>{
      'New Lead': 'Waiting for Sales action',
      'Rejected': 'Lead rejected',
      'Follow Up': 'Waiting for follow up',
      'Converted': 'Waiting for KYC collection',
      'KYC Collected': 'Waiting for Sales Manager approval',
      'Sent To Sales Manager': 'Waiting for Sales Manager review',
      'Approved By Sales Manager': 'Waiting for Finance Manager assignment',
      'Rejected By Sales Manager': 'Lead rejected by Sales Manager',
      'Assigned To Document Administrator':
          'Waiting for Document Administrator',
      'Documents Verification Started': 'Document verification in progress',
      'Portal Processing Started': 'Portal processing in progress',
      'Loan Application Initiated': 'Loan application in progress',
      'Documents Submitted': 'Waiting for Bank Process',
      'Banking Process Start': 'Banking process started',
      'Bank Coordination In Progress': 'Bank coordination in progress',
      'Bank Process Complete': 'Bank process complete',
      'Finance Verification Started': 'Finance verification in progress',
      'Amount Received': 'Waiting for Installation Manager',
      'Assigned To Material Engineer': 'Waiting for Material Engineer',
      'Material Verification Started': 'Material verification in progress',
      'Material Completed': 'Waiting for Electrical Engineer',
      'Assigned To Electrical Engineer': 'Waiting for Electrical Engineer',
      'Installation Started': 'Installation in progress',
      'Installation Completed': 'Waiting for Installation Manager',
      'Installation Done': 'Waiting for Document Administrator',
      'DCR Reports Completed':
          'Waiting for Document Administrator discom update',
      'Discom Status': 'Waiting for final completion',
      'Final Complete': 'Lead fully completed',
      'Lead Closed': 'Waiting for Document Administrator closing updates',
      'Lead Completed': 'Lead completed',
    };
    final clean = (status ?? '').trim();
    if (clean.isEmpty) return 'Waiting for conversion';
    return map[clean] ?? 'Workflow in progress';
  }

  /// Copy of web `STATUS_TO_STAGE_INDEX` (0–11).
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
      'Material Completed': 7,
      'Assigned To Electrical Engineer': 8,
      'Installation Started': 8,
      'Installation Completed': 8,
      'Assigned To Discom User': 8,
      'Meter Process Started': 8,
      'Government Approval Completed': 8,
      'Installation Done': 9,
      'Lead Completed': 9,
      'Lead Closed': 10,
      'DCR Reports Completed': 10,
      'Discom Status': 10,
      'Final Complete': 11,
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

  static bool _hasNonEmptyValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return true;
    if (value is bool) return value;
    return value.toString().trim().isNotEmpty;
  }

  static List<Map<String, dynamic>> _parseTitledDocs(dynamic raw) {
    dynamic decoded = raw;
    if (decoded is String) {
      final trimmed = decoded.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is Map) {
      decoded = decoded.values.toList();
    }
    if (decoded is! List) return const [];

    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static bool _leadHasDocumentTitle(Map<String, dynamic> lead, String title) {
    final needle = title.trim().toLowerCase();
    final docs = _parseTitledDocs(
      lead['additional_documents'] ?? lead['additionalDocuments'],
    );
    return docs.any((d) {
      final docTitle = (d['title'] ?? d['label'] ?? d['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final path = (d['file'] ?? d['path'] ?? d['url'] ?? '').toString();
      return docTitle == needle && _hasNonEmptyValue(path);
    });
  }

  /// Labels of missing fields/docs required before KYC Collected.
  /// [lead] should use the same snake_case keys as the web/API payload.
  static List<String> getMissingKycDetails(Map<String, dynamic>? lead) {
    if (lead == null) {
      return [
        ...kycRequiredTextFields.map((f) => f['label']!),
        ...kycRequiredDocTitles,
        'Cheque / passbook',
      ];
    }

    final missing = <String>[];
    for (final field in kycRequiredTextFields) {
      final key = field['key']!;
      final camel = _snakeToCamel(key);
      final value = lead[key] ?? lead[camel];
      if (!_hasNonEmptyValue(value)) missing.add(field['label']!);
    }

    for (final title in kycRequiredDocTitles) {
      if (!_leadHasDocumentTitle(lead, title)) missing.add(title);
    }

    final cheque =
        lead['cheque_passbook_copy'] ?? lead['chequePassbookCopy'] ?? '';
    if (!_hasNonEmptyValue(cheque)) missing.add('Cheque / passbook');

    return missing;
  }

  static bool hasFilledKycDetails(Map<String, dynamic>? lead) {
    return getMissingKycDetails(lead).isEmpty;
  }

  static String _snakeToCamel(String key) {
    final parts = key.split('_');
    if (parts.length < 2) return key;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }
}

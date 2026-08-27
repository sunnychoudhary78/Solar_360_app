class SupportTicketOption {
  final String value;
  final String label;

  const SupportTicketOption({required this.value, required this.label});
}

class SupportTicketConstants {
  SupportTicketConstants._();

  static const statuses = <SupportTicketOption>[
    SupportTicketOption(value: 'complaint_raised', label: 'Complaint Raised'),
    SupportTicketOption(value: 'open', label: 'Open'),
    SupportTicketOption(value: 'assigned', label: 'Assigned'),
    SupportTicketOption(value: 'in_progress', label: 'In Progress'),
    SupportTicketOption(value: 'waiting_customer', label: 'Waiting Customer'),
    SupportTicketOption(value: 'waiting_parts', label: 'Waiting Parts'),
    SupportTicketOption(value: 'resolved', label: 'Resolved'),
    SupportTicketOption(value: 'closed', label: 'Closed'),
    SupportTicketOption(value: 'reopened', label: 'Reopened'),
    SupportTicketOption(value: 'cancelled', label: 'Cancelled'),
  ];

  static const processStatuses = <SupportTicketOption>[
    SupportTicketOption(value: 'complaint_raised', label: 'Complaint Raised'),
    SupportTicketOption(value: 'open', label: 'Open'),
    SupportTicketOption(value: 'assigned', label: 'Assigned'),
    SupportTicketOption(value: 'in_progress', label: 'In Progress'),
    SupportTicketOption(value: 'waiting_customer', label: 'Waiting Customer'),
    SupportTicketOption(value: 'waiting_parts', label: 'Waiting Parts'),
    SupportTicketOption(value: 'resolved', label: 'Resolved'),
    SupportTicketOption(value: 'reopened', label: 'Reopened'),
  ];

  static const priorities = <SupportTicketOption>[
    SupportTicketOption(value: 'low', label: 'Low'),
    SupportTicketOption(value: 'medium', label: 'Medium'),
    SupportTicketOption(value: 'high', label: 'High'),
    SupportTicketOption(value: 'urgent', label: 'Urgent'),
  ];

  static const categories = <String>[
    'Installation',
    'Inverter',
    'Solar Panel',
    'Battery',
    'Net Metering',
    'Subsidy',
    'Maintenance',
    'Billing',
    'Warranty',
    'Other',
  ];

  static const requestTypes = <SupportTicketOption>[
    SupportTicketOption(value: 'complaint', label: 'Complaint'),
    SupportTicketOption(value: 'service_request', label: 'Service Request'),
    SupportTicketOption(value: 'technical_support', label: 'Technical Support'),
    SupportTicketOption(
      value: 'installation_support',
      label: 'Installation Support',
    ),
    SupportTicketOption(value: 'maintenance', label: 'Maintenance'),
    SupportTicketOption(value: 'billing_payment', label: 'Billing & Payment'),
    SupportTicketOption(value: 'warranty', label: 'Warranty'),
    SupportTicketOption(value: 'other', label: 'Other'),
  ];

  static const processFlow = <String>[
    'complaint_raised',
    'assigned',
    'in_progress',
    'waiting_customer',
    'waiting_parts',
    'resolved',
  ];

  static String statusLabel(String? status) {
    final value = (status ?? '').trim();
    if (value.isEmpty) return 'Unknown';
    for (final item in statuses) {
      if (item.value == value) return item.label;
    }
    return _titleCase(value);
  }

  static String priorityLabel(String? priority) {
    final value = (priority ?? '').trim();
    if (value.isEmpty) return 'Medium';
    for (final item in priorities) {
      if (item.value == value) return item.label;
    }
    return _titleCase(value);
  }

  static String categoryLabel(String? category) {
    final value = (category ?? '').trim();
    if (value.isEmpty) return '—';
    for (final item in categories) {
      if (item.toLowerCase() == value.toLowerCase()) return item;
    }
    return _titleCase(value);
  }

  static String requestTypeLabel(String? type) {
    final value = (type ?? '').trim();
    if (value.isEmpty) return 'Support Request';
    for (final item in requestTypes) {
      if (item.value == value) return item.label;
    }
    return _titleCase(value);
  }

  static String _titleCase(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class SupportTicketCounts {
  final int total;
  final int complaintRaised;
  final int open;
  final int assigned;
  final int inProgress;
  final int waitingCustomer;
  final int waitingParts;
  final int resolved;
  final int closed;
  final int reopened;
  final int cancelled;

  const SupportTicketCounts({
    this.total = 0,
    this.complaintRaised = 0,
    this.open = 0,
    this.assigned = 0,
    this.inProgress = 0,
    this.waitingCustomer = 0,
    this.waitingParts = 0,
    this.resolved = 0,
    this.closed = 0,
    this.reopened = 0,
    this.cancelled = 0,
  });

  int get newRequests => complaintRaised + open;

  factory SupportTicketCounts.fromJson(dynamic json) {
    if (json is! Map) return const SupportTicketCounts();
    final map = Map<String, dynamic>.from(json);
    final data = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : map;
    int read(String key) {
      final value = data[key];
      return value is num ? value.toInt() : 0;
    }

    return SupportTicketCounts(
      total: read('total'),
      complaintRaised: read('complaint_raised'),
      open: read('open'),
      assigned: read('assigned'),
      inProgress: read('in_progress'),
      waitingCustomer: read('waiting_customer'),
      waitingParts: read('waiting_parts'),
      resolved: read('resolved'),
      closed: read('closed'),
      reopened: read('reopened'),
      cancelled: read('cancelled'),
    );
  }

  SupportTicketCounts merge(SupportTicketCounts other) {
    return SupportTicketCounts(
      total: other.total != 0 ? other.total : total,
      complaintRaised: other.complaintRaised != 0
          ? other.complaintRaised
          : complaintRaised,
      open: other.open != 0 ? other.open : open,
      assigned: other.assigned != 0 ? other.assigned : assigned,
      inProgress: other.inProgress != 0 ? other.inProgress : inProgress,
      waitingCustomer: other.waitingCustomer != 0
          ? other.waitingCustomer
          : waitingCustomer,
      waitingParts: other.waitingParts != 0 ? other.waitingParts : waitingParts,
      resolved: other.resolved != 0 ? other.resolved : resolved,
      closed: other.closed != 0 ? other.closed : closed,
      reopened: other.reopened != 0 ? other.reopened : reopened,
      cancelled: other.cancelled != 0 ? other.cancelled : cancelled,
    );
  }
}

import 'package:solar_sales/shared/utils/formatters.dart';

class AmcChecklistItem {
  const AmcChecklistItem({
    required this.key,
    required this.label,
    this.done = false,
    this.notes = '',
  });

  final String key;
  final String label;
  final bool done;
  final String notes;

  factory AmcChecklistItem.fromJson(Map<String, dynamic> json) {
    return AmcChecklistItem(
      key: asString(json['key']),
      label: asString(json['label']),
      done: asBool(json['done']),
      notes: asString(json['notes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'done': done,
        'notes': notes,
      };

  AmcChecklistItem copyWith({
    String? key,
    String? label,
    bool? done,
    String? notes,
  }) {
    return AmcChecklistItem(
      key: key ?? this.key,
      label: label ?? this.label,
      done: done ?? this.done,
      notes: notes ?? this.notes,
    );
  }
}

class AmcMeta {
  const AmcMeta({
    this.visitsPerYear = const [1, 2, 3, 4],
    this.contractStatuses = const ['draft', 'active', 'expired', 'cancelled'],
    this.visitStatuses = const [
      'scheduled',
      'in_progress',
      'completed',
      'skipped',
      'cancelled',
    ],
    this.checklist = const [],
  });

  final List<int> visitsPerYear;
  final List<String> contractStatuses;
  final List<String> visitStatuses;
  final List<AmcChecklistItem> checklist;

  factory AmcMeta.fromJson(Map<String, dynamic> json) {
    final visitsRaw = json['visits_per_year'];
    final visits = <int>[];
    if (visitsRaw is List) {
      for (final v in visitsRaw) {
        final n = asInt(v, 0);
        if (n > 0) visits.add(n);
      }
    }
    return AmcMeta(
      visitsPerYear: visits.isEmpty ? const [1, 2, 3, 4] : visits,
      contractStatuses: _stringList(json['contract_statuses'], const [
        'draft',
        'active',
        'expired',
        'cancelled',
      ]),
      visitStatuses: _stringList(json['visit_statuses'], const [
        'scheduled',
        'in_progress',
        'completed',
        'skipped',
        'cancelled',
      ]),
      checklist: _checklistList(json['checklist']),
    );
  }

  static List<String> _stringList(dynamic raw, List<String> fallback) {
    if (raw is! List || raw.isEmpty) return fallback;
    return raw.map((e) => asString(e)).where((e) => e.isNotEmpty).toList();
  }

  static List<AmcChecklistItem> _checklistList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => AmcChecklistItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class AmcSummary {
  const AmcSummary({
    this.plants = 0,
    this.amcActive = 0,
    this.overdue = 0,
    this.dueThisMonth = 0,
    this.completedThisMonth = 0,
    this.scheduled = 0,
  });

  final int plants;
  final int amcActive;
  final int overdue;
  final int dueThisMonth;
  final int completedThisMonth;
  final int scheduled;

  factory AmcSummary.fromJson(Map<String, dynamic> json) {
    return AmcSummary(
      plants: asInt(json['plants']),
      amcActive: asInt(json['amc_active']),
      overdue: asInt(json['overdue']),
      dueThisMonth: asInt(json['due_this_month']),
      completedThisMonth: asInt(json['completed_this_month']),
      scheduled: asInt(json['scheduled']),
    );
  }
}

class AmcAssignee {
  const AmcAssignee({
    required this.id,
    required this.name,
    this.email = '',
    this.role,
    this.designation,
  });

  final String id;
  final String name;
  final String email;
  final String? role;
  final String? designation;

  factory AmcAssignee.fromJson(Map<String, dynamic> json) {
    return AmcAssignee(
      id: asString(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
      role: asString(json['role']).isEmpty ? null : asString(json['role']),
      designation: asString(json['designation']).isEmpty
          ? null
          : asString(json['designation']),
    );
  }

  String get optionLabel {
    if (role != null && role!.isNotEmpty) return '$name · $role';
    return name;
  }
}

class AmcContractRef {
  const AmcContractRef({
    required this.id,
    this.status = 'active',
    this.visitsPerYear = 2,
    this.startDate = '',
    this.endDate = '',
    this.notes = '',
  });

  final String id;
  final String status;
  final int visitsPerYear;
  final String startDate;
  final String endDate;
  final String notes;

  factory AmcContractRef.fromJson(Map<String, dynamic> json) {
    return AmcContractRef(
      id: asString(json['id']),
      status: asString(json['status'], 'active'),
      visitsPerYear: asInt(json['visits_per_year'], 2),
      startDate: asString(json['start_date']),
      endDate: asString(json['end_date']),
      notes: asString(json['notes']),
    );
  }
}

class AmcPlantRef {
  const AmcPlantRef({
    required this.id,
    this.leadCode = '',
    this.fullName = '',
    this.mobile = '',
  });

  final String id;
  final String leadCode;
  final String fullName;
  final String mobile;

  factory AmcPlantRef.fromJson(Map<String, dynamic> json) {
    return AmcPlantRef(
      id: asString(json['id']).isNotEmpty
          ? asString(json['id'])
          : asString(json['lead_id']),
      leadCode: asString(json['lead_code']),
      fullName: asString(json['full_name']),
      mobile: asString(json['mobile']),
    );
  }
}

class AmcPlant {
  const AmcPlant({
    required this.id,
    required this.leadId,
    this.leadCode = '',
    this.fullName = '',
    this.mobile = '',
    this.status = '',
    this.city = '',
    this.state = '',
    this.address = '',
    this.capacity = '',
    this.inverterType = '',
    this.inverterSerialNumber = '',
    this.solarPanelBrand = '',
    this.numberOfSolarPanels,
    this.district = '',
    this.contract,
    this.nextVisitDate = '',
    this.overdueVisits = 0,
    this.completedVisits = 0,
    this.openVisits = 0,
    this.visits = const [],
  });

  final String id;
  final String leadId;
  final String leadCode;
  final String fullName;
  final String mobile;
  final String status;
  final String city;
  final String state;
  final String address;
  final String capacity;
  final String inverterType;
  final String inverterSerialNumber;
  final String solarPanelBrand;
  final int? numberOfSolarPanels;
  final String district;
  final AmcContractRef? contract;
  final String nextVisitDate;
  final int overdueVisits;
  final int completedVisits;
  final int openVisits;
  final List<AmcVisit> visits;

  bool get hasActiveAmc =>
      contract != null &&
      contract!.id.isNotEmpty &&
      contract!.status != 'cancelled';

  factory AmcPlant.fromJson(Map<String, dynamic> json) {
    final leadId = asString(json['lead_id']).isNotEmpty
        ? asString(json['lead_id'])
        : asString(json['id']);
    AmcContractRef? contract;
    final rawContract = json['contract'];
    if (rawContract is Map) {
      contract =
          AmcContractRef.fromJson(Map<String, dynamic>.from(rawContract));
      if (contract.id.isEmpty) contract = null;
    }
    final visitsRaw = json['visits'];
    final visits = <AmcVisit>[];
    if (visitsRaw is List) {
      for (final item in visitsRaw.whereType<Map>()) {
        visits.add(AmcVisit.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return AmcPlant(
      id: asString(json['id']).isNotEmpty ? asString(json['id']) : leadId,
      leadId: leadId,
      leadCode: asString(json['lead_code']),
      fullName: asString(json['full_name']),
      mobile: asString(json['mobile']),
      status: asString(json['status']),
      city: asString(json['city']),
      state: asString(json['state']),
      address: asString(json['address']),
      capacity: asString(json['capacity']),
      inverterType: asString(json['inverter_type']),
      inverterSerialNumber: asString(json['inverter_serial_number']),
      solarPanelBrand: asString(json['solar_panel_brand']),
      numberOfSolarPanels: json['number_of_solar_panels'] == null
          ? null
          : asInt(json['number_of_solar_panels']),
      district: asString(json['district']),
      contract: contract,
      nextVisitDate: asString(json['next_visit_date']),
      overdueVisits: asInt(json['overdue_visits']),
      completedVisits: asInt(json['completed_visits']),
      openVisits: asInt(json['open_visits']),
      visits: visits,
    );
  }
}

class AmcVisitListSummary {
  const AmcVisitListSummary({
    this.total = 0,
    this.scheduled = 0,
    this.inProgress = 0,
    this.overdue = 0,
    this.completed = 0,
    this.dueToday = 0,
  });

  final int total;
  final int scheduled;
  final int inProgress;
  final int overdue;
  final int completed;
  final int dueToday;

  factory AmcVisitListSummary.fromJson(Map<String, dynamic> json) {
    return AmcVisitListSummary(
      total: asInt(json['total']),
      scheduled: asInt(json['scheduled']),
      inProgress: asInt(json['in_progress']),
      overdue: asInt(json['overdue']),
      completed: asInt(json['completed']),
      dueToday: asInt(json['due_today']),
    );
  }
}

class AmcVisitListResult {
  const AmcVisitListResult({
    this.data = const [],
    this.summary = const AmcVisitListSummary(),
  });

  final List<AmcVisit> data;
  final AmcVisitListSummary summary;

  factory AmcVisitListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    final visits = <AmcVisit>[];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        visits.add(AmcVisit.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    final summaryRaw = json['summary'];
    return AmcVisitListResult(
      data: visits,
      summary: summaryRaw is Map
          ? AmcVisitListSummary.fromJson(
              Map<String, dynamic>.from(summaryRaw),
            )
          : const AmcVisitListSummary(),
    );
  }
}

class AmcVisit {
  const AmcVisit({
    required this.id,
    this.companyId = '',
    this.contractId = '',
    this.leadId = '',
    this.visitNo = 0,
    this.title = '',
    this.scheduledDate = '',
    this.completedAt,
    this.status = 'scheduled',
    this.isOverdue = false,
    this.assigneeId,
    this.assignee,
    this.checklist = const [],
    this.findings = '',
    this.customerSignoff = false,
    this.photos = const [],
    this.supportTicketId,
    this.plant,
    this.contract,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String contractId;
  final String leadId;
  final int visitNo;
  final String title;
  final String scheduledDate;
  final DateTime? completedAt;
  final String status;
  final bool isOverdue;
  final String? assigneeId;
  final AmcAssignee? assignee;
  final List<AmcChecklistItem> checklist;
  final String findings;
  final bool customerSignoff;
  final List<String> photos;
  final String? supportTicketId;
  final AmcPlantRef? plant;
  final AmcContractRef? contract;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen => status == 'scheduled' || status == 'in_progress';
  bool get isCompleted => status == 'completed';

  AmcVisit copyWith({
    String? id,
    String? companyId,
    String? contractId,
    String? leadId,
    int? visitNo,
    String? title,
    String? scheduledDate,
    DateTime? completedAt,
    String? status,
    bool? isOverdue,
    String? assigneeId,
    AmcAssignee? assignee,
    List<AmcChecklistItem>? checklist,
    String? findings,
    bool? customerSignoff,
    List<String>? photos,
    String? supportTicketId,
    AmcPlantRef? plant,
    AmcContractRef? contract,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAssignee = false,
  }) {
    return AmcVisit(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      contractId: contractId ?? this.contractId,
      leadId: leadId ?? this.leadId,
      visitNo: visitNo ?? this.visitNo,
      title: title ?? this.title,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      isOverdue: isOverdue ?? this.isOverdue,
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      checklist: checklist ?? this.checklist,
      findings: findings ?? this.findings,
      customerSignoff: customerSignoff ?? this.customerSignoff,
      photos: photos ?? this.photos,
      supportTicketId: supportTicketId ?? this.supportTicketId,
      plant: plant ?? this.plant,
      contract: contract ?? this.contract,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get plantLabel {
    final name = plant?.fullName.trim() ?? '';
    final code = plant?.leadCode.trim() ?? '';
    if (name.isNotEmpty && code.isNotEmpty) return '$code — $name';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return 'Plant';
  }

  factory AmcVisit.fromJson(Map<String, dynamic> json) {
    AmcAssignee? assignee;
    final rawAssignee = json['assignee'];
    if (rawAssignee is Map) {
      assignee = AmcAssignee.fromJson(Map<String, dynamic>.from(rawAssignee));
      if (assignee.id.isEmpty) assignee = null;
    }
    AmcPlantRef? plant;
    final rawPlant = json['plant'];
    if (rawPlant is Map) {
      plant = AmcPlantRef.fromJson(Map<String, dynamic>.from(rawPlant));
      if (plant.id.isEmpty) plant = null;
    }
    AmcContractRef? contract;
    final rawContract = json['contract'];
    if (rawContract is Map) {
      contract =
          AmcContractRef.fromJson(Map<String, dynamic>.from(rawContract));
      if (contract.id.isEmpty) contract = null;
    }
    final photosRaw = json['photos'];
    final photos = <String>[];
    if (photosRaw is List) {
      for (final p in photosRaw) {
        final s = asString(p).trim();
        if (s.isNotEmpty) photos.add(s);
      }
    }
    final checklistRaw = json['checklist'];
    final checklist = <AmcChecklistItem>[];
    if (checklistRaw is List) {
      for (final item in checklistRaw.whereType<Map>()) {
        checklist.add(
          AmcChecklistItem.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    final assigneeIdRaw = asString(json['assignee_id']);
    return AmcVisit(
      id: asString(json['id']),
      companyId: asString(json['company_id']),
      contractId: asString(json['contract_id']),
      leadId: asString(json['lead_id']),
      visitNo: asInt(json['visit_no']),
      title: asString(json['title']),
      scheduledDate: asString(json['scheduled_date']),
      completedAt: parseDate(json['completed_at']),
      status: asString(json['status'], 'scheduled'),
      isOverdue: asBool(json['is_overdue']),
      assigneeId: assigneeIdRaw.isEmpty ? null : assigneeIdRaw,
      assignee: assignee,
      checklist: checklist,
      findings: asString(json['findings']),
      customerSignoff: asBool(json['customer_signoff']),
      photos: photos,
      supportTicketId: asString(json['support_ticket_id']).isEmpty
          ? null
          : asString(json['support_ticket_id']),
      plant: plant,
      contract: contract,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

/// Formats API `YYYY-MM-DD` as `DD/MM/YYYY` (web list parity). Do not TZ-shift.
String formatAmcDate(String? ymd) {
  final raw = (ymd ?? '').trim();
  if (raw.isEmpty) return '—';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
}

String amcVisitStatusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'skipped':
      return 'Skipped';
    case 'cancelled':
      return 'Cancelled';
    case 'scheduled':
    default:
      return 'Scheduled';
  }
}

String todayIstYmd() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

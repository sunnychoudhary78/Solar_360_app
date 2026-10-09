import 'package:solar_sales/shared/utils/formatters.dart';

class SolarTaskPhase {
  const SolarTaskPhase({
    required this.key,
    required this.label,
    this.hint = '',
  });

  final String key;
  final String label;
  final String hint;

  factory SolarTaskPhase.fromJson(Map<String, dynamic> json) {
    return SolarTaskPhase(
      key: asString(json['key']),
      label: asString(json['label']),
      hint: asString(json['hint']),
    );
  }
}

class SolarTaskAssignee {
  const SolarTaskAssignee({
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

  factory SolarTaskAssignee.fromJson(Map<String, dynamic> json) {
    return SolarTaskAssignee(
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

class SolarTaskProject {
  const SolarTaskProject({
    required this.id,
    required this.leadCode,
    required this.fullName,
    this.status = '',
    this.currentDepartment = '',
    this.mobile = '',
    this.taskCount = 0,
    this.openCount = 0,
  });

  final String id;
  final String leadCode;
  final String fullName;
  final String status;
  final String currentDepartment;
  final String mobile;
  final int taskCount;
  final int openCount;

  factory SolarTaskProject.fromJson(Map<String, dynamic> json) {
    return SolarTaskProject(
      id: asString(json['id']),
      leadCode: asString(json['lead_code']),
      fullName: asString(json['full_name']),
      status: asString(json['status']),
      currentDepartment: asString(json['current_department']),
      mobile: asString(json['mobile']),
      taskCount: asInt(json['task_count']),
      openCount: asInt(json['open_count']),
    );
  }

  String get optionLabel {
    final open = openCount > 0 ? ' · $openCount open' : '';
    return '$leadCode — $fullName$open';
  }
}

class SolarTaskDependency {
  const SolarTaskDependency({
    required this.id,
    required this.title,
    this.status,
    this.phaseKey,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String? status;
  final String? phaseKey;
  final bool isActive;

  factory SolarTaskDependency.fromJson(Map<String, dynamic> json) {
    return SolarTaskDependency(
      id: asString(json['id']),
      title: asString(json['title']),
      status: asString(json['status']).isEmpty
          ? null
          : asString(json['status']),
      phaseKey: asString(json['phase_key']).isEmpty
          ? null
          : asString(json['phase_key']),
      isActive: asBool(json['is_active'], true),
    );
  }
}

class SolarTaskProjectRef {
  const SolarTaskProjectRef({
    required this.id,
    required this.leadCode,
    required this.fullName,
    this.status = '',
    this.currentDepartment = '',
  });

  final String id;
  final String leadCode;
  final String fullName;
  final String status;
  final String currentDepartment;

  factory SolarTaskProjectRef.fromJson(Map<String, dynamic> json) {
    return SolarTaskProjectRef(
      id: asString(json['id']),
      leadCode: asString(json['lead_code']),
      fullName: asString(json['full_name']),
      status: asString(json['status']),
      currentDepartment: asString(json['current_department']),
    );
  }
}

class SolarTaskAssigneeRef {
  const SolarTaskAssigneeRef({
    required this.id,
    required this.name,
    this.email = '',
  });

  final String id;
  final String name;
  final String email;

  factory SolarTaskAssigneeRef.fromJson(Map<String, dynamic> json) {
    return SolarTaskAssigneeRef(
      id: asString(json['id']),
      name: asString(json['name']),
      email: asString(json['email']),
    );
  }
}

class SolarTaskModel {
  const SolarTaskModel({
    required this.id,
    required this.companyId,
    required this.leadId,
    required this.phaseKey,
    required this.title,
    this.phaseLabel = '',
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.assigneeId,
    this.assignee,
    this.startDate,
    this.dueDate,
    this.completedAt,
    this.sortOrder = 0,
    this.dependsOnIds = const [],
    this.dependencies = const [],
    this.blockedBy = const [],
    this.isBlocked = false,
    this.isOverdue = false,
    this.project,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String companyId;
  final String leadId;
  final String phaseKey;
  final String phaseLabel;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? assigneeId;
  final SolarTaskAssigneeRef? assignee;
  final String? startDate;
  final String? dueDate;
  final String? completedAt;
  final int sortOrder;
  final List<String> dependsOnIds;
  final List<SolarTaskDependency> dependencies;
  final List<SolarTaskDependency> blockedBy;
  final bool isBlocked;
  final bool isOverdue;
  final SolarTaskProjectRef? project;
  final String? createdAt;
  final String? updatedAt;

  factory SolarTaskModel.fromJson(Map<String, dynamic> json) {
    return SolarTaskModel(
      id: asString(json['id']),
      companyId: asString(json['company_id']),
      leadId: asString(json['lead_id']),
      phaseKey: asString(json['phase_key']),
      phaseLabel: asString(json['phase_label']),
      title: asString(json['title']),
      description: asString(json['description']),
      status: asString(json['status'], 'todo'),
      priority: asString(json['priority'], 'medium'),
      assigneeId: asString(json['assignee_id']).isEmpty
          ? null
          : asString(json['assignee_id']),
      assignee: json['assignee'] is Map
          ? SolarTaskAssigneeRef.fromJson(
              Map<String, dynamic>.from(json['assignee'] as Map),
            )
          : null,
      startDate: _dateOnly(json['start_date']),
      dueDate: _dateOnly(json['due_date']),
      completedAt: asString(json['completed_at']).isEmpty
          ? null
          : asString(json['completed_at']),
      sortOrder: asInt(json['sort_order']),
      dependsOnIds: _stringList(json['depends_on_ids']),
      dependencies: _depList(json['dependencies']),
      blockedBy: _depList(json['blocked_by']),
      isBlocked: asBool(json['is_blocked']),
      isOverdue: asBool(json['is_overdue']),
      project: json['project'] is Map
          ? SolarTaskProjectRef.fromJson(
              Map<String, dynamic>.from(json['project'] as Map),
            )
          : null,
      createdAt: asString(json['created_at']).isEmpty
          ? null
          : asString(json['created_at']),
      updatedAt: asString(json['updated_at']).isEmpty
          ? null
          : asString(json['updated_at']),
    );
  }

  static String? _dateOnly(dynamic value) {
    final raw = asString(value);
    if (raw.isEmpty) return null;
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => asString(e))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static List<SolarTaskDependency> _depList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (e) => SolarTaskDependency.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(growable: false);
  }
}

class SolarTaskMeta {
  const SolarTaskMeta({
    this.phases = const [],
    this.statuses = const [],
    this.priorities = const [],
  });

  final List<SolarTaskPhase> phases;
  final List<String> statuses;
  final List<String> priorities;

  factory SolarTaskMeta.fromJson(Map<String, dynamic> json) {
    final phases = (json['phases'] is List)
        ? (json['phases'] as List)
            .whereType<Map>()
            .map(
              (e) => SolarTaskPhase.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((p) => p.key.isNotEmpty)
            .toList()
        : const <SolarTaskPhase>[];
    final statuses = (json['statuses'] is List)
        ? (json['statuses'] as List)
            .map((e) => asString(e))
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final priorities = (json['priorities'] is List)
        ? (json['priorities'] as List)
            .map((e) => asString(e))
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    return SolarTaskMeta(
      phases: phases,
      statuses: statuses,
      priorities: priorities,
    );
  }
}

class SolarTaskListResult {
  const SolarTaskListResult({
    this.data = const [],
    this.summary = const {},
  });

  final List<SolarTaskModel> data;
  final Map<String, int> summary;

  factory SolarTaskListResult.fromJson(Map<String, dynamic> json) {
    final rows = (json['data'] is List)
        ? (json['data'] as List)
            .whereType<Map>()
            .map((e) => SolarTaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <SolarTaskModel>[];
    final summaryRaw = json['summary'];
    final summary = <String, int>{};
    if (summaryRaw is Map) {
      for (final entry in summaryRaw.entries) {
        summary['${entry.key}'] = asInt(entry.value);
      }
    }
    return SolarTaskListResult(data: rows, summary: summary);
  }
}

class SolarTaskFormData {
  const SolarTaskFormData({
    this.id,
    this.leadId = '',
    this.phaseKey = 'sales',
    this.title = '',
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    this.assigneeId = '',
    this.startDate = '',
    this.dueDate = '',
    this.dependsOnIds = const [],
  });

  final String? id;
  final String leadId;
  final String phaseKey;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assigneeId;
  final String startDate;
  final String dueDate;
  final List<String> dependsOnIds;

  bool get isEditing => id != null && id!.isNotEmpty;

  SolarTaskFormData copyWith({
    String? id,
    String? leadId,
    String? phaseKey,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    String? startDate,
    String? dueDate,
    List<String>? dependsOnIds,
    bool clearId = false,
  }) {
    return SolarTaskFormData(
      id: clearId ? null : (id ?? this.id),
      leadId: leadId ?? this.leadId,
      phaseKey: phaseKey ?? this.phaseKey,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      dependsOnIds: dependsOnIds ?? this.dependsOnIds,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'lead_id': leadId,
      'phase_key': phaseKey,
      'title': title.trim(),
      'description': description.trim(),
      'status': status,
      'priority': priority,
      'assignee_id': assigneeId.isEmpty ? null : assigneeId,
      'start_date': startDate.isEmpty ? null : startDate,
      'due_date': dueDate.isEmpty ? null : dueDate,
      'depends_on_ids': dependsOnIds,
    };
  }

  factory SolarTaskFormData.fromTask(SolarTaskModel task) {
    return SolarTaskFormData(
      id: task.id,
      leadId: task.leadId,
      phaseKey: task.phaseKey,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      assigneeId: task.assigneeId ?? '',
      startDate: task.startDate ?? '',
      dueDate: task.dueDate ?? '',
      dependsOnIds: List<String>.from(task.dependsOnIds),
    );
  }
}

class SolarTaskClientSummary {
  const SolarTaskClientSummary({
    this.open = 0,
    this.inProgress = 0,
    this.waiting = 0,
    this.overdue = 0,
    this.done = 0,
  });

  final int open;
  final int inProgress;
  final int waiting;
  final int overdue;
  final int done;

  factory SolarTaskClientSummary.fromTasks(List<SolarTaskModel> tasks) {
    var open = 0;
    var inProgress = 0;
    var waiting = 0;
    var overdue = 0;
    var done = 0;
    for (final task in tasks) {
      if (task.status == 'done') done += 1;
      if (task.status == 'in_progress') inProgress += 1;
      if (task.isOverdue) overdue += 1;
      if (task.isBlocked &&
          task.status != 'done' &&
          task.status != 'cancelled') {
        waiting += 1;
      }
      if (task.status != 'done' && task.status != 'cancelled') open += 1;
    }
    return SolarTaskClientSummary(
      open: open,
      inProgress: inProgress,
      waiting: waiting,
      overdue: overdue,
      done: done,
    );
  }
}

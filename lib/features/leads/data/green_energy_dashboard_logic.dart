import 'package:intl/intl.dart';

import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class TerritoryFilters {
  const TerritoryFilters({
    this.state = '',
    this.district = '',
    this.role = '',
    this.userId = '',
  });

  final String state;
  final String district;
  final String role;
  final String userId;

  bool get hasAny =>
      state.trim().isNotEmpty ||
      district.trim().isNotEmpty ||
      role.trim().isNotEmpty ||
      userId.trim().isNotEmpty;

  TerritoryFilters copyWith({
    String? state,
    String? district,
    String? role,
    String? userId,
    bool clearDistrict = false,
    bool clearRole = false,
    bool clearUser = false,
    bool clearState = false,
  }) {
    return TerritoryFilters(
      state: clearState ? '' : (state ?? this.state),
      district: clearDistrict ? '' : (district ?? this.district),
      role: clearRole ? '' : (role ?? this.role),
      userId: clearUser ? '' : (userId ?? this.userId),
    );
  }

  TerritoryFilters cleared() => const TerritoryFilters();
}

class StateAnalytics {
  const StateAnalytics({
    required this.name,
    this.users = 0,
    this.leads = 0,
    this.open = 0,
    this.converted = 0,
    this.completed = 0,
    this.rejected = 0,
    this.active = 0,
    this.installPending = 0,
  });

  final String name;
  final int users;
  final int leads;
  final int open;
  final int converted;
  final int completed;
  final int rejected;
  final int active;
  final int installPending;

  StateAnalytics copyWith({
    int? users,
    int? leads,
    int? open,
    int? converted,
    int? completed,
    int? rejected,
    int? active,
    int? installPending,
  }) {
    return StateAnalytics(
      name: name,
      users: users ?? this.users,
      leads: leads ?? this.leads,
      open: open ?? this.open,
      converted: converted ?? this.converted,
      completed: completed ?? this.completed,
      rejected: rejected ?? this.rejected,
      active: active ?? this.active,
      installPending: installPending ?? this.installPending,
    );
  }
}

class NamedCount {
  const NamedCount({
    required this.name,
    required this.value,
    this.display = '',
    this.key = '',
  });

  final String name;
  final int value;
  final String display;
  final String key;
}

class AgingCounts {
  const AgingCounts({
    this.fresh = 0,
    this.warming = 0,
    this.aging = 0,
    this.stale = 0,
  });

  final int fresh;
  final int warming;
  final int aging;
  final int stale;

  int get total => fresh + warming + aging + stale;
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.key,
    required this.month,
    this.created = 0,
    this.converted = 0,
    this.completed = 0,
  });

  final String key;
  final String month;
  final int created;
  final int converted;
  final int completed;

  MonthlyTrendPoint copyWith({int? created, int? converted, int? completed}) {
    return MonthlyTrendPoint(
      key: key,
      month: month,
      created: created ?? this.created,
      converted: converted ?? this.converted,
      completed: completed ?? this.completed,
    );
  }
}

class RecentLeadRow {
  const RecentLeadRow({
    required this.id,
    required this.name,
    required this.code,
    required this.state,
    required this.status,
  });

  final String id;
  final String name;
  final String code;
  final String state;
  final String status;
}

class DashboardKpis {
  const DashboardKpis({
    this.total = 0,
    this.open = 0,
    this.converted = 0,
    this.completed = 0,
    this.active = 0,
    this.rejected = 0,
    this.installPending = 0,
    this.inPipeline = 0,
    this.approved = 0,
    this.urgent = 0,
    this.high = 0,
    this.medium = 0,
    this.low = 0,
    this.newThisWeek = 0,
    this.mixPipeline = 0,
    this.mixConverted = 0,
  });

  final int total;
  final int open;
  final int converted;
  final int completed;
  final int active;
  final int rejected;
  final int installPending;
  final int inPipeline;
  final int approved;
  final int urgent;
  final int high;
  final int medium;
  final int low;
  final int newThisWeek;
  final int mixPipeline;
  final int mixConverted;

  int get leadMixTotal => mixPipeline + mixConverted + completed + rejected;

  int get priorityMixTotal => urgent + high + medium + low;

  /// Web `conversionPct = round(converted / total * 100)`.
  int get conversionPercent =>
      total == 0 ? 0 : ((converted / total) * 100).round();

  /// Web `completionPct = round(completed / total * 100)`.
  int get completionPercent =>
      total == 0 ? 0 : ((completed / total) * 100).round();

  /// Web `openPct = round(open / total * 100)`.
  int get openPercent => total == 0 ? 0 : ((open / total) * 100).round();

  double pctOf(int value) => total == 0 ? 0 : (value / total) * 100;
}

class DashboardInsights {
  const DashboardInsights({
    this.aging = const AgingCounts(),
    this.createdToday = 0,
    this.createdYesterday = 0,
    this.createdThisMonth = 0,
    this.createdLastMonth = 0,
    this.momCreatedPercent = 0,
    this.topStates = const [],
    this.topAssignees = const [],
    this.byDepartment = const [],
    this.monthly = const [],
    this.stageBars = const [],
    this.recent = const [],
  });

  final AgingCounts aging;
  final int createdToday;
  final int createdYesterday;
  final int createdThisMonth;
  final int createdLastMonth;
  final int momCreatedPercent;
  final List<NamedCount> topStates;
  final List<NamedCount> topAssignees;
  final List<NamedCount> byDepartment;
  final List<MonthlyTrendPoint> monthly;
  final List<NamedCount> stageBars;
  final List<RecentLeadRow> recent;
}

class GreenEnergyDashboardSnapshot {
  const GreenEnergyDashboardSnapshot({
    required this.filters,
    required this.users,
    required this.leads,
    required this.kpis,
    required this.insights,
    required this.stateAnalytics,
    required this.availableStates,
    required this.availableDistricts,
    required this.availableRoles,
    required this.availableUsers,
    required this.canSeeRejected,
  });

  final TerritoryFilters filters;
  final List<TerritoryUser> users;
  final List<LeadModel> leads;
  final DashboardKpis kpis;
  final DashboardInsights insights;
  final Map<String, StateAnalytics> stateAnalytics;
  final List<String> availableStates;
  final List<String> availableDistricts;
  final List<String> availableRoles;
  final List<TerritoryUser> availableUsers;
  final bool canSeeRejected;

  int get maxStateLeads {
    var max = 1;
    for (final item in stateAnalytics.values) {
      if (item.leads > max) max = item.leads;
    }
    return max;
  }

  StateAnalytics? get selectedState {
    final state = normalizeStateName(filters.state);
    if (state.isEmpty) return null;
    return stateAnalytics[state] ??
        StateAnalytics(name: state);
  }

  List<StateAnalytics> get activeStates {
    final list = stateAnalytics.values
        .where((item) => item.leads > 0)
        .toList()
      ..sort((a, b) => b.leads.compareTo(a.leads));
    return list;
  }
}

bool isOpenLead(LeadModel lead) {
  return !LeadWorkflow.isCompletedStatus(
        lead.status,
        department: lead.currentDepartment,
      ) &&
      !LeadWorkflow.isRejectedStatus(lead.status);
}

/// Maps a lead priority onto the four Priority mix buckets.
/// Blank or unknown values follow the form/web default: Medium.
String normalizeLeadPriority(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'urgent':
      return 'urgent';
    case 'high':
      return 'high';
    case 'low':
      return 'low';
    default:
      return 'medium';
  }
}

bool hasFilledInstallationDetails(LeadModel lead) {
  final details = lead.installationDetails;
  if (details == null || details.isEmpty) return false;

  String value(List<String> keys) {
    for (final key in keys) {
      final raw = details[key];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        return raw.toString().trim();
      }
    }
    return '';
  }

  return value(['file_no', 'fileNo']).isNotEmpty &&
      value(['panel_type', 'panelType']).isNotEmpty &&
      value(['solar_panel_brand', 'solarPanelBrand']).isNotEmpty &&
      value([
        'number_of_solar_panels',
        'numberOfSolarPanels',
        'panel_count',
        'panelCount',
      ]).isNotEmpty;
}

bool _equalsIgnoreCase(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

List<TerritoryUser> usersMatchingFilters(
  List<TerritoryUser> users,
  TerritoryFilters filters,
) {
  return users.where((user) {
    if (filters.state.trim().isNotEmpty &&
        !sameState(user.state, filters.state)) {
      return false;
    }
    if (filters.district.trim().isNotEmpty &&
        !_equalsIgnoreCase(user.district, filters.district)) {
      return false;
    }
    if (filters.role.trim().isNotEmpty && !user.matchesRole(filters.role)) {
      return false;
    }
    return true;
  }).toList();
}

List<LeadModel> applyTerritoryFilters({
  required List<LeadModel> leads,
  required List<TerritoryUser> users,
  required TerritoryFilters filters,
}) {
  if (!filters.hasAny) return List<LeadModel>.from(leads);

  final byId = <String, TerritoryUser>{
    for (final user in users) if (user.id.isNotEmpty) user.id: user,
  };

  var result = leads.where((lead) {
    if (filters.state.isEmpty &&
        filters.district.isEmpty &&
        filters.role.isEmpty) {
      return true;
    }

    final assigned = byId[lead.assignedTo];
    final creator = byId[lead.createdBy];
    final assignedOrCreator = assigned ?? creator;

    bool matchesState(TerritoryUser? user) {
      if (filters.state.isEmpty) return true;
      return sameState(user?.state, filters.state) ||
          sameState(lead.state, filters.state);
    }

    bool matchesDistrict(TerritoryUser? user) {
      if (filters.district.isEmpty) return true;
      return _equalsIgnoreCase(user?.district ?? '', filters.district) ||
          _equalsIgnoreCase(lead.district, filters.district);
    }

    bool matchesRole(TerritoryUser? user) {
      if (filters.role.isEmpty) return true;
      if (user == null) return false;
      return user.matchesRole(filters.role);
    }

    bool matches(TerritoryUser? user) =>
        matchesState(user) && matchesDistrict(user) && matchesRole(user);

    if (matches(assignedOrCreator)) return true;
    if (assigned != null && matches(assigned)) return true;
    if (creator != null && matches(creator)) return true;
    return false;
  }).toList();

  if (filters.userId.trim().isNotEmpty) {
    final uid = filters.userId.trim();
    result = result.where((lead) => lead.createdBy.trim() == uid).toList();
  }

  return result;
}

DashboardKpis buildDashboardKpis(
  List<LeadModel> leads, {
  required bool canSeeRejected,
}) {
  final source = canSeeRejected
      ? leads
      : leads
          .where((lead) => !LeadWorkflow.isRejectedStatus(lead.status))
          .toList();

  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  var open = 0;
  var converted = 0;
  var completed = 0;
  var rejected = 0;
  var active = 0;
  var installPending = 0;
  var inPipeline = 0;
  var mixPipeline = 0;
  var mixConverted = 0;
  var approved = 0;
  var urgent = 0;
  var high = 0;
  var medium = 0;
  var low = 0;
  var newThisWeek = 0;

  for (final lead in source) {
    final isRejected = LeadWorkflow.isRejectedStatus(lead.status);
    final isCompleted = LeadWorkflow.isCompletedStatus(
      lead.status,
      department: lead.currentDepartment,
    );
    final isConverted = LeadWorkflow.isConvertedPipelineStatus(lead.status);

    // Same independent filters as web `stats` useMemo.
    if (isRejected) {
      rejected += 1;
    } else if (isCompleted) {
      completed += 1;
    } else {
      open += 1;
      inPipeline += 1;
      if (lead.isActive) active += 1;
      if (isConverted) {
        mixConverted += 1;
      } else {
        mixPipeline += 1;
      }
      if (LeadWorkflow.isApprovedStatus(lead.status)) approved += 1;
      if (!hasFilledInstallationDetails(lead)) installPending += 1;
      switch (normalizeLeadPriority(lead.priority)) {
        case 'urgent':
          urgent += 1;
        case 'high':
          high += 1;
        case 'low':
          low += 1;
        default:
          medium += 1;
      }
      final created = parseDate(lead.createdAt);
      if (created != null && !created.isBefore(weekAgo)) newThisWeek += 1;
    }
    // Web `stats.converted = source.filter(isConvertedLead)` — independent of
    // open/rejected, so "Rejected By Sales Manager" still counts as converted.
    if (isConverted) converted += 1;
  }

  return DashboardKpis(
    total: source.length,
    open: open,
    converted: converted,
    completed: completed,
    active: active,
    rejected: canSeeRejected ? rejected : 0,
    installPending: installPending,
    inPipeline: inPipeline,
    approved: approved,
    urgent: urgent,
    high: high,
    medium: medium,
    low: low,
    newThisWeek: newThisWeek,
    mixPipeline: mixPipeline,
    mixConverted: mixConverted,
  );
}

const leadDepartmentBuckets = <({String value, String label})>[
  (value: 'Sales', label: 'Sales'),
  (value: 'Support', label: 'Documents'),
  (value: 'Bank Process', label: 'Bank Process'),
  (value: 'Finance', label: 'Finance'),
  (value: 'Installation', label: 'Installation'),
];

const leadStageBuckets = <({String key, String name, List<String> match})>[
  (key: 'early', name: 'New / Follow-up', match: ['New Lead', 'Follow Up']),
  (
    key: 'sales',
    name: 'KYC / Sales',
    match: [
      'Converted',
      'KYC Collected',
      'Sent To Sales Manager',
      'Approved By Sales Manager',
    ],
  ),
  (
    key: 'docs',
    name: 'Documents / Bank',
    match: [
      'Assigned To Document Administrator',
      'Documents Verification Started',
      'Portal Processing Started',
      'Loan Application Initiated',
      'Documents Submitted',
      'Banking Process Start',
      'Bank Coordination In Progress',
      'Bank Process Complete',
    ],
  ),
  (
    key: 'finance',
    name: 'Finance / Install',
    match: [
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
    ],
  ),
  (
    key: 'done',
    name: 'Completed',
    match: ['Final Complete', 'Lead Completed', 'Lead Closed'],
  ),
];

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String _monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final year = int.tryParse(parts[0]) ?? 0;
  final month = int.tryParse(parts[1]) ?? 1;
  return DateFormat('MMM').format(DateTime(year, month, 1));
}

List<NamedCount> buildLeadMixSlices(
  DashboardKpis kpis, {
  required bool canSeeRejected,
}) {
  return [
    NamedCount(key: 'pipeline', name: 'In pipeline', value: kpis.inPipeline),
    NamedCount(key: 'converted', name: 'Converted', value: kpis.converted),
    NamedCount(key: 'completed', name: 'Completed', value: kpis.completed),
    if (canSeeRejected)
      NamedCount(key: 'rejected', name: 'Rejected', value: kpis.rejected),
  ];
}

int pieSlicePercent(int value, int sliceTotal) {
  if (sliceTotal <= 0) return 0;
  return ((value / sliceTotal) * 100).round();
}

List<MonthlyTrendPoint> buildMonthlyTrend(List<LeadModel> leads) {
  final now = DateTime.now();
  final keys = <String>[
    for (var i = 5; i >= 0; i--) _monthKey(DateTime(now.year, now.month - i, 1)),
  ];
  final counts = <String, MonthlyTrendPoint>{
    for (final key in keys)
      key: MonthlyTrendPoint(key: key, month: _monthLabel(key)),
  };

  for (final lead in leads) {
    final created = parseDate(lead.createdAt);
    if (created != null) {
      final createdKey = _monthKey(created);
      final bucket = counts[createdKey];
      if (bucket != null) {
        counts[createdKey] = bucket.copyWith(created: bucket.created + 1);
      }
    }

    final done = LeadWorkflow.isCompletedStatus(
      lead.status,
      department: lead.currentDepartment,
    );
    // Web monthly "In converted flow" omits Rejected By Sales Manager.
    final convertedLike = done ||
        (LeadWorkflow.isConvertedPipelineStatus(lead.status) &&
            !LeadWorkflow.isRejectedStatus(lead.status));
    final touch = parseDate(
          lead.updatedAt.isNotEmpty ? lead.updatedAt : lead.createdAt,
        ) ??
        created;
    if (touch == null) continue;
    final touchKey = _monthKey(touch);
    final bucket = counts[touchKey];
    if (bucket == null) continue;
    counts[touchKey] = bucket.copyWith(
      converted: bucket.converted + (convertedLike ? 1 : 0),
      completed: bucket.completed + (done ? 1 : 0),
    );
  }

  return [for (final key in keys) counts[key]!];
}

List<NamedCount> buildStageBars(List<LeadModel> leads) {
  return [
    for (final bucket in leadStageBuckets)
      NamedCount(
        key: bucket.key,
        name: bucket.name,
        value: leads
            .where((lead) => bucket.match.contains(lead.status.trim()))
            .length,
      ),
  ].where((item) => item.value > 0).toList();
}

DashboardInsights buildDashboardInsights(List<LeadModel> leads) {
  final open = leads.where(isOpenLead).toList();
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final thisMonthKey = _monthKey(todayStart);
  final lastMonthKey = _monthKey(DateTime(now.year, now.month - 1, 1));

  var createdToday = 0;
  var createdYesterday = 0;
  var createdThisMonth = 0;
  var createdLastMonth = 0;
  var fresh = 0;
  var warming = 0;
  var aging = 0;
  var stale = 0;

  for (final lead in leads) {
    final created = parseDate(lead.createdAt);
    if (created != null) {
      if (!created.isBefore(todayStart)) {
        createdToday += 1;
      } else if (!created.isBefore(yesterdayStart) &&
          created.isBefore(todayStart)) {
        createdYesterday += 1;
      }
      final key = _monthKey(created);
      if (key == thisMonthKey) createdThisMonth += 1;
      if (key == lastMonthKey) createdLastMonth += 1;
    }
  }

  for (final lead in open) {
    final touch = parseDate(
      lead.updatedAt.isNotEmpty ? lead.updatedAt : lead.createdAt,
    );
    if (touch == null) {
      warming += 1;
      continue;
    }
    final days = now.difference(touch).inMilliseconds / 86400000;
    if (days <= 7) {
      fresh += 1;
    } else if (days <= 21) {
      warming += 1;
    } else if (days <= 45) {
      aging += 1;
    } else {
      stale += 1;
    }
  }

  final stateCounts = <String, ({int total, int openCount, int completed})>{};
  for (final lead in leads) {
    final state = normalizeStateName(lead.state);
    final name = state.isEmpty ? 'Unknown' : state;
    final current =
        stateCounts[name] ?? (total: 0, openCount: 0, completed: 0);
    final isCompleted = LeadWorkflow.isCompletedStatus(
      lead.status,
      department: lead.currentDepartment,
    );
    final isRejected = LeadWorkflow.isRejectedStatus(lead.status);
    stateCounts[name] = (
      total: current.total + 1,
      openCount: current.openCount + ((!isCompleted && !isRejected) ? 1 : 0),
      completed: current.completed + (isCompleted ? 1 : 0),
    );
  }
  final topStates = stateCounts.entries
      .map(
        (e) => NamedCount(
          name: e.key,
          value: e.value.total,
          display: '${e.value.total} · ${e.value.openCount} open',
        ),
      )
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final assigneeCounts = <String, int>{};
  for (final lead in open) {
    final name = lead.assignedToName.trim().isEmpty
        ? 'Unassigned'
        : lead.assignedToName.trim();
    assigneeCounts[name] = (assigneeCounts[name] ?? 0) + 1;
  }
  final topAssignees = assigneeCounts.entries
      .map((e) => NamedCount(name: e.key, value: e.value, display: '${e.value}'))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final byDepartment = [
    for (final dept in leadDepartmentBuckets)
      NamedCount(
        name: dept.label,
        value: open
            .where(
              (lead) =>
                  LeadWorkflow.normalizeDepartmentValue(
                    lead.currentDepartment,
                  ) ==
                  dept.value,
            )
            .length,
      ),
  ].where((item) => item.value > 0).toList();

  final recent = [...leads]..sort((a, b) {
      final ta =
          parseDate(a.updatedAt.isNotEmpty ? a.updatedAt : a.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb =
          parseDate(b.updatedAt.isNotEmpty ? b.updatedAt : b.createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

  final momCreatedPercent = createdLastMonth > 0
      ? (((createdThisMonth - createdLastMonth) / createdLastMonth) * 100)
            .round()
      : createdThisMonth > 0
      ? 100
      : 0;

  return DashboardInsights(
    aging: AgingCounts(
      fresh: fresh,
      warming: warming,
      aging: aging,
      stale: stale,
    ),
    createdToday: createdToday,
    createdYesterday: createdYesterday,
    createdThisMonth: createdThisMonth,
    createdLastMonth: createdLastMonth,
    momCreatedPercent: momCreatedPercent,
    topStates: topStates.take(6).toList(),
    topAssignees: topAssignees.take(6).toList(),
    byDepartment: byDepartment,
    monthly: buildMonthlyTrend(leads),
    stageBars: buildStageBars(leads),
    recent: recent
        .take(8)
        .map(
          (lead) => RecentLeadRow(
            id: lead.id,
            name: lead.fullName.trim().isEmpty ? '—' : lead.fullName,
            code: lead.leadCode,
            state: lead.state,
            status: LeadWorkflow.getStatusDisplayLabel(lead.status),
          ),
        )
        .toList(),
  );
}

Map<String, StateAnalytics> buildStateAnalytics({
  required List<LeadModel> leads,
  required List<TerritoryUser> users,
  required bool canSeeRejected,
}) {
  final result = <String, StateAnalytics>{
    for (final name in indiaStateNames) name: StateAnalytics(name: name),
  };

  void bump(String rawState, StateAnalytics Function(StateAnalytics) update) {
    final state = normalizeStateName(rawState);
    if (state.isEmpty) return;
    result[state] = update(
      result[state] ?? StateAnalytics(name: state),
    );
  }

  for (final user in users) {
    bump(
      user.state,
      (current) => current.copyWith(users: current.users + 1),
    );
  }

  for (final lead in leads) {
    bump(lead.state, (current) {
      final isRejected = LeadWorkflow.isRejectedStatus(lead.status);
      final isCompleted = LeadWorkflow.isCompletedStatus(
        lead.status,
        department: lead.currentDepartment,
      );
      final isConverted = LeadWorkflow.isConvertedPipelineStatus(lead.status);
      final openLead = !isCompleted && !isRejected;

      return current.copyWith(
        leads: current.leads + 1,
        rejected: current.rejected + ((canSeeRejected && isRejected) ? 1 : 0),
        completed: current.completed + (isCompleted ? 1 : 0),
        open: current.open + (openLead ? 1 : 0),
        converted: current.converted + (isConverted ? 1 : 0),
        active: current.active + ((openLead && lead.isActive) ? 1 : 0),
        installPending: current.installPending +
            ((openLead && !hasFilledInstallationDetails(lead)) ? 1 : 0),
      );
    });
  }

  return result;
}

GreenEnergyDashboardSnapshot buildDashboardSnapshot({
  required List<LeadModel> allLeads,
  required List<TerritoryUser> users,
  required TerritoryFilters filters,
  required bool canSeeRejected,
}) {
  // Pipeline + charts are identical for every role (including Company Admin).
  // Rejected leads stay in the totals so Convert/Done % and pies do not shift.
  final pipelineLeads = allLeads;

  final filtered = applyTerritoryFilters(
    leads: pipelineLeads,
    users: users,
    filters: filters,
  );

  final matchingUsers = usersMatchingFilters(users, filters);

  final states = <String>{
    ...indiaStateNames,
    for (final user in users)
      if (user.state.trim().isNotEmpty) normalizeStateName(user.state),
    for (final lead in pipelineLeads)
      if (lead.state.trim().isNotEmpty) normalizeStateName(lead.state),
  }.where((item) => item.trim().isNotEmpty).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final districts = <String>{};
  for (final user in users) {
    if (filters.state.isNotEmpty && !sameState(user.state, filters.state)) {
      continue;
    }
    if (user.district.trim().isNotEmpty) districts.add(user.district.trim());
  }
  for (final lead in pipelineLeads) {
    if (filters.state.isNotEmpty && !sameState(lead.state, filters.state)) {
      continue;
    }
    if (lead.district.trim().isNotEmpty) districts.add(lead.district.trim());
  }
  final districtList = districts.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final roles = <String>{};
  for (final user in users) {
    roles.addAll(user.roles.where((role) => role.trim().isNotEmpty));
  }
  final roleList = roles.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  // Territory filters only drive the map highlight + selected-state card.
  return GreenEnergyDashboardSnapshot(
    filters: filters,
    users: users,
    leads: filtered,
    kpis: buildDashboardKpis(pipelineLeads, canSeeRejected: true),
    insights: buildDashboardInsights(pipelineLeads),
    stateAnalytics: buildStateAnalytics(
      leads: pipelineLeads,
      users: users,
      canSeeRejected: true,
    ),
    availableStates: states,
    availableDistricts: districtList,
    availableRoles: roleList,
    availableUsers: matchingUsers,
    canSeeRejected: canSeeRejected,
  );
}

import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';

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
  final int urgent;
  final int high;
  final int medium;
  final int low;
  final int newThisWeek;
  /// Early pipeline only (open and not yet converted). Used by Lead mix.
  final int mixPipeline;
  /// Converted and still open. Used by Lead mix so slices do not overlap.
  final int mixConverted;

  int get leadMixTotal => mixPipeline + mixConverted + completed + rejected;

  int get priorityMixTotal => urgent + high + medium + low;

  double pctOf(int value) => total == 0 ? 0 : (value / total) * 100;
}

class GreenEnergyDashboardSnapshot {
  const GreenEnergyDashboardSnapshot({
    required this.filters,
    required this.users,
    required this.leads,
    required this.kpis,
    required this.stateAnalytics,
    required this.availableStates,
    required this.availableDistricts,
    required this.availableRoles,
    required this.availableUsers,
  });

  final TerritoryFilters filters;
  final List<TerritoryUser> users;
  final List<LeadModel> leads;
  final DashboardKpis kpis;
  final Map<String, StateAnalytics> stateAnalytics;
  final List<String> availableStates;
  final List<String> availableDistricts;
  final List<String> availableRoles;
  final List<TerritoryUser> availableUsers;

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
      final created = DateTime.tryParse(lead.createdAt);
      if (created != null && !created.isBefore(weekAgo)) newThisWeek += 1;
    }
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
    urgent: urgent,
    high: high,
    medium: medium,
    low: low,
    newThisWeek: newThisWeek,
    mixPipeline: mixPipeline,
    mixConverted: mixConverted,
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
  final visibleLeads = canSeeRejected
      ? allLeads
      : allLeads
          .where((lead) => !LeadWorkflow.isRejectedStatus(lead.status))
          .toList();

  final filtered = applyTerritoryFilters(
    leads: visibleLeads,
    users: users,
    filters: filters,
  );

  final matchingUsers = usersMatchingFilters(users, filters);

  final states = <String>{
    ...indiaStateNames,
    for (final user in users)
      if (user.state.trim().isNotEmpty) normalizeStateName(user.state),
    for (final lead in visibleLeads)
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
  for (final lead in visibleLeads) {
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

  return GreenEnergyDashboardSnapshot(
    filters: filters,
    users: users,
    leads: filtered,
    kpis: buildDashboardKpis(filtered, canSeeRejected: canSeeRejected),
    stateAnalytics: buildStateAnalytics(
      leads: filtered,
      users: users,
      canSeeRejected: canSeeRejected,
    ),
    availableStates: states,
    availableDistricts: districtList,
    availableRoles: roleList,
    availableUsers: matchingUsers,
  );
}

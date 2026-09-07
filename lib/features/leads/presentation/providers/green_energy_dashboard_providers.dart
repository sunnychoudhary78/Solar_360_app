import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';

const _fallbackTerritoryRoles = <String>[
  'Sales',
  'SolarSales',
  'Sales Manager',
  'Finance Manager',
  'Document Administrator',
  'Bank Process',
  'Finance User',
  'Installation Manager',
  'Installation Team',
  'Material Engineer',
  'Electrical Engineer',
  'Company Admin',
];

final territoryFiltersProvider =
    NotifierProvider<TerritoryFiltersNotifier, TerritoryFilters>(
  TerritoryFiltersNotifier.new,
);

class TerritoryFiltersNotifier extends Notifier<TerritoryFilters> {
  @override
  TerritoryFilters build() => const TerritoryFilters();

  void setState(String value) {
    final canonical = normalizeStateName(value);
    state = state.copyWith(
      state: canonical,
      clearState: canonical.isEmpty,
      clearDistrict: true,
      clearUser: true,
    );
  }

  void toggleState(String value) {
    final canonical = normalizeStateName(value);
    if (canonical.isNotEmpty && sameState(state.state, canonical)) {
      state = state.copyWith(clearState: true, clearDistrict: true, clearUser: true);
      return;
    }
    setState(canonical);
  }

  void setDistrict(String value) {
    state = state.copyWith(district: value, clearUser: true);
  }

  void setRole(String value) {
    state = state.copyWith(role: value, clearUser: true);
  }

  void setUser(String value) {
    state = state.copyWith(userId: value);
  }

  void clearAll() {
    state = const TerritoryFilters();
  }
}

/// Same permission name as web (`territoryFilters`). Assigned per role in Roles UI.
const territoryFiltersPermission = 'territoryFilters';

final territoryUsersProvider =
    FutureProvider.autoDispose<List<TerritoryUser>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.hasPermission(territoryFiltersPermission)) {
    return const [];
  }
  final repo = ref.watch(leadRepositoryProvider);
  try {
    final users = await repo.getAllUsers();
    return users.map(TerritoryUser.fromJson).where((u) => u.id.isNotEmpty).toList();
  } catch (_) {
    try {
      final users = await repo.getUsersByRole(_fallbackTerritoryRoles);
      return users
          .map(TerritoryUser.fromJson)
          .where((u) => u.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
});

final greenEnergyDashboardLeadsProvider =
    FutureProvider.autoDispose<List<LeadModel>>((ref) async {
  return ref.watch(leadRepositoryProvider).getAllLeads();
});

final greenEnergyDashboardProvider =
    Provider.autoDispose<AsyncValue<GreenEnergyDashboardSnapshot>>((ref) {
  final leadsAsync = ref.watch(greenEnergyDashboardLeadsProvider);
  final auth = ref.watch(authProvider);
  final canUseTerritoryFilters =
      auth.hasPermission(territoryFiltersPermission);
  final usersAsync = canUseTerritoryFilters
      ? ref.watch(territoryUsersProvider)
      : const AsyncValue<List<TerritoryUser>>.data([]);
  final filters = canUseTerritoryFilters
      ? ref.watch(territoryFiltersProvider)
      : const TerritoryFilters();
  final canSeeRejected =
      LeadWorkflow.canViewRejectedLeads(auth.effectiveRoleName);

  if (leadsAsync.hasError && !leadsAsync.hasValue) {
    return AsyncValue.error(leadsAsync.error!, leadsAsync.stackTrace!);
  }
  if (leadsAsync.isLoading && !leadsAsync.hasValue) {
    return const AsyncValue.loading();
  }

  final leads = leadsAsync.asData?.value ?? const <LeadModel>[];
  final users = usersAsync.asData?.value ?? const <TerritoryUser>[];

  return AsyncValue.data(
    buildDashboardSnapshot(
      allLeads: leads,
      users: users,
      filters: filters,
      canSeeRejected: canSeeRejected,
    ),
  );
});

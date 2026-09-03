import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/core/utils/role_utils.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/leads/data/lead_api_service.dart';
import 'package:solar_sales/features/leads/data/lead_repository.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final leadApiServiceProvider = Provider<LeadApiService>((ref) {
  return LeadApiService(
    ref.watch(apiServiceProvider),
    ref.watch(dioClientProvider).dio,
  );
});

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(ref.watch(leadApiServiceProvider));
});

final allLeadsProvider = FutureProvider.autoDispose<List<LeadModel>>((
  ref,
) async {
  final repository = ref.watch(leadRepositoryProvider);
  final leads = await repository.getAllLeads();
  return leads.where((lead) => lead.isActive).toList();
});

/// Client-chunked lead lists for All / Converted / Completed screens.
enum LeadListScope { all, converted, completed }

final leadListProvider =
    NotifierProvider.family<LeadListNotifier, LeadListState, LeadListScope>(
      LeadListNotifier.new,
    );

class LeadListState {
  final List<LeadModel> items;
  final List<LeadModel> cached;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final String? statusFilter;
  final String? error;

  const LeadListState({
    this.items = const [],
    this.cached = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.statusFilter,
    this.error,
  });

  List<String> get statusOptions {
    final set = <String>{};
    for (final lead in cached) {
      if (lead.status.trim().isNotEmpty) set.add(lead.status.trim());
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  LeadListState copyWith({
    List<LeadModel>? items,
    List<LeadModel>? cached,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? statusFilter,
    String? error,
    bool clearError = false,
    bool clearStatusFilter = false,
  }) {
    return LeadListState(
      items: items ?? this.items,
      cached: cached ?? this.cached,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

bool _matchesScope(LeadModel lead, LeadListScope scope) {
  switch (scope) {
    case LeadListScope.all:
      return true;
    case LeadListScope.converted:
      return LeadWorkflow.isConvertedPipelineStatus(lead.status);
    case LeadListScope.completed:
      return LeadWorkflow.isCompletedStatus(
        lead.status,
        department: lead.currentDepartment,
      );
  }
}

class LeadListNotifier extends Notifier<LeadListState> {
  LeadListNotifier(this.scope);

  final LeadListScope scope;
  static const int pageSize = 20;
  Timer? _debounce;

  @override
  LeadListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const LeadListState(isLoading: true);
  }

  LeadRepository get _repo => ref.read(leadRepositoryProvider);

  List<LeadModel> _applyFilters(List<LeadModel> source) {
    var list = source.where((lead) => _matchesScope(lead, scope)).toList();
    final role = ref.read(authProvider).effectiveRoleName;
    if (!LeadWorkflow.canViewRejectedLeads(role)) {
      list = list
          .where((lead) => !LeadWorkflow.isRejectedStatus(lead.status))
          .toList();
    }
    final status = state.statusFilter;
    if (status != null && status.isNotEmpty && status != 'All') {
      list = list.where((l) => l.status.trim() == status).toList();
    }
    final q = state.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((lead) {
        return lead.fullName.toLowerCase().contains(q) ||
            lead.mobile.toLowerCase().contains(q) ||
            lead.leadCode.toLowerCase().contains(q) ||
            lead.status.toLowerCase().contains(q) ||
            lead.currentDepartment.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  void _emitChunk({
    required List<LeadModel> cached,
    required int visibleCount,
  }) {
    final filtered = _applyFilters(cached);
    final take = visibleCount.clamp(0, filtered.length);
    final items = filtered.take(take).toList();
    state = state.copyWith(
      cached: cached,
      items: items,
      isLoading: false,
      isLoadingMore: false,
      hasMore: items.length < filtered.length,
      clearError: true,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final all = (await _repo.getAllLeads())
          .where((lead) => lead.isActive)
          .toList();
      _emitChunk(cached: all, visibleCount: pageSize);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    _emitChunk(
      cached: state.cached,
      visibleCount: state.items.length + pageSize,
    );
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _emitChunk(cached: state.cached, visibleCount: pageSize);
    });
  }

  void setStatusFilter(String? value) {
    state = state.copyWith(
      statusFilter: value,
      clearStatusFilter: value == null || value == 'All',
    );
    _emitChunk(cached: state.cached, visibleCount: pageSize);
  }
}

final leadDetailProvider = FutureProvider.autoDispose.family<LeadModel, String>(
  (ref, id) async {
    return ref.watch(leadRepositoryProvider).getLeadById(id);
  },
);

final leadActionLoadingProvider =
    NotifierProvider<LeadActionLoadingNotifier, bool>(
      LeadActionLoadingNotifier.new,
    );

class LeadActionLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) => state = value;
}

extension SolarAuthState on AuthState {
  String get appRole => RoleUtils.normalizeAppRole(effectiveRoleName);

  String get workflowRoleKey => LeadWorkflow.resolveRoleKey(effectiveRoleName);

  String get displayName => profile?.name ?? authUser?.name ?? 'User';

  String? get profilePhoto => profile?.photo ?? authUser?.photo;

  String get roleName =>
      profile?.roleName ?? authUser?.roleName ?? effectiveRoleName;

  String get roleTitle => RoleUtils.displayTitleForRole(effectiveRoleName);

  String get userId => profile?.id ?? authUser?.id ?? '';
}

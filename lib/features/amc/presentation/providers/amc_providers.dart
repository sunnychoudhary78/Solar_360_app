import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/amc/data/amc_api_service.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final amcApiServiceProvider = Provider<AmcApiService>((ref) {
  return AmcApiService(ref.watch(apiServiceProvider));
});

enum AmcHomeTab { visits, plants }

/// Web `VISIT_CHIPS` ids: '', overdue, today, month, in_progress, unassigned, done_month
class AmcVisitChip {
  const AmcVisitChip(this.id, this.label);
  final String id;
  final String label;
}

const amcVisitChips = <AmcVisitChip>[
  AmcVisitChip('', 'All'),
  AmcVisitChip('overdue', 'Overdue'),
  AmcVisitChip('today', 'Due today'),
  AmcVisitChip('month', 'This month'),
  AmcVisitChip('in_progress', 'In progress'),
  AmcVisitChip('unassigned', 'Unassigned'),
  AmcVisitChip('done_month', 'Done this month'),
];

/// Web `PLANT_CHIPS`
class AmcPlantChip {
  const AmcPlantChip(this.id, this.label);
  final String id;
  final String label;
}

const amcPlantChips = <AmcPlantChip>[
  AmcPlantChip('', 'All plants'),
  AmcPlantChip('none', 'No AMC yet'),
  AmcPlantChip('active', 'Active AMC'),
  AmcPlantChip('overdue', 'Overdue visits'),
];

class AmcHomeState {
  const AmcHomeState({
    this.tab = AmcHomeTab.visits,
    this.summary = const AmcSummary(),
    this.meta = const AmcMeta(),
    this.assignees = const [],
    this.visits = const [],
    this.visitSummary = const AmcVisitListSummary(),
    this.plants = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.searchInput = '',
    this.search = '',
    this.visitFilter = '',
    this.assigneeFilter = '',
    this.plantAmcFilter = '',
    this.error,
  });

  final AmcHomeTab tab;
  final AmcSummary summary;
  final AmcMeta meta;
  final List<AmcAssignee> assignees;
  final List<AmcVisit> visits;
  final AmcVisitListSummary visitSummary;
  final List<AmcPlant> plants;
  final bool isLoading;
  final bool isRefreshing;
  final String searchInput;
  final String search;
  final String visitFilter;
  final String assigneeFilter;
  final String plantAmcFilter;
  final String? error;

  List<AmcPlant> get plantsWithAmc =>
      plants.where((p) => p.contract?.id.isNotEmpty == true).toList();

  AmcHomeState copyWith({
    AmcHomeTab? tab,
    AmcSummary? summary,
    AmcMeta? meta,
    List<AmcAssignee>? assignees,
    List<AmcVisit>? visits,
    AmcVisitListSummary? visitSummary,
    List<AmcPlant>? plants,
    bool? isLoading,
    bool? isRefreshing,
    String? searchInput,
    String? search,
    String? visitFilter,
    String? assigneeFilter,
    String? plantAmcFilter,
    String? error,
    bool clearError = false,
  }) {
    return AmcHomeState(
      tab: tab ?? this.tab,
      summary: summary ?? this.summary,
      meta: meta ?? this.meta,
      assignees: assignees ?? this.assignees,
      visits: visits ?? this.visits,
      visitSummary: visitSummary ?? this.visitSummary,
      plants: plants ?? this.plants,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      searchInput: searchInput ?? this.searchInput,
      search: search ?? this.search,
      visitFilter: visitFilter ?? this.visitFilter,
      assigneeFilter: assigneeFilter ?? this.assigneeFilter,
      plantAmcFilter: plantAmcFilter ?? this.plantAmcFilter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AmcHomeNotifier extends Notifier<AmcHomeState> {
  Timer? _debounce;

  @override
  AmcHomeState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AmcHomeState();
  }

  AmcApiService get _api => ref.read(amcApiServiceProvider);

  Future<void> bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meta = await _api.meta();
      final summary = await _api.summary();
      final assignees = await _api.assignees();
      state = state.copyWith(
        meta: meta,
        summary: summary,
        assignees: assignees,
      );
      if (state.tab == AmcHomeTab.visits) {
        await _reloadVisits();
      } else {
        await _reloadPlants();
      }
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<void> refresh() async {
    // Allow refresh even while a filter load is in flight (e.g. return from
    // visit detail). Only skip duplicate pull-to-refresh.
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      await _reloadSummary();
      if (state.tab == AmcHomeTab.visits) {
        await _reloadVisits();
      } else {
        await _reloadPlants();
      }
      state = state.copyWith(
        isRefreshing: false,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        isLoading: false,
        error: cleanError(e),
      );
    }
  }

  Future<void> _reloadSummary() async {
    final summary = await _api.summary();
    state = state.copyWith(summary: summary);
  }

  Future<void> _reloadVisits() async {
    String? status;
    String? due;
    String? completed;
    var overdue = false;
    var assigneeId = state.assigneeFilter;

    switch (state.visitFilter) {
      case 'overdue':
        overdue = true;
      case 'today':
        due = 'today';
      case 'month':
        due = 'month';
      case 'in_progress':
        status = 'in_progress';
      case 'unassigned':
        assigneeId = 'unassigned';
      case 'done_month':
      case 'completed':
        completed = 'month';
    }

    final result = await _api.visits(
      search: state.search,
      status: status,
      assigneeId: assigneeId.isEmpty ? null : assigneeId,
      overdue: overdue,
      due: due,
      completed: completed,
    );
    state = state.copyWith(
      visits: result.data,
      visitSummary: result.summary,
    );
  }

  Future<void> _reloadPlants({bool silent = false}) async {
    final plants = await _api.plants(
      search: silent ? null : state.search,
      amc: silent
          ? null
          : (state.plantAmcFilter.isEmpty ? null : state.plantAmcFilter),
    );
    state = state.copyWith(plants: plants);
  }

  Future<void> setTab(AmcHomeTab tab) async {
    if (state.tab == tab) return;
    state = state.copyWith(
      tab: tab,
      isLoading: true,
      clearError: true,
      visitFilter: tab == AmcHomeTab.plants ? state.visitFilter : state.visitFilter,
      plantAmcFilter:
          tab == AmcHomeTab.visits ? state.plantAmcFilter : state.plantAmcFilter,
    );
    // Match web: switching tab clears the other filter context in URL;
    // keep filters in state but reload the active list.
    try {
      if (tab == AmcHomeTab.visits) {
        await _reloadVisits();
      } else {
        await _reloadPlants();
      }
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  void setSearchInput(String value) {
    state = state.copyWith(searchInput: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      state = state.copyWith(search: value.trim());
      try {
        if (state.tab == AmcHomeTab.visits) {
          await _reloadVisits();
        } else {
          await _reloadPlants();
        }
      } catch (e) {
        state = state.copyWith(error: cleanError(e));
      }
    });
  }

  Future<void> setVisitFilter(String value) async {
    state = state.copyWith(
      tab: AmcHomeTab.visits,
      visitFilter: value,
      assigneeFilter: value == 'unassigned' ? '' : state.assigneeFilter,
      isLoading: true,
      clearError: true,
    );
    try {
      await _reloadVisits();
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<void> setAssigneeFilter(String value) async {
    if (value == 'unassigned') {
      await setVisitFilter('unassigned');
      return;
    }
    state = state.copyWith(
      assigneeFilter: value,
      visitFilter:
          state.visitFilter == 'unassigned' ? '' : state.visitFilter,
      isLoading: true,
      clearError: true,
    );
    try {
      await _reloadVisits();
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<void> setPlantAmcFilter(String value) async {
    state = state.copyWith(
      tab: AmcHomeTab.plants,
      plantAmcFilter: value,
      isLoading: true,
      clearError: true,
    );
    try {
      await _reloadPlants();
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<AmcPlant> startAmc(Map<String, dynamic> body) async {
    final plant = await _api.startContract(body);
    await _reloadSummary();
    await _reloadVisits();
    await _reloadPlants();
    return plant;
  }

  Future<AmcPlant> renewAmc(String contractId) async {
    final plant = await _api.renewContract(contractId);
    await refresh();
    return plant;
  }

  Future<AmcVisit> createExtraVisit(Map<String, dynamic> body) async {
    final visit = await _api.createVisit(body);
    await _reloadSummary();
    await _reloadVisits();
    return visit;
  }

  Future<void> removeVisit(String id) async {
    await _api.removeVisit(id);
    await refresh();
  }

  Future<AmcPlant> loadPlant(String leadId) {
    return _api.plant(leadId);
  }

  /// Always fetch active-AMC plants for Extra visit (ignore current list filter).
  Future<List<AmcPlant>> loadPlantsWithAmc() async {
    final plants = await _api.plants(amc: 'active');
    return plants
        .where((p) => p.contract?.id.isNotEmpty == true)
        .toList(growable: false);
  }

  Future<void> ensureAssigneesLoaded() async {
    if (state.assignees.isNotEmpty) return;
    try {
      final assignees = await _api.assignees();
      state = state.copyWith(assignees: assignees);
    } catch (_) {}
  }
}

final amcHomeProvider =
    NotifierProvider<AmcHomeNotifier, AmcHomeState>(AmcHomeNotifier.new);

final amcVisitDetailProvider =
    FutureProvider.autoDispose.family<AmcVisit, String>((ref, id) async {
  return ref.watch(amcApiServiceProvider).visit(id);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/amc/data/amc_api_service.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final amcApiServiceProvider = Provider<AmcApiService>((ref) {
  return AmcApiService(ref.watch(apiServiceProvider));
});

enum AmcHomeTab { visits, plants }

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
    this.visitSearch = '',
    this.plantSearch = '',
    this.visitStatusFilter = '',
    this.overdueOnly = false,
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
  final String visitSearch;
  final String plantSearch;
  final String visitStatusFilter;
  final bool overdueOnly;
  final String plantAmcFilter;
  final String? error;

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
    String? visitSearch,
    String? plantSearch,
    String? visitStatusFilter,
    bool? overdueOnly,
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
      visitSearch: visitSearch ?? this.visitSearch,
      plantSearch: plantSearch ?? this.plantSearch,
      visitStatusFilter: visitStatusFilter ?? this.visitStatusFilter,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      plantAmcFilter: plantAmcFilter ?? this.plantAmcFilter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AmcHomeNotifier extends Notifier<AmcHomeState> {
  @override
  AmcHomeState build() => const AmcHomeState();

  AmcApiService get _api => ref.read(amcApiServiceProvider);

  Future<void> bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.meta(),
        _api.summary(),
        _api.assignees(),
        _api.visits(
          search: state.visitSearch,
          status: state.visitStatusFilter.isEmpty
              ? null
              : state.visitStatusFilter,
          overdue: state.overdueOnly,
        ),
        _api.plants(
          search: state.plantSearch,
          amc: state.plantAmcFilter.isEmpty ? null : state.plantAmcFilter,
        ),
      ]);
      final visitResult = results[3] as AmcVisitListResult;
      state = state.copyWith(
        meta: results[0] as AmcMeta,
        summary: results[1] as AmcSummary,
        assignees: results[2] as List<AmcAssignee>,
        visits: visitResult.data,
        visitSummary: visitResult.summary,
        plants: results[4] as List<AmcPlant>,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: cleanError(e),
      );
    }
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      await Future.wait([
        _reloadSummary(),
        _reloadVisits(),
        _reloadPlants(),
      ]);
      state = state.copyWith(isRefreshing: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: cleanError(e),
      );
    }
  }

  Future<void> _reloadSummary() async {
    final summary = await _api.summary();
    state = state.copyWith(summary: summary);
  }

  Future<void> _reloadVisits() async {
    final result = await _api.visits(
      search: state.visitSearch,
      status:
          state.visitStatusFilter.isEmpty ? null : state.visitStatusFilter,
      overdue: state.overdueOnly,
    );
    state = state.copyWith(
      visits: result.data,
      visitSummary: result.summary,
    );
  }

  Future<void> _reloadPlants() async {
    final plants = await _api.plants(
      search: state.plantSearch,
      amc: state.plantAmcFilter.isEmpty ? null : state.plantAmcFilter,
    );
    state = state.copyWith(plants: plants);
  }

  void setTab(AmcHomeTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
  }

  Future<void> setVisitSearch(String value) async {
    state = state.copyWith(visitSearch: value);
    try {
      await _reloadVisits();
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<void> setPlantSearch(String value) async {
    state = state.copyWith(plantSearch: value);
    try {
      await _reloadPlants();
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<void> setVisitStatusFilter(String value) async {
    state = state.copyWith(
      visitStatusFilter: value,
      overdueOnly: value.isEmpty ? state.overdueOnly : false,
    );
    try {
      await _reloadVisits();
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<void> setOverdueOnly(bool value) async {
    state = state.copyWith(
      overdueOnly: value,
      visitStatusFilter: value ? '' : state.visitStatusFilter,
    );
    try {
      await _reloadVisits();
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<void> setPlantAmcFilter(String value) async {
    state = state.copyWith(plantAmcFilter: value);
    try {
      await _reloadPlants();
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<AmcPlant> startAmc(Map<String, dynamic> body) async {
    final plant = await _api.startContract(body);
    await refresh();
    return plant;
  }

  Future<AmcPlant> renewAmc(String contractId) async {
    final plant = await _api.renewContract(contractId);
    await refresh();
    return plant;
  }

  Future<AmcVisit> createExtraVisit(Map<String, dynamic> body) async {
    final visit = await _api.createVisit(body);
    await refresh();
    return visit;
  }

  Future<void> removeVisit(String id) async {
    await _api.removeVisit(id);
    await refresh();
  }
}

final amcHomeProvider =
    NotifierProvider<AmcHomeNotifier, AmcHomeState>(AmcHomeNotifier.new);

final amcVisitDetailProvider =
    FutureProvider.autoDispose.family<AmcVisit, String>((ref, id) async {
  return ref.watch(amcApiServiceProvider).visit(id);
});

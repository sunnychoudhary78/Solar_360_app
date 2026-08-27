import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/support/data/support_api_service.dart';
import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final supportApiServiceProvider = Provider<SupportApiService>((ref) {
  return SupportApiService(ref.watch(apiServiceProvider));
});

enum SupportTicketTab { newRequests, all }

class SupportTicketListState {
  final List<SupportTicketModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final String statusFilter;
  final String priorityFilter;
  final String categoryFilter;
  final SupportTicketTab tab;
  final SupportTicketCounts counts;
  final String? error;
  final int page;

  const SupportTicketListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.statusFilter = '',
    this.priorityFilter = '',
    this.categoryFilter = '',
    this.tab = SupportTicketTab.newRequests,
    this.counts = const SupportTicketCounts(),
    this.error,
    this.page = 0,
  });

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      statusFilter.isNotEmpty ||
      priorityFilter.isNotEmpty ||
      categoryFilter.isNotEmpty;

  SupportTicketListState copyWith({
    List<SupportTicketModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? statusFilter,
    String? priorityFilter,
    String? categoryFilter,
    SupportTicketTab? tab,
    SupportTicketCounts? counts,
    String? error,
    int? page,
    bool clearError = false,
  }) {
    return SupportTicketListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      tab: tab ?? this.tab,
      counts: counts ?? this.counts,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class SupportTicketListNotifier extends Notifier<SupportTicketListState> {
  Timer? _debounce;

  @override
  SupportTicketListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const SupportTicketListState(isLoading: true);
  }

  SupportApiService get _api => ref.read(supportApiServiceProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final ticketsFuture = _loadTickets(page: 1);
      final countsFuture = _loadCounts();
      final tickets = await ticketsFuture;
      final counts = await countsFuture;
      state = state.copyWith(
        items: tickets.data,
        isLoading: false,
        hasMore: tickets.hasMore,
        page: tickets.page,
        counts: counts,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<({List<SupportTicketModel> data, bool hasMore, int page})>
  _loadTickets({required int page}) async {
    final search = state.search;
    final priority = state.priorityFilter;
    final category = state.categoryFilter;

    if (state.tab == SupportTicketTab.newRequests &&
        state.statusFilter.isEmpty) {
      final open = await _api.list(
        search: search,
        status: 'open',
        priority: priority,
        category: category,
        page: 1,
        limit: 50,
      );
      final raised = await _api.list(
        search: search,
        status: 'complaint_raised',
        priority: priority,
        category: category,
        page: 1,
        limit: 50,
      );
      final merged = <String, SupportTicketModel>{};
      for (final ticket in [...raised.data, ...open.data]) {
        merged[ticket.id] = ticket;
      }
      final items = merged.values.toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      return (data: items, hasMore: false, page: 1);
    }

    final result = await _api.list(
      search: search,
      status: state.statusFilter,
      priority: priority,
      category: category,
      page: page,
    );
    return (data: result.data, hasMore: result.hasMore, page: result.page);
  }

  Future<SupportTicketCounts> _loadCounts() async {
    try {
      final totals = await Future.wait([
        _api.count(),
        _api.count(status: 'complaint_raised'),
        _api.count(status: 'open'),
        _api.count(status: 'resolved'),
        _api.count(status: 'closed'),
      ]);
      return SupportTicketCounts(
        total: totals[0],
        complaintRaised: totals[1],
        open: totals[2],
        resolved: totals[3],
        closed: totals[4],
      );
    } catch (_) {
      return state.counts;
    }
  }

  Future<void> loadMore() async {
    if (state.tab == SupportTicketTab.newRequests &&
        state.statusFilter.isEmpty) {
      return;
    }
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _loadTickets(page: nextPage);
      state = state.copyWith(
        items: [...state.items, ...result.data],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: result.page,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: cleanError(e));
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  void setTab(SupportTicketTab tab) {
    if (state.tab == tab && state.statusFilter.isEmpty) return;
    state = state.copyWith(tab: tab, statusFilter: '');
    refresh();
  }

  void setStatusFilter(String status) {
    if (status.isEmpty) {
      setTab(SupportTicketTab.all);
      return;
    }
    state = state.copyWith(tab: SupportTicketTab.all, statusFilter: status);
    refresh();
  }

  void setPriorityFilter(String priority) {
    state = state.copyWith(priorityFilter: priority);
    refresh();
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(categoryFilter: category);
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(
      search: '',
      statusFilter: '',
      priorityFilter: '',
      categoryFilter: '',
    );
    refresh();
  }
}

final supportTicketListProvider =
    NotifierProvider<SupportTicketListNotifier, SupportTicketListState>(
      SupportTicketListNotifier.new,
    );

final supportTicketDetailProvider = FutureProvider.autoDispose
    .family<SupportTicketModel, String>((ref, id) {
      return ref.watch(supportApiServiceProvider).getById(id);
    });

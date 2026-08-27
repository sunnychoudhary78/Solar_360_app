import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/customer_portal/data/customer_portal_api_service.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/features/leads/data/lead_api_service.dart';
import 'package:solar_sales/features/leads/data/lead_repository.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final customerLeadApiServiceProvider = Provider<LeadApiService>((ref) {
  return LeadApiService(
    ref.watch(apiServiceProvider),
    ref.watch(dioClientProvider).dio,
    leadsPath: ApiEndpoints.customerLeads,
    leadPath: ApiEndpoints.customerLead,
  );
});

final customerLeadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(ref.watch(customerLeadApiServiceProvider));
});

final customerLeadsProvider = FutureProvider.autoDispose<List<LeadModel>>((
  ref,
) {
  return ref.watch(customerLeadRepositoryProvider).getAllLeads();
});

final customerPortalApiServiceProvider = Provider<CustomerPortalApiService>((
  ref,
) {
  return CustomerPortalApiService(ref.watch(apiServiceProvider));
});

class CustomerTicketListState {
  final List<SupportTicketModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final String statusFilter;
  final String priorityFilter;
  final String categoryFilter;
  final SupportTicketCounts counts;
  final String? error;
  final int page;

  const CustomerTicketListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.statusFilter = '',
    this.priorityFilter = '',
    this.categoryFilter = '',
    this.counts = const SupportTicketCounts(),
    this.error,
    this.page = 0,
  });

  bool get hasActiveFilters =>
      search.isNotEmpty ||
      statusFilter.isNotEmpty ||
      priorityFilter.isNotEmpty ||
      categoryFilter.isNotEmpty;

  CustomerTicketListState copyWith({
    List<SupportTicketModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? statusFilter,
    String? priorityFilter,
    String? categoryFilter,
    SupportTicketCounts? counts,
    String? error,
    int? page,
    bool clearError = false,
  }) {
    return CustomerTicketListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      counts: counts ?? this.counts,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class CustomerTicketListNotifier extends Notifier<CustomerTicketListState> {
  Timer? _debounce;

  @override
  CustomerTicketListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const CustomerTicketListState(isLoading: true);
  }

  CustomerPortalApiService get _api =>
      ref.read(customerPortalApiServiceProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _api.listTickets(
        search: state.search,
        status: state.statusFilter,
        priority: state.priorityFilter,
        category: state.categoryFilter,
        page: 1,
      );
      SupportTicketCounts counts;
      try {
        counts = await _loadCounts();
      } catch (_) {
        counts = state.counts;
      }
      state = state.copyWith(
        items: result.data,
        isLoading: false,
        hasMore: result.hasMore,
        page: result.page,
        counts: counts,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<SupportTicketCounts> _loadCounts() async {
    SupportTicketCounts dashboard = const SupportTicketCounts();
    try {
      dashboard = await _api.dashboard();
    } catch (_) {}
    final totals = await Future.wait([
      _api.countTickets(),
      _api.countTickets(status: 'complaint_raised'),
      _api.countTickets(status: 'open'),
      _api.countTickets(status: 'resolved'),
      _api.countTickets(status: 'closed'),
    ]);
    return dashboard.merge(
      SupportTicketCounts(
        total: totals[0],
        complaintRaised: totals[1],
        open: totals[2],
        resolved: totals[3],
        closed: totals[4],
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _api.listTickets(
        search: state.search,
        status: state.statusFilter,
        priority: state.priorityFilter,
        category: state.categoryFilter,
        page: nextPage,
      );
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

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
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

final customerTicketsProvider =
    NotifierProvider<CustomerTicketListNotifier, CustomerTicketListState>(
      CustomerTicketListNotifier.new,
    );

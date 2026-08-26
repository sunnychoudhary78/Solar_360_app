import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/support/data/support_api_service.dart';
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
  final SupportTicketTab tab;
  final String? error;
  final int page;

  const SupportTicketListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.tab = SupportTicketTab.newRequests,
    this.error,
    this.page = 0,
  });

  SupportTicketListState copyWith({
    List<SupportTicketModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    SupportTicketTab? tab,
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
      tab: tab ?? this.tab,
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
      if (state.tab == SupportTicketTab.newRequests) {
        final open = await _api.list(
          search: state.search,
          status: 'open',
          page: 1,
          limit: 50,
        );
        final raised = await _api.list(
          search: state.search,
          status: 'complaint_raised',
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
        state = state.copyWith(
          items: items,
          isLoading: false,
          hasMore: false,
          page: 1,
          clearError: true,
        );
        return;
      }

      final result = await _api.list(search: state.search, page: 1);
      state = state.copyWith(
        items: result.data,
        isLoading: false,
        hasMore: result.hasMore,
        page: result.page,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  Future<void> loadMore() async {
    if (state.tab == SupportTicketTab.newRequests) return;
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _api.list(
        search: state.search,
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

  void setTab(SupportTicketTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
    refresh();
  }
}

final supportTicketListProvider =
    NotifierProvider<SupportTicketListNotifier, SupportTicketListState>(
  SupportTicketListNotifier.new,
);

final supportTicketDetailProvider =
    FutureProvider.autoDispose.family<SupportTicketModel, String>((ref, id) {
  return ref.watch(supportApiServiceProvider).getById(id);
});

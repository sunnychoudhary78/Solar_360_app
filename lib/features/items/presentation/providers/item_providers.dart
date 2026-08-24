import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/item_api_service.dart';
import '../../data/item_repository.dart';
import '../../data/models/item_model.dart';

final itemApiServiceProvider = Provider<ItemApiService>((ref) {
  return ItemApiService(ref.watch(apiServiceProvider));
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.watch(itemApiServiceProvider));
});

class ItemListState {
  final List<ItemModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final String? status;
  final String? error;
  final int page;

  const ItemListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.status,
    this.error,
    this.page = 0,
  });

  ItemListState copyWith({
    List<ItemModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? status,
    String? error,
    int? page,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return ItemListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class ItemListNotifier extends Notifier<ItemListState> {
  Timer? _debounce;

  @override
  ItemListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const ItemListState(isLoading: true);
  }

  ItemRepository get _repo => ref.read(itemRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _repo.list(
        search: state.search,
        status: state.status,
        page: 1,
      );
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
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.list(
        search: state.search,
        status: state.status,
        page: state.page + 1,
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

  void setStatus(String? status) {
    state = state.copyWith(
      status: status,
      clearStatus: status == null,
    );
    refresh();
  }
}

final itemListProvider = NotifierProvider<ItemListNotifier, ItemListState>(
  ItemListNotifier.new,
);

final itemDetailProvider =
    FutureProvider.family<ItemModel, String>((ref, id) async {
  return ref.watch(itemRepositoryProvider).getById(id);
});

/// Approved, active items for quotation/invoice/stock pickers.
/// Hidden/deactivated items are excluded so they never appear in dropdowns.
final approvedItemsProvider = FutureProvider.autoDispose<List<ItemModel>>((
  ref,
) async {
  final items = await ref.watch(itemRepositoryProvider).listApproved();
  return items.where((item) => item.isActive).toList();
});

final stockableItemsProvider = FutureProvider.autoDispose<List<ItemModel>>((
  ref,
) async {
  final items = await ref.watch(itemRepositoryProvider).listStockable();
  return items.where((item) => item.isActive).toList();
});

final pendingItemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  return ref.watch(itemRepositoryProvider).pendingApprovals();
});

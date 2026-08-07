import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/customer_api_service.dart';
import '../../data/customer_repository.dart';
import '../../data/models/customer_model.dart';

final customerApiServiceProvider = Provider<CustomerApiService>((ref) {
  return CustomerApiService(ref.watch(apiServiceProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(customerApiServiceProvider));
});

class CustomerListState {
  final List<CustomerModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final String? error;
  final int page;

  const CustomerListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.error,
    this.page = 0,
  });

  CustomerListState copyWith({
    List<CustomerModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? error,
    int? page,
    bool clearError = false,
  }) {
    return CustomerListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class CustomerListNotifier extends Notifier<CustomerListState> {
  Timer? _debounce;

  @override
  CustomerListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const CustomerListState(isLoading: true);
  }

  CustomerRepository get _repo => ref.read(customerRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _repo.list(search: state.search, page: 1);
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
      final nextPage = state.page + 1;
      final result = await _repo.list(search: state.search, page: nextPage);
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
}

final customerListProvider =
    NotifierProvider<CustomerListNotifier, CustomerListState>(
  CustomerListNotifier.new,
);

final customerDetailProvider =
    FutureProvider.family<CustomerModel, String>((ref, id) async {
  return ref.watch(customerRepositoryProvider).getById(id);
});

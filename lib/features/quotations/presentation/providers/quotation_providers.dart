import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/quotation_model.dart';
import '../../data/quotation_api_service.dart';
import '../../data/quotation_repository.dart';

final quotationApiServiceProvider = Provider<QuotationApiService>((ref) {
  return QuotationApiService(ref.watch(apiServiceProvider));
});

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  return QuotationRepository(ref.watch(quotationApiServiceProvider));
});

class QuotationListState {
  final List<QuotationModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? status;
  final String? error;
  final int page;

  const QuotationListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.status,
    this.error,
    this.page = 0,
  });

  QuotationListState copyWith({
    List<QuotationModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? status,
    String? error,
    int? page,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return QuotationListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      status: clearStatus ? null : (status ?? this.status),
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class QuotationListNotifier extends Notifier<QuotationListState> {
  @override
  QuotationListState build() {
    Future.microtask(refresh);
    return const QuotationListState(isLoading: true);
  }

  QuotationRepository get _repo => ref.read(quotationRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _repo.list(status: state.status, page: 1);
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
      final result =
          await _repo.list(status: state.status, page: state.page + 1);
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

  void setStatus(String? status) {
    state = state.copyWith(status: status, clearStatus: status == null);
    refresh();
  }
}

final quotationListProvider =
    NotifierProvider<QuotationListNotifier, QuotationListState>(
  QuotationListNotifier.new,
);

final quotationDetailProvider =
    FutureProvider.autoDispose.family<QuotationModel, String>((ref, id) async {
  return ref.watch(quotationRepositoryProvider).getById(id);
});

final pendingQuotationsProvider =
    FutureProvider.autoDispose<List<QuotationModel>>((ref) async {
  return ref.watch(quotationRepositoryProvider).pendingApprovals();
});

final invoiceableQuotationsProvider =
    FutureProvider.autoDispose<List<QuotationModel>>((ref) async {
  return ref.watch(quotationRepositoryProvider).listInvoiceable();
});

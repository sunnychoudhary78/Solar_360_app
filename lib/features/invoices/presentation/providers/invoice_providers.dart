import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/invoice_api_service.dart';
import '../../data/invoice_repository.dart';
import '../../data/models/invoice_model.dart';

final invoiceApiServiceProvider = Provider<InvoiceApiService>((ref) {
  return InvoiceApiService(ref.watch(apiServiceProvider));
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(invoiceApiServiceProvider));
});

class InvoiceListState {
  final List<InvoiceModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? status;
  final String? error;
  final int page;

  const InvoiceListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.status,
    this.error,
    this.page = 0,
  });

  InvoiceListState copyWith({
    List<InvoiceModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? status,
    String? error,
    int? page,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return InvoiceListState(
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

class InvoiceListNotifier extends Notifier<InvoiceListState> {
  @override
  InvoiceListState build() {
    Future.microtask(refresh);
    return const InvoiceListState(isLoading: true);
  }

  InvoiceRepository get _repo => ref.read(invoiceRepositoryProvider);

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

final invoiceListProvider =
    NotifierProvider<InvoiceListNotifier, InvoiceListState>(
  InvoiceListNotifier.new,
);

final invoiceDetailProvider =
    FutureProvider.autoDispose.family<InvoiceModel, String>((ref, id) async {
  return ref.watch(invoiceRepositoryProvider).getById(id);
});

final pendingInvoicesProvider =
    FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  return ref.watch(invoiceRepositoryProvider).pendingApprovals();
});

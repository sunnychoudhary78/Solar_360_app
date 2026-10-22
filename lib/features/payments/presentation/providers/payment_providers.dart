import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/payment_models.dart';
import '../../data/payment_api_service.dart';
import '../../data/payment_repository.dart';

final paymentApiServiceProvider = Provider<PaymentApiService>((ref) {
  return PaymentApiService(ref.watch(apiServiceProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(paymentApiServiceProvider));
});

/// Permissions from §5 of the handoff.
const paymentReadPermissions = ['payment.read', 'invoice.read', 'lead.read'];
const paymentWritePermissions = [
  'payment.create',
  'payment.update',
  'invoice.create',
  'invoice.approve',
  'lead.update',
];
const paymentDeletePermissions = ['payment.delete', 'payment.update'];

final paymentDashboardProvider =
    FutureProvider.autoDispose<PaymentDashboardModel>((ref) async {
  return ref.watch(paymentRepositoryProvider).dashboard();
});

/// Milestones + roll-up for one invoice (used by the invoice payments block).
final invoicePaymentProvider =
    FutureProvider.autoDispose.family<InvoicePaymentBundle, String>(
  (ref, invoiceId) async {
    return ref.watch(paymentRepositoryProvider).forInvoice(invoiceId);
  },
);

class PaymentMilestoneListState {
  final List<PaymentScheduleModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? status;
  final String query;
  final String? error;
  final int page;

  const PaymentMilestoneListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.status,
    this.query = '',
    this.error,
    this.page = 0,
  });

  PaymentMilestoneListState copyWith({
    List<PaymentScheduleModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? status,
    String? query,
    String? error,
    int? page,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return PaymentMilestoneListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
    );
  }
}

class PaymentMilestoneListNotifier
    extends Notifier<PaymentMilestoneListState> {
  @override
  PaymentMilestoneListState build() {
    Future.microtask(refresh);
    return const PaymentMilestoneListState(isLoading: true);
  }

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _repo.list(
        status: state.status,
        q: state.query,
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
        status: state.status,
        q: state.query,
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

  void setStatus(String? status) {
    state = state.copyWith(status: status, clearStatus: status == null);
    refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    refresh();
  }
}

final paymentMilestoneListProvider =
    NotifierProvider<PaymentMilestoneListNotifier, PaymentMilestoneListState>(
  PaymentMilestoneListNotifier.new,
);

/// Invalidates every collections surface after a write.
void invalidatePaymentSurfaces(WidgetRef ref, {String? invoiceId}) {
  ref.invalidate(paymentDashboardProvider);
  ref.invalidate(paymentMilestoneListProvider);
  if (invoiceId != null && invoiceId.isNotEmpty) {
    ref.invalidate(invoicePaymentProvider(invoiceId));
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/payment_models.dart';
// PaymentScheduleStatus lives in payment_models.dart
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

/// Dashboard/list rows can arrive without paid_amount/receipts. For rows that
/// look unpaid, pull the per-invoice schedules (the same source the invoice
/// screen uses) and merge the real paid amount, balance and status.
Future<List<PaymentScheduleModel>> enrichPaidInfo(
  PaymentRepository repo,
  List<PaymentScheduleModel> list,
) async {
  final invoiceIds = list
      .where(
        (s) =>
            s.sourceId.isNotEmpty &&
            s.paidAmount <= 0.009 &&
            s.receipts.isEmpty,
      )
      .map((s) => s.sourceId)
      .toSet();
  if (invoiceIds.isEmpty) return list;

  final byInvoice = <String, Map<String, PaymentScheduleModel>>{};
  await Future.wait(
    invoiceIds.map((id) async {
      try {
        final bundle = await repo.forInvoice(id);
        byInvoice[id] = {for (final s in bundle.schedules) s.id: s};
      } catch (_) {
        // Keep the original row if the lookup fails.
      }
    }),
  );

  return list.map((s) {
    final fresh = byInvoice[s.sourceId]?[s.id];
    if (fresh == null) return s;
    return s.copyWith(
      amount: fresh.amount,
      paidAmount: fresh.paidAmount,
      balance: fresh.balance,
      status: fresh.status,
      isOverdue: fresh.isOverdue,
      daysOverdue: fresh.daysOverdue,
      receipts: fresh.receipts,
    );
  }).toList();
}

final paymentDashboardProvider =
    FutureProvider.autoDispose<PaymentDashboardModel>((ref) async {
      final repo = ref.watch(paymentRepositoryProvider);
      final d = await repo.dashboard();
      final results = await Future.wait([
        enrichPaidInfo(repo, d.topOverdue),
        enrichPaidInfo(repo, d.dueThisWeek),
      ]);
      return PaymentDashboardModel(
        collectedThisMonth: d.collectedThisMonth,
        outstanding: d.outstanding,
        overdueAmount: d.overdueAmount,
        overdueCount: d.overdueCount,
        dueThisWeekAmount: d.dueThisWeekAmount,
        dueThisWeekCount: d.dueThisWeekCount,
        paidCount: d.paidCount,
        partialCount: d.partialCount,
        pendingCount: d.pendingCount,
        aging: d.aging,
        topOverdue: results[0],
        dueThisWeek: results[1],
        recentPayments: d.recentPayments,
      );
    });

/// Milestones + roll-up for one invoice (used by the invoice payments block).
final invoicePaymentProvider = FutureProvider.autoDispose
    .family<InvoicePaymentBundle, String>((ref, invoiceId) async {
      return ref.watch(paymentRepositoryProvider).forInvoice(invoiceId);
    });

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

class PaymentMilestoneListNotifier extends Notifier<PaymentMilestoneListState> {
  @override
  PaymentMilestoneListState build() {
    Future.microtask(refresh);
    return const PaymentMilestoneListState(isLoading: true);
  }

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  /// "Partial" is derived on the client too (paid > 0 and balance > 0), because
  /// the server can leave a part-paid milestone flagged pending/overdue. For
  /// that filter we pull every page unfiltered, enrich, and keep the partial ones.
  Future<({List<PaymentScheduleModel> items, bool hasMore, int page})>
  _fetchPage(int page) async {
    final status = state.status;
    if (status == PaymentScheduleStatus.partial) {
      final out = <PaymentScheduleModel>[];
      var p = 1;
      var more = true;
      while (more && p <= 30) {
        final r = await _repo.list(status: null, q: state.query, page: p);
        final enriched = await enrichPaidInfo(_repo, r.data);
        out.addAll(
          enriched.where((s) => s.status == PaymentScheduleStatus.partial),
        );
        more = r.hasMore;
        p++;
      }
      return (items: out, hasMore: false, page: p - 1);
    }
    final r = await _repo.list(status: status, q: state.query, page: page);
    final enriched = await enrichPaidInfo(_repo, r.data);
    final items = status == PaymentScheduleStatus.pending
        // exclude milestones that already have a part payment
        ? enriched
              .where((s) => s.status != PaymentScheduleStatus.partial)
              .toList()
        : enriched;
    return (items: items, hasMore: r.hasMore, page: r.page);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _fetchPage(1);
      state = state.copyWith(
        items: result.items,
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
      final result = await _fetchPage(state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...result.items],
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
// void invalidatePaymentSurfaces(WidgetRef ref, {String? invoiceId}) {
//   ref.invalidate(paymentDashboardProvider);
//   ref.invalidate(paymentMilestoneListProvider);
//   if (invoiceId != null && invoiceId.isNotEmpty) {
//     ref.invalidate(invoicePaymentProvider(invoiceId));
//   }
// }

/// Partial = some amount received, balance still remaining
/// (also counts part-paid milestones that are overdue).
final paymentPartialCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final repo = ref.watch(paymentRepositoryProvider);
  var count = 0;
  var page = 1;
  var more = true;
  while (more && page <= 30) {
    final r = await repo.list(status: null, q: '', page: page);
    final enriched = await enrichPaidInfo(repo, r.data);
    count += enriched
        .where((s) => s.paidAmount > 0.009 && s.balance > 0.009)
        .length;
    more = r.hasMore;
    page++;
  }
  return count;
});

void invalidatePaymentSurfaces(WidgetRef ref, {String? invoiceId}) {
  ref.invalidate(paymentDashboardProvider);
  ref.invalidate(paymentPartialCountProvider); // <-- add
  ref.invalidate(paymentMilestoneListProvider);
  if (invoiceId != null && invoiceId.isNotEmpty) {
    ref.invalidate(invoicePaymentProvider(invoiceId));
  }
}

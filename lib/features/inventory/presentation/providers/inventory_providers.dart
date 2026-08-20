import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/inventory_api_service.dart';
import '../../data/inventory_repository.dart';
import '../../data/models/inventory_models.dart';

final inventoryApiServiceProvider = Provider<InventoryApiService>((ref) {
  return InventoryApiService(ref.watch(apiServiceProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(inventoryApiServiceProvider));
});

final warehousesProvider = FutureProvider<List<WarehouseModel>>((ref) async {
  return ref.watch(inventoryRepositoryProvider).listWarehouses();
});

/// Management list includes deactivated warehouses so they can be reactivated.
final managedWarehousesProvider =
    FutureProvider<List<WarehouseModel>>((ref) async {
  return ref
      .watch(inventoryRepositoryProvider)
      .listWarehouses(includeInactive: true);
});

void invalidateWarehouseProviders(WidgetRef ref) {
  ref.invalidate(warehousesProvider);
  ref.invalidate(managedWarehousesProvider);
}

final lowStockProvider = FutureProvider<List<StockModel>>((ref) async {
  return ref.watch(inventoryRepositoryProvider).getLowStock();
});

class StockListState {
  final List<StockModel> items;
  final bool isLoading;
  final String? warehouseId;
  final bool lowStockOnly;
  final String? error;

  const StockListState({
    this.items = const [],
    this.isLoading = false,
    this.warehouseId,
    this.lowStockOnly = false,
    this.error,
  });

  StockListState copyWith({
    List<StockModel>? items,
    bool? isLoading,
    String? warehouseId,
    bool? lowStockOnly,
    String? error,
    bool clearError = false,
    bool clearWarehouse = false,
  }) {
    return StockListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class StockListNotifier extends Notifier<StockListState> {
  @override
  StockListState build() {
    Future.microtask(refresh);
    return const StockListState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(inventoryRepositoryProvider).getStock(
            warehouseId: state.warehouseId,
            lowStockOnly: state.lowStockOnly ? true : null,
          );
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  void setWarehouse(String? id) {
    state = state.copyWith(warehouseId: id, clearWarehouse: id == null);
    refresh();
  }

  void setLowStockOnly(bool value) {
    state = state.copyWith(lowStockOnly: value);
    refresh();
  }
}

final stockListProvider = NotifierProvider<StockListNotifier, StockListState>(
  StockListNotifier.new,
);

class LedgerListState {
  final List<StockTransactionModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int page;
  final String? warehouseId;
  final String? itemId;
  final String? transType;
  final String? invoiceNumber;

  const LedgerListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
    this.warehouseId,
    this.itemId,
    this.transType,
    this.invoiceNumber,
  });

  LedgerListState copyWith({
    List<StockTransactionModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? page,
    String? warehouseId,
    String? itemId,
    String? transType,
    String? invoiceNumber,
    bool clearError = false,
    bool clearWarehouse = false,
    bool clearItem = false,
    bool clearTransType = false,
    bool clearInvoiceNumber = false,
  }) {
    return LedgerListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      warehouseId:
          clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      itemId: clearItem ? null : (itemId ?? this.itemId),
      transType: clearTransType ? null : (transType ?? this.transType),
      invoiceNumber: clearInvoiceNumber
          ? null
          : (invoiceNumber ?? this.invoiceNumber),
    );
  }
}

class LedgerListNotifier extends Notifier<LedgerListState> {
  @override
  LedgerListState build() {
    Future.microtask(refresh);
    return const LedgerListState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await ref.read(inventoryRepositoryProvider).getLedger(
            page: 1,
            warehouseId: state.warehouseId,
            itemId: state.itemId,
            transType: state.transType,
            invoiceNumber: state.invoiceNumber,
          );
      final items = await _enrichTransferCompanions(result.data);
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: result.hasMore,
        page: result.page,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanError(e));
    }
  }

  void setWarehouse(String? id) {
    state = state.copyWith(
      warehouseId: id,
      clearWarehouse: id == null,
    );
    refresh();
  }

  void setItem(String? id) {
    state = state.copyWith(itemId: id, clearItem: id == null);
    refresh();
  }

  void setTransType(String? type) {
    state = state.copyWith(transType: type, clearTransType: type == null);
    refresh();
  }

  void setInvoiceNumber(String? value) {
    final trimmed = value?.trim();
    state = state.copyWith(
      invoiceNumber: trimmed?.isEmpty == true ? null : trimmed,
      clearInvoiceNumber: trimmed == null || (trimmed.isEmpty),
    );
    refresh();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await ref
          .read(inventoryRepositoryProvider)
          .getLedger(
            page: state.page + 1,
            warehouseId: state.warehouseId,
            itemId: state.itemId,
            transType: state.transType,
            invoiceNumber: state.invoiceNumber,
          );
      final pageItems = await _enrichTransferCompanions(result.data);
      final existingIds = {for (final tx in state.items) tx.id};
      state = state.copyWith(
        items: [
          ...state.items,
          ...pageItems.where((tx) => !existingIds.contains(tx.id)),
        ],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: result.page,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: cleanError(e));
    }
  }

  /// Destination side of a transfer is stored as `trans_type = in` with the
  /// same transfer reference number. When the TRANSFER filter is on, those
  /// rows are omitted by the API, so we load recent `in` rows and keep the
  /// ones that share a transfer reference.
  ///
  /// Note: searching by `invoiceNumber` cannot be used here — the API only
  /// matches `reference_type = invoice`, which excludes transfer refs.
  Future<List<StockTransactionModel>> _enrichTransferCompanions(
    List<StockTransactionModel> items,
  ) async {
    final transfers = items
        .where((tx) => tx.transType.toLowerCase() == 'transfer')
        .toList();
    if (transfers.isEmpty) return items;

    final neededRefs = <String>{};
    for (final tx in transfers) {
      final ref = tx.referenceNumber?.trim();
      if (ref == null || ref.isEmpty) continue;

      final hasCompanion = items.any(
        (candidate) =>
            candidate.id != tx.id &&
            candidate.itemId == tx.itemId &&
            candidate.warehouseId != tx.warehouseId &&
            candidate.referenceNumber?.trim() == ref &&
            (candidate.transType.toLowerCase() == 'in' ||
                candidate.transType.toLowerCase() == 'transfer'),
      );
      if (!hasCompanion) neededRefs.add(ref);
    }

    if (neededRefs.isEmpty) return items;

    final repo = ref.read(inventoryRepositoryProvider);
    final byId = <String, StockTransactionModel>{
      for (final tx in items) tx.id: tx,
    };
    final foundRefs = <String>{};

    // Pull recent stock-in pages until every transfer ref is matched (cap pages).
    for (var page = 1; page <= 5 && foundRefs.length < neededRefs.length; page++) {
      final inPage = await repo.getLedger(
        page: page,
        limit: 50,
        itemId: state.itemId,
        transType: 'in',
      );

      for (final row in inPage.data) {
        final ref = row.referenceNumber?.trim();
        if (ref == null || ref.isEmpty || !neededRefs.contains(ref)) continue;

        final linkedToTransfer =
            row.referenceType?.toLowerCase() == 'transfer' ||
            ref.toUpperCase().startsWith('TRF-') ||
            (row.notes?.toLowerCase().contains('(in)') ?? false);
        if (!linkedToTransfer) continue;

        byId.putIfAbsent(row.id, () => row);
        foundRefs.add(ref);
      }

      if (!inPage.hasMore) break;
    }

    return byId.values.toList();
  }
}

final ledgerListProvider =
    NotifierProvider<LedgerListNotifier, LedgerListState>(
  LedgerListNotifier.new,
);

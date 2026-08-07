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
}

final ledgerListProvider =
    NotifierProvider<LedgerListNotifier, LedgerListState>(
  LedgerListNotifier.new,
);

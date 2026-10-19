import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/customers/data/customer_repository.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/items/data/item_repository.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';

import '../../data/costing_api_service.dart';
import '../../data/costing_repositry.dart';
import '../../data/models/costing_model.dart';

final costingApiServiceProvider = Provider<CostingApiService>((ref) {
  return CostingApiService(ref.watch(apiServiceProvider));
});

final costingRepositoryProvider = Provider<CostingRepository>((ref) {
  return CostingRepository(ref.watch(costingApiServiceProvider));
});

class CostingState {
  final List<CustomerModel> customers;
  final List<ItemModel> items;
  final String? selectedCustomerId;
  final CostingSheet? sheet;
  final bool isLoadingCatalogs;
  final bool isLoadingSheet;
  final bool isMutating;
  final String? catalogError;

  const CostingState({
    this.customers = const [],
    this.items = const [],
    this.selectedCustomerId,
    this.sheet,
    this.isLoadingCatalogs = true,
    this.isLoadingSheet = false,
    this.isMutating = false,
    this.catalogError,
  });

  CostingState copyWith({
    List<CustomerModel>? customers,
    List<ItemModel>? items,
    String? selectedCustomerId,
    CostingSheet? sheet,
    bool? isLoadingCatalogs,
    bool? isLoadingSheet,
    bool? isMutating,
    String? catalogError,
    bool clearCustomer = false,
    bool clearSheet = false,
    bool clearCatalogError = false,
  }) {
    return CostingState(
      customers: customers ?? this.customers,
      items: items ?? this.items,
      selectedCustomerId: clearCustomer
          ? null
          : (selectedCustomerId ?? this.selectedCustomerId),
      sheet: clearSheet ? null : (sheet ?? this.sheet),
      isLoadingCatalogs: isLoadingCatalogs ?? this.isLoadingCatalogs,
      isLoadingSheet: isLoadingSheet ?? this.isLoadingSheet,
      isMutating: isMutating ?? this.isMutating,
      catalogError: clearCatalogError
          ? null
          : (catalogError ?? this.catalogError),
    );
  }
}

class CostingNotifier extends Notifier<CostingState> {
  int _selectionVersion = 0;

  CustomerRepository get _customerRepository =>
      ref.read(customerRepositoryProvider);
  ItemRepository get _itemRepository => ref.read(itemRepositoryProvider);
  CostingRepository get _repository => ref.read(costingRepositoryProvider);

  @override
  CostingState build() {
    Future.microtask(loadCatalogs);
    return const CostingState();
  }

  Future<void> loadCatalogs() async {
    state = state.copyWith(isLoadingCatalogs: true, clearCatalogError: true);
    try {
      final customersFuture = _customerRepository.list(limit: 100);
      final itemsFuture = _itemRepository.listApproved();
      final customers = await customersFuture;
      final items = await itemsFuture;
      state = state.copyWith(
        customers: customers.data,
        items: items.where((item) => item.isActive).toList(),
        isLoadingCatalogs: false,
        clearCatalogError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingCatalogs: false,
        catalogError: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> selectCustomer(String? customerId) async {
    final version = ++_selectionVersion;
    if (customerId == null || customerId.isEmpty) {
      state = state.copyWith(
        clearCustomer: true,
        clearSheet: true,
        isLoadingSheet: false,
      );
      return;
    }

    state = state.copyWith(
      selectedCustomerId: customerId,
      clearSheet: true,
      isLoadingSheet: true,
    );
    try {
      final sheet = await _repository.getForCustomer(customerId);
      if (version == _selectionVersion) {
        state = state.copyWith(sheet: sheet, isLoadingSheet: false);
      }
    } catch (_) {
      if (version == _selectionVersion) {
        state = state.copyWith(clearSheet: true, isLoadingSheet: false);
      }
      rethrow;
    }
  }

  Future<void> addCatalogLine({
    required String itemId,
    required double unitPrice,
    required double quantity,
  }) async {
    final customerId = state.selectedCustomerId;
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Select a customer first');
    }
    await _mutate(
      customerId,
      () => _repository.addLine(customerId, {
        'kind': 'catalog',
        'item_id': itemId,
        'unit_price': unitPrice,
        'quantity': quantity,
      }),
    );
  }

  Future<void> addCustomLine({
    required String name,
    required double unitPrice,
    required double quantity,
  }) async {
    final customerId = state.selectedCustomerId;
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Select a customer first');
    }
    await _mutate(
      customerId,
      () => _repository.addLine(customerId, {
        'kind': 'custom',
        'name': name,
        'unit_price': unitPrice,
        'quantity': quantity,
      }),
    );
  }

  Future<void> removeLine(String lineId) async {
    final sheet = state.sheet;
    if (sheet == null) return;
    await _mutate(
      sheet.customerId,
      () => _repository.removeLine(sheet.id, lineId),
    );
  }

  Future<void> clearLines() async {
    final sheet = state.sheet;
    if (sheet == null) return;
    await _mutate(sheet.customerId, () => _repository.clear(sheet.id));
  }

  Future<Uint8List> downloadPdf() async {
    final sheet = state.sheet;
    if (sheet == null || sheet.items.isEmpty) {
      throw StateError('There are no costing items to download');
    }
    return _repository.downloadPdf(sheet.id);
  }

  Future<void> _mutate(
    String customerId,
    Future<CostingSheet> Function() operation,
  ) async {
    if (state.isMutating) {
      throw StateError('A costing update is already in progress');
    }
    state = state.copyWith(isMutating: true);
    try {
      final updatedSheet = await operation();
      if (state.selectedCustomerId == customerId) {
        state = state.copyWith(sheet: updatedSheet);
      }
    } finally {
      state = state.copyWith(isMutating: false);
    }
  }
}

final costingProvider = NotifierProvider<CostingNotifier, CostingState>(
  CostingNotifier.new,
);

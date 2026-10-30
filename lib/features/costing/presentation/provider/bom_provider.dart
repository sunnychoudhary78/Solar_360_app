import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/costing_repositry.dart';
import '../../data/models/costing_model.dart';
import 'costing_provider.dart';

/// Bill-of-materials draft form state (`Billbook only`).
///
/// Materials are held locally and only sent to the server on **Save BOM**.
class BomState {
  final List<CustomerModel> customers;
  final List<ItemModel> items;

  /// Existing project id — null until the first successful create.
  final String? bomId;
  final String? customerId;
  final String projectName;
  final List<BomLine> lines;
  final bool dirty;

  final bool canReadBom;
  final bool canCreateBom;
  final bool canUseCatalog;
  final bool isLoadingLookups;
  final bool isLoadingBom;
  final bool isSaving;
  final String? error;

  const BomState({
    this.customers = const [],
    this.items = const [],
    this.bomId,
    this.customerId,
    this.projectName = '',
    this.lines = const [],
    this.dirty = false,
    this.canReadBom = false,
    this.canCreateBom = false,
    this.canUseCatalog = false,
    this.isLoadingLookups = true,
    this.isLoadingBom = false,
    this.isSaving = false,
    this.error,
  });

  /// A saved, clean project with at least one material can produce a PDF.
  bool get canDownloadPdf =>
      bomId != null && bomId!.isNotEmpty && !dirty && lines.isNotEmpty;

  BomState copyWith({
    List<CustomerModel>? customers,
    List<ItemModel>? items,
    String? bomId,
    String? customerId,
    String? projectName,
    List<BomLine>? lines,
    bool? dirty,
    bool? canReadBom,
    bool? canCreateBom,
    bool? canUseCatalog,
    bool? isLoadingLookups,
    bool? isLoadingBom,
    bool? isSaving,
    String? error,
    bool clearBomId = false,
    bool clearCustomer = false,
    bool clearError = false,
  }) {
    return BomState(
      customers: customers ?? this.customers,
      items: items ?? this.items,
      bomId: clearBomId ? null : (bomId ?? this.bomId),
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      projectName: projectName ?? this.projectName,
      lines: lines ?? this.lines,
      dirty: dirty ?? this.dirty,
      canReadBom: canReadBom ?? this.canReadBom,
      canCreateBom: canCreateBom ?? this.canCreateBom,
      canUseCatalog: canUseCatalog ?? this.canUseCatalog,
      isLoadingLookups: isLoadingLookups ?? this.isLoadingLookups,
      isLoadingBom: isLoadingBom ?? this.isLoadingBom,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BomNotifier extends Notifier<BomState> {
  CostingRepository get _repository => ref.read(costingRepositoryProvider);

  @override
  BomState build() {
    final auth = ref.watch(authProvider);
    final canReadBom =
        auth.hasPermission('bom.read') || auth.hasPermission('bom.create');
    final canCreateBom = auth.hasPermission('bom.create');
    final canUseCatalog = auth.hasPermission('item.read');
    final initial = BomState(
      canReadBom: canReadBom,
      canCreateBom: canCreateBom,
      canUseCatalog: canUseCatalog,
      isLoadingLookups: canReadBom,
    );
    if (canReadBom) Future.microtask(loadLookups);
    return initial;
  }

  Future<void> loadLookups() async {
    final auth = ref.read(authProvider);
    state = state.copyWith(isLoadingLookups: true, clearError: true);
    try {
      final customersFuture = auth.hasPermission('customer.read')
          ? ref.read(customerRepositoryProvider).list(limit: 100)
          : null;
      final itemsFuture = state.canUseCatalog
          ? ref.read(itemRepositoryProvider).listApproved()
          : null;
      final customers = customersFuture == null ? null : await customersFuture;
      final items = itemsFuture == null ? null : await itemsFuture;
      state = state.copyWith(
        customers: customers?.data,
        items: items?.where((item) => item.isActive).toList(),
        isLoadingLookups: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingLookups: false,
        error: cleanError(error),
      );
    }
  }

  /// Resets the form for a brand-new project.
  void startNew() {
    state = state.copyWith(
      clearBomId: true,
      clearCustomer: true,
      projectName: '',
      lines: const [],
      dirty: false,
      isLoadingBom: false,
      clearError: true,
    );
  }

  Future<void> openBom(String bomId) async {
    state = state.copyWith(isLoadingBom: true, clearError: true);
    try {
      final bom = await _repository.getBom(bomId);
      state = state.copyWith(
        bomId: bom.id,
        projectName: bom.projectName,
        customerId: bom.customerId,
        lines: [...bom.items],
        dirty: false,
        isLoadingBom: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingBom: false,
        error: cleanError(error),
      );
    }
  }

  void setProjectName(String value) {
    state = state.copyWith(projectName: value, dirty: true);
  }

  void setCustomer(String? customerId) {
    state = state.copyWith(
      customerId: customerId,
      clearCustomer: customerId == null,
      dirty: true,
    );
  }

  void addLine(BomLine line) {
    state = state.copyWith(lines: [...state.lines, line], dirty: true);
  }

  void removeLineAt(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final next = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: next, dirty: true);
  }

  Future<void> save() async {
    if (state.isSaving) return;
    final projectName = state.projectName.trim();
    if (projectName.isEmpty) {
      throw StateError('Project name is required');
    }
    final customerId = state.customerId;
    if (customerId == null || customerId.isEmpty) {
      throw StateError('Select a customer');
    }
    final body = <String, dynamic>{
      'project_name': projectName,
      'customer_id': customerId,
      'items': [for (final line in state.lines) line.toPayload()],
    };
    state = state.copyWith(isSaving: true);
    try {
      final currentId = state.bomId;
      final saved = currentId == null || currentId.isEmpty
          ? await _repository.createBom(body)
          : await _repository.saveBom(currentId, body);
      state = state.copyWith(
        bomId: saved.id,
        projectName: saved.projectName,
        customerId: saved.customerId ?? customerId,
        lines: [...saved.items],
        dirty: false,
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<Uint8List> downloadPdf() async {
    if (state.dirty) {
      throw StateError('Save your changes before downloading the PDF');
    }
    final bomId = state.bomId;
    if (bomId == null || bomId.isEmpty || state.lines.isEmpty) {
      throw StateError('There are no materials to download');
    }
    return _repository.downloadBomPdf(bomId);
  }
}

final bomProvider = NotifierProvider<BomNotifier, BomState>(BomNotifier.new);

/// BOM project list (`GET /boms`) — Overview + project picker.
class BomListState {
  final List<BomListRow> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;
  final int total;
  final String? error;

  const BomListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.dateFrom,
    this.dateTo,
    this.page = 0,
    this.total = 0,
    this.error,
  });

  bool get hasFilters =>
      search.trim().isNotEmpty || dateFrom != null || dateTo != null;

  BomListState copyWith({
    List<BomListRow>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    int? total,
    String? error,
    bool clearError = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return BomListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      page: page ?? this.page,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BomListNotifier extends Notifier<BomListState> {
  static const int pageSize = 20;
  Timer? _debounce;

  @override
  BomListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const BomListState(isLoading: true);
  }

  CostingRepository get _repo => ref.read(costingRepositoryProvider);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _repo.listBoms(
        search: state.search,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        page: 1,
        limit: pageSize,
      );
      state = state.copyWith(
        items: result.data,
        total: result.total,
        isLoading: false,
        hasMore: result.hasMore,
        page: result.page,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: cleanError(error));
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listBoms(
        search: state.search,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        page: state.page + 1,
        limit: pageSize,
      );
      state = state.copyWith(
        items: [...state.items, ...result.data],
        total: result.total,
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: result.page,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: cleanError(error));
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  void setDateRange({DateTime? from, DateTime? to}) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
    );
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(
      search: '',
      clearDateFrom: true,
      clearDateTo: true,
    );
    refresh();
  }
}

final bomListProvider = NotifierProvider<BomListNotifier, BomListState>(
  BomListNotifier.new,
);

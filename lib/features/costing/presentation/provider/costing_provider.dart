import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customers/data/customer_repository.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/items/data/item_repository.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

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
  final List<CostingLead> leads;
  final List<ItemModel> items;
  final List<CostingVendor> vendors;
  final String? selectedPartyId;
  final CostingSheet? sheet;

  /// Local draft lines — only pushed to the server on **Save costing**.
  final List<CostingLine> lines;
  final bool dirty;
  final String? pendingVendorId;

  /// One-off vendor typed by the user that is NOT in the vendor list.
  /// Applies to this costing only and is never added to the Vendors tab.
  final CostingVendor? customVendor;
  final bool isGreenEnergyScreen;
  final bool canBillbook;
  final bool canSolar;
  final bool canReadCosting;
  final bool canCreateCosting;
  final bool canReadBom;
  final bool canCreateBom;
  final bool canUseCatalog;
  final bool canSelectVendor;
  final bool useLeadParty;
  final bool showBom;
  final bool isLoadingCatalogs;
  final bool isLoadingSheet;
  final bool isMutating;
  final String? catalogError;

  const CostingState({
    this.customers = const [],
    this.leads = const [],
    this.items = const [],
    this.vendors = const [],
    this.selectedPartyId,
    this.sheet,
    this.lines = const [],
    this.dirty = false,
    this.pendingVendorId,
    this.customVendor,
    this.isGreenEnergyScreen = false,
    this.canBillbook = false,
    this.canSolar = false,
    this.canReadCosting = false,
    this.canCreateCosting = false,
    this.canReadBom = false,
    this.canCreateBom = false,
    this.canUseCatalog = false,
    this.canSelectVendor = false,
    this.useLeadParty = false,
    this.showBom = false,
    this.isLoadingCatalogs = true,
    this.isLoadingSheet = false,
    this.isMutating = false,
    this.catalogError,
  });

  /// Draft vendor selection (falls back to the saved sheet's vendor).
  String? get vendorId => pendingVendorId ?? sheet?.vendorId;

  /// Sum of the local draft lines; the server total is authoritative after save.
  double get draftTotal =>
      lines.fold(0, (sum, line) => sum + line.unitPrice * line.quantity);

  CostingState copyWith({
    List<CustomerModel>? customers,
    List<CostingLead>? leads,
    List<ItemModel>? items,
    List<CostingVendor>? vendors,
    String? selectedPartyId,
    CostingSheet? sheet,
    List<CostingLine>? lines,
    bool? dirty,
    String? pendingVendorId,
    CostingVendor? customVendor,
    bool? isGreenEnergyScreen,
    bool? canBillbook,
    bool? canSolar,
    bool? canReadCosting,
    bool? canCreateCosting,
    bool? canReadBom,
    bool? canCreateBom,
    bool? canUseCatalog,
    bool? canSelectVendor,
    bool? useLeadParty,
    bool? showBom,
    bool? isLoadingCatalogs,
    bool? isLoadingSheet,
    bool? isMutating,
    String? catalogError,
    bool clearParty = false,
    bool clearSheet = false,
    bool clearPendingVendor = false,
    bool clearCustomVendor = false,
    bool clearCatalogError = false,
  }) {
    return CostingState(
      customers: customers ?? this.customers,
      leads: leads ?? this.leads,
      items: items ?? this.items,
      vendors: vendors ?? this.vendors,
      selectedPartyId: clearParty
          ? null
          : (selectedPartyId ?? this.selectedPartyId),
      sheet: clearSheet ? null : (sheet ?? this.sheet),
      lines: lines ?? this.lines,
      dirty: dirty ?? this.dirty,
      pendingVendorId: clearPendingVendor
          ? null
          : (pendingVendorId ?? this.pendingVendorId),
      customVendor: clearCustomVendor
          ? null
          : (customVendor ?? this.customVendor),
      isGreenEnergyScreen: isGreenEnergyScreen ?? this.isGreenEnergyScreen,
      canBillbook: canBillbook ?? this.canBillbook,
      canSolar: canSolar ?? this.canSolar,
      canReadCosting: canReadCosting ?? this.canReadCosting,
      canCreateCosting: canCreateCosting ?? this.canCreateCosting,
      canReadBom: canReadBom ?? this.canReadBom,
      canCreateBom: canCreateBom ?? this.canCreateBom,
      canUseCatalog: canUseCatalog ?? this.canUseCatalog,
      canSelectVendor: canSelectVendor ?? this.canSelectVendor,
      useLeadParty: useLeadParty ?? this.useLeadParty,
      showBom: showBom ?? this.showBom,
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
  CostingNotifier(this.isGreenEnergyScreen);

  final bool isGreenEnergyScreen;
  int _selectionVersion = 0;

  CustomerRepository get _customerRepository =>
      ref.read(customerRepositoryProvider);
  ItemRepository get _itemRepository => ref.read(itemRepositoryProvider);
  CostingRepository get _repository => ref.read(costingRepositoryProvider);

  @override
  CostingState build() {
    final auth = ref.watch(authProvider);
    final canBillbook =
        auth.companyModules.billbook &&
        (auth.isCompanyAdmin ||
            _hasAnyRole(auth.roles, _billbookRoles) ||
            auth.hasAny(_billbookPermissions));
    final canSolar =
        auth.companyModules.solar &&
        (auth.isCompanyAdmin ||
            _hasAnyRole(auth.roles, _solarRoles) ||
            auth.hasAny(_solarPermissions));
    final canReadCosting =
        auth.hasPermission('costing.read') ||
        auth.hasPermission('costing.create');
    final canCreateCosting = auth.hasPermission('costing.create');
    final canReadBom =
        auth.hasPermission('bom.read') || auth.hasPermission('bom.create');
    final canCreateBom = auth.hasPermission('bom.create');
    final useLeadParty = isGreenEnergyScreen && !canBillbook;
    final canUseCatalog = canBillbook && auth.hasPermission('item.read');
    final canSelectVendor = canBillbook;
    // BOM lives on the Billbook Costing & BOM screen only.
    final showBom = !isGreenEnergyScreen && canBillbook && canReadBom;

    final initial = CostingState(
      isGreenEnergyScreen: isGreenEnergyScreen,
      canBillbook: canBillbook,
      canSolar: canSolar,
      canReadCosting: canReadCosting,
      canCreateCosting: canCreateCosting,
      canReadBom: canReadBom,
      canCreateBom: canCreateBom,
      canUseCatalog: canUseCatalog,
      canSelectVendor: canSelectVendor,
      useLeadParty: useLeadParty,
      showBom: showBom,
      isLoadingCatalogs: canReadCosting,
    );
    if (canReadCosting) Future.microtask(loadCatalogs);
    return initial;
  }

  static const _billbookRoles = {
    'salesexecutive',
    'saleshead',
    'financeexecutive',
    'financehead',
    'procurementexecutive',
    'procurementhod',
  };
  static const _solarRoles = {
    'sales',
    'solarsales',
    'sales manager',
    'finance manager',
    'document administrator',
    'bank process',
    'finance user',
    'installation manager',
    'installation team',
    'material engineer',
    'electrical engineer',
  };
  static const List<String> _billbookPermissions = [
    'module.billbook.access',
    'item.read',
    'inventory.read',
    'quotation.read',
    'invoice.read',
    'report.read',
    'stats.read',
  ];
  static const List<String> _solarPermissions = [
    'module.solar.access',
    'lead.read',
    'leads.read',
    'closedlead.read',
    'installation.read',
    'dashboard.read',
  ];

  static bool _hasAnyRole(List<String> userRoles, Set<String> allowed) {
    return userRoles.any((role) => allowed.contains(role.trim().toLowerCase()));
  }

  Future<void> loadCatalogs() async {
    final snapshot = state;
    state = state.copyWith(isLoadingCatalogs: true, clearCatalogError: true);
    try {
      final customersFuture =
          !snapshot.useLeadParty && snapshot.canReadCosting && _canReadParty
          ? _customerRepository.list(limit: 100)
          : null;
      final leadsFuture =
          snapshot.useLeadParty && snapshot.canReadCosting && _canReadParty
          ? _repository.listLeads()
          : null;
      final itemsFuture = snapshot.canUseCatalog
          ? _itemRepository.listApproved()
          : null;
      final vendorsFuture = snapshot.canReadCosting
          ? _repository.listVendors()
          : null;

      final customers = customersFuture == null ? null : await customersFuture;
      final leads = leadsFuture == null ? null : await leadsFuture;
      final items = itemsFuture == null ? null : await itemsFuture;
      final vendors = vendorsFuture == null ? null : await vendorsFuture;
      state = state.copyWith(
        customers: customers?.data,
        leads: leads,
        items: items?.where((item) => item.isActive).toList(),
        vendors: vendors?.where((vendor) => vendor.isActive).toList(),
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

  bool get _canReadParty {
    final auth = ref.read(authProvider);
    return state.useLeadParty
        ? auth.hasPermission('lead.read')
        : auth.hasPermission('customer.read');
  }

  Future<void> selectParty(String? partyId) async {
    final version = ++_selectionVersion;
    if (partyId == null || partyId.isEmpty) {
      state = state.copyWith(
        clearParty: true,
        clearSheet: true,
        lines: const [],
        dirty: false,
        clearPendingVendor: true,
        clearCustomVendor: true,
        isLoadingSheet: false,
      );
      return;
    }

    state = state.copyWith(
      selectedPartyId: partyId,
      clearSheet: true,
      lines: const [],
      dirty: false,
      clearPendingVendor: true,
      clearCustomVendor: true,
      isLoadingSheet: true,
    );
    try {
      final sheet = state.useLeadParty
          ? await _repository.getForLead(partyId)
          : await _repository.getForCustomer(partyId);
      if (version == _selectionVersion) {
        state = state.copyWith(
          sheet: sheet,
          lines: [...sheet.items],
          dirty: false,
          pendingVendorId: sheet.vendorId,
          clearPendingVendor: sheet.vendorId == null,
          isLoadingSheet: false,
        );
      }
    } catch (_) {
      if (version == _selectionVersion) {
        state = state.copyWith(
          clearSheet: true,
          lines: const [],
          dirty: false,
          isLoadingSheet: false,
        );
      }
      rethrow;
    }
  }

  /// Adds a priced line to the local draft. Nothing is persisted until
  /// [saveSheet] runs.
  void addDraftLine(CostingLine line) {
    state = state.copyWith(lines: [...state.lines, line], dirty: true);
  }

  void removeDraftLineAt(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final next = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: next, dirty: true);
  }

  void clearDraftLines() {
    if (state.lines.isEmpty) return;
    state = state.copyWith(lines: const [], dirty: true);
  }

  /// Sets the draft vendor from the saved vendor list
  /// (persisted on the next [saveSheet]).
  void setVendor(String? vendorId) {
    state = state.copyWith(
      pendingVendorId: vendorId,
      clearPendingVendor: vendorId == null,
      clearCustomVendor: true, // a real vendor replaces any custom one
      dirty: true,
    );
  }

  /// One-off vendor for THIS costing only. It is never added to the vendor
  /// list — only the Vendors tab creates real vendors.
  void setCustomVendor({
    required String name,
    String address = '',
    String contactNumber = '',
  }) {
    state = state.copyWith(
      clearPendingVendor: true, // not a saved vendor
      customVendor: CostingVendor(
        id: '', // empty id = not in vendor list
        name: name,
        address: address,
        contactNumber: contactNumber,
        isActive: true, // remove if CostingVendor has no such parameter
      ),
      dirty: true,
    );
  }

  /// Clears both the saved-vendor selection and any custom vendor.
  void clearVendor() {
    state = state.copyWith(
      clearPendingVendor: true,
      clearCustomVendor: true,
      dirty: true,
    );
  }

  /// Saves the whole sheet in one transaction (`POST .../save`).
  Future<void> saveSheet() async {
    final partyId = state.selectedPartyId;
    if (partyId == null || partyId.isEmpty) {
      throw StateError('Select a customer or lead first');
    }
    if (state.isMutating) return;
    final custom = state.customVendor;
    final body = <String, dynamic>{
      'vendor_id': state.pendingVendorId,
      // Free-text vendor, not in the vendor list. Rename keys to match
      // your backend.
      if (custom != null) ...{
        'vendor_name': custom.name,
        'vendor_address': custom.address,
        'vendor_contact_number': custom.contactNumber,
      },
      'items': [for (final line in state.lines) line.toPayload()],
    };
    state = state.copyWith(isMutating: true);
    try {
      final saved = state.useLeadParty
          ? await _repository.saveLeadSheet(partyId, body)
          : await _repository.saveCustomerSheet(partyId, body);
      state = state.copyWith(
        sheet: saved,
        lines: [...saved.items],
        dirty: false,
        pendingVendorId: saved.vendorId,
        clearPendingVendor: saved.vendorId == null,
      );
    } finally {
      state = state.copyWith(isMutating: false);
    }
  }

  Future<CostingVendor> saveVendor({
    String? vendorId,
    required String name,
    String? address,
    String? contactNumber,
  }) async {
    final body = {
      'name': name.trim(),
      'address': address?.trim() ?? '',
      'contact_number': contactNumber?.trim() ?? '',
    };
    final saved = vendorId == null
        ? await _repository.createVendor(body)
        : await _repository.updateVendor(vendorId, body);
    final vendors = [
      for (final vendor in state.vendors)
        if (vendor.id != saved.id) vendor,
      saved,
    ];
    state = state.copyWith(vendors: vendors);
    return saved;
  }

  Future<void> deleteVendor(String vendorId) async {
    await _repository.deleteVendor(vendorId);
    state = state.copyWith(
      vendors: state.vendors.where((vendor) => vendor.id != vendorId).toList(),
    );
    if (state.sheet?.vendorId == vendorId ||
        state.pendingVendorId == vendorId) {
      setVendor(null);
    }
  }

  /// PDF is only available once the sheet is saved, clean and non-empty.
  Future<Uint8List> downloadPdf() async {
    if (state.dirty) {
      throw StateError('Save your changes before downloading the PDF');
    }
    final sheet = state.sheet;
    if (sheet == null || sheet.items.isEmpty) {
      throw StateError('There are no costing items to download');
    }
    return _repository.downloadPdf(sheet.id);
  }
}

final costingProvider =
    NotifierProvider.family<CostingNotifier, CostingState, bool>(
      CostingNotifier.new,
    );

/// All Costings tab state (`GET /costings`).
class CostingListState {
  final List<CostingListRow> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String search;

  /// Vendor uuid, or `none` for sheets without a vendor.
  final String? vendorId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;
  final int total;
  final String? error;

  const CostingListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.search = '',
    this.vendorId,
    this.dateFrom,
    this.dateTo,
    this.page = 0,
    this.total = 0,
    this.error,
  });

  bool get hasFilters =>
      search.trim().isNotEmpty ||
      vendorId != null ||
      dateFrom != null ||
      dateTo != null;

  CostingListState copyWith({
    List<CostingListRow>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? search,
    String? vendorId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? page,
    int? total,
    String? error,
    bool clearError = false,
    bool clearVendor = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return CostingListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      page: page ?? this.page,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CostingListNotifier extends Notifier<CostingListState> {
  CostingListNotifier(this.isGreenEnergy);

  final bool isGreenEnergy;
  static const int pageSize = 20;
  Timer? _debounce;

  @override
  CostingListState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const CostingListState(isLoading: true);
  }

  CostingRepository get _repo => ref.read(costingRepositoryProvider);

  /// `party` query: customers unless this is the Green Energy screen with
  /// Billbook turned off, in which case the sheets are saved against leads.
  String get _party {
    if (!isGreenEnergy) return 'customer';
    final auth = ref.read(authProvider);
    final canBillbook =
        auth.companyModules.billbook &&
        (auth.isCompanyAdmin ||
            CostingNotifier._hasAnyRole(
              auth.roles,
              CostingNotifier._billbookRoles,
            ) ||
            auth.hasAny(CostingNotifier._billbookPermissions));
    return canBillbook ? 'customer' : 'lead';
  }

  /// Selecting a party can make the server create an empty sheet before
  /// anything is saved. Only costings with at least one saved item belong
  /// in the Overview.
  static bool _isSaved(CostingListRow row) => row.itemCount > 0;

  /// Fetches pages starting at [startPage] until a page's worth of visible
  /// rows is collected (or the server runs out), so hiding empty sheets
  /// never leaves a short list that can't scroll to trigger [loadMore].
  Future<({List<CostingListRow> rows, int total, bool hasMore, int page})>
  _fetchVisible(int startPage) async {
    final rows = <CostingListRow>[];
    var next = startPage;
    var lastPage = startPage - 1;
    var hasMore = true;
    var total = 0;
    var requests = 0;
    while (hasMore && rows.length < pageSize && requests < 10) {
      final result = await _repo.listCostings(
        party: _party,
        search: state.search,
        vendorId: state.vendorId,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        page: next,
        limit: pageSize,
      );
      rows.addAll(result.data.where(_isSaved));
      total = result.total;
      hasMore = result.hasMore;
      lastPage = result.page;
      next = lastPage + 1;
      requests++;
    }
    return (rows: rows, total: total, hasMore: hasMore, page: lastPage);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, page: 0);
    try {
      final result = await _fetchVisible(1);
      state = state.copyWith(
        items: result.rows,
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
      final result = await _fetchVisible(state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...result.rows],
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

  void setVendor(String? vendorId) {
    state = state.copyWith(vendorId: vendorId, clearVendor: vendorId == null);
    refresh();
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
      clearVendor: true,
      clearDateFrom: true,
      clearDateTo: true,
    );
    refresh();
  }
}

final costingListProvider =
    NotifierProvider.family<CostingListNotifier, CostingListState, bool>(
      CostingListNotifier.new,
    );

/// Full sheet for the bill dialog (`GET /costings/:id`).
final costingDetailProvider =
    FutureProvider.autoDispose.family<CostingSheet, String>((ref, id) {
      return ref.watch(costingRepositoryProvider).getById(id);
    });
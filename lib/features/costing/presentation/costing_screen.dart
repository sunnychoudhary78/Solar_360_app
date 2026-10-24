import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/costing/presentation/widgets/costing_section.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import 'provider/bom_provider.dart';
import 'provider/costing_provider.dart';
import 'widgets/bom_tab.dart';
import 'widgets/costing_item_form.dart';
import 'widgets/costing_line_tile.dart';
import 'widgets/costing_overview_tab.dart';


class CostingScreen extends ConsumerStatefulWidget {
  final bool isGreenEnergy;

  const CostingScreen({super.key, this.isGreenEnergy = false});

  @override
  ConsumerState<CostingScreen> createState() => _CostingScreenState();
}

class _CostingScreenState extends ConsumerState<CostingScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _vendorAddressController = TextEditingController();
  final _vendorContactController = TextEditingController();
  final _vendorNameFocus = FocusNode();
  String _kind = 'catalog';
  String? _selectedItemId;
  String _vendorKind = 'select';
  bool _isDownloading = false;
  bool _isDeletingVendor = false;
  bool _isSaving = false;
  bool _vendorHadFocus = false;

  @override
  void initState() {
    super.initState();
    _vendorNameFocus.addListener(_onVendorNameFocusChanged);
  }

  @override
  void dispose() {
    _vendorNameFocus
      ..removeListener(_onVendorNameFocusChanged)
      ..dispose();
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _vendorNameController.dispose();
    _vendorAddressController.dispose();
    _vendorContactController.dispose();
    super.dispose();
  }

  void _onVendorNameFocusChanged() {
    final hasFocus = _vendorNameFocus.hasFocus;
    final lostFocus = _vendorHadFocus && !hasFocus; // real focus-loss only
    _vendorHadFocus = hasFocus;
    if (!lostFocus) return;

    _resolveTypedVendor();
  }

  /// Vendor is part of the local draft — persisted on Save costing.
  void _setVendor(String? vendorId) => _notifier.setVendor(vendorId);

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  CostingNotifier get _notifier =>
      ref.read(costingProvider(widget.isGreenEnergy).notifier);

  CostingListNotifier get _listNotifier =>
      ref.read(costingListProvider(widget.isGreenEnergy).notifier);

  /// Keeps the Overview table in sync after a save.
  void _refreshList() => _listNotifier.refresh();

  Future<void> _selectParty(String? partyId) async {
    try {
      await _notifier.selectParty(partyId);
      if (!mounted) return;
      final vendor = ref
          .read(costingProvider(widget.isGreenEnergy))
          .sheet
          ?.vendor;
      _syncVendorControllers(vendor);
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    }
  }

  /// Create New Costing: open the Costing tab with the party cleared.
  void _startNewCosting(TabController controller) {
    controller.animateTo(1);
    _selectParty(null);
  }

  /// Edit / View a row: open the Costing tab with that party's sheet loaded.
  void _editCosting(TabController controller, CostingListRow row) {
    controller.animateTo(1);
    _selectParty(row.partyId);
  }

  /// Open a project BOM from Overview: jump to the BOM tab and load it.
  void _openBom(TabController controller, BomListRow row) {
    controller.animateTo(2);
    if (row.id.isEmpty) {
      ref.read(bomProvider.notifier).startNew();
    } else {
      ref.read(bomProvider.notifier).openBom(row.id);
    }
  }

  /// Resolves the typed vendor name:
  /// - Matches an existing vendor -> uses that vendor (by id).
  /// - No match                   -> creates it in the vendor list and links
  ///                                 it by id, so it shows up in the Overview.
  /// - Empty                      -> clears the vendor.
  /// Always returns true so Save / Add item are never blocked by the vendor.
  ///
  /// With [validate] = true (Save / Add item), a partly filled vendor is
  /// rejected: name and a 10-digit contact number are both mandatory.
  Future<bool> _resolveTypedVendor({bool validate = false}) async {
    final state = ref.read(costingProvider(widget.isGreenEnergy));
    final typingVendor = !state.canSelectVendor || _vendorKind == 'custom';
    if (!typingVendor) return true; // vendor chosen via dropdown

    final name = _vendorNameController.text.trim();
    final contact = _vendorContactController.text.trim();
    if (name.isEmpty) {
      if (validate && (contact.isNotEmpty ||
          _vendorAddressController.text.trim().isNotEmpty)) {
        _showMessage('Vendor name is required', isError: true);
        return false;
      }
      _notifier.clearVendor();
      return true;
    }

    final match = state.vendors
        .where((v) => v.name.trim().toLowerCase() == name.toLowerCase())
        .firstOrNull;

    if (match != null) {
      _setVendor(match.id);
      _syncVendorControllers(match);
      return true;
    }

    if (validate) {
      if (contact.isEmpty) {
        _showMessage('Contact number is required', isError: true);
        return false;
      }
      if (contact.length != 10) {
        _showMessage('Contact number must be exactly 10 digits',
            isError: true);
        return false;
      }
      // Save / Add item: create the typed vendor so it can be linked by id
      // and shown in the Overview.
      try {
        final created = await _notifier.saveVendor(
          name: name,
          address: _vendorAddressController.text.trim(),
          contactNumber: contact,
        );
        _setVendor(created.id);
        _syncVendorControllers(created);
        return true;
      } catch (_) {
        // Cannot create a vendor — keep it on this costing only.
      }
    }
    _notifier.setCustomVendor(
      name: name,
      address: _vendorAddressController.text.trim(),
      contactNumber: contact,
    );
    return true;
  }

  /// Shared validator: mandatory, digits only, exactly 10 digits.
  static String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Contact number is required';
    if (v.length != 10) return 'Enter a valid 10-digit number';
    return null;
  }

  static final List<TextInputFormatter> _phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  void _syncVendorControllers(CostingVendor? vendor) {
    _vendorNameController.text = vendor?.name ?? '';
    _vendorAddressController.text = vendor?.address ?? '';
    _vendorContactController.text = vendor?.contactNumber ?? '';
  }

  /// Adds the typed line to the local draft (no server call until Save).
  Future<void> _submitLine(CostingState state) async {
    if (state.selectedPartyId == null) {
      _showMessage('Select a customer or lead first', isError: true);
      return;
    }
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    final kind = state.canUseCatalog ? _kind : 'custom';
    if (kind == 'catalog' && _selectedItemId == null) {
      _showMessage('Select an approved item', isError: true);
      return;
    }
    if (kind == 'custom' && _nameController.text.trim().isEmpty) {
      _showMessage('Enter an item name', isError: true);
      return;
    }
    if (price == null || !price.isFinite || price < 0) {
      _showMessage('Enter a valid price', isError: true);
      return;
    }
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _showMessage('Enter a quantity greater than zero', isError: true);
      return;
    }

    if (!await _resolveTypedVendor(validate: true)) return;
    final chosen = state.items
        .where((item) => item.id == _selectedItemId)
        .firstOrNull;
    _notifier.addDraftLine(
      CostingLine.draft(
        name: kind == 'catalog'
            ? (chosen?.name ?? '')
            : _nameController.text.trim(),
        kind: kind,
        unitPrice: price,
        quantity: quantity,
        itemId: kind == 'catalog' ? _selectedItemId : null,
        unit: kind == 'catalog' ? chosen?.unit : null,
      ),
    );
    _clearDraft();
    setState(() {});
    _showMessage('Item added — remember to save');
  }

  void _clearDraft() {
    _nameController.clear();
    _priceController.clear();
    _quantityController.clear();
    setState(() => _selectedItemId = null);
  }

  Future<void> _saveCosting() async {
    if (!await _resolveTypedVendor(validate: true)) return;
    setState(() => _isSaving = true);
    try {
      await _notifier.saveSheet();
      _refreshList();
      _showMessage('Costing saved');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeLine(int index) async {
    final line = ref.read(costingProvider(widget.isGreenEnergy)).lines[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove costing item?'),
        content: Text('Remove ${line.name} from this costing sheet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _notifier.removeDraftLineAt(index);
    _showMessage('Item removed — remember to save');
  }

  Future<void> _clearLines() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear costing items?'),
        content: const Text('This will remove every item from this draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _notifier.clearDraftLines();
    _showMessage('All items cleared — remember to save');
  }

  Future<void> _downloadPdf(CostingSheet sheet, CostingState state) async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _notifier.downloadPdf();
      final partyName = state.useLeadParty
          ? sheet.lead?.fullName
          : sheet.customer?.name;
      final safeName = (partyName ?? 'party')
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final savedPath = await saveBytesAsDownload(
        bytes: bytes,
        fileName: 'costing-${safeName.isEmpty ? 'party' : safeName}.pdf',
        openAfterSave: true,
      );
      _showMessage('PDF saved: $savedPath');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _editVendor([CostingVendor? vendor]) async {
    final name = TextEditingController(text: vendor?.name ?? '');
    final address = TextEditingController(text: vendor?.address ?? '');
    final contact = TextEditingController(text: vendor?.contactNumber ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(vendor == null ? 'Add vendor' : 'Edit vendor'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contact,
                  decoration: const InputDecoration(
                    labelText: 'Contact number *',
                    counterText: '',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: _phoneFormatters,
                  maxLength: 10,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        await _notifier.saveVendor(
          vendorId: vendor?.id,
          name: name.text,
          address: address.text,
          contactNumber: contact.text,
        );
        _showMessage('Vendor saved');
      } catch (error) {
        _showMessage(cleanError(error), isError: true);
      }
    }
    name.dispose();
    address.dispose();
    contact.dispose();
  }

  Future<void> _deleteVendor(CostingVendor vendor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: Text('${vendor.name} will be removed from the vendor list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeletingVendor = true);
    try {
      await _notifier.deleteVendor(vendor.id);
      _refreshList();
      _showMessage('Vendor deleted');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isDeletingVendor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(costingProvider(widget.isGreenEnergy));
    final auth = ref.watch(authProvider);
    final hasModuleAccess = widget.isGreenEnergy
        ? state.canSolar
        : state.canBillbook;

    if (!hasModuleAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Costing')),
        body: const _HintCard(
          icon: Icons.lock_outline,
          message: 'You do not have access to this costing module.',
        ),
      );
    }

    final canCreate = state.canCreateCosting;
    final tabs = <Tab>[
      const Tab(text: 'Overview'),
      const Tab(text: 'Costing'),
      if (state.showBom) const Tab(text: 'BOM'),
      if (state.canSelectVendor) const Tab(text: 'Vendors'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (tabContext) {
          final controller = DefaultTabController.of(tabContext);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Costing'),
              actions: [
                if (canCreate)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: () => _startNewCosting(controller),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New'),
                    ),
                  ),
              ],
              bottom: TabBar(
                tabs: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            body: TabBarView(
              children: [
                CostingOverviewTab(
                  isGreenEnergy: widget.isGreenEnergy,
                  showBom: state.showBom,
                  canSelectVendor: state.canSelectVendor,
                  canCreateCosting: canCreate,
                  canCreateBom: state.canCreateBom,
                  vendors: state.vendors,
                  onEditCosting: (row) => _editCosting(controller, row),
                  onOpenBom: (row) => _openBom(controller, row),
                ),
                _formTab(state, auth, canCreate),
                if (state.showBom)
                  BomTab(onSaved: () => ref.read(bomListProvider.notifier).refresh()),
                if (state.canSelectVendor)
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [_vendorsList(state)],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _formTab(CostingState state, dynamic auth, bool canCreate) {
    final partyPermission = state.useLeadParty ? 'lead.read' : 'customer.read';
    final canReadParty = auth.hasPermission(partyPermission) as bool;
    final canRead = state.canReadCosting && canReadParty;
    final sheet = state.sheet;
    final lines = state.lines;
    final selectedCustomer = state.customers
        .where((customer) => customer.id == state.selectedPartyId)
        .firstOrNull;
    final selectedLead = state.leads
        .where((lead) => lead.id == state.selectedPartyId)
        .firstOrNull;
    final lineTotal =
        (double.tryParse(_priceController.text) ?? 0) *
        (double.tryParse(_quantityController.text) ?? 0);
    final scheme = Theme.of(context).colorScheme;
    final canDownloadPdf =
        sheet != null && !state.dirty && lines.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.isGreenEnergy ? 'Green Energy / Costing' : 'Sales / Costing',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (state.dirty) const UnsavedBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.isGreenEnergy
              ? state.canBillbook
                    ? 'Priced project sheet — select or type vendors and items'
                    : 'Select a lead — type vendors and items (Billbook is not on this subscription)'
              : 'Priced project sheet — select a customer, add items, then Save. '
                    'A typed vendor that is not in the list is added to your vendors.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (state.catalogError != null)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.catalogError!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoadingCatalogs
                        ? null
                        : _notifier.loadCatalogs,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        if (!canRead)
          _HintCard(
            icon: Icons.lock_outline,
            message:
                'You need ${!state.canReadCosting ? 'costing.read or costing.create' : partyPermission} permission to view costing.',
          ),
        if (canRead) _partyCard(state, selectedCustomer, selectedLead),
        if (canRead && !canReadParty)
          _HintCard(
            icon: Icons.lock_outline,
            message: 'You need $partyPermission permission to list parties.',
          )
        else if (canRead && state.selectedPartyId == null)
          _HintCard(
            icon: Icons.person_search_outlined,
            message:
                'Select a ${state.useLeadParty ? 'lead' : 'customer'} to view or add costing.',
          )
        else if (canRead && state.selectedPartyId != null) ...[
          if (state.isLoadingSheet)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sheet != null) ...[
            _vendorCard(state, canCreate),
            if (canCreate)
              _sectionCard(
                context,
                title: 'Add item',
                child: CostingItemForm(
                  items: state.items,
                  canUseCatalog: state.canUseCatalog,
                  kind: state.canUseCatalog ? _kind : 'custom',
                  selectedItemId: _selectedItemId,
                  nameController: _nameController,
                  priceController: _priceController,
                  quantityController: _quantityController,
                  enabled: !state.isMutating && !_isSaving,
                  isSaving: false,
                  lineTotal: lineTotal,
                  onKindChanged: (kind) => setState(() {
                    _kind = kind;
                    _selectedItemId = null;
                    _nameController.clear();
                    _priceController.clear();
                  }),
                  onItemChanged: (itemId) {
                    final chosen = state.items
                        .where((item) => item.id == itemId)
                        .firstOrNull;
                    setState(() {
                      _selectedItemId = itemId;
                      _priceController.text =
                          chosen?.sellingPrice.toStringAsFixed(2) ?? '';
                    });
                  },
                  onDraftChanged: (_) => setState(() {}),
                  onSubmit: () => _submitLine(state),
                ),
              )
            else
              const _HintCard(
                icon: Icons.lock_outline,
                message: 'You have view-only access to costing.',
              ),
            _sectionCard(
              context,
              title: 'Costing list',
              trailing: Text('${lines.length} items'),
              child: lines.isEmpty
                  ? const _HintCard(
                      icon: Icons.receipt_long_outlined,
                      message: 'No items yet. Add items, then Save costing.',
                    )
                  : Column(
                      children: [
                        for (var index = 0; index < lines.length; index++) ...[
                          if (index > 0) const Divider(height: 1),
                          CostingLineTile(
                            line: lines[index],
                            index: index,
                            enabled: canCreate && !state.isMutating && !_isSaving,
                            onRemove: () => _removeLine(index),
                          ),
                        ],
                      ],
                    ),
            ),
            _sectionCard(
              context,
              title: 'Total price',
              trailing: Text(
                formatInr(state.draftTotal),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canCreate && !state.isMutating && !_isSaving
                          ? _saveCosting
                          : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'Saving…' : 'Save costing'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: canDownloadPdf && !_isDownloading
                          ? () => _downloadPdf(sheet, state)
                          : null,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Download PDF'),
                    ),
                  ),
                  if (canCreate && lines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isMutating || _isSaving
                            ? null
                            : _clearLines,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear all'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _partyCard(
    CostingState state,
    CustomerModel? selectedCustomer,
    CostingLead? selectedLead,
  ) {
    final isLead = state.useLeadParty;
    final selectedId = state.selectedPartyId;
    final entries = isLead
        ? state.leads.map((lead) {
            return DropdownMenuItem<String>(
              value: lead.id,
              child: Text(
                '${lead.fullName}${lead.leadCode.isNotEmpty ? ' (${lead.leadCode})' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList()
        : state.customers
              .map(
                (customer) => DropdownMenuItem<String>(
                  value: customer.id,
                  child: Text(customer.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList();
    final detail = isLead && selectedLead != null
        ? [
            selectedLead.email,
            selectedLead.mobile,
            selectedLead.city,
            selectedLead.state,
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · ')
        : selectedCustomer == null
        ? ''
        : [
            selectedCustomer.email,
            selectedCustomer.phone,
            selectedCustomer.city,
          ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
    return _sectionCard(
      context,
      title: isLead ? 'Lead' : 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(selectedId),
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isLead ? 'Lead *' : 'Customer *',
              prefixIcon: Icon(
                isLead ? Icons.person_outline : Icons.business_outlined,
              ),
              suffixIcon: state.isLoadingCatalogs
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            items: entries,
            onChanged: state.isLoadingSheet || state.isMutating
                ? null
                : _selectParty,
            hint: Text(
              state.isLoadingCatalogs
                  ? 'Loading…'
                  : 'Select ${isLead ? 'a lead' : 'a customer'}',
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _vendorCard(CostingState state, bool canCreate) {
    final selectedVendorId = state.vendorId;
    final matchedVendor = state.vendors
        .where((vendor) => vendor.id == selectedVendorId)
        .firstOrNull;
    return _sectionCard(
      context,
      title: 'Vendor (optional)',
      child: Column(
        children: [
          if (state.canSelectVendor)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'select', label: Text('Select')),
                ButtonSegment(value: 'custom', label: Text('Type')),
              ],
              selected: {_vendorKind},
              onSelectionChanged: canCreate
                  ? (selection) => setState(() {
                      _vendorKind = selection.first;
                      if (_vendorKind == 'custom') {
                        // Fall back to the one-off custom vendor so a typed
                        // vendor reappears when toggling Select -> Type.
                        _syncVendorControllers(
                          matchedVendor ?? state.customVendor,
                        );
                      }
                    })
                  : null,
            ),
          if (!state.canSelectVendor || _vendorKind == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _vendorNameController,
              focusNode: _vendorNameFocus,
              enabled: canCreate,
              readOnly: state.isMutating,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vendor name *',
                helperText:
                    'Not in the vendor list? It will be added to your vendors.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vendorContactController,
              enabled: canCreate,
              readOnly: state.isMutating,
              keyboardType: TextInputType.phone,
              inputFormatters: _phoneFormatters,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Contact number *',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vendorAddressController,
              enabled: canCreate,
              readOnly: state.isMutating,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
          ] else ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedVendorId),
              initialValue: selectedVendorId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select vendor'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('No vendor selected'),
                ),
                ...state.vendors.map(
                  (vendor) => DropdownMenuItem(
                    value: vendor.id,
                    child: Text(vendor.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: canCreate && !state.isMutating
                  ? (vendorId) async {
                      final id = vendorId == null || vendorId.isEmpty
                          ? null
                          : vendorId;
                      if (id == null) _syncVendorControllers(null);
                      _setVendor(id);
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _vendorsList(CostingState state) {
    return _sectionCard(
      context,
      title: 'Vendors',
      trailing: state.canCreateCosting
          ? IconButton(
              tooltip: 'Add vendor',
              onPressed: () => _editVendor(),
              icon: const Icon(Icons.add),
            )
          : null,
      child: state.vendors.isEmpty
          ? const Text('No vendors found.')
          : Column(
              children: [
                for (var index = 0; index < state.vendors.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(state.vendors[index].name),
                    subtitle: Text(
                      [
                            state.vendors[index].contactNumber,
                            state.vendors[index].address,
                          ]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.canCreateCosting) ...[
                          IconButton(
                            tooltip: 'Edit vendor',
                            onPressed: () => _editVendor(state.vendors[index]),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete vendor',
                            onPressed: _isDeletingVendor
                                ? null
                                : () => _deleteVendor(state.vendors[index]),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
    IconData? icon,
  }) {
    return CostingSectionCard(
      title: title,
      icon: icon ?? _iconFor(title),
      trailing: trailing,
      child: child,
    );
  }

  static IconData? _iconFor(String title) {
    switch (title) {
      case 'Lead':
        return Icons.person_outline;
      case 'Customer':
        return Icons.business_outlined;
      case 'Vendor (optional)':
      case 'Vendors':
        return Icons.storefront_outlined;
      case 'Add item':
        return Icons.add_box_outlined;
      case 'Costing list':
        return Icons.receipt_long_outlined;
      case 'Total price':
        return Icons.payments_outlined;
    }
    return null;
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HintCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) =>
      CostingHintCard(icon: icon, message: message);
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import 'provider/costing_provider.dart';
import 'widgets/costing_item_form.dart';
import 'widgets/costing_line_tile.dart';

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
  bool _isSavingVendor = false;
  Future<void>? _vendorSaveTask;
  bool _isDeletingVendor = false;
  String? _removingLineId;
  bool _isClearing = false;
  bool _showVendors = false;
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

    if (_vendorNameController.text.trim().isNotEmpty) {
      _saveTypedVendor();
    } else {
      _setVendor(null);
    }
  }

  Future<void> _setVendor(String? vendorId) async {
    final current = ref.read(costingProvider(widget.isGreenEnergy));
    if (current.isMutating) return;

    // Skip the API call if nothing would change.
    final currentVendorId = current.sheet?.vendorId ?? current.pendingVendorId;
    if (vendorId == null && currentVendorId == null) return;

    try {
      await _notifier.setVendor(vendorId);
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    }
  }

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

  // Future<void> _setVendor(String? vendorId) async {
  //   try {
  //     await _notifier.setVendor(vendorId);
  //   } catch (error) {
  //     _showMessage(cleanError(error), isError: true);
  //   }
  // }

  Future<void> _saveTypedVendor() {
    final activeSave = _vendorSaveTask;
    if (activeSave != null) return activeSave;
    final name = _vendorNameController.text.trim();
    if (name.isEmpty) {
      return _setVendor(null);
    }
    final task = _performTypedVendorSave(name);
    final trackedTask = task.whenComplete(() => _vendorSaveTask = null);
    _vendorSaveTask = trackedTask;
    return trackedTask;
  }

  void _syncVendorControllers(CostingVendor? vendor) {
    _vendorNameController.text = vendor?.name ?? '';
    _vendorAddressController.text = vendor?.address ?? '';
    _vendorContactController.text = vendor?.contactNumber ?? '';
  }

  Future<void> _performTypedVendorSave(String name) async {
    if (mounted) setState(() => _isSavingVendor = true);
    try {
      await _notifier.findOrCreateVendor(
        name: name,
        address: _vendorAddressController.text,
        contactNumber: _vendorContactController.text,
      );
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSavingVendor = false);
    }
  }

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

    try {
      if (_vendorNameController.text.trim().isNotEmpty) {
        await _saveTypedVendor();
      }
      if (kind == 'catalog') {
        await _notifier.addCatalogLine(
          itemId: _selectedItemId!,
          unitPrice: price,
          quantity: quantity,
        );
      } else {
        await _notifier.addCustomLine(
          name: _nameController.text.trim(),
          unitPrice: price,
          quantity: quantity,
        );
      }
      _clearDraft();
      _showMessage('Item saved');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    }
  }

  void _clearDraft() {
    _nameController.clear();
    _priceController.clear();
    _quantityController.clear();
    setState(() => _selectedItemId = null);
  }

  Future<void> _removeLine(CostingLine line) async {
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
    setState(() => _removingLineId = line.id);
    try {
      await _notifier.removeLine(line.id);
      _showMessage('Item removed');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _removingLineId = null);
    }
  }

  Future<void> _clearLines() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear costing items?'),
        content: const Text(
          'This will remove every item saved for this party.',
        ),
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
    setState(() => _isClearing = true);
    try {
      await _notifier.clearLines();
      _showMessage('All items cleared');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
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
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: contact,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
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
    final partyPermission = state.useLeadParty ? 'lead.read' : 'customer.read';
    final canReadParty = auth.hasPermission(partyPermission);
    final canRead = state.canReadCosting && canReadParty;
    final canCreate = state.canCreateCosting;
    final sheet = state.sheet;
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
    final hasModuleAccess = widget.isGreenEnergy
        ? state.canSolar
        : state.canBillbook;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Costing'),
        actions: [
          if (!_showVendors)
            IconButton(
              tooltip: 'Download PDF',
              onPressed:
                  sheet != null &&
                      sheet.items.isNotEmpty &&
                      !_isDownloading &&
                      !state.isLoadingSheet
                  ? () => _downloadPdf(sheet, state)
                  : null,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: !hasModuleAccess
          ? const _HintCard(
              icon: Icons.lock_outline,
              message: 'You do not have access to this costing module.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.isGreenEnergy
                      ? 'Green Energy / Costing'
                      : 'Sales / Costing',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isGreenEnergy
                      ? state.canBillbook
                            ? 'Uses Billbook customers — select or type vendors and items'
                            : 'Select a lead — type vendors and items (Billbook is not on this subscription)'
                      : 'Items are saved per customer — switch customers anytime to continue',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (state.canSelectVendor) ...[
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Costing')),
                      ButtonSegment(value: true, label: Text('Vendors')),
                    ],
                    selected: {_showVendors},
                    onSelectionChanged: (selection) =>
                        setState(() => _showVendors = selection.first),
                  ),
                ],
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
                if (_showVendors && state.canSelectVendor)
                  _vendorsList(state)
                else ...[
                  if (!canRead)
                    _HintCard(
                      icon: Icons.lock_outline,
                      message:
                          'You need ${!state.canReadCosting ? 'costing.read or costing.create' : partyPermission} permission to view costing.',
                    ),
                  if (canRead)
                    _partyCard(state, selectedCustomer, selectedLead),
                  if (canRead && !canReadParty)
                    _HintCard(
                      icon: Icons.lock_outline,
                      message:
                          'You need $partyPermission permission to list parties.',
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
                            enabled: !state.isMutating,
                            isSaving: state.isMutating,
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
                                    chosen?.sellingPrice.toStringAsFixed(2) ??
                                    '';
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
                        trailing: Text('${sheet.items.length} items'),
                        child: sheet.items.isEmpty
                            ? const _HintCard(
                                icon: Icons.receipt_long_outlined,
                                message: 'No items saved for this party yet.',
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < sheet.items.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const Divider(height: 1),
                                    CostingLineTile(
                                      line: sheet.items[index],
                                      index: index,
                                      enabled: canCreate && !state.isMutating,
                                      isRemoving:
                                          _removingLineId ==
                                          sheet.items[index].id,
                                      onRemove: () =>
                                          _removeLine(sheet.items[index]),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      _sectionCard(
                        context,
                        title: 'Total price',
                        trailing: Text(
                          formatInr(sheet.totalAmount),
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        child: canCreate && sheet.items.isNotEmpty
                            ? SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: state.isMutating
                                      ? null
                                      : _clearLines,
                                  icon: _isClearing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_sweep_outlined),
                                  label: Text(
                                    _isClearing ? 'Clearing…' : 'Clear all',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: scheme.error,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ],
              ],
            ),
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
    final selectedVendorId = state.sheet?.vendorId ?? state.pendingVendorId;
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
                        // vendor null ho to fields clear ho jayengi
                        _syncVendorControllers(matchedVendor);
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
              decoration: InputDecoration(
                labelText: 'Vendor name',
                suffixIcon: _isSavingVendor
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vendorContactController,
              enabled: canCreate,
              readOnly: state.isMutating,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
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
                      await _setVendor(id);
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HintCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

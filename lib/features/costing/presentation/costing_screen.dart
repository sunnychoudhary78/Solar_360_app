import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import 'provider/costing_provider.dart';
import 'widgets/costing_item_form.dart';
import 'widgets/costing_line_tile.dart';
import 'widgets/customer_dropdown.dart';

class CostingScreen extends ConsumerStatefulWidget {
  const CostingScreen({super.key});

  @override
  ConsumerState<CostingScreen> createState() => _CostingScreenState();
}

class _CostingScreenState extends ConsumerState<CostingScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  String _kind = 'catalog';
  String? _selectedItemId;
  bool _isDownloading = false;
  String? _removingLineId;
  bool _isClearing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
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

  Future<void> _selectCustomer(String? customerId) async {
    try {
      await ref.read(costingProvider.notifier).selectCustomer(customerId);
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    }
  }

  Future<void> _submitLine() async {
    final state = ref.read(costingProvider);
    if (state.selectedCustomerId == null) {
      _showMessage('Select a customer first', isError: true);
      return;
    }
    final price = double.tryParse(_priceController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());
    if (_kind == 'catalog' && _selectedItemId == null) {
      _showMessage('Select an approved item', isError: true);
      return;
    }
    if (_kind == 'custom' && _nameController.text.trim().isEmpty) {
      _showMessage('Enter an item name', isError: true);
      return;
    }
    if (price == null || !price.isFinite || price <= 0) {
      _showMessage('Enter a valid price greater than zero', isError: true);
      return;
    }
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _showMessage('Enter a quantity greater than zero', isError: true);
      return;
    }

    try {
      final notifier = ref.read(costingProvider.notifier);
      if (_kind == 'catalog') {
        await notifier.addCatalogLine(
          itemId: _selectedItemId!,
          unitPrice: price,
          quantity: quantity,
        );
      } else {
        await notifier.addCustomLine(
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
    setState(() => _removingLineId = line.id);
    try {
      await ref.read(costingProvider.notifier).removeLine(line.id);
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
          'This will remove every item saved for this customer.',
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
      await ref.read(costingProvider.notifier).clearLines();
      _showMessage('All items cleared');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _downloadPdf(CostingSheet sheet) async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await ref.read(costingProvider.notifier).downloadPdf();
      final customer = ref
          .read(costingProvider)
          .customers
          .where((item) => item.id == sheet.customerId)
          .firstOrNull;
      final customerName = customer?.name ?? sheet.customer?.name ?? 'customer';
      final safeCustomer = customerName
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final savedPath = await saveBytesAsDownload(
        bytes: bytes,
        fileName:
            'costing-${safeCustomer.isEmpty ? 'customer' : safeCustomer}.pdf',
        openAfterSave: true,
      );
      _showMessage('PDF saved: $savedPath');
    } catch (error) {
      _showMessage(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(costingProvider);
    final auth = ref.watch(authProvider);
    final missingReadPermissions = [
      if (!auth.hasPermission('costing.read')) 'costing.read',
      if (!auth.hasPermission('customer.read')) 'customer.read',
      if (!auth.hasPermission('item.read')) 'item.read',
    ];
    final canRead = missingReadPermissions.isEmpty;
    final canCreate = auth.hasPermission('costing.create');
    final sheet = state.sheet;
    final selectedCustomer = state.customers
        .where((customer) => customer.id == state.selectedCustomerId)
        .firstOrNull;
    final lineTotal =
        (double.tryParse(_priceController.text) ?? 0) *
        (double.tryParse(_quantityController.text) ?? 0);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Costing'),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed:
                sheet != null &&
                    sheet.items.isNotEmpty &&
                    !_isDownloading &&
                    !state.isLoadingSheet
                ? () => _downloadPdf(sheet)
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                          : () => ref
                                .read(costingProvider.notifier)
                                .loadCatalogs(),
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
                  'You need ${missingReadPermissions.join(', ')} permission'
                  '${missingReadPermissions.length == 1 ? '' : 's'} to view costing.',
            ),
          if (canRead)
            _sectionCard(
              context,
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomerDropdown(
                    customers: state.customers,
                    selectedCustomerId: state.selectedCustomerId,
                    isLoading: state.isLoadingCatalogs,
                    enabled: !state.isLoadingSheet && !state.isMutating,
                    onChanged: _selectCustomer,
                  ),
                  if (selectedCustomer != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      [
                        if (selectedCustomer.email?.isNotEmpty == true)
                          selectedCustomer.email!,
                        if (selectedCustomer.phone?.isNotEmpty == true)
                          selectedCustomer.phone!,
                        if (selectedCustomer.city?.isNotEmpty == true)
                          selectedCustomer.city!,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (canRead && state.selectedCustomerId == null)
            const _HintCard(
              icon: Icons.person_search_outlined,
              message: 'Select a customer to view or add costing.',
            )
          else if (canRead) ...[
            if (state.isLoadingSheet)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading saved items…'),
                    ],
                  ),
                ),
              )
            else if (sheet != null) ...[
              if (canCreate)
                _sectionCard(
                  context,
                  title: 'Add item',
                  child: CostingItemForm(
                    items: state.items,
                    kind: _kind,
                    selectedItemId: _selectedItemId,
                    nameController: _nameController,
                    priceController: _priceController,
                    quantityController: _quantityController,
                    enabled: !state.isMutating,
                    isSaving: state.isMutating,
                    lineTotal: lineTotal,
                    onKindChanged: (kind) {
                      setState(() {
                        _kind = kind;
                        _selectedItemId = null;
                        _nameController.clear();
                        _priceController.clear();
                      });
                    },
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
                    onSubmit: _submitLine,
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
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: _HintCard(
                          icon: Icons.receipt_long_outlined,
                          message: 'No items saved for this customer yet.',
                        ),
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
                                  _removingLineId == sheet.items[index].id,
                              onRemove: () => _removeLine(sheet.items[index]),
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
                          onPressed: state.isMutating ? null : _clearLines,
                          icon: _isClearing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_sweep_outlined),
                          label: Text(_isClearing ? 'Clearing…' : 'Clear all'),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/costing/presentation/widgets/costing_section.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/costing_model.dart';
import '../provider/bom_provider.dart';


/// BOM form tab — project materials with **no prices** (`/api/boms`).
class BomTab extends ConsumerStatefulWidget {
  const BomTab({super.key, this.onSaved});

  /// Called after a successful save so the Overview list can refresh.
  final VoidCallback? onSaved;

  @override
  ConsumerState<BomTab> createState() => _BomTabState();
}

class _BomTabState extends ConsumerState<BomTab> {
  final TextEditingController _projectController = TextEditingController();
  String _lastProjectName = '';
  bool _isDownloading = false;

  @override
  void dispose() {
    _projectController.dispose();
    super.dispose();
  }

  BomNotifier get _notifier => ref.read(bomProvider.notifier);

  void _snack(String message, {bool isError = false}) {
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

  Future<void> _save() async {
    try {
      await _notifier.save();
      widget.onSaved?.call();
      _snack('BOM saved');
    } catch (error) {
      _snack(cleanError(error), isError: true);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _notifier.downloadPdf();
      final state = ref.read(bomProvider);
      final safeName = state.projectName
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final saved = await saveBytesAsDownload(
        bytes: bytes,
        fileName: 'bom-${safeName.isEmpty ? 'project' : safeName}.pdf',
        openAfterSave: true,
      );
      _snack('PDF saved: $saved');
    } catch (error) {
      _snack(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openExisting(String bomId) async {
    if (bomId.isEmpty) return;
    await _notifier.openBom(bomId);
  }

  Future<void> _removeLine(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove material?'),
        content: const Text('Remove this material from the BOM?'),
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
    _notifier.removeLineAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bomProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!state.canReadBom) {
      return const _HintCard(
        icon: Icons.lock_outline,
        message:
            'You need bom.read or bom.create permission to view project BOMs.',
      );
    }

    if (state.projectName != _lastProjectName) {
      _lastProjectName = state.projectName;
      _projectController.value = TextEditingValue(
        text: state.projectName,
        selection: TextSelection.collapsed(offset: state.projectName.length),
      );
    }

    final projects = ref.watch(bomListProvider).items;
    final canCreate = state.canCreateBom;
    final busy = state.isSaving || state.isLoadingBom;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Materials this project needs — quantities only, no rates.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (state.dirty) const UnsavedBadge(),
          ],
        ),
        const SizedBox(height: 14),
        if (state.error != null)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoadingLookups
                        ? null
                        : _notifier.loadLookups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        _sectionCard(
          context,
          title: 'Project',
          trailing: canCreate
              ? TextButton.icon(
                  onPressed: busy ? null : _notifier.startNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _projectController,
                enabled: canCreate,
                readOnly: busy,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (value) {
                  _lastProjectName = value;
                  _notifier.setProjectName(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Project name *',
                  hintText: 'e.g. 5 kW rooftop — Kothrud',
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
              ),
              if (projects.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Open existing project',
                    prefixIcon: Icon(Icons.folder_open_outlined),
                  ),
                  items: projects
                      .where((project) => project.id.isNotEmpty)
                      .map(
                        (project) => DropdownMenuItem(
                          value: project.id,
                          child: Text(
                            '${project.projectName} · ${project.customerName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy ? null : (id) => _openExisting(id ?? ''),
                  hint: const Text('Select a project'),
                ),
              ],
              const SizedBox(height: 12),
              _customerField(state, busy, canCreate),
            ],
          ),
        ),
        if (state.isLoadingBom)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (canCreate)
            _sectionCard(
              context,
              title: 'Add material',
              child: _MaterialForm(
                items: state.items,
                canUseCatalog: state.canUseCatalog,
                enabled: !busy,
                onAdd: _notifier.addLine,
              ),
            )
          else
            const _HintCard(
              icon: Icons.lock_outline,
              message: 'You have view-only access to BOM.',
            ),
          _sectionCard(
            context,
            title: 'Materials',
            trailing: Text('${state.lines.length} items'),
            child: state.lines.isEmpty
                ? const _HintCard(
                    icon: Icons.inventory_2_outlined,
                    message:
                        'No materials yet. Add the materials this project needs.',
                  )
                : Column(
                    children: [
                      for (var index = 0; index < state.lines.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _MaterialTile(
                          line: state.lines[index],
                          index: index,
                          enabled: canCreate && !busy,
                          onRemove: () => _removeLine(index),
                        ),
                      ],
                    ],
                  ),
          ),
          _sectionCard(
            context,
            title: 'Save',
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canCreate && !busy ? _save : null,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(state.isSaving ? 'Saving…' : 'Save BOM'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: state.canDownloadPdf && !_isDownloading
                        ? _downloadPdf
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _customerField(BomState state, bool busy, bool canCreate) {
    final selectedId = state.customerId;
    return DropdownButtonFormField<String>(
      key: ValueKey(selectedId),
      initialValue: state.customers.any((c) => c.id == selectedId)
          ? selectedId
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Customer (job owner) *',
        prefixIcon: const Icon(Icons.business_outlined),
        suffixIcon: state.isLoadingLookups
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
      items: state.customers
          .map(
            (customer) => DropdownMenuItem(
              value: customer.id,
              child: Text(customer.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: canCreate && !busy
          ? (id) => _notifier.setCustomer(id)
          : null,
      hint: Text(
        state.isLoadingLookups ? 'Loading…' : 'Select a customer',
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
      case 'Project':
        return Icons.assignment_outlined;
      case 'Add material':
        return Icons.add_box_outlined;
      case 'Materials':
        return Icons.inventory_2_outlined;
      case 'Save':
        return Icons.save_outlined;
    }
    return null;
  }
}

class _MaterialForm extends StatefulWidget {
  const _MaterialForm({
    required this.items,
    required this.canUseCatalog,
    required this.enabled,
    required this.onAdd,
  });

  final List<ItemModel> items;
  final bool canUseCatalog;
  final bool enabled;
  final void Function(BomLine line) onAdd;

  @override
  State<_MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends State<_MaterialForm> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _specController = TextEditingController();
  String _kind = 'catalog';
  String? _selectedItemId;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _specController.dispose();
    super.dispose();
  }

  void _resetDraft() {
    _nameController.clear();
    _unitController.clear();
    _quantityController.clear();
    _specController.clear();
    setState(() => _selectedItemId = null);
  }

  void _submit() {
    final quantity = double.tryParse(_quantityController.text.trim());
    final kind = widget.canUseCatalog ? _kind : 'custom';
    if (kind == 'catalog' && (_selectedItemId == null || _selectedItemId!.isEmpty)) {
      _snack('Select an item');
      return;
    }
    if (kind == 'custom' && _nameController.text.trim().isEmpty) {
      _snack('Item name is required');
      return;
    }
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _snack('Quantity must be greater than 0');
      return;
    }
    final chosen = widget.items
        .where((item) => item.id == _selectedItemId)
        .firstOrNull;
    widget.onAdd(
      BomLine.draft(
        name: kind == 'catalog'
            ? (chosen?.name ?? '')
            : _nameController.text.trim(),
        kind: kind,
        quantity: quantity,
        itemId: kind == 'catalog' ? _selectedItemId : null,
        unit: kind == 'catalog' ? chosen?.unit : _unitController.text.trim(),
        spec: _specController.text,
      ),
    );
    _resetDraft();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.canUseCatalog) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'catalog',
                label: Text('Select'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: 'custom',
                label: Text('Type'),
                icon: Icon(Icons.edit_outlined),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: widget.enabled
                ? (selection) => setState(() {
                    _kind = selection.first;
                    _selectedItemId = null;
                    _nameController.clear();
                  })
                : null,
          ),
          const SizedBox(height: 16),
        ],
        if (_kind == 'catalog' && widget.canUseCatalog)
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedItemId),
            initialValue: _selectedItemId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Approved item *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: widget.items
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: widget.enabled
                ? (id) => setState(() => _selectedItemId = id)
                : null,
            hint: Text(
              widget.items.isEmpty
                  ? 'No approved items available'
                  : 'Select item',
            ),
          )
        else
          TextField(
            controller: _nameController,
            enabled: widget.enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Material name *',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _quantityController,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
              ),
            ),
            if (!widget.canUseCatalog || _kind == 'custom') ...[
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  enabled: widget.enabled,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'pcs, m, set',
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _specController,
          enabled: widget.enabled,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Specification',
            hintText: 'e.g. 540W, bifacial, silver frame',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.enabled ? _submit : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add material'),
          ),
        ),
      ],
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.line,
    required this.index,
    required this.enabled,
    required this.onRemove,
  });

  final BomLine line;
  final int index;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      line.kind == 'catalog' ? 'Catalog' : 'Custom',
      if (line.unit != null && line.unit!.isNotEmpty) line.unit!,
      'Qty ${_qty(line.quantity)}',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text('${index + 1}'),
      ),
      title: Text(
        line.name.isEmpty ? 'Untitled material' : line.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta),
          if (line.spec != null && line.spec!.trim().isNotEmpty)
            Text(
              line.spec!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Remove material',
        onPressed: enabled ? onRemove : null,
        icon: const Icon(Icons.delete_outline_rounded),
        color: scheme.error,
      ),
    );
  }

  static String _qty(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _HintCard extends CostingHintCard {
  const _HintCard({required super.icon, required super.message});
}
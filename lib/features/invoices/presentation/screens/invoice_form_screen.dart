import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/providers/branding_providers.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/gst_breakdown.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/document_totals_summary.dart';
import 'package:solar_sales/shared/widgets/invoice_dispatch_fields.dart';
import 'package:solar_sales/shared/widgets/party_address_fields.dart';

import '../../data/models/invoice_model.dart';
import '../providers/invoice_providers.dart';

class _LineDraft {
  String? itemId;
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  final gst = TextEditingController(text: '18');
  final description = TextEditingController();

  void dispose() {
    qty.dispose();
    price.dispose();
    gst.dispose();
    description.dispose();
  }
}

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceFormScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _invoiceNumberCtrl = TextEditingController();
  final _motorVehicleNo = TextEditingController();
  final _ewayBillNo = TextEditingController();
  final List<_LineDraft> _lines = [];
  bool _initialized = false;
  bool _loading = false;
  bool _editBlocked = false;
  String? _status;
  String? _invoiceNumber;
  String? _customerName;
  String? _paymentMode;
  bool _stockDeducted = false;
  PartyAddressModel _billTo = PartyAddressModel.empty();
  PartyAddressModel _shipTo = PartyAddressModel.empty();
  String? _fromBranchId = '';
  bool _shipSameAsBill = true;

  @override
  void dispose() {
    _notes.dispose();
    _invoiceNumberCtrl.dispose();
    _motorVehicleNo.dispose();
    _ewayBillNo.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _fill(InvoiceModel inv) {
    _status = inv.status;
    _invoiceNumber = inv.invoiceNumber;
    _invoiceNumberCtrl.text = inv.invoiceNumber;
    _customerName = inv.customerName;
    _stockDeducted = inv.stockDeducted;
    _paymentMode = inv.paymentMode;
    _motorVehicleNo.text = inv.motorVehicleNo ?? '';
    _ewayBillNo.text = inv.ewayBillNo ?? '';
    _notes.text = inv.notes ?? '';
    for (final l in _lines) {
      l.dispose();
    }
    _lines
      ..clear()
      ..addAll(
        inv.items.map((item) {
          final line = _LineDraft();
          line.itemId = item.itemId;
          line.qty.text = item.quantity.toString();
          line.price.text = item.unitPrice.toString();
          line.gst.text = item.gstPercent.toString();
          line.description.text = item.description ?? '';
          return line;
        }),
      );
    if (_lines.isEmpty) _lines.add(_LineDraft());
    _billTo = inv.billTo ?? PartyAddressModel.fromCustomer(inv.customer);
    _shipTo = inv.shipTo ?? _billTo;
    _fromBranchId = inv.fromBranchId ?? '';
    _shipSameAsBill =
        _shipTo.name == _billTo.name && _shipTo.address == _billTo.address;
  }

  Map<String, dynamic> _fromPartyPayload() {
    final branding = ref.read(solarBrandingProvider).value;
    if (branding == null) return {};
    return branding.fromPartyPayload(_fromBranchId);
  }

  bool _assertCanEdit() {
    final auth = ref.read(authProvider);
    final canEdit = DocumentWorkflow.canEditInvoice(
      _status ?? '',
      canCreate: auth.hasPermission('invoice.create'),
      canApprove: auth.hasPermission('invoice.approve'),
      stockDeducted: _stockDeducted,
    );
    if (!canEdit) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(
            _status == 'pending_approval'
                ? 'Only approvers can edit invoices pending approval'
                : 'This invoice cannot be edited',
          );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_assertCanEdit()) return;
    if (_lines.isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError('Add at least one line item');
      return;
    }

    final dupError = AppValidators.duplicateLineItems(
      _lines.map((l) => l.itemId),
    );
    if (dupError != null) {
      ref.read(globalLoadingProvider.notifier).showError(dupError);
      return;
    }

    final items = <InvoiceItemModel>[];
    for (final line in _lines) {
      if (line.itemId == null) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError('Select an item for each line');
        return;
      }
      items.add(
        InvoiceItemModel(
          itemId: line.itemId!,
          quantity: int.parse(line.qty.text.trim()),
          unitPrice: double.parse(line.price.text.trim()),
          gstPercent: double.parse(line.gst.text.trim()),
          description: line.description.text.trim().isEmpty
              ? null
              : line.description.text.trim(),
        ),
      );
    }

    setState(() => _loading = true);
    ref.read(globalLoadingProvider.notifier).showLoading('Updating invoice...');

    try {
      final wasRejected = _status == 'rejected';
      await ref
          .read(invoiceRepositoryProvider)
          .update(
            id: widget.invoiceId,
            items: items,
            notes: _notes.text.trim(),
            invoiceNumber: _invoiceNumberCtrl.text.trim().isEmpty
                ? null
                : _invoiceNumberCtrl.text.trim(),
            paymentMode: _paymentMode,
            motorVehicleNo: _motorVehicleNo.text.trim().isEmpty
                ? null
                : _motorVehicleNo.text.trim(),
            ewayBillNo: _ewayBillNo.text.trim().isEmpty
                ? null
                : _ewayBillNo.text.trim(),
            billTo: _billTo,
            shipTo: _shipSameAsBill ? _billTo : _shipTo,
            shipSameAsBill: _shipSameAsBill,
            fromParty: _fromPartyPayload(),
          );
      ref.invalidate(invoiceListProvider);
      ref.invalidate(pendingInvoicesProvider);
      ref.invalidate(invoiceDetailProvider(widget.invoiceId));
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            wasRejected
                ? 'Updated — status reset to draft'
                : 'Invoice updated',
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      final async = ref.watch(invoiceDetailProvider(widget.invoiceId));
      return async.when(
        loading: () => const Scaffold(body: LoadingState()),
        error: (e, _) => Scaffold(
          appBar: const AppAppBar(title: 'Edit Invoice'),
          body: ErrorState(
            message: cleanError(e),
            onRetry: () =>
                ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
          ),
        ),
        data: (inv) {
          if (!_initialized) {
            final auth = ref.read(authProvider);
            final allowed = DocumentWorkflow.canEditInvoice(
              inv.status,
              canCreate: auth.hasPermission('invoice.create'),
              canApprove: auth.hasPermission('invoice.approve'),
              stockDeducted: inv.stockDeducted,
            );
            if (!allowed) {
              _editBlocked = true;
              _initialized = true;
              _status = inv.status;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref.read(globalLoadingProvider.notifier).showError(
                      inv.status == 'pending_approval'
                          ? 'Only approvers can edit invoices pending approval'
                          : 'This invoice cannot be edited',
                    );
                Navigator.pop(context);
              });
            } else {
              _fill(inv);
              _initialized = true;
            }
          }
          if (_editBlocked) {
            return const Scaffold(body: LoadingState());
          }
          return _buildForm();
        },
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    final itemsAsync = ref.watch(approvedItemsProvider);
    final brandingAsync = ref.watch(solarBrandingProvider);

    return Scaffold(
      appBar: AppAppBar(
        title: _invoiceNumber != null
            ? 'Edit ${_invoiceNumber!}'
            : 'Edit Invoice',
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          // Extra bottom padding di hai taaki content button ke peeche na chhupe
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_customerName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Customer'),
                subtitle: Text(_customerName!),
              ),
            brandingAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (branding) => Column(
                children: [
                  FromAddressSelector(
                    branchId: _fromBranchId,
                    companyAddress: branding.companyAddress,
                    branches: branding.branchAddresses,
                    onChanged: (v) => setState(() => _fromBranchId = v),
                  ),
                  const SizedBox(height: 16),
                  PartyAddressEditor(
                    key: ValueKey('bill_${_billTo.name}_${_billTo.address}'),
                    title: 'Bill To',
                    party: _billTo,
                    onChanged: (p) => setState(() {
                      _billTo = p;
                      if (_shipSameAsBill) _shipTo = p;
                    }),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ship To same as Bill To'),
                    value: _shipSameAsBill,
                    onChanged: (v) => setState(() {
                      _shipSameAsBill = v ?? true;
                      if (_shipSameAsBill) _shipTo = _billTo;
                    }),
                  ),
                  if (!_shipSameAsBill)
                    PartyAddressEditor(
                      key: ValueKey('ship_${_shipTo.name}_${_shipTo.address}'),
                      title: 'Ship To',
                      party: _shipTo,
                      onChanged: (p) => setState(() => _shipTo = p),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            InvoiceDispatchFields(
              paymentMode: _paymentMode,
              motorVehicleNo: _motorVehicleNo,
              ewayBillNo: _ewayBillNo,
              onPaymentModeChanged: (v) => setState(() => _paymentMode = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Line items',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            itemsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(cleanError(e)),
              data: (approved) => Column(
                children: [
                  for (var i = 0; i < _lines.length; i++)
                    _buildLineCard(i, approved),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Document details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _invoiceNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Invoice number',
                hintText: 'Leave blank to keep auto number',
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              validator: (v) => AppValidators.maxLength(
                v,
                max: 50,
                field: 'Invoice number',
              ),
              onChanged: (v) => setState(() => _invoiceNumber = v.trim()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes for this invoice',
              ),
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              validator: (v) =>
                  AppValidators.maxLength(v, max: 500, field: 'Notes'),
            ),
            const SizedBox(height: 16),
            DocumentTotalsSummary(lines: _lineTotalsInputs()),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              child: const Text('Update'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(int index, List<ItemModel> approved) {
    final line = _lines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Line ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_lines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _lines.removeAt(index).dispose();
                      });
                    },
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: line.itemId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Item *'),
              items: approved
                  .map(
                    (it) => DropdownMenuItem(
                      value: it.id,
                      child: Text(
                        '${it.name} (${formatInr(it.sellingPrice)}, ${ItemUnits.labelFor(it.unit)}, GST ${it.gstPercent}%)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  line.itemId = v;
                  ItemModel? item;
                  for (final it in approved) {
                    if (it.id == v) {
                      item = it;
                      break;
                    }
                  }
                  if (item != null) {
                    line.price.text = item.sellingPrice.toString();
                    line.gst.text = item.gstPercent.toString();
                    if (line.description.text.isEmpty) {
                      line.description.text = item.name;
                    }
                  }
                });
              },
              validator: (v) => v == null ? 'Select item' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.qty,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: (v) => AppValidators.positiveNumber(v, 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: line.price,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: (v) =>
                        AppValidators.nonNegativeNumber(v, 'Price'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: line.gst,
                    decoration: const InputDecoration(labelText: 'GST %'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: AppValidators.gstPercent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: line.description,
              decoration: const InputDecoration(labelText: 'Description'),
              inputFormatters: [LengthLimitingTextInputFormatter(250)],
              validator: (v) =>
                  AppValidators.maxLength(v, max: 250, field: 'Description'),
            ),
          ],
        ),
      ),
    );
  }

  List<LineTotalsInput> _lineTotalsInputs() {
    return _lines
        .where((l) => l.itemId != null)
        .map((l) {
          final qty = int.tryParse(l.qty.text.trim()) ?? 0;
          final price = double.tryParse(l.price.text.trim()) ?? 0;
          final gst = double.tryParse(l.gst.text.trim()) ?? 0;
          return LineTotalsInput(
            quantity: qty,
            unitPrice: price,
            gstPercent: gst,
          );
        })
        .where((l) => l.quantity > 0)
        .toList();
  }
}

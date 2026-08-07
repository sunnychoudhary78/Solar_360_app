import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/providers/branding_providers.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/utils/gst_breakdown.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
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

class InvoiceDirectFormScreen extends ConsumerStatefulWidget {
  const InvoiceDirectFormScreen({super.key});

  @override
  ConsumerState<InvoiceDirectFormScreen> createState() =>
      _InvoiceDirectFormScreenState();
}

class _InvoiceDirectFormScreenState
    extends ConsumerState<InvoiceDirectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _motorVehicleNo = TextEditingController();
  final _ewayBillNo = TextEditingController();
  String? _customerId;
  String? _paymentMode;
  final List<_LineDraft> _lines = [];
  bool _loading = false;
  PartyAddressModel _billTo = PartyAddressModel.empty();
  PartyAddressModel _shipTo = PartyAddressModel.empty();
  String? _fromBranchId = '';
  bool _shipSameAsBill = true;

  @override
  void initState() {
    super.initState();
    _addNewLine();
  }

  void _addNewLine() {
    final line = _LineDraft();
    line.qty.addListener(_onLineInputChanged);
    line.price.addListener(_onLineInputChanged);
    line.gst.addListener(_onLineInputChanged);
    _lines.add(line);
  }

  void _onLineInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notes.dispose();
    _invoiceNumber.dispose();
    _motorVehicleNo.dispose();
    _ewayBillNo.dispose();
    for (final l in _lines) {
      l.qty.removeListener(_onLineInputChanged);
      l.price.removeListener(_onLineInputChanged);
      l.gst.removeListener(_onLineInputChanged);
      l.dispose();
    }
    super.dispose();
  }

  void _onCustomerChanged(String? id, List<CustomerModel> customers) {
    setState(() {
      _customerId = id;
      if (id != null) {
        CustomerModel? cust;
        for (final c in customers) {
          if (c.id == id) {
            cust = c;
            break;
          }
        }
        if (cust != null) {
          final party = PartyAddressModel.fromCustomer(cust);
          _billTo = party;
          _shipTo = party;
          _shipSameAsBill = true;
        }
      }
    });
  }

  Map<String, dynamic> _fromPartyPayload() {
    final branding = ref.read(solarBrandingProvider).value;
    if (branding == null) return {};
    return branding.fromPartyPayload(_fromBranchId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ref.read(globalLoadingProvider.notifier).showError('Select a customer');
      return;
    }
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
    ref.read(globalLoadingProvider.notifier).showLoading('Creating invoice...');

    try {
      final inv = await ref.read(invoiceRepositoryProvider).createDirect(
            customerId: _customerId!,
            items: items,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            invoiceNumber: _invoiceNumber.text.trim(),
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
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Invoice created');
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/invoices/detail',
          arguments: inv.id,
        );
      }
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final itemsAsync = ref.watch(approvedItemsProvider);
    final brandingAsync = ref.watch(solarBrandingProvider);

    return Scaffold(
      appBar: const AppAppBar(title: 'Direct Invoice'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (customersAsync.isLoading && customersAsync.items.isEmpty)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: _customerId,
                    decoration: const InputDecoration(labelText: 'Customer *'),
                    items: customersAsync.items
                        .map(
                          (CustomerModel c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        _onCustomerChanged(v, customersAsync.items),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Select a customer' : null,
                  ),
                const SizedBox(height: 16),
                brandingAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (branding) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (!_shipSameAsBill) ...[
                        const SizedBox(height: 12),
                        PartyAddressEditor(
                          key: ValueKey(
                            'ship_${_shipTo.name}_${_shipTo.address}',
                          ),
                          title: 'Ship To',
                          party: _shipTo,
                          onChanged: (p) => setState(() => _shipTo = p),
                        ),
                      ],
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Line items',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _addNewLine()),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                  controller: _invoiceNumber,
                  decoration: const InputDecoration(
                    labelText: 'Invoice number (optional)',
                    hintText: 'Auto-generated if blank',
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  validator: (v) => AppValidators.maxLength(
                    v,
                    max: 50,
                    field: 'Invoice number',
                  ),
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
                  validator: (v) => AppValidators.maxLength(
                    v,
                    max: 500,
                    field: 'Notes',
                  ),
                ),
                const SizedBox(height: 20),
                DocumentTotalsSummary(lines: _lineTotalsInputs()),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _save,
                    child: const Text('Create invoice'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Line ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (_lines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        final removed = _lines.removeAt(index);
                        removed.qty.removeListener(_onLineInputChanged);
                        removed.price.removeListener(_onLineInputChanged);
                        removed.gst.removeListener(_onLineInputChanged);
                        removed.dispose();
                      });
                    },
                  ),
              ],
            ),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: line.itemId,
              decoration: const InputDecoration(labelText: 'Item *'),
              items: approved
                  .map(
                    (it) => DropdownMenuItem(
                      value: it.id,
                      child: Text(
                        '${it.name} (${formatInr(it.sellingPrice)}, ${ItemUnits.labelFor(it.unit)}, GST ${it.gstPercent}%)',
                        maxLines:1,
                        overflow: TextOverflow.ellipsis,
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
            if (line.itemId != null) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  ItemModel? selected;
                  for (final it in approved) {
                    if (it.id == line.itemId) {
                      selected = it;
                      break;
                    }
                  }
                  if (selected == null) return const SizedBox.shrink();
                  final item = selected;
                  final codes = [
                    if (item.hsnCode != null && item.hsnCode!.isNotEmpty)
                      item.hsnCode,
                    if (item.sacCode != null && item.sacCode!.isNotEmpty)
                      item.sacCode,
                  ].join(' / ');
                  if (codes.isEmpty) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'HSN/SAC: $codes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: line.description,
              decoration: const InputDecoration(labelText: 'Description'),
              inputFormatters: [LengthLimitingTextInputFormatter(250)],
              validator: (v) => AppValidators.maxLength(
                v,
                max: 250,
                field: 'Description',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
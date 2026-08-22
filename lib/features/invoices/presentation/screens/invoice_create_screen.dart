import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/features/quotations/data/models/quotation_model.dart';
import 'package:solar_sales/features/quotations/presentation/providers/quotation_providers.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/models/party_address_model.dart';
import 'package:solar_sales/shared/providers/branding_providers.dart';
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

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  final String? quotationId;

  const InvoiceCreateScreen({super.key, this.quotationId});

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _quotationId;
  final _notes = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _motorVehicleNo = TextEditingController();
  final _ewayBillNo = TextEditingController();
  final List<_LineDraft> _lines = [];
  bool _loading = false;
  PartyAddressModel _billTo = PartyAddressModel.empty();
  PartyAddressModel _shipTo = PartyAddressModel.empty();
  String? _fromBranchId = '';
  bool _shipSameAsBill = true;
  String? _paymentMode;
  QuotationModel? _preview;

  @override
  void initState() {
    super.initState();
    _quotationId = widget.quotationId;
    if (_quotationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPreview());
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _invoiceNumber.dispose();
    _motorVehicleNo.dispose();
    _ewayBillNo.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _attachLineListeners(_LineDraft line) {
    line.qty.addListener(_refreshUi);
    line.price.addListener(_refreshUi);
    line.gst.addListener(_refreshUi);
  }

  void _refreshUi() {
    if (mounted) setState(() {});
  }

  void _fillLinesFromQuotation(QuotationModel q) {
    for (final l in _lines) {
      l.dispose();
    }
    _lines
      ..clear()
      ..addAll(
        q.items.map((item) {
          final line = _LineDraft();
          line.itemId = item.itemId;
          line.qty.text = item.quantity.toString();
          line.price.text = item.unitPrice.toString();
          line.gst.text = item.gstPercent.toString();
          line.description.text = item.description ?? '';
          _attachLineListeners(line);
          return line;
        }),
      );
    if (_lines.isEmpty) {
      final line = _LineDraft();
      _attachLineListeners(line);
      _lines.add(line);
    }
  }

  Future<void> _loadPreview() async {
    if (_quotationId == null) {
      setState(() {
        _preview = null;
        for (final l in _lines) {
          l.dispose();
        }
        _lines.clear();
      });
      return;
    }
    try {
      final q = await ref
          .read(quotationRepositoryProvider)
          .getById(_quotationId!);
      if (!mounted) return;
      setState(() {
        _preview = q;
        _billTo = q.billTo ?? PartyAddressModel.fromCustomer(q.customer);
        _shipTo = q.shipTo ?? _billTo;
        _fromBranchId = q.fromBranchId ?? '';
        _shipSameAsBill =
            _shipTo.name == _billTo.name && _shipTo.address == _billTo.address;
        if (_notes.text.isEmpty && q.notes != null) {
          _notes.text = q.notes!;
        }
        _fillLinesFromQuotation(q);
      });
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Map<String, dynamic> _fromPartyPayload() {
    final branding = ref.read(solarBrandingProvider).value;
    if (branding == null) return {};
    return branding.fromPartyPayload(_fromBranchId);
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_quotationId == null) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError('Select a sent (invoiceable) quotation');
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
    ref
        .read(globalLoadingProvider.notifier)
        .showLoading('Creating invoice...');

    try {
      final inv = await ref.read(invoiceRepositoryProvider).createFromQuotation(
            quotationId: _quotationId!,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            invoiceNumber: _invoiceNumber.text.trim().isEmpty
                ? null
                : _invoiceNumber.text.trim(),
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
            items: items,
          );
      ref.invalidate(invoiceListProvider);
      ref.invalidate(quotationListProvider);
      ref.invalidate(invoiceableQuotationsProvider);
      if (_quotationId != null) {
        ref.invalidate(quotationDetailProvider(_quotationId!));
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Invoice created');
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/invoices/detail',
        arguments: inv.id,
      );
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
    final async = ref.watch(invoiceableQuotationsProvider);
    final brandingAsync = ref.watch(solarBrandingProvider);
    final itemsAsync = ref.watch(approvedItemsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(title: 'Create Invoice'),
      body: SafeArea(
        child: async.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: cleanError(e),
            onRetry: () => ref.invalidate(invoiceableQuotationsProvider),
          ),
          data: (quotations) {
            if (quotations.isEmpty) {
              return const EmptyState(
                title: 'No invoiceable quotations',
                subtitle: 'Approve a quotation first',
                icon: Icons.request_quote_outlined,
              );
            }

            return Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _quotationId,
                      decoration: const InputDecoration(
                        labelText: 'Approved quotation *',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: quotations.map((q) {
                        final formattedText =
                            '${q.quotationNumber} • ${q.customerName} (${formatInr(q.totalAmount)})';
                        return DropdownMenuItem<String>(
                          value: q.id,
                          child: Text(
                            formattedText,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) async {
                        setState(() => _quotationId = v);
                        await _loadPreview();
                      },
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Select a quotation' : null,
                    ),
                    if (_preview != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Customer: ${_preview!.customerName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
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
                            onChanged: (v) =>
                                setState(() => _fromBranchId = v),
                          ),
                          const SizedBox(height: 16),
                          PartyAddressEditor(
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
                              title: 'Ship To',
                              party: _shipTo,
                              onChanged: (p) => setState(() => _shipTo = p),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InvoiceDispatchFields(
                      paymentMode: _paymentMode,
                      motorVehicleNo: _motorVehicleNo,
                      ewayBillNo: _ewayBillNo,
                      onPaymentModeChanged: (v) =>
                          setState(() => _paymentMode = v),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Line Items',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            final line = _LineDraft();
                            _attachLineListeners(line);
                            _lines.add(line);
                          }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    itemsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => ErrorState(
                        message: cleanError(e),
                        onRetry: () => ref.invalidate(approvedItemsProvider),
                      ),
                      data: (approved) => Column(
                        children: [
                          for (var i = 0; i < _lines.length; i++)
                            _buildLineCard(i, approved),
                          if (_lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Select a quotation to load line items',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Document details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _invoiceNumber,
                      decoration: const InputDecoration(
                        labelText: ' Leave Blank For Auto',
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
                    if (_lines.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DocumentTotalsSummary(lines: _lineTotalsInputs()),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _create,
                        child: const Text(
                          'Create invoice',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLineCard(int index, List<ItemModel> approved) {
    final line = _lines[index];
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lines.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _lines.removeAt(index).dispose();
                    });
                  },
                ),
              ),
            DropdownButtonFormField<String>(
              value: line.itemId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Item *',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: approved
                  .map(
                    (it) => DropdownMenuItem(
                      value: it.id,
                      child: Text(
                        '${it.name} (${formatInr(it.sellingPrice)}, ${ItemUnits.labelFor(it.unit)}, GST ${it.gstPercent}%)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
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
                  flex: 3,
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
                  flex: 2,
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
              decoration: const InputDecoration(
                labelText: 'Description / Item Details',
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(250)],
              validator: (v) =>
                  AppValidators.maxLength(v, max: 250, field: 'Description'),
            ),
          ],
        ),
      ),
    );
  }
}

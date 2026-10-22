import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/inventory/presentation/utils/stock_movement_utils.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
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
import 'package:solar_sales/shared/widgets/dropdown_separated_item.dart';
import 'package:solar_sales/shared/widgets/party_address_fields.dart';
import 'package:solar_sales/shared/widgets/warehouse_field.dart';
import 'package:solar_sales/shared/widgets/marketing_template_picker.dart';

import '../../data/models/quotation_model.dart';
import '../providers/quotation_providers.dart';
import '../widgets/quotation_solar_design_picker.dart';

class _LineDraft {
  String? itemId;
  String? warehouseId;
  String? warehouseName;

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

class QuotationFormScreen extends ConsumerStatefulWidget {
  final String? quotationId;
  final String? initialCustomerId;

  const QuotationFormScreen({
    super.key,
    this.quotationId,
    this.initialCustomerId,
  });

  @override
  ConsumerState<QuotationFormScreen> createState() =>
      _QuotationFormScreenState();
}

class _QuotationFormScreenState extends ConsumerState<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _notes = TextEditingController();
  final _quotationNumber = TextEditingController();

  // PERF: only the totals card listens to this, so typing in qty / price / GST
  // no longer rebuilds the whole screen.
  final ValueNotifier<int> _totalsTick = ValueNotifier<int>(0);

  String? _customerId;
  String? _solarDesignId;
  QuotationSolarDesign? _attachedSolarDesign;
  DateTime? _validUntil;

  final List<_LineDraft> _lines = [_LineDraft()];

  bool _initialized = false;
  bool _loading = false;

  String? _status;
  bool _editBlocked = false;

  PartyAddressModel _billTo = PartyAddressModel.empty();
  PartyAddressModel _shipTo = PartyAddressModel.empty();

  String? _fromBranchId = '';

  bool _shipSameAsBill = true;
  String? _marketingTemplateId;

  bool get isEdit => widget.quotationId != null;

  @override
  void initState() {
    super.initState();
    _attachLineListeners(_lines.first);
    final initialCustomer = widget.initialCustomerId?.trim();
    if (!isEdit && initialCustomer != null && initialCustomer.isNotEmpty) {
      _customerId = initialCustomer;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(stockListProvider.notifier).refresh();
    });
  }

  void _attachLineListeners(_LineDraft line) {
    line.qty.addListener(_bumpTotals);
    line.price.addListener(_bumpTotals);
    line.gst.addListener(_bumpTotals);
  }

  // No setState here on purpose.
  void _bumpTotals() {
    _totalsTick.value++;
  }

  @override
  void dispose() {
    _totalsTick.dispose();
    _notes.dispose();
    _quotationNumber.dispose();

    for (final line in _lines) {
      line.dispose();
    }

    super.dispose();
  }

  void _fill(QuotationModel q) {
    _status = q.status;
    _customerId = q.customerId;
    _solarDesignId = q.solarDesignId ?? q.solarDesign?.id;
    _attachedSolarDesign = q.solarDesign;
    _quotationNumber.text = q.quotationNumber;
    _notes.text = q.notes ?? '';
    _validUntil = q.validUntil;
    _marketingTemplateId = q.marketingTemplateId;

    for (final line in _lines) {
      line.dispose();
    }

    _lines
      ..clear()
      ..addAll(
        q.items.map((item) {
          final line = _LineDraft();

          line.itemId = item.itemId;
          line.warehouseId = item.warehouseId;
          line.warehouseName = item.warehouseName;

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

    _billTo = q.billTo ?? PartyAddressModel.fromCustomer(q.customer);
    _shipTo = q.shipTo ?? _billTo;

    _fromBranchId = q.fromBranchId ?? '';

    _shipSameAsBill =
        _shipTo.name == _billTo.name && _shipTo.address == _billTo.address;
  }

  void _onCustomerChanged(String? id, List<CustomerModel> customers) {
    setState(() {
      if (_customerId != id) {
        _solarDesignId = null;
        _attachedSolarDesign = null;
      }
      _customerId = id;

      if (id != null) {
        CustomerModel? customer;

        for (final c in customers) {
          if (c.id == id) {
            customer = c;
            break;
          }
        }

        if (customer != null) {
          final party = PartyAddressModel.fromCustomer(customer);

          _billTo = party;
          _shipTo = party;
          _shipSameAsBill = true;
        }
      }
    });
  }

  Map<String, dynamic> _fromPartyPayload() {
    final branding = ref.read(solarBrandingProvider).value;

    if (branding == null) {
      return {};
    }

    return branding.fromPartyPayload(_fromBranchId);
  }

  bool _assertCanEdit() {
    if (!isEdit) {
      return true;
    }

    final auth = ref.read(authProvider);

    final canEdit = DocumentWorkflow.canEditQuotation(
      _status ?? '',
      canCreate: auth.hasPermission('quotation.create'),
      canApprove: auth.hasPermission('quotation.approve'),
    );

    if (!canEdit) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(
            _status == 'pending_approval'
                ? 'Only approvers can edit quotations pending approval'
                : 'This quotation cannot be edited',
          );

      return false;
    }

    return true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final lastDate = today.add(const Duration(days: 365 * 2));

    var initial = _validUntil ?? today.add(const Duration(days: 30));

    if (initial.isBefore(today)) {
      initial = today;
    }

    if (initial.isAfter(lastDate)) {
      initial = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _validUntil = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_assertCanEdit()) {
      return;
    }

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

    final dupError = AppValidators.duplicateItemWarehousePairs(
      _lines.map((line) => (line.itemId, line.warehouseId)),
    );

    if (dupError != null) {
      ref.read(globalLoadingProvider.notifier).showError(dupError);

      return;
    }

    final items = <QuotationItemModel>[];

    for (final line in _lines) {
      if (line.itemId == null) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError('Select an item for each line');

        return;
      }

      if (line.warehouseId == null || line.warehouseId!.isEmpty) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError('Select a warehouse for each line item');

        return;
      }

      items.add(
        QuotationItemModel(
          itemId: line.itemId!,
          warehouseId: line.warehouseId,
          quantity: int.parse(line.qty.text.trim()),
          unitPrice: double.parse(line.price.text.trim()),
          gstPercent: double.parse(line.gst.text.trim()),
          description: line.description.text.trim().isEmpty
              ? null
              : line.description.text.trim(),
        ),
      );
    }

    setState(() {
      _loading = true;
    });

    ref
        .read(globalLoadingProvider.notifier)
        .showLoading(
          isEdit ? 'Updating quotation...' : 'Creating quotation...',
        );

    try {
      final repo = ref.read(quotationRepositoryProvider);

      final fromParty = _fromPartyPayload();

      final qNum = _quotationNumber.text.trim();

      final notes = _notes.text.trim();

      final wasRejected = _status == 'rejected';

      if (isEdit) {
        await repo.update(
          id: widget.quotationId!,
          customerId: _customerId!,
          items: items,
          notes: notes,
          quotationNumber: qNum.isEmpty ? null : qNum,
          validUntil: _validUntil,
          billTo: _billTo,
          shipTo: _shipSameAsBill ? _billTo : _shipTo,
          shipSameAsBill: _shipSameAsBill,
          fromParty: fromParty,
          marketingTemplateId: _marketingTemplateId,
          includeSolarDesignId: true,
          solarDesignId: _solarDesignId,
        );
      } else {
        await repo.create(
          customerId: _customerId!,
          items: items,
          notes: notes.isEmpty ? null : notes,
          quotationNumber: qNum.isEmpty ? null : qNum,
          validUntil: _validUntil,
          billTo: _billTo,
          shipTo: _shipSameAsBill ? _billTo : _shipTo,
          shipSameAsBill: _shipSameAsBill,
          fromParty: fromParty,
          marketingTemplateId: _marketingTemplateId,
          solarDesignId: _solarDesignId,
        );
      }

      ref.invalidate(quotationListProvider);

      ref.invalidate(pendingQuotationsProvider);

      if (isEdit) {
        ref.invalidate(quotationDetailProvider(widget.quotationId!));
      }

      ref.read(globalLoadingProvider.notifier).hide();

      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess(
            isEdit
                ? (wasRejected
                      ? 'Updated — status reset to draft'
                      : 'Quotation updated')
                : 'Quotation created',
          );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();

      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && !_initialized) {
      final async = ref.watch(quotationDetailProvider(widget.quotationId!));

      return async.when(
        loading: () => const Scaffold(body: LoadingState()),
        error: (e, _) => Scaffold(
          appBar: const AppAppBar(title: 'Edit Quotation'),
          body: ErrorState(
            message: cleanError(e),
            onRetry: () {
              ref.invalidate(quotationDetailProvider(widget.quotationId!));
            },
          ),
        ),
        data: (q) {
          if (!_initialized) {
            final auth = ref.read(authProvider);

            final allowed = DocumentWorkflow.canEditQuotation(
              q.status,
              canCreate: auth.hasPermission('quotation.create'),
              canApprove: auth.hasPermission('quotation.approve'),
            );

            if (!allowed) {
              _editBlocked = true;
              _initialized = true;
              _status = q.status;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }

                ref
                    .read(globalLoadingProvider.notifier)
                    .showError(
                      q.status == 'pending_approval'
                          ? 'Only approvers can edit quotations pending approval'
                          : 'This quotation cannot be edited',
                    );

                Navigator.pop(context);
              });
            } else {
              _fill(q);
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
    final customersAsync = ref.watch(customerListProvider);

    if (!isEdit &&
        _customerId != null &&
        _billTo.name.trim().isEmpty &&
        customersAsync.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_billTo.name.trim().isNotEmpty) return;
        _onCustomerChanged(_customerId, customersAsync.items);
      });
    }

    final itemsAsync = ref.watch(approvedItemsProvider);

    final brandingAsync = ref.watch(solarBrandingProvider);

    // PERF: watch stock once here (not once per line card) and compute the
    // per-item summary once per build.
    final stockRows = ref.watch(stockListProvider.select((s) => s.items));
    final stockByItem = _stockSummaryByItem(stockRows);

    final theme = Theme.of(context);

    // Selected customer (for the info card)
    CustomerModel? selectedCustomer;
    if (_customerId != null) {
      for (final c in customersAsync.items) {
        if (c.id == _customerId) {
          selectedCustomer = c;
          break;
        }
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(title: isEdit ? 'Edit Quotation' : 'New Quotation'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            // PERF: paddingOf only listens to padding changes. MediaQuery.of
            // rebuilt the whole form on every frame of the keyboard animation.
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (customersAsync.isLoading &&
                          customersAsync.items.isEmpty)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          value: _customerId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Select Customer *',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          items: customersAsync.items
                              .map(
                                (CustomerModel c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              _onCustomerChanged(v, customersAsync.items),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Select a customer'
                              : null,
                        ),

                      // Customer email / phone / address
                      if (selectedCustomer != null)
                        _CustomerInfoCard(customer: selectedCustomer),

                      QuotationSolarDesignPicker(
                        customerId: _customerId,
                        selectedDesignId: _solarDesignId,
                        attachedDesign: _attachedSolarDesign,
                        onChanged: (id) {
                          setState(() {
                            _solarDesignId = id;
                            if (id == null) {
                              _attachedSolarDesign = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Address & Branch Configuration Card
              brandingAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (branding) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.dividerColor.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Address & Branch Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        FromAddressSelector(
                          branchId: _fromBranchId,
                          companyAddress: branding.companyAddress,
                          branches: branding.branchAddresses,
                          onChanged: (v) => setState(() {
                            _fromBranchId = v;
                          }),
                        ),

                        const Divider(height: 28),

                        // IMPORTANT:
                        // No dynamic ValueKey here.
                        // PERF: no setState on keystroke. The editor already
                        // shows what the user typed; we only store the value.
                        PartyAddressEditor(
                          title: 'Bill To',
                          party: _billTo,
                          onChanged: (p) {
                            _billTo = p;

                            if (_shipSameAsBill) {
                              _shipTo = p;
                            }
                          },
                        ),

                        const SizedBox(height: 8),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Shipping address is same as billing',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: _shipSameAsBill,
                          onChanged: (v) {
                            setState(() {
                              _shipSameAsBill = v;

                              if (_shipSameAsBill) {
                                _shipTo = _billTo;
                              }
                            });
                          },
                        ),

                        if (!_shipSameAsBill) ...[
                          const SizedBox(height: 8),

                          // IMPORTANT:
                          // No dynamic ValueKey here either.
                          PartyAddressEditor(
                            title: 'Ship To',
                            party: _shipTo,
                            onChanged: (p) {
                              _shipTo = p; // PERF: no setState
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Line Items Header Section
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
                    onPressed: () {
                      setState(() {
                        final newDraft = _LineDraft();

                        _attachLineListeners(newDraft);

                        _lines.add(newDraft);
                      });
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              itemsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(cleanError(e)),
                data: (approved) => Column(
                  children: [
                    for (var i = 0; i < _lines.length; i++)
                      RepaintBoundary(
                        child: _buildLineCard(
                          i,
                          approved,
                          stockByItem,
                          stockRows,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Notes & validity
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes & validity',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _quotationNumber,
                        decoration: InputDecoration(
                          labelText: 'Leave blank to auto-generate',
                          hintText: 'Auto-generated if blank',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        inputFormatters: [LengthLimitingTextInputFormatter(50)],
                        validator: (v) => AppValidators.maxLength(
                          v,
                          max: 50,
                          field: 'Quotation number',
                        ),
                      ),

                      const SizedBox(height: 12),

                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Valid until',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            _validUntil == null
                                ? 'Select Date'
                                : formatDate(_validUntil),
                            style: TextStyle(
                              color: _validUntil == null
                                  ? theme.hintColor
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notes,
                        decoration: InputDecoration(
                          labelText: 'Notes / Remarks',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        maxLines: 2,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500),
                        ],
                        validator: (v) => AppValidators.maxLength(
                          v,
                          max: 500,
                          field: 'Notes',
                        ),
                      ),
                      const SizedBox(height: 12),
                      MarketingTemplatePicker(
                        appliesTo: 'quotation',
                        value: _marketingTemplateId,
                        onChanged: (id) =>
                            setState(() => _marketingTemplateId = id),
                        enabled: !_editBlocked,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Section
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // PERF: only this widget rebuilds while typing qty/price/GST.
                  child: ValueListenableBuilder<int>(
                    valueListenable: _totalsTick,
                    builder: (_, __, ___) =>
                        DocumentTotalsSummary(lines: _lineTotalsInputs()),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Submit Button
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _loading ? null : _save,
                child: Text(
                  isEdit ? 'Update Quotation' : 'Create Quotation',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(
    int index,
    List<ItemModel> approved,
    Map<String, _ItemStockSummary> stockByItem,
    List<StockModel> stockRows,
  ) {
    final line = _lines[index];
    final theme = Theme.of(context);

    String itemPickerLabel(ItemModel item) {
      final stock = _itemStockSummary(item, stockByItem);
      final whLabel = stock.warehouseCount == 1
          ? '1 wh'
          : '${stock.warehouseCount} wh';
      return '${item.name} — ${formatInr(item.sellingPrice)} / ${ItemUnits.labelFor(item.unit)} · $whLabel · stock ${stock.total}';
    }

    ItemModel? selectedItem;
    if (line.itemId != null) {
      for (final it in approved) {
        if (it.id == line.itemId) {
          selectedItem = it;
          break;
        }
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lines.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 32,
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _lines.removeAt(index).dispose();
                      });
                      _bumpTotals();
                    },
                  ),
                ),
              ),

            if (_lines.length > 1) const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: line.itemId,
              isExpanded: true,
              itemHeight: null,
              decoration: InputDecoration(
                labelText: 'Select Item *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              selectedItemBuilder: (context) {
                return approved.map((it) {
                  final stock = _itemStockSummary(it, stockByItem);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${it.name} — ${formatInr(it.sellingPrice)} · stock ${stock.total}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList();
              },
              items: separatedDropdownMenuItems(
                items: approved,
                value: (it) => it.id,
                child: (it) => Text(
                  itemPickerLabel(it),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
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
                    line.price.text = item.sellingPrice > 0
                        ? item.sellingPrice.toString()
                        : '';

                    line.gst.text = item.gstPercent.toString();

                    line.description.text = item.description?.trim() ?? '';

                    final assignedIds = item.stockLevels
                        .map((level) => level.warehouseId)
                        .where((id) => id.isNotEmpty)
                        .toList();
                    if (assignedIds.length == 1) {
                      line.warehouseId = assignedIds.first;
                      line.warehouseName = item.stockLevels.first.warehouseName;
                    } else if (line.warehouseId != null &&
                        !assignedIds.contains(line.warehouseId)) {
                      line.warehouseId = null;
                      line.warehouseName = null;
                    }
                  }
                });
                _bumpTotals();
              },
              validator: (v) => v == null ? 'Select item' : null,
            ),

            if (selectedItem != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Price: ${formatInr(selectedItem.sellingPrice)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Total stock: ${_itemStockSummary(selectedItem, stockByItem).total} units',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (line.warehouseId != null &&
                        line.warehouseId!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final available = _itemStockAtWarehouse(
                            selectedItem!,
                            line.warehouseId,
                            stockRows,
                          );
                          final color = available > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error;

                          return Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Available at warehouse: $available units',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            WarehouseField(
              warehouseId: line.warehouseId,
              warehouseName: line.warehouseName,
              itemId: line.itemId,
              itemWarehouseIds: selectedItem?.stockLevels
                  .map((level) => level.warehouseId)
                  .where((id) => id.isNotEmpty),
              readOnly: false,
              requiredField: true,
              onChanged: (id) {
                setState(() {
                  line.warehouseId = id;
                  line.warehouseName = null;
                });
              },
            ),

            if (selectedItem != null) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final item = selectedItem!;

                  final codes = [
                    if (item.hsnCode != null && item.hsnCode!.isNotEmpty)
                      'HSN: ${item.hsnCode}',
                    if (item.sacCode != null && item.sacCode!.isNotEmpty)
                      'SAC: ${item.sacCode}',
                  ].join(' | ');

                  if (codes.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        codes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: line.qty,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'GST %',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
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
              decoration: InputDecoration(
                labelText: 'Description / Item Details',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
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

/// Shows the selected customer's email, phone and address.
/// NOTE: adjust the field names (email / phone / address / city / state)
/// if your CustomerModel uses different ones.
class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.customer});

  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final location = [
      customer.address,
      customer.city,
      customer.state,
    ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

    Widget row(IconData icon, String? text) {
      if (text == null || text.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.hintColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.email_outlined, customer.email),
          row(Icons.phone_outlined, customer.phone),
          row(Icons.location_on_outlined, location),
        ],
      ),
    );
  }
}

class _ItemStockSummary {
  const _ItemStockSummary({required this.total, required this.warehouseCount});

  final int total;
  final int warehouseCount;
}

Map<String, _ItemStockSummary> _stockSummaryByItem(List<StockModel> stock) {
  final totals = <String, int>{};
  final warehouses = <String, Set<String>>{};

  for (final row in stock) {
    totals[row.itemId] = (totals[row.itemId] ?? 0) + row.currentQuantity;
    warehouses.putIfAbsent(row.itemId, () => {}).add(row.warehouseId);
  }

  return {
    for (final entry in totals.entries)
      entry.key: _ItemStockSummary(
        total: entry.value,
        warehouseCount: warehouses[entry.key]?.length ?? 0,
      ),
  };
}

_ItemStockSummary _itemStockSummary(
  ItemModel item,
  Map<String, _ItemStockSummary> stockByItem,
) {
  // Inventory stock list is current after transfers; item.stockLevels can lag.
  final live = stockByItem[item.id];
  if (live != null && (live.total > 0 || live.warehouseCount > 0)) {
    return live;
  }

  if (item.stockLevels.isNotEmpty) {
    final parsedTotal = item.stockLevels.fold<int>(
      0,
      (sum, level) => sum + level.currentQuantity,
    );
    final total = item.totalQuantity ?? parsedTotal;
    final warehouseCount = item.stockLevels
        .where((level) => level.currentQuantity > 0)
        .length;
    if (total > 0 || parsedTotal > 0) {
      return _ItemStockSummary(
        total: total > 0 ? total : parsedTotal,
        warehouseCount: warehouseCount > 0
            ? warehouseCount
            : item.stockLevels.length,
      );
    }
  }

  return live ?? const _ItemStockSummary(total: 0, warehouseCount: 0);
}

int _itemStockAtWarehouse(
  ItemModel item,
  String? warehouseId,
  List<StockModel> stockRows,
) {
  if (warehouseId == null || warehouseId.isEmpty) return 0;

  final hasLiveRow = stockRows.any(
    (row) => row.itemId == item.id && row.warehouseId == warehouseId,
  );
  if (hasLiveRow) {
    return availableQtyAtWarehouse(item.id, warehouseId, stockRows);
  }

  for (final level in item.stockLevels) {
    if (level.warehouseId == warehouseId) {
      return level.currentQuantity;
    }
  }

  return 0;
}




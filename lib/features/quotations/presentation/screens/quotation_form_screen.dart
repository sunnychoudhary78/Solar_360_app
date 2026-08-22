import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
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
import 'package:solar_sales/shared/widgets/party_address_fields.dart';
import 'package:solar_sales/shared/widgets/warehouse_field.dart';

import '../../data/models/quotation_model.dart';
import '../providers/quotation_providers.dart';

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

  const QuotationFormScreen({
    super.key,
    this.quotationId,
  });

  @override
  ConsumerState<QuotationFormScreen> createState() =>
      _QuotationFormScreenState();
}

class _QuotationFormScreenState
    extends ConsumerState<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _notes = TextEditingController();
  final _quotationNumber = TextEditingController();

  String? _customerId;
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

  bool get isEdit => widget.quotationId != null;

  @override
  void initState() {
    super.initState();
    _attachLineListeners(_lines.first);
  }

  void _attachLineListeners(_LineDraft line) {
    line.qty.addListener(_refreshUi);
    line.price.addListener(_refreshUi);
    line.gst.addListener(_refreshUi);
  }

  void _refreshUi() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
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
    _quotationNumber.text = q.quotationNumber;
    _notes.text = q.notes ?? '';
    _validUntil = q.validUntil;

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
        _shipTo.name == _billTo.name &&
        _shipTo.address == _billTo.address;
  }

  void _onCustomerChanged(
    String? id,
    List<CustomerModel> customers,
  ) {
    setState(() {
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
      ref.read(globalLoadingProvider.notifier).showError(
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

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final lastDate = today.add(
      const Duration(days: 365 * 2),
    );

    var initial =
        _validUntil ?? today.add(const Duration(days: 30));

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
      ref
          .read(globalLoadingProvider.notifier)
          .showError('Select a customer');

      return;
    }

    if (_lines.isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError('Add at least one line item');

      return;
    }

    final dupError =
        AppValidators.duplicateItemWarehousePairs(
      _lines.map(
        (line) => (
          line.itemId,
          line.warehouseId,
        ),
      ),
    );

    if (dupError != null) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(dupError);

      return;
    }

    final items = <QuotationItemModel>[];

    for (final line in _lines) {
      if (line.itemId == null) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError(
              'Select an item for each line',
            );

        return;
      }

      if (line.warehouseId == null ||
          line.warehouseId!.isEmpty) {
        ref
            .read(globalLoadingProvider.notifier)
            .showError(
              'Select a warehouse for each line item',
            );

        return;
      }

      items.add(
        QuotationItemModel(
          itemId: line.itemId!,
          warehouseId: line.warehouseId,
          quantity: int.parse(
            line.qty.text.trim(),
          ),
          unitPrice: double.parse(
            line.price.text.trim(),
          ),
          gstPercent: double.parse(
            line.gst.text.trim(),
          ),
          description:
              line.description.text.trim().isEmpty
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
          isEdit
              ? 'Updating quotation...'
              : 'Creating quotation...',
        );

    try {
      final repo =
          ref.read(quotationRepositoryProvider);

      final fromParty = _fromPartyPayload();

      final qNum =
          _quotationNumber.text.trim();

      final notes =
          _notes.text.trim();

      final wasRejected =
          _status == 'rejected';

      if (isEdit) {
        await repo.update(
          id: widget.quotationId!,
          customerId: _customerId!,
          items: items,
          notes: notes,
          quotationNumber:
              qNum.isEmpty ? null : qNum,
          validUntil: _validUntil,
          billTo: _billTo,
          shipTo:
              _shipSameAsBill
                  ? _billTo
                  : _shipTo,
          shipSameAsBill:
              _shipSameAsBill,
          fromParty: fromParty,
        );
      } else {
        await repo.create(
          customerId: _customerId!,
          items: items,
          notes:
              notes.isEmpty ? null : notes,
          quotationNumber:
              qNum.isEmpty ? null : qNum,
          validUntil: _validUntil,
          billTo: _billTo,
          shipTo:
              _shipSameAsBill
                  ? _billTo
                  : _shipTo,
          shipSameAsBill:
              _shipSameAsBill,
          fromParty: fromParty,
        );
      }

      ref.invalidate(
        quotationListProvider,
      );

      ref.invalidate(
        pendingQuotationsProvider,
      );

      if (isEdit) {
        ref.invalidate(
          quotationDetailProvider(
            widget.quotationId!,
          ),
        );
      }

      ref
          .read(globalLoadingProvider.notifier)
          .hide();

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
        Navigator.pop(
          context,
          true,
        );
      }
    } catch (e) {
      ref
          .read(globalLoadingProvider.notifier)
          .hide();

      ref
          .read(globalLoadingProvider.notifier)
          .showApiError(e);
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
      final async =
          ref.watch(
            quotationDetailProvider(
              widget.quotationId!,
            ),
          );

      return async.when(
        loading: () => const Scaffold(
          body: LoadingState(),
        ),
        error: (e, _) => Scaffold(
          appBar: const AppAppBar(
            title: 'Edit Quotation',
          ),
          body: ErrorState(
            message: cleanError(e),
            onRetry: () {
              ref.invalidate(
                quotationDetailProvider(
                  widget.quotationId!,
                ),
              );
            },
          ),
        ),
        data: (q) {
          if (!_initialized) {
            final auth =
                ref.read(authProvider);

            final allowed =
                DocumentWorkflow.canEditQuotation(
              q.status,
              canCreate:
                  auth.hasPermission(
                'quotation.create',
              ),
              canApprove:
                  auth.hasPermission(
                'quotation.approve',
              ),
            );

            if (!allowed) {
              _editBlocked = true;
              _initialized = true;
              _status = q.status;

              WidgetsBinding.instance
                  .addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }

                ref
                    .read(
                      globalLoadingProvider
                          .notifier,
                    )
                    .showError(
                      q.status ==
                              'pending_approval'
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
            return const Scaffold(
              body: LoadingState(),
            );
          }

          return _buildForm();
        },
      );
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final customersAsync =
        ref.watch(customerListProvider);

    final itemsAsync =
        ref.watch(approvedItemsProvider);

    final brandingAsync =
        ref.watch(solarBrandingProvider);

    final theme =
        Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title:
            isEdit
                ? 'Edit Quotation'
                : 'New Quotation',
      ),
      body: Form(
        key: _formKey,
        autovalidateMode:
            AutovalidateMode
                .onUserInteraction,
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context)
                    .padding
                    .bottom +
                24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // Customer Details Card
              Card(
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  side: BorderSide(
                    color: theme
                        .dividerColor
                        .withOpacity(
                          0.4,
                        ),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer Details',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      if (customersAsync
                              .isLoading &&
                          customersAsync
                              .items
                              .isEmpty)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<
                            String>(
                          value:
                              _customerId,
                          isExpanded: true,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Select Customer *',
                            prefixIcon:
                                const Icon(
                              Icons
                                  .person_outline,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  12,
                              vertical:
                                  14,
                            ),
                          ),
                          items:
                              customersAsync
                                  .items
                                  .map(
                            (
                              CustomerModel
                                  c,
                            ) =>
                                DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ).toList(),
                          onChanged: (v) =>
                              _onCustomerChanged(
                            v,
                            customersAsync
                                .items,
                          ),
                          validator: (v) =>
                              v == null ||
                                      v.isEmpty
                                  ? 'Select a customer'
                                  : null,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // Address & Branch Configuration Card
              brandingAsync.when(
                loading: () =>
                    const LinearProgressIndicator(),
                error: (_, __) =>
                    const SizedBox.shrink(),
                data: (branding) =>
                    Card(
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    side: BorderSide(
                      color: theme
                          .dividerColor
                          .withOpacity(
                            0.4,
                          ),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Address & Branch Configuration',
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        FromAddressSelector(
                          branchId:
                              _fromBranchId,
                          companyAddress:
                              branding
                                  .companyAddress,
                          branches:
                              branding
                                  .branchAddresses,
                          onChanged: (v) =>
                              setState(
                            () {
                              _fromBranchId =
                                  v;
                            },
                          ),
                        ),

                        const Divider(
                          height: 28,
                        ),

                        // IMPORTANT:
                        // No dynamic ValueKey here.
                        // This keeps the PartyAddressEditor
                        // alive while the user types.
                        PartyAddressEditor(
                          title:
                              'Bill To',
                          party:
                              _billTo,
                          onChanged:
                              (p) {
                            setState(() {
                              _billTo = p;

                              if (_shipSameAsBill) {
                                _shipTo =
                                    p;
                              }
                            });
                          },
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        SwitchListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          title:
                              const Text(
                            'Shipping address is same as billing',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          value:
                              _shipSameAsBill,
                          onChanged: (v) {
                            setState(() {
                              _shipSameAsBill =
                                  v;

                              if (_shipSameAsBill) {
                                _shipTo =
                                    _billTo;
                              }
                            });
                          },
                        ),

                        if (!_shipSameAsBill) ...[
                          const SizedBox(
                            height: 8,
                          ),

                          // IMPORTANT:
                          // No dynamic ValueKey here either.
                          PartyAddressEditor(
                            title:
                                'Ship To',
                            party:
                                _shipTo,
                            onChanged:
                                (p) {
                              setState(() {
                                _shipTo =
                                    p;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // Line Items Header Section
              Row(
                children: [
                  Text(
                    'Line Items',
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final newDraft =
                            _LineDraft();

                        _attachLineListeners(
                          newDraft,
                        );

                        _lines.add(
                          newDraft,
                        );
                      });
                    },
                    icon: const Icon(
                      Icons.add,
                      size: 18,
                    ),
                    label:
                        const Text(
                      'Add Item',
                    ),
                    style:
                        OutlinedButton
                            .styleFrom(
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              itemsAsync.when(
                loading: () =>
                    const Padding(
                  padding:
                      EdgeInsets.all(
                    16,
                  ),
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) =>
                    Text(
                  cleanError(e),
                ),
                data: (approved) =>
                    Column(
                  children: [
                    for (
                      var i = 0;
                      i < _lines.length;
                      i++
                    )
                      _buildLineCard(
                        i,
                        approved,
                      ),
                  ],
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // Notes & validity
              Card(
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  side: BorderSide(
                    color: theme
                        .dividerColor
                        .withOpacity(
                          0.4,
                        ),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes & validity',
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextFormField(
                        controller:
                            _quotationNumber,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Leave blank to auto-generate',
                          hintText:
                              'Auto-generated if blank',
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                12,
                            vertical:
                                14,
                          ),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            50,
                          ),
                        ],
                        validator: (v) =>
                            AppValidators
                                .maxLength(
                          v,
                          max: 50,
                          field:
                              'Quotation number',
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      InkWell(
                        onTap:
                            _pickDate,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        child:
                            InputDecorator(
                          decoration:
                              InputDecoration(
                            labelText:
                                'Valid until',
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  12,
                              vertical:
                                  14,
                            ),
                          ),
                          child: Text(
                            _validUntil ==
                                    null
                                ? 'Select Date'
                                : formatDate(
                                    _validUntil,
                                  ),
                            style:
                                TextStyle(
                              color:
                                  _validUntil ==
                                          null
                                      ? theme
                                          .hintColor
                                      : theme
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      TextFormField(
                        controller:
                            _notes,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Notes / Remarks',
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                12,
                            vertical:
                                14,
                          ),
                        ),
                        maxLines: 2,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            500,
                          ),
                        ],
                        validator: (v) =>
                            AppValidators
                                .maxLength(
                          v,
                          max: 500,
                          field: 'Notes',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // Summary Section
              Card(
                elevation: 0,
                color: theme
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  side: BorderSide(
                    color: theme
                        .dividerColor
                        .withOpacity(
                          0.4,
                        ),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child:
                      DocumentTotalsSummary(
                    lines:
                        _lineTotalsInputs(),
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // Action Submit Button
              FilledButton(
                style:
                    FilledButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(
                    52,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                onPressed:
                    _loading ? null : _save,
                child: Text(
                  isEdit
                      ? 'Update Quotation'
                      : 'Create Quotation',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
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
  ) {
    final line = _lines[index];
    final theme =
        Theme.of(context);
    final stockByItem = _stockSummaryByItem(
      ref.watch(stockListProvider).items,
    );

    String itemPickerLabel(ItemModel item) {
      final stock = _itemStockSummary(item, stockByItem);
      final whLabel =
          stock.warehouseCount == 1 ? '1 wh' : '${stock.warehouseCount} wh';
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
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        side: BorderSide(
          color: theme
              .dividerColor
              .withOpacity(
                0.4,
              ),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          12,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            if (_lines.length > 1)
              Align(
                alignment:
                    Alignment.centerRight,
                child: SizedBox(
                  height: 32,
                  width: 32,
                  child: IconButton(
                    padding:
                        EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(),
                    visualDensity:
                        VisualDensity
                            .compact,
                    icon: Icon(
                      Icons
                          .delete_outline,
                      color: theme
                          .colorScheme
                          .error,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _lines
                            .removeAt(
                              index,
                            )
                            .dispose();
                      });
                    },
                  ),
                ),
              ),

            if (_lines.length > 1)
              const SizedBox(
                height: 8,
              ),

            DropdownButtonFormField<
                String>(
              value: line.itemId,
              isExpanded: true,
              decoration:
                  InputDecoration(
                labelText:
                    'Select Item *',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      12,
                  vertical:
                      12,
                ),
              ),
              selectedItemBuilder:
                  (context) {
                return approved
                    .map(
                  (it) {
                    final stock =
                        _itemStockSummary(it, stockByItem);
                    return Align(
                      alignment:
                          Alignment
                              .centerLeft,
                      child: Text(
                        '${it.name} — ${formatInr(it.sellingPrice)} · stock ${stock.total}',
                        overflow:
                            TextOverflow
                                .ellipsis,
                        maxLines: 1,
                      ),
                    );
                  },
                ).toList();
              },
              items: approved
                  .map(
                (it) =>
                    DropdownMenuItem(
                  value: it.id,
                  child: Text(
                    itemPickerLabel(it),
                    overflow:
                        TextOverflow
                            .ellipsis,
                    maxLines: 2,
                  ),
                ),
              )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  line.itemId = v;

                  ItemModel? item;

                  for (final it
                      in approved) {
                    if (it.id == v) {
                      item = it;
                      break;
                    }
                  }

                  if (item != null) {
                    line.price.text =
                        item.sellingPrice >
                                0
                            ? item
                                .sellingPrice
                                .toString()
                            : '';

                    line.gst.text =
                        item.gstPercent
                            .toString();

                    line.description
                            .text =
                        item.description
                            ?.trim() ??
                        '';
                  }
                });
              },
              validator: (v) =>
                  v == null
                      ? 'Select item'
                      : null,
            ),

            if (selectedItem != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
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
                      'Stock: ${_itemStockSummary(selectedItem, stockByItem).total} units',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(
              height: 12,
            ),

            WarehouseField(
              warehouseId:
                  line.warehouseId,
              warehouseName:
                  line.warehouseName,
              itemId: line.itemId,
              readOnly: false,
              requiredField: true,
              onChanged: (id) {
                setState(() {
                  line.warehouseId =
                      id;
                  line.warehouseName =
                      null;
                });
              },
            ),

            if (line.itemId != null) ...[
              const SizedBox(
                height: 6,
              ),
              Builder(
                builder:
                    (context) {
                  ItemModel? selected;

                  for (final it
                      in approved) {
                    if (it.id ==
                        line.itemId) {
                      selected = it;
                      break;
                    }
                  }

                  if (selected ==
                      null) {
                    return const SizedBox
                        .shrink();
                  }

                  final item =
                      selected;

                  final codes = [
                    if (item.hsnCode !=
                            null &&
                        item.hsnCode!
                            .isNotEmpty)
                      'HSN: ${item.hsnCode}',
                    if (item.sacCode !=
                            null &&
                        item.sacCode!
                            .isNotEmpty)
                      'SAC: ${item.sacCode}',
                  ].join(' | ');

                  if (codes.isEmpty) {
                    return const SizedBox
                        .shrink();
                  }

                  return Align(
                    alignment:
                        Alignment
                            .centerLeft,
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        left: 4,
                      ),
                      child: Text(
                        codes,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme
                              .hintColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(
              height: 12,
            ),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Expanded(
                  flex: 2,
                  child:
                      TextFormField(
                    controller:
                        line.qty,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Qty',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            10,
                        vertical:
                            12,
                      ),
                    ),
                    keyboardType:
                        TextInputType
                            .number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly,
                      LengthLimitingTextInputFormatter(
                        8,
                      ),
                    ],
                    validator: (v) =>
                        AppValidators
                            .positiveNumber(
                      v,
                      'Qty',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  flex: 3,
                  child:
                      TextFormField(
                    controller:
                        line.price,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Price',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            10,
                        vertical:
                            12,
                      ),
                    ),
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .allow(
                        RegExp(
                          r'[0-9.]',
                        ),
                      ),
                      LengthLimitingTextInputFormatter(
                        12,
                      ),
                    ],
                    validator: (v) =>
                        AppValidators
                            .nonNegativeNumber(
                      v,
                      'Price',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  flex: 2,
                  child:
                      TextFormField(
                    controller:
                        line.gst,
                    decoration:
                        InputDecoration(
                      labelText:
                          'GST %',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            10,
                        vertical:
                            12,
                      ),
                    ),
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .allow(
                        RegExp(
                          r'[0-9.]',
                        ),
                      ),
                      LengthLimitingTextInputFormatter(
                        6,
                      ),
                    ],
                    validator:
                        AppValidators
                            .gstPercent,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            TextFormField(
              controller:
                  line.description,
              decoration:
                  InputDecoration(
                labelText:
                    'Description / Item Details',
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      12,
                  vertical:
                      12,
                ),
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  250,
                ),
              ],
              validator: (v) =>
                  AppValidators
                      .maxLength(
                v,
                max: 250,
                field:
                    'Description',
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<LineTotalsInput>
      _lineTotalsInputs() {
    return _lines
        .where(
          (l) => l.itemId != null,
        )
        .map((l) {
          final qty =
              int.tryParse(
                    l.qty.text.trim(),
                  ) ??
                  0;

          final price =
              double.tryParse(
                    l.price.text.trim(),
                  ) ??
                  0;

          final gst =
              double.tryParse(
                    l.gst.text.trim(),
                  ) ??
                  0;

          return LineTotalsInput(
            quantity: qty,
            unitPrice: price,
            gstPercent: gst,
          );
        })
        .where(
          (l) => l.quantity > 0,
        )
        .toList();
  }
}

class _ItemStockSummary {
  const _ItemStockSummary({
    required this.total,
    required this.warehouseCount,
  });

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
  if (item.stockLevels.isNotEmpty) {
    final total = item.totalQuantity ??
        item.stockLevels.fold<int>(
          0,
          (sum, level) => sum + level.currentQuantity,
        );
    final warehouseCount = item.stockLevels
        .where((level) => level.currentQuantity > 0)
        .length;
    return _ItemStockSummary(
      total: total,
      warehouseCount:
          warehouseCount > 0 ? warehouseCount : item.stockLevels.length,
    );
  }

  return stockByItem[item.id] ??
      const _ItemStockSummary(total: 0, warehouseCount: 0);
}
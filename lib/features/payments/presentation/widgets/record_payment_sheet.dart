import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/constants/payment_modes.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/payment_models.dart';
import '../providers/payment_providers.dart';

/// Record payment sheet — amount defaults to the remaining balance (§7.5).
/// Returns true when a receipt was recorded.
Future<bool> showRecordPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  PaymentScheduleModel schedule, {
  String? invoiceId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _RecordPaymentSheet(
      schedule: schedule,
      invoiceId: invoiceId ?? schedule.sourceId,
    ),
  );
  return result ?? false;
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({required this.schedule, this.invoiceId});

  final PaymentScheduleModel schedule;
  final String? invoiceId;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _mode = 'UPI';
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.schedule.balance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _paidAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _paidAt.hour,
        _paidAt.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.parse(_amountController.text.trim());
    setState(() => _saving = true);
    ref.read(globalLoadingProvider.notifier).showLoading('Recording receipt...');
    try {
      await ref.read(paymentRepositoryProvider).recordReceipt(
            scheduleId: widget.schedule.id,
            amount: amount,
            mode: _mode,
            referenceNo: _referenceController.text,
            paidAt: _paidAt,
            notes: _notesController.text,
          );
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Payment recorded');
      invalidatePaymentSurfaces(ref, invoiceId: widget.invoiceId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balance = widget.schedule.balance;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Record payment',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.schedule.displayTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        label: 'Milestone',
                        value: formatInr(widget.schedule.amount),
                      ),
                    ),
                    Expanded(
                      child: _Summary(
                        label: 'Received',
                        value: formatInr(widget.schedule.paidAmount),
                      ),
                    ),
                    Expanded(
                      child: _Summary(
                        label: 'Balance',
                        value: formatInr(balance),
                        highlight: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                  if (parsed > balance + 0.009) {
                    return 'Amount exceeds balance of ${formatInr(balance)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: PaymentModes.values
                    .map(
                      (mode) =>
                          DropdownMenuItem<String>(value: mode, child: Text(mode)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _mode = value ?? _mode),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _referenceController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Reference / UTR (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Paid on',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(formatDate(_paidAt)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Recording…' : 'Record payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.primary : null,
          ),
        ),
      ],
    );
  }
}

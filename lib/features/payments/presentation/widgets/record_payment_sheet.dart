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
///
/// [accent], [index] and [total] are optional: when passed from the invoice
/// panel the sheet uses the same colour / "Milestone 1 of 2" tag as the card
/// the user tapped, so it is obvious which block they are paying.
Future<bool> showRecordPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  PaymentScheduleModel schedule, {
  String? invoiceId,
  Color? accent,
  int? index,
  int? total,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _RecordPaymentSheet(
      schedule: schedule,
      invoiceId: invoiceId ?? schedule.sourceId,
      accent: accent,
      index: index,
      total: total,
    ),
  );
  return result ?? false;
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({
    required this.schedule,
    this.invoiceId,
    this.accent,
    this.index,
    this.total,
  });

  final PaymentScheduleModel schedule;
  final String? invoiceId;
  final Color? accent;
  final int? index;
  final int? total;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  late String _mode;
  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.schedule.balance.toStringAsFixed(2),
    );
    final modes = PaymentModes.values;
    _mode = modes.contains('UPI')
        ? 'UPI'
        : (modes.isNotEmpty ? modes.first : 'UPI');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double value) {
    _amountController.text = value.toStringAsFixed(2);
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
    setState(() {});
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
    FocusScope.of(context).unfocus();
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
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accent ?? scheme.primary;
    final fg = _onAccent(accent);
    final schedule = widget.schedule;
    final balance = schedule.balance;
    final progress = schedule.amount <= 0
        ? 0.0
        : (schedule.paidAmount / schedule.amount).clamp(0.0, 1.0);
    final typedAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final remainingAfter = (balance - typedAmount).clamp(0.0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.payments_outlined, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record payment',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          schedule.displayTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.index != null && widget.total != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${widget.index! + 1} / ${widget.total}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Milestone summary ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.45 : 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Summary(
                            label: 'Milestone',
                            value: formatInr(schedule.amount),
                          ),
                        ),
                        Expanded(
                          child: _Summary(
                            label: 'Received',
                            value: formatInr(schedule.paidAmount),
                          ),
                        ),
                        Expanded(
                          child: _Summary(
                            label: 'Balance',
                            value: formatInr(balance),
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: accent,
                        backgroundColor: accent.withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Amount ────────────────────────────────────────────────
              TextFormField(
                controller: _amountController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ActionChip(
                    label: const Text('Full balance'),
                    onPressed: _saving ? null : () => _setAmount(balance),
                  ),
                  ActionChip(
                    label: const Text('50%'),
                    onPressed: _saving ? null : () => _setAmount(balance / 2),
                  ),
                  if (typedAmount > 0 && typedAmount <= balance + 0.009)
                    Text(
                      remainingAfter <= 0.009
                          ? 'Milestone will be fully paid'
                          : 'Remaining after: ${formatInr(remainingAfter)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Mode (chips instead of dropdown: 1 tap) ───────────────
              Text(
                'Payment mode',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final mode in PaymentModes.values)
                    ChoiceChip(
                      label: Text(mode),
                      selected: _mode == mode,
                      selectedColor: accent.withValues(
                        alpha: isDark ? 0.28 : 0.18,
                      ),
                      checkmarkColor: accent,
                      labelStyle: TextStyle(
                        fontWeight: _mode == mode
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: _mode == mode ? accent : null,
                      ),
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Reference + Date (same row on wide, stacked otherwise) ─
              TextFormField(
                controller: _referenceController,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Reference / UTR (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
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
                maxLength: 250,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Actions ───────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: fg,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        _saving
                            ? 'Recording…'
                            : (typedAmount > 0
                                ? 'Record ${formatInr(typedAmount)}'
                                : 'Record payment'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Readable text/icon colour to place on top of a solid [accent] fill.
Color _onAccent(Color accent) =>
    ThemeData.estimateBrightnessForColor(accent) == Brightness.light
        ? const Color(0xFF111827)
        : Colors.white;

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

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
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
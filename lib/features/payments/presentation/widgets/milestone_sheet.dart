import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/payment_models.dart';
import '../payment_format.dart';
import '../providers/payment_providers.dart';

/// Add an extra milestone (§7.6) or edit an existing one (§7.7).
/// Pass [schedule] to edit; omit it to add against [invoiceId].
Future<bool> showMilestoneSheet(
  BuildContext context,
  WidgetRef ref, {
  required String invoiceId,
  PaymentScheduleModel? schedule,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _MilestoneSheet(
      invoiceId: invoiceId,
      schedule: schedule,
    ),
  );
  return result ?? false;
}

class _MilestoneSheet extends ConsumerStatefulWidget {
  const _MilestoneSheet({required this.invoiceId, this.schedule});

  final String invoiceId;
  final PaymentScheduleModel? schedule;

  @override
  ConsumerState<_MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends ConsumerState<_MilestoneSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  DateTime? _dueDate;
  bool _isCustomerDue = true;
  bool _saving = false;

  bool get _isEdit => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _titleController = TextEditingController(text: schedule?.title ?? '');
    _amountController = TextEditingController(
      text: schedule == null ? '' : schedule.amount.toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: schedule?.notes ?? '');
    _dueDate = parseDueDate(schedule?.dueDate) ?? DateTime.now();
    _isCustomerDue = schedule?.isCustomerDue ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amountController.text.trim());
    final dueDate = _dueDate == null ? null : formatDueDateYmd(_dueDate!);

    setState(() => _saving = true);
    ref.read(globalLoadingProvider.notifier).showLoading(
          _isEdit ? 'Updating milestone...' : 'Adding milestone...',
        );
    try {
      final repo = ref.read(paymentRepositoryProvider);
      if (_isEdit) {
        await repo.updateSchedule(
          widget.schedule!.id,
          title: _titleController.text,
          amount: amount,
          dueDate: dueDate,
          notes: _notesController.text,
        );
      } else {
        await repo.addSchedule(
          sourceId: widget.invoiceId,
          title: _titleController.text,
          amount: amount,
          dueDate: dueDate,
          isCustomerDue: _isCustomerDue,
        );
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess(
            _isEdit ? 'Milestone updated' : 'Milestone added',
          );
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
    final paidAmount = widget.schedule?.paidAmount ?? 0;

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
                _isEdit ? 'Edit milestone' : 'Add milestone',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 4),
                Text(
                  'Received so far ${formatInr(paidAmount)} — amount cannot go below this.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Extra material',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Title is required'
                    : null,
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
                  if (parsed < paidAmount - 0.009) {
                    return 'Amount cannot be less than received '
                        '${formatInr(paidAmount)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(
                    _dueDate == null ? 'Not set' : formatDate(_dueDate),
                  ),
                ),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isCustomerDue,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isCustomerDue = value),
                  title: const Text('Customer due'),
                  subtitle: const Text(
                    'Counted in collections and overdue reminders',
                  ),
                ),
              ] else ...[
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
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _saving ? null : _submit,
                child: Text(
                  _saving
                      ? 'Saving…'
                      : (_isEdit ? 'Save changes' : 'Add milestone'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

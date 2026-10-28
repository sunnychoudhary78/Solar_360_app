import 'package:flutter/material.dart';

import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

Future<Map<String, dynamic>?> showAmcStartSheet(
  BuildContext context, {
  required AmcPlant plant,
  required List<AmcAssignee> assignees,
  required List<int> visitsPerYearOptions,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AmcStartSheet(
      plant: plant,
      assignees: assignees,
      visitsPerYearOptions: visitsPerYearOptions,
    ),
  );
}

class _AmcStartSheet extends StatefulWidget {
  const _AmcStartSheet({
    required this.plant,
    required this.assignees,
    required this.visitsPerYearOptions,
  });

  final AmcPlant plant;
  final List<AmcAssignee> assignees;
  final List<int> visitsPerYearOptions;

  @override
  State<_AmcStartSheet> createState() => _AmcStartSheetState();
}

class _AmcStartSheetState extends State<_AmcStartSheet> {
  late String _startDate;
  late int _visitsPerYear;
  String? _assigneeId;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDate = todayIstYmd();
    final opts = widget.visitsPerYearOptions;
    _visitsPerYear = opts.contains(2) ? 2 : (opts.isNotEmpty ? opts.first : 2);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_startDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _submit() {
    if (_saving) return;
    setState(() => _saving = true);
    Navigator.pop(context, {
      'lead_id': widget.plant.leadId,
      'start_date': _startDate,
      'visits_per_year': _visitsPerYear,
      if (_assigneeId != null && _assigneeId!.isNotEmpty)
        'assignee_id': _assigneeId,
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start AMC',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.plant.leadCode} — ${widget.plant.fullName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(formatAmcDate(_startDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Text(
              'Visits per year',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.visitsPerYearOptions.map((n) {
                final selected = _visitsPerYear == n;
                return ChoiceChip(
                  label: Text('$n'),
                  selected: selected,
                  onSelected: (_) => setState(() => _visitsPerYear = n),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use — match app pattern; initialValue is not controlled
              value: _assigneeId ?? '',
              decoration: const InputDecoration(
                labelText: 'Assignee (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Unassigned'),
                ),
                ...widget.assignees.map(
                  (a) => DropdownMenuItem<String>(
                    value: a.id,
                    child: Text(a.optionLabel),
                  ),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _assigneeId = (v == null || v.isEmpty) ? null : v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: const Text('Start AMC'),
            ),
            const SizedBox(height: 8),
            Text(
              'Creates one contract and schedules visits across 12 months.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> runAmcAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successMessage,
}) async {
  try {
    await action();
    if (context.mounted) {
      showAppSnackBar(context, successMessage);
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }
}

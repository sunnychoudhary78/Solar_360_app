import 'package:flutter/material.dart';

import 'package:solar_sales/features/amc/data/models/amc_models.dart';

Future<Map<String, dynamic>?> showAmcExtraVisitSheet(
  BuildContext context, {
  required AmcPlant plant,
  required List<AmcAssignee> assignees,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AmcExtraVisitSheet(
      plant: plant,
      assignees: assignees,
    ),
  );
}

class _AmcExtraVisitSheet extends StatefulWidget {
  const _AmcExtraVisitSheet({
    required this.plant,
    required this.assignees,
  });

  final AmcPlant plant;
  final List<AmcAssignee> assignees;

  @override
  State<_AmcExtraVisitSheet> createState() => _AmcExtraVisitSheetState();
}

class _AmcExtraVisitSheetState extends State<_AmcExtraVisitSheet> {
  late String _scheduledDate;
  String? _assigneeId;
  final _title = TextEditingController();
  final _findings = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _scheduledDate = todayIstYmd();
  }

  @override
  void dispose() {
    _title.dispose();
    _findings.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_scheduledDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _scheduledDate =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _submit() {
    final contractId = widget.plant.contract?.id ?? '';
    if (contractId.isEmpty) {
      setState(() => _error = 'This plant has no active AMC contract');
      return;
    }
    if (_scheduledDate.isEmpty) {
      setState(() => _error = 'Scheduled date is required');
      return;
    }
    Navigator.pop(context, {
      'contract_id': contractId,
      'scheduled_date': _scheduledDate,
      if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
      if (_assigneeId != null && _assigneeId!.isNotEmpty)
        'assignee_id': _assigneeId,
      if (_findings.text.trim().isNotEmpty) 'findings': _findings.text.trim(),
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
              'Extra visit',
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
              title: const Text('Scheduled date'),
              subtitle: Text(formatAmcDate(_scheduledDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                border: OutlineInputBorder(),
              ),
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
              controller: _findings,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Add visit'),
            ),
          ],
        ),
      ),
    );
  }
}

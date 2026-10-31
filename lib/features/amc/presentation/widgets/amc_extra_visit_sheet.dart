import 'package:flutter/material.dart';

import 'package:solar_sales/features/amc/data/models/amc_models.dart';

Future<Map<String, dynamic>?> showAmcExtraVisitSheet(
  BuildContext context, {
  AmcPlant? plant,
  required List<AmcPlant> plantsWithAmc,
  required List<AmcAssignee> assignees,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AmcExtraVisitSheet(
      plant: plant,
      plantsWithAmc: plantsWithAmc,
      assignees: assignees,
    ),
  );
}

class _AmcExtraVisitSheet extends StatefulWidget {
  const _AmcExtraVisitSheet({
    this.plant,
    required this.plantsWithAmc,
    required this.assignees,
  });

  final AmcPlant? plant;
  final List<AmcPlant> plantsWithAmc;
  final List<AmcAssignee> assignees;

  @override
  State<_AmcExtraVisitSheet> createState() => _AmcExtraVisitSheetState();
}

class _AmcExtraVisitSheetState extends State<_AmcExtraVisitSheet> {
  late String _scheduledDate;
  late String _contractId;
  String _assigneeId = '';
  final _title = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _scheduledDate = todayIstYmd();
    _contractId = widget.plant?.contract?.id ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
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
    if (_contractId.isEmpty) {
      setState(() => _error = 'Select a plant with an active AMC');
      return;
    }
    Navigator.pop(context, {
      'contract_id': _contractId,
      'scheduled_date': _scheduledDate,
      if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
      'assignee_id': _assigneeId.isEmpty ? null : _assigneeId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final lockedPlant = widget.plant;

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
              'Add a one-off maintenance visit on this AMC.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            if (lockedPlant != null)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Plant',
                  border: OutlineInputBorder(),
                ),
                child: Text(lockedPlant.plantLabel),
              )
            else
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _contractId.isEmpty ? null : _contractId,
                decoration: const InputDecoration(
                  labelText: 'Plant',
                  border: OutlineInputBorder(),
                ),
                items: widget.plantsWithAmc
                    .where((p) => p.contract?.id.isNotEmpty == true)
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.contract!.id,
                        child: Text(p.plantLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _contractId = v ?? ''),
              ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visit date'),
              subtitle: Text(formatAmcDate(_scheduledDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Optional — e.g. Emergency cleaning',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _assigneeId,
              decoration: const InputDecoration(
                labelText: 'Technician',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Unassigned')),
                ...widget.assignees.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                ),
              ],
              onChanged: (v) => setState(() => _assigneeId = v ?? ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
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

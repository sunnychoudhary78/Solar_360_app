import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';
import 'package:solar_sales/features/solar_tasks/data/solar_task_constants.dart';
import 'package:solar_sales/features/solar_tasks/presentation/providers/solar_task_providers.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/dropdown_separated_item.dart';

Future<void> showSolarTaskFormSheet({
  required BuildContext context,
  required WidgetRef ref,
  SolarTaskFormData? initial,
  String? preferredPhaseKey,
}) {
  final board = ref.read(solarTaskBoardProvider);
  final notifier = ref.read(solarTaskBoardProvider.notifier);
  final form = initial ??
      SolarTaskFormData(
        leadId: board.projectId,
        phaseKey: preferredPhaseKey?.isNotEmpty == true
            ? preferredPhaseKey!
            : (board.phaseFilter.isNotEmpty
                ? board.phaseFilter
                : (board.phases.isNotEmpty
                    ? board.phases.first.key
                    : 'sales')),
      );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return _SolarTaskFormSheet(
        initial: form,
        canOpenLeads: notifier.canOpenLeads,
      );
    },
  );
}

class _SolarTaskFormSheet extends ConsumerStatefulWidget {
  const _SolarTaskFormSheet({
    required this.initial,
    required this.canOpenLeads,
  });

  final SolarTaskFormData initial;
  final bool canOpenLeads;

  @override
  ConsumerState<_SolarTaskFormSheet> createState() =>
      _SolarTaskFormSheetState();
}

class _SolarTaskFormSheetState extends ConsumerState<_SolarTaskFormSheet> {
  late SolarTaskFormData _form;
  String _formError = '';
  bool _saving = false;
  bool _loadingDeps = false;

  @override
  void initState() {
    super.initState();
    _form = widget.initial;
    Future.microtask(_loadDeps);
  }

  Future<void> _loadDeps() async {
    if (_form.leadId.isEmpty) return;
    setState(() => _loadingDeps = true);
    await ref
        .read(solarTaskBoardProvider.notifier)
        .loadDependencyOptions(_form.leadId);
    if (mounted) setState(() => _loadingDeps = false);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _form.startDate : _form.dueDate;
    DateTime initial = DateTime.now();
    if (current.isNotEmpty) {
      final parsed = DateTime.tryParse(current);
      if (parsed != null) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final value =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      _form = isStart
          ? _form.copyWith(startDate: value)
          : _form.copyWith(dueDate: value);
    });
  }

  Future<void> _save() async {
    if (_form.leadId.isEmpty) {
      setState(() => _formError = 'Choose a lead');
      return;
    }
    if (_form.assigneeId.isEmpty) {
      setState(
        () => _formError =
            'Choose who this task is assigned to. Only that person will see it.',
      );
      return;
    }
    if (_form.title.trim().isEmpty) {
      setState(() => _formError = 'Title is required');
      return;
    }
    if (_form.startDate.isNotEmpty &&
        _form.dueDate.isNotEmpty &&
        _form.startDate.compareTo(_form.dueDate) > 0) {
      setState(() => _formError = 'Deadline cannot be before the start date');
      return;
    }

    final notifier = ref.read(solarTaskBoardProvider.notifier);
    setState(() {
      _saving = true;
      _formError = '';
    });
    try {
      final payload = _form.toPayload();
      await notifier.saveTask(_form);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(context, notifier.successMessage(_form, payload));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = cleanError(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(solarTaskBoardProvider);
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dependencyGroups = board.phases
        .map(
          (phase) => (
            phase: phase,
            tasks: board.dependencyOptions
                .where(
                  (task) =>
                      task.phaseKey == phase.key && task.id != _form.id,
                )
                .toList(growable: false),
          ),
        )
        .where((group) => group.tasks.isNotEmpty)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Text(
                _form.isEditing ? 'Edit task' : 'Add task',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                board.projects.isEmpty
                    ? 'This task needs a solar lead. Create the lead first, then come back to add tasks.'
                    : 'Choose the lead, the person who should see this task, the phase, the deadline, and which steps must finish first.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              if (board.projects.isEmpty) ...[
                Text(
                  'A project is created as a lead, from the Leads page. After you save the lead, it shows up in the Project list on this page.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (widget.canOpenLeads) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/solar/leads');
                    },
                    child: const Text('Go to Leads'),
                  ),
                ],
              ] else ...[
                const _FieldLabel('Lead', isRequired: true),
                DropdownButtonFormField<String>(
                  key: ValueKey('lead-${_form.leadId}'),
                  initialValue: _form.leadId.isEmpty ? null : _form.leadId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Select a lead'),
                  selectedItemBuilder: (context) => [
                    for (final project in board.projects)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${project.leadCode} — ${project.fullName}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                  ],
                  items: separatedDropdownMenuItems(
                    items: board.projects,
                    value: (p) => p.id,
                    child: (p) => Text(
                      '${p.leadCode} — ${p.fullName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onChanged: _form.isEditing
                      ? null
                      : (value) async {
                          setState(() {
                            _form = _form.copyWith(
                              leadId: value ?? '',
                              dependsOnIds: const [],
                            );
                          });
                          await _loadDeps();
                        },
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Title', isRequired: true),
                TextFormField(
                  initialValue: _form.title,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'What needs to be done',
                    counterText: '',
                  ),
                  onChanged: (value) =>
                      setState(() => _form = _form.copyWith(title: value)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Phase', isRequired: true),
                          DropdownButtonFormField<String>(
                            key: ValueKey('phase-${_form.phaseKey}'),
                            initialValue: _form.phaseKey,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            selectedItemBuilder: (context) => [
                              for (final phase in board.phases)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    phase.label,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                            items: separatedDropdownMenuItems(
                              items: board.phases,
                              value: (p) => p.key,
                              child: (p) => Text(p.label),
                            ),
                            onChanged: (value) => setState(
                              () => _form =
                                  _form.copyWith(phaseKey: value ?? 'sales'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Assignee', isRequired: true),
                          DropdownButtonFormField<String>(
                            key: ValueKey('assignee-${_form.assigneeId}'),
                            initialValue: _form.assigneeId.isEmpty
                                ? null
                                : _form.assigneeId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            hint: const Text('Select a person'),
                            selectedItemBuilder: (context) => [
                              for (final person in board.assignees)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    person.optionLabel,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                            items: separatedDropdownMenuItems(
                              items: board.assignees,
                              value: (a) => a.id,
                              child: (a) => Text(
                                a.optionLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onChanged: (value) => setState(
                              () => _form =
                                  _form.copyWith(assigneeId: value ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Only this person sees the task. Managers can still open Whole team.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Status'),
                          DropdownButtonFormField<String>(
                            key: ValueKey('status-${_form.status}'),
                            initialValue: _form.status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            selectedItemBuilder: (context) => [
                              for (final status in SolarTaskConstants.statuses)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    status.label,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                            items: separatedDropdownMenuItems(
                              items: SolarTaskConstants.statuses,
                              value: (s) => s.value,
                              child: (s) => Text(s.label),
                            ),
                            onChanged: (value) => setState(
                              () => _form =
                                  _form.copyWith(status: value ?? 'todo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Priority'),
                          DropdownButtonFormField<String>(
                            key: ValueKey('priority-${_form.priority}'),
                            initialValue: _form.priority,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            selectedItemBuilder: (context) => [
                              for (final priority
                                  in SolarTaskConstants.priorities)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    priority.label,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                            ],
                            items: separatedDropdownMenuItems(
                              items: SolarTaskConstants.priorities,
                              value: (p) => p.value,
                              child: (p) => Text(p.label),
                            ),
                            onChanged: (value) => setState(
                              () => _form =
                                  _form.copyWith(priority: value ?? 'medium'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Start date'),
                          OutlinedButton(
                            onPressed: () => _pickDate(isStart: true),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _form.startDate.isEmpty
                                    ? 'Select date'
                                    : SolarTaskConstants.formatDate(
                                        _form.startDate,
                                      ),
                              ),
                            ),
                          ),
                          if (_form.startDate.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(
                                () => _form = _form.copyWith(startDate: ''),
                              ),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Deadline'),
                          OutlinedButton(
                            onPressed: () => _pickDate(isStart: false),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _form.dueDate.isEmpty
                                    ? 'Select date'
                                    : SolarTaskConstants.formatDate(
                                        _form.dueDate,
                                      ),
                              ),
                            ),
                          ),
                          if (_form.dueDate.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(
                                () => _form = _form.copyWith(dueDate: ''),
                              ),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Notes'),
                TextFormField(
                  initialValue: _form.description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Details for the person doing this step',
                  ),
                  onChanged: (value) => setState(
                    () => _form = _form.copyWith(description: value),
                  ),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Depends on'),
                Text(
                  'This task stays waiting until every selected task is done. Dependencies must be on the same lead.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: _loadingDeps
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : dependencyGroups.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Add another task on this lead before linking a dependency.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                for (final group in dependencyGroups) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      4,
                                    ),
                                    child: Text(
                                      group.phase.label.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  for (final task in group.tasks)
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      value: _form.dependsOnIds
                                          .contains(task.id),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text(
                                        '${task.title} · ${SolarTaskConstants.statusLabel(task.status)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      onChanged: (checked) {
                                        final next =
                                            List<String>.from(_form.dependsOnIds);
                                        if (checked == true) {
                                          if (!next.contains(task.id)) {
                                            next.add(task.id);
                                          }
                                        } else {
                                          next.remove(task.id);
                                        }
                                        setState(
                                          () => _form = _form.copyWith(
                                            dependsOnIds: next,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ],
                            ),
                ),
                if (_formError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError,
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : (_form.isEditing ? 'Save task' : 'Add task'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          children: [
            if (isRequired)
              TextSpan(
                text: ' *',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

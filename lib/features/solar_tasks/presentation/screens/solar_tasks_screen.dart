import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';
import 'package:solar_sales/features/solar_tasks/data/solar_task_constants.dart';
import 'package:solar_sales/features/solar_tasks/presentation/providers/solar_task_providers.dart';
import 'package:solar_sales/features/solar_tasks/presentation/solar_task_access.dart';
import 'package:solar_sales/features/solar_tasks/presentation/widgets/solar_task_badge.dart';
import 'package:solar_sales/features/solar_tasks/presentation/widgets/solar_task_form_sheet.dart';
import 'package:solar_sales/features/solar_tasks/presentation/widgets/solar_task_preview_sheet.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/dropdown_separated_item.dart';

class SolarTasksScreen extends ConsumerStatefulWidget {
  const SolarTasksScreen({
    super.key,
    this.initialProjectId,
    this.initialTaskId,
  });

  final String? initialProjectId;
  final String? initialTaskId;

  @override
  ConsumerState<SolarTasksScreen> createState() => _SolarTasksScreenState();
}

class _SolarTasksScreenState extends ConsumerState<SolarTasksScreen> {
  final _searchController = TextEditingController();
  bool _appliedInitialArgs = false;
  bool _openedInitialTask = false;
  bool _permissionsRefreshStarted = false;
  String? _pendingTaskId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Match web RequirePermission: re-check /auth/permissions on page open.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _permissionsRefreshStarted) return;
      _permissionsRefreshStarted = true;
      try {
        await ref.read(authProvider.notifier).refreshPermissions();
      } catch (_) {
        // Keep cached permissions if refresh fails.
      }
      if (!mounted) return;
      if (SolarTaskAccess.canRead(ref.read(authProvider))) {
        await ref.read(solarTaskBoardProvider.notifier).bootstrap();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialArgs) return;
    _appliedInitialArgs = true;

    String? projectId = widget.initialProjectId;
    String? taskId = widget.initialTaskId;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      projectId ??= args;
    } else if (args is Map) {
      projectId ??=
          args['project']?.toString() ?? args['projectId']?.toString();
      taskId ??= args['task']?.toString() ?? args['taskId']?.toString();
    }
    _pendingTaskId = (taskId ?? '').trim().isEmpty ? null : taskId!.trim();
    if (projectId != null && projectId.isNotEmpty) {
      ref.read(solarTaskBoardProvider.notifier).setInitialProject(projectId);
    }
  }

  Future<void> _maybeOpenInitialTask() async {
    final taskId = _pendingTaskId;
    if (_openedInitialTask || taskId == null || taskId.isEmpty) return;
    final board = ref.read(solarTaskBoardProvider);
    if (board.isLoading || !board.projectsReady) return;

    _openedInitialTask = true;
    final task =
        await ref.read(solarTaskBoardProvider.notifier).resolveTask(taskId);
    if (!mounted || task == null) return;
    await _openPreview(task);
  }

  Future<void> _openCreate([String? phaseKey]) {
    if (!SolarTaskAccess.canCreate(ref.read(authProvider))) {
      showAppSnackBar(
        context,
        'You do not have permission to create tasks.',
        isError: true,
      );
      return Future.value();
    }
    return showSolarTaskFormSheet(
      context: context,
      ref: ref,
      preferredPhaseKey: phaseKey,
    );
  }

  Future<void> _openEdit(SolarTaskModel task) {
    if (!SolarTaskAccess.canUpdate(ref.read(authProvider))) {
      showAppSnackBar(
        context,
        'You do not have permission to update tasks.',
        isError: true,
      );
      return Future.value();
    }
    return showSolarTaskFormSheet(
      context: context,
      ref: ref,
      initial: SolarTaskFormData.fromTask(task),
    );
  }

  Future<void> _openPreview(SolarTaskModel task) {
    final board = ref.read(solarTaskBoardProvider);
    final canUpdate = SolarTaskAccess.canUpdate(ref.read(authProvider));
    return showSolarTaskPreviewSheet(
      context: context,
      task: task,
      phases: board.phases,
      canUpdate: canUpdate,
      onEdit: () => _openEdit(task),
    );
  }

  Future<void> _changeStatus(SolarTaskModel task, String status) async {
    if (status == task.status) return;
    if (!SolarTaskAccess.canUpdate(ref.read(authProvider))) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'You do not have permission to update tasks.',
        isError: true,
      );
      return;
    }
    try {
      await ref.read(solarTaskBoardProvider.notifier).changeStatus(task, status);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(solarTaskBoardProvider);
    final notifier = ref.read(solarTaskBoardProvider.notifier);
    final auth = ref.watch(authProvider);
    final canRead = SolarTaskAccess.canRead(auth);
    final canCreate = SolarTaskAccess.canCreate(auth);
    final canUpdate = SolarTaskAccess.canUpdate(auth);
    final canOversee = SolarTaskAccess.canOversee(auth);
    final canOpenLeads = SolarTaskAccess.canOpenLeads(auth);
    final scheme = Theme.of(context).colorScheme;
    final summary = board.summary;

    ref.listen(solarTaskBoardProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        showAppSnackBar(context, next.error!, isError: true);
      }
      if (!next.isLoading && next.projectsReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeOpenInitialTask();
        });
      }
    });

    if (!canRead) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: const AppAppBar(title: 'Task Management'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Access denied',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your role is missing "task.read". Ask an admin to grant it, then log out and log in again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Task Management',
        actions: [
          if (canCreate)
            TextButton.icon(
              onPressed: () => _openCreate(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add task'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Green Energy',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      board.scope == 'team'
                          ? 'Every task in the company. Switch to Mine to see only your own.'
                          : 'Only the tasks assigned to you.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryStrip(summary: summary),
                    const SizedBox(height: 12),
                    _FilterCard(
                      board: board,
                      canOversee: canOversee,
                      canOpenLeads: canOpenLeads,
                      searchController: _searchController,
                      onLeadChanged: notifier.selectProject,
                      onSearchChanged: notifier.setSearch,
                      onStatusChanged: notifier.setStatusFilter,
                      onPhaseChanged: notifier.setPhaseFilter,
                      onAssigneeChanged: notifier.setAssigneeFilter,
                      onScopeChanged: notifier.setScope,
                      onToggleOverdue: notifier.toggleOverdueOnly,
                      onOpenLead: (id) {
                        Navigator.of(context).pushNamed(
                          '/solar/leads/detail',
                          arguments: id,
                        );
                      },
                      onAddLead: () {
                        Navigator.of(context).pushNamed('/solar/leads');
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (board.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Loading tasks…')),
              )
            else if (board.activePhases.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBoard(
                  teamScope: board.scope == 'team',
                  canCreate: canCreate,
                  onAdd: () => _openCreate(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList.builder(
                  itemCount: board.activePhases.length,
                  itemBuilder: (context, index) {
                    final entry = board.activePhases[index];
                    return _PhaseSection(
                      phase: entry.phase,
                      tasks: entry.tasks,
                      showProjectLink: board.projectId.isEmpty,
                      canUpdate: canUpdate,
                      onPreview: _openPreview,
                      onEdit: _openEdit,
                      onStatusChanged: _changeStatus,
                      onSelectProject: notifier.selectProject,
                    );
                  },
                ),
              ),
            if (!board.isLoading &&
                board.quietPhases.isNotEmpty &&
                canCreate)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Card(
                    elevation: 0,
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton(
                            onPressed: notifier.toggleShowEmptyPhases,
                            child: Text(
                              '${board.showEmptyPhases ? 'Hide' : 'Show'} ${board.quietPhases.length} empty ${board.quietPhases.length == 1 ? 'phase' : 'phases'}',
                            ),
                          ),
                          if (board.showEmptyPhases)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final entry in board.quietPhases)
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: scheme.outlineVariant,
                                        style: BorderStyle.solid,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: () =>
                                        _openCreate(entry.phase.key),
                                    child: Text('+ ${entry.phase.label}'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final SolarTaskClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (label: 'Open', value: summary.open, hint: 'Still to finish', alert: false),
      (
        label: 'In progress',
        value: summary.inProgress,
        hint: 'Being worked',
        alert: false,
      ),
      (
        label: 'Waiting',
        value: summary.waiting,
        hint: 'Needs a prior step',
        alert: false,
      ),
      (
        label: 'Overdue',
        value: summary.overdue,
        hint: 'Past the deadline',
        alert: summary.overdue > 0,
      ),
      (label: 'Done', value: summary.done, hint: 'Finished', alert: false),
    ];

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Container(width: 1, height: 56, color: scheme.outlineVariant),
                    Expanded(child: _StatCell(item: items[i])),
                  ],
                ],
              );
            }
            return Wrap(
              children: [
                for (final item in items)
                  SizedBox(
                    width: constraints.maxWidth / 2,
                    child: _StatCell(item: item),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.item});

  final ({String label, int value, String hint, bool alert}) item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.value}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: item.alert ? const Color(0xFFE11D48) : null,
                ),
          ),
          Text(
            item.hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.board,
    required this.canOversee,
    required this.canOpenLeads,
    required this.searchController,
    required this.onLeadChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPhaseChanged,
    required this.onAssigneeChanged,
    required this.onScopeChanged,
    required this.onToggleOverdue,
    required this.onOpenLead,
    required this.onAddLead,
  });

  final SolarTaskBoardState board;
  final bool canOversee;
  final bool canOpenLeads;
  final TextEditingController searchController;
  final ValueChanged<String> onLeadChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPhaseChanged;
  final ValueChanged<String> onAssigneeChanged;
  final ValueChanged<String> onScopeChanged;
  final VoidCallback onToggleOverdue;
  final ValueChanged<String> onOpenLead;
  final VoidCallback onAddLead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = board.selectedProject;

    return Card(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'LEAD',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                if (canOpenLeads)
                  TextButton(
                    onPressed: onAddLead,
                    child: const Text('Add lead'),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('filter-lead-${board.projectId}'),
              initialValue: board.projectId.isEmpty ? '' : board.projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              selectedItemBuilder: (context) => [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    board.scope == 'team' ? 'All leads' : 'All my leads',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                for (final project in board.projects)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      project.optionLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    board.scope == 'team' ? 'All leads' : 'All my leads',
                  ),
                ),
                ...separatedDropdownMenuItems(
                  items: board.projects,
                  value: (p) => p.id,
                  child: (p) => Text(
                    p.optionLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => onLeadChanged(value ?? ''),
            ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => onOpenLead(selected.id),
                    child: Text(selected.leadCode),
                  ),
                  Text(
                    ' · ${selected.fullName} · ${selected.status}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) {
                return TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Title or lead',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: value.text.isEmpty
                        ? const Icon(Icons.search)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          ),
                  ),
                  onChanged: onSearchChanged,
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('filter-status-${board.statusFilter}'),
                    initialValue: board.statusFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Any')),
                      ...SolarTaskConstants.statuses.map(
                        (s) => DropdownMenuItem(
                          value: s.value,
                          child: Text(s.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => onStatusChanged(value ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('filter-phase-${board.phaseFilter}'),
                    initialValue: board.phaseFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Phase',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All')),
                      ...board.phases.map(
                        (p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => onPhaseChanged(value ?? ''),
                  ),
                ),
              ],
            ),
            if (board.scope == 'team') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('filter-assignee-${board.assigneeFilter}'),
                initialValue: board.assigneeFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assignee',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Everyone')),
                  const DropdownMenuItem(
                    value: 'unassigned',
                    child: Text('Unassigned'),
                  ),
                  ...board.assignees.map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => onAssigneeChanged(value ?? ''),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canOversee)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mine', label: Text('Mine')),
                      ButtonSegment(value: 'team', label: Text('Team')),
                    ],
                    selected: {board.scope},
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) onScopeChanged(values.first);
                    },
                  ),
                FilterChip(
                  label: const Text('Overdue'),
                  selected: board.overdueOnly,
                  selectedColor: const Color(0xFFFFE4E6),
                  checkmarkColor: const Color(0xFFBE123C),
                  labelStyle: TextStyle(
                    color: board.overdueOnly
                        ? const Color(0xFFBE123C)
                        : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: board.overdueOnly
                        ? const Color(0xFFFECDD3)
                        : scheme.outlineVariant,
                  ),
                  onSelected: (_) => onToggleOverdue(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({
    required this.teamScope,
    required this.canCreate,
    required this.onAdd,
  });

  final bool teamScope;
  final bool canCreate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            teamScope
                ? 'No tasks in the company yet'
                : 'Nothing is assigned to you here',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            teamScope
                ? 'Tasks for every assignee show here. Pick a lead above to narrow the list, or add a task and choose who should do it.'
                : 'Tasks assigned to other people stay on their list. Use Team if you manage the company, or add a task with yourself as the assignee.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (canCreate) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({
    required this.phase,
    required this.tasks,
    required this.showProjectLink,
    required this.canUpdate,
    required this.onPreview,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onSelectProject,
  });

  final SolarTaskPhase phase;
  final List<SolarTaskModel> tasks;
  final bool showProjectLink;
  final bool canUpdate;
  final ValueChanged<SolarTaskModel> onPreview;
  final ValueChanged<SolarTaskModel> onEdit;
  final Future<void> Function(SolarTaskModel task, String status)
      onStatusChanged;
  final ValueChanged<String> onSelectProject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = SolarTaskConstants.phasePercent(tasks);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (phase.hint.isNotEmpty)
                        Text(
                          phase.hint,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 6,
                          backgroundColor: scheme.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final task in tasks)
            _TaskRow(
              task: task,
              showProjectLink: showProjectLink,
              canUpdate: canUpdate,
              onPreview: () => onPreview(task),
              onEdit: () => onEdit(task),
              onStatusChanged: (status) => onStatusChanged(task, status),
              onSelectProject: onSelectProject,
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.showProjectLink,
    required this.canUpdate,
    required this.onPreview,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onSelectProject,
  });

  final SolarTaskModel task;
  final bool showProjectLink;
  final bool canUpdate;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSelectProject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.status == 'done';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: SolarTaskConstants.statusDotColor(task.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration:
                                        done ? TextDecoration.lineThrough : null,
                                    color: done
                                        ? scheme.onSurfaceVariant
                                        : null,
                                  ),
                        ),
                        SolarTaskBadge.priority(task.priority),
                        if (task.isBlocked) SolarTaskBadge.waiting(),
                        if (task.isOverdue) SolarTaskBadge.overdue(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.12),
                              child: Text(
                                SolarTaskConstants.initials(
                                  task.assignee?.name,
                                ),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              task.assignee?.name ?? 'Unassigned',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: task.isOverdue
                                  ? const Color(0xFFE11D48)
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.dueDate == null
                                  ? 'No deadline'
                                  : SolarTaskConstants.formatDate(task.dueDate),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: task.isOverdue
                                        ? const Color(0xFFE11D48)
                                        : scheme.onSurfaceVariant,
                                    fontWeight: task.isOverdue
                                        ? FontWeight.w700
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                        if (showProjectLink && task.project != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => onSelectProject(task.leadId),
                            child: Text(
                              '${task.project!.leadCode} · ${task.project!.fullName}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (canUpdate)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('row-status-${task.id}-${task.status}'),
                    initialValue: task.status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    items: SolarTaskConstants.statuses
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.value,
                            child: Text(s.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onStatusChanged(value);
                    },
                  ),
                )
              else
                SolarTaskBadge.status(task.status),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Preview',
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
              ),
              if (canUpdate) ...[
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

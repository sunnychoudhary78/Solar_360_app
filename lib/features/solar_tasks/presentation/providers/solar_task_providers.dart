import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';
import 'package:solar_sales/features/solar_tasks/data/solar_task_api_service.dart';
import 'package:solar_sales/features/solar_tasks/data/solar_task_constants.dart';
import 'package:solar_sales/features/solar_tasks/presentation/solar_task_access.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

final solarTaskApiServiceProvider = Provider<SolarTaskApiService>((ref) {
  return SolarTaskApiService(ref.watch(apiServiceProvider));
});

class SolarTaskBoardState {
  const SolarTaskBoardState({
    this.phases = SolarTaskConstants.fallbackPhases,
    this.projects = const [],
    this.assignees = const [],
    this.tasks = const [],
    this.dependencyOptions = const [],
    this.isLoading = false,
    this.projectsReady = false,
    this.scope = 'mine',
    this.projectId = '',
    this.search = '',
    this.statusFilter = '',
    this.phaseFilter = '',
    this.assigneeFilter = '',
    this.overdueOnly = false,
    this.showEmptyPhases = false,
    this.error,
  });

  final List<SolarTaskPhase> phases;
  final List<SolarTaskProject> projects;
  final List<SolarTaskAssignee> assignees;
  final List<SolarTaskModel> tasks;
  final List<SolarTaskModel> dependencyOptions;
  final bool isLoading;
  final bool projectsReady;
  final String scope;
  final String projectId;
  final String search;
  final String statusFilter;
  final String phaseFilter;
  final String assigneeFilter;
  final bool overdueOnly;
  final bool showEmptyPhases;
  final String? error;

  SolarTaskClientSummary get summary =>
      SolarTaskClientSummary.fromTasks(tasks);

  SolarTaskProject? get selectedProject {
    if (projectId.isEmpty) return null;
    for (final project in projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  List<SolarTaskModel> get visibleTasks {
    final term = search.trim().toLowerCase();
    return tasks.where((task) {
      if (phaseFilter.isNotEmpty && task.phaseKey != phaseFilter) {
        return false;
      }
      if (statusFilter.isNotEmpty && task.status != statusFilter) {
        return false;
      }
      if (assigneeFilter == 'unassigned' &&
          (task.assigneeId != null && task.assigneeId!.isNotEmpty)) {
        return false;
      }
      if (assigneeFilter.isNotEmpty &&
          assigneeFilter != 'unassigned' &&
          task.assigneeId != assigneeFilter) {
        return false;
      }
      if (overdueOnly && !task.isOverdue) return false;
      if (term.isEmpty) return true;
      final haystack = [
        task.title,
        task.description,
        task.assignee?.name,
        task.project?.fullName,
        task.project?.leadCode,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(term);
    }).toList(growable: false);
  }

  List<({SolarTaskPhase phase, List<SolarTaskModel> tasks})> get filledPhases {
    return phases
        .where((phase) => phaseFilter.isEmpty || phase.key == phaseFilter)
        .map(
          (phase) => (
            phase: phase,
            tasks: visibleTasks
                .where((task) => task.phaseKey == phase.key)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<({SolarTaskPhase phase, List<SolarTaskModel> tasks})> get activePhases {
    final known = phases.map((p) => p.key).toSet();
    final unmatched = visibleTasks
        .where(
          (task) =>
              !known.contains(task.phaseKey) &&
              (phaseFilter.isEmpty || task.phaseKey == phaseFilter),
        )
        .toList(growable: false);
    final filled = filledPhases
        .where((entry) => entry.tasks.isNotEmpty)
        .toList(growable: false);
    return [
      if (unmatched.isNotEmpty)
        (
          phase: const SolarTaskPhase(
            key: 'other',
            label: 'Other',
            hint: 'Tasks outside the standard phases',
          ),
          tasks: unmatched,
        ),
      ...filled,
    ];
  }

  List<({SolarTaskPhase phase, List<SolarTaskModel> tasks})> get quietPhases {
    return filledPhases
        .where((entry) => entry.tasks.isEmpty)
        .toList(growable: false);
  }

  SolarTaskBoardState copyWith({
    List<SolarTaskPhase>? phases,
    List<SolarTaskProject>? projects,
    List<SolarTaskAssignee>? assignees,
    List<SolarTaskModel>? tasks,
    List<SolarTaskModel>? dependencyOptions,
    bool? isLoading,
    bool? projectsReady,
    String? scope,
    String? projectId,
    String? search,
    String? statusFilter,
    String? phaseFilter,
    String? assigneeFilter,
    bool? overdueOnly,
    bool? showEmptyPhases,
    String? error,
    bool clearError = false,
  }) {
    return SolarTaskBoardState(
      phases: phases ?? this.phases,
      projects: projects ?? this.projects,
      assignees: assignees ?? this.assignees,
      tasks: tasks ?? this.tasks,
      dependencyOptions: dependencyOptions ?? this.dependencyOptions,
      isLoading: isLoading ?? this.isLoading,
      projectsReady: projectsReady ?? this.projectsReady,
      scope: scope ?? this.scope,
      projectId: projectId ?? this.projectId,
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      phaseFilter: phaseFilter ?? this.phaseFilter,
      assigneeFilter: assigneeFilter ?? this.assigneeFilter,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      showEmptyPhases: showEmptyPhases ?? this.showEmptyPhases,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SolarTaskBoardNotifier extends Notifier<SolarTaskBoardState> {
  int _listRequest = 0;
  bool _scopeTouched = false;

  @override
  SolarTaskBoardState build() {
    final auth = ref.read(authProvider);
    final canRead = SolarTaskAccess.canRead(auth);
    final canOversee = SolarTaskAccess.canOversee(auth);

    // Drop Team scope immediately if the active role loses task.delete.
    ref.listen(authProvider, (previous, next) {
      final hadOversee =
          previous != null && SolarTaskAccess.canOversee(previous);
      final hadRead = previous != null && SolarTaskAccess.canRead(previous);
      final lostOversee = hadOversee && !SolarTaskAccess.canOversee(next);
      final lostRead = hadRead && !SolarTaskAccess.canRead(next);
      if (lostRead) {
        state = const SolarTaskBoardState(
          scope: 'mine',
          isLoading: false,
          projectsReady: true,
        );
        return;
      }
      if (lostOversee && state.scope == 'team') {
        _scopeTouched = false;
        state = state.copyWith(scope: 'mine', assigneeFilter: '');
        Future.microtask(() async {
          await loadProjects();
          await loadTasks();
        });
      }
    });

    if (!canRead) {
      return const SolarTaskBoardState(
        scope: 'mine',
        isLoading: false,
        projectsReady: true,
      );
    }

    Future.microtask(bootstrap);
    return SolarTaskBoardState(
      scope: canOversee ? 'team' : 'mine',
      isLoading: true,
    );
  }

  SolarTaskApiService get _api => ref.read(solarTaskApiServiceProvider);

  bool get canRead => SolarTaskAccess.canRead(ref.read(authProvider));
  bool get canCreate => SolarTaskAccess.canCreate(ref.read(authProvider));
  bool get canUpdate => SolarTaskAccess.canUpdate(ref.read(authProvider));
  bool get canOversee => SolarTaskAccess.canOversee(ref.read(authProvider));
  bool get canOpenLeads =>
      SolarTaskAccess.canOpenLeads(ref.read(authProvider));

  /// Effective list scope for API calls — never sends `team` without permission.
  String? get _apiScope {
    if (state.scope == 'team' && canOversee) return 'team';
    return null;
  }

  String get currentUserId {
    final auth = ref.read(authProvider);
    return auth.profile?.id ?? auth.authUser?.id ?? '';
  }

  Future<void> bootstrap() async {
    if (!canRead) {
      state = state.copyWith(
        tasks: const [],
        projects: const [],
        isLoading: false,
        projectsReady: true,
      );
      return;
    }

    if (!_scopeTouched && canOversee && state.scope != 'team') {
      state = state.copyWith(scope: 'team');
    }
    if (!canOversee && state.scope == 'team') {
      state = state.copyWith(scope: 'mine', assigneeFilter: '');
    }

    try {
      final metaFuture = _api.meta();
      final assigneesFuture = _api.assignees();
      final projectsFuture = _api.projects(scope: _apiScope);

      final meta = await metaFuture;
      final assignees = await assigneesFuture;
      final projects = await projectsFuture;

      state = state.copyWith(
        phases: meta.phases.isNotEmpty
            ? meta.phases
            : SolarTaskConstants.fallbackPhases,
        assignees: assignees,
        projects: projects,
        projectsReady: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        projectsReady: true,
        error: cleanError(e),
      );
    }

    await loadTasks();
  }

  Future<void> loadProjects() async {
    if (!canRead) return;
    try {
      final projects = await _api.projects(scope: _apiScope);
      state = state.copyWith(projects: projects, projectsReady: true);
    } catch (e) {
      state = state.copyWith(error: cleanError(e));
    }
  }

  Future<void> loadTasks() async {
    if (!canRead) {
      state = state.copyWith(
        tasks: const [],
        isLoading: false,
        projectsReady: true,
      );
      return;
    }
    final requestId = ++_listRequest;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.list(
        leadId: state.projectId.isEmpty ? null : state.projectId,
        scope: _apiScope,
      );
      if (requestId != _listRequest) return;
      state = state.copyWith(
        tasks: result.data,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (requestId != _listRequest) return;
      state = state.copyWith(
        tasks: const [],
        isLoading: false,
        error: cleanError(e),
      );
    }
  }

  Future<void> refresh() async {
    await Future.wait([loadProjects(), loadTasks()]);
  }

  void setInitialProject(String? projectId) {
    final id = (projectId ?? '').trim();
    if (id.isEmpty || id == state.projectId) return;
    state = state.copyWith(projectId: id);
    Future.microtask(loadTasks);
  }

  void selectProject(String id) {
    if (id == state.projectId) return;
    state = state.copyWith(projectId: id);
    Future.microtask(loadTasks);
  }

  void setScope(String scope) {
    if (scope == 'team' && !canOversee) return;
    _scopeTouched = true;
    if (scope == state.scope) return;
    state = state.copyWith(
      scope: scope,
      assigneeFilter: scope == 'mine' ? '' : state.assigneeFilter,
    );
    Future.microtask(() async {
      await loadProjects();
      await loadTasks();
    });
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void setStatusFilter(String value) {
    state = state.copyWith(statusFilter: value);
  }

  void setPhaseFilter(String value) {
    state = state.copyWith(phaseFilter: value);
  }

  void setAssigneeFilter(String value) {
    state = state.copyWith(assigneeFilter: value);
  }

  void toggleOverdueOnly() {
    state = state.copyWith(overdueOnly: !state.overdueOnly);
  }

  void toggleShowEmptyPhases() {
    state = state.copyWith(showEmptyPhases: !state.showEmptyPhases);
  }

  Future<List<SolarTaskModel>> loadDependencyOptions(String leadId) async {
    if (leadId.isEmpty) {
      state = state.copyWith(dependencyOptions: const []);
      return const [];
    }

    final canReuse = !canOversee &&
        leadId == state.projectId &&
        state.scope != 'team';
    if (canReuse) {
      state = state.copyWith(dependencyOptions: state.tasks);
      return state.tasks;
    }

    try {
      final result = await _api.list(
        leadId: leadId,
        scope: canOversee ? 'team' : null,
      );
      state = state.copyWith(dependencyOptions: result.data);
      return result.data;
    } catch (_) {
      state = state.copyWith(dependencyOptions: const []);
      return const [];
    }
  }

  Future<void> changeStatus(SolarTaskModel task, String status) async {
    if (!canUpdate) {
      throw Exception('You do not have permission to update tasks.');
    }
    await _api.updateStatus(task.id, status);
    await loadTasks();
  }

  /// Resolves a task from the loaded board, or fetches it by id when needed
  /// (assignment notification deep links).
  Future<SolarTaskModel?> resolveTask(String taskId) async {
    if (!canRead) return null;
    final id = taskId.trim();
    if (id.isEmpty) return null;
    for (final task in state.tasks) {
      if (task.id == id) return task;
    }
    try {
      return await _api.getById(id);
    } catch (_) {
      return null;
    }
  }

  Future<SolarTaskModel> saveTask(SolarTaskFormData form) async {
    if (form.isEditing) {
      if (!canUpdate) {
        throw Exception('You do not have permission to update tasks.');
      }
    } else if (!canCreate) {
      throw Exception('You do not have permission to create tasks.');
    }

    final payload = form.toPayload();
    final SolarTaskModel saved;
    if (form.isEditing) {
      saved = await _api.update(form.id!, payload);
    } else {
      saved = await _api.create(payload);
    }

    final leadId = asString(payload['lead_id']);
    if (leadId.isNotEmpty && leadId != state.projectId) {
      state = state.copyWith(projectId: leadId);
      await loadProjects();
      await loadTasks();
    } else {
      await refresh();
    }
    return saved;
  }

  String successMessage(SolarTaskFormData form, Map<String, dynamic> payload) {
    if (form.isEditing) return 'Task updated';
    final assigneeId = asString(payload['assignee_id']);
    final assignedToMe = assigneeId.isNotEmpty &&
        assigneeId == currentUserId;
    if (assignedToMe) return 'Task added';
    String? name;
    for (final person in state.assignees) {
      if (person.id == assigneeId) {
        name = person.name;
        break;
      }
    }
    return 'Task added for ${name ?? 'the assignee'}. Only they will see it.';
  }
}

final solarTaskBoardProvider =
    NotifierProvider<SolarTaskBoardNotifier, SolarTaskBoardState>(
      SolarTaskBoardNotifier.new,
    );

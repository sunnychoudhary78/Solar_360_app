import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/amc_access.dart';
import 'package:solar_sales/features/amc/presentation/providers/amc_providers.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_extra_visit_sheet.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_kpi_row.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_plant_card.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_plant_history_sheet.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_start_sheet.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_visit_card.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class AmcVisitsScreen extends ConsumerStatefulWidget {
  const AmcVisitsScreen({super.key});

  @override
  ConsumerState<AmcVisitsScreen> createState() => _AmcVisitsScreenState();
}

class _AmcVisitsScreenState extends ConsumerState<AmcVisitsScreen> {
  final _search = TextEditingController();
  bool _bootstrapped = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _bootstrapped) return;
      _bootstrapped = true;
      try {
        await ref.read(authProvider.notifier).refreshPermissions();
      } catch (_) {}
      if (!mounted) return;
      if (AmcAccess.canRead(ref.read(authProvider))) {
        await ref.read(amcHomeProvider.notifier).bootstrap();
      }
    });
  }

  Future<void> _openVisit(AmcVisit visit) async {
    await Navigator.of(context).pushNamed(
      '/solar/amc/visit',
      arguments: visit.id,
    );
    if (!mounted) return;
    await ref.read(amcHomeProvider.notifier).refresh();
  }

  Future<void> _startAmc(AmcPlant plant) async {
    final state = ref.read(amcHomeProvider);
    final body = await showAmcStartSheet(
      context,
      plant: plant,
      assignees: state.assignees,
      visitsPerYearOptions: state.meta.visitsPerYear,
    );
    if (body == null || !mounted) return;
    await runAmcAction(
      context,
      successMessage: 'AMC started and visits scheduled',
      action: () async {
        await ref.read(amcHomeProvider.notifier).startAmc(body);
        await ref.read(amcHomeProvider.notifier).setVisitFilter('');
      },
    );
  }

  Future<void> _extraVisit([AmcPlant? plant]) async {
    final notifier = ref.read(amcHomeProvider.notifier);
    await notifier.ensurePlantsLoadedSilent();
    if (!mounted) return;
    final state = ref.read(amcHomeProvider);
    final body = await showAmcExtraVisitSheet(
      context,
      plant: plant,
      plantsWithAmc: state.plantsWithAmc,
      assignees: state.assignees,
    );
    if (body == null || !mounted) return;
    await runAmcAction(
      context,
      successMessage: 'Extra visit scheduled',
      action: () async {
        await notifier.createExtraVisit(body);
        await notifier.setVisitFilter('');
      },
    );
  }

  Future<void> _renew(AmcPlant plant) async {
    final contractId = plant.contract?.id ?? '';
    if (contractId.isEmpty) return;
    final n = plant.contract?.visitsPerYear ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew this AMC for another year?'),
        content: Text(
          'This extends ${plant.plantLabel} by 12 months and adds another $n visit${n == 1 ? '' : 's'}. Completed visits stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runAmcAction(
      context,
      successMessage: 'Next year of AMC visits added',
      action: () => ref.read(amcHomeProvider.notifier).renewAmc(contractId),
    );
  }

  Future<void> _openHistory(AmcPlant plant) {
    return showAmcPlantHistorySheet(
      context,
      plant: plant,
      canCreate: AmcAccess.canCreate(ref.read(authProvider)),
      onStartAmc: _startAmc,
      onExtraVisit: _extraVisit,
      onOpenVisit: _openVisit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!AmcAccess.canRead(auth)) {
      return const Scaffold(
        appBar: AppAppBar(title: 'AMC Visits'),
        body: EmptyState(
          title: 'No access',
          subtitle: 'You need amc.read permission to open AMC Visits.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final state = ref.watch(amcHomeProvider);
    final canCreate = AmcAccess.canCreate(auth);
    final notifier = ref.read(amcHomeProvider.notifier);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'AMC Visits',
        subtitle: 'Schedule annual maintenance on installed plants',
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'Extra visit',
              onPressed: () => _extraVisit(),
              icon: const Icon(Icons.add_circle_outline),
            ),
          if (canCreate)
            IconButton(
              tooltip: 'Start AMC',
              onPressed: () async {
                await notifier.setPlantAmcFilter('none');
              },
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading ? null : () => notifier.refresh(),
            icon: state.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.isLoading && state.visits.isEmpty && state.plants.isEmpty
          ? const LoadingState(message: 'Loading AMC…')
          : state.error != null &&
                  state.visits.isEmpty &&
                  state.plants.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => notifier.bootstrap(),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      AmcKpiRow(
                        summary: state.summary,
                        onPlants: () => notifier.setTab(AmcHomeTab.plants),
                        onActiveAmc: () => notifier.setPlantAmcFilter('active'),
                        onOverdue: () => notifier.setVisitFilter('overdue'),
                        onDueToday: () => notifier.setVisitFilter('today'),
                        onThisMonth: () => notifier.setVisitFilter('month'),
                        onDoneMonth: () =>
                            notifier.setVisitFilter('done_month'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TabChip(
                              label: 'Visits',
                              selected: state.tab == AmcHomeTab.visits,
                              onTap: () => notifier.setTab(AmcHomeTab.visits),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TabChip(
                              label: 'Plants',
                              selected: state.tab == AmcHomeTab.plants,
                              onTap: () => notifier.setTab(AmcHomeTab.plants),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: state.tab == AmcHomeTab.visits
                              ? 'Search visits or customer'
                              : 'Search plant, code, inverter',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _search.clear();
                                    notifier.setSearchInput('');
                                    setState(() {});
                                  },
                                ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() {});
                          notifier.setSearchInput(v);
                        },
                      ),
                      const SizedBox(height: 10),
                      if (state.tab == AmcHomeTab.visits) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final chip in amcVisitChips)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      chip.id == 'overdue' &&
                                              state.summary.overdue > 0
                                          ? '${chip.label} · ${state.summary.overdue}'
                                          : chip.id == 'today' &&
                                                  state.summary.dueToday > 0
                                              ? '${chip.label} · ${state.summary.dueToday}'
                                              : chip.label,
                                    ),
                                    selected: state.visitFilter == chip.id,
                                    selectedColor: chip.id == 'overdue'
                                        ? const Color(0xFFE11D48)
                                        : null,
                                    labelStyle: chip.id == 'overdue' &&
                                            state.visitFilter == chip.id
                                        ? const TextStyle(color: Colors.white)
                                        : null,
                                    checkmarkColor: chip.id == 'overdue' &&
                                            state.visitFilter == chip.id
                                        ? Colors.white
                                        : null,
                                    onSelected: (_) =>
                                        notifier.setVisitFilter(chip.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: state.visitFilter == 'unassigned'
                              ? 'unassigned'
                              : state.assigneeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Technician',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All technicians'),
                            ),
                            const DropdownMenuItem(
                              value: 'unassigned',
                              child: Text('Unassigned'),
                            ),
                            ...state.assignees.map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              notifier.setAssigneeFilter(v ?? ''),
                        ),
                        const SizedBox(height: 12),
                        if (state.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: LoadingState(message: 'Loading visits…'),
                          )
                        else if (state.visits.isEmpty)
                          EmptyState(
                            title: state.search.isNotEmpty ||
                                    state.visitFilter.isNotEmpty
                                ? 'No visits match these filters'
                                : 'No AMC visits yet',
                            subtitle: state.search.isNotEmpty ||
                                    state.visitFilter.isNotEmpty
                                ? 'Clear the filter or search to see the rest of the calendar.'
                                : 'Start AMC on an installed plant to schedule the year’s maintenance visits.',
                            icon: Icons.event_available_outlined,
                            action: canCreate &&
                                    state.search.isEmpty &&
                                    state.visitFilter.isEmpty
                                ? FilledButton(
                                    onPressed: () =>
                                        notifier.setPlantAmcFilter('none'),
                                    child: const Text('Start AMC'),
                                  )
                                : null,
                          )
                        else
                          ...groupAmcVisits(state.visits).map((group) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: .45),
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        10,
                                        14,
                                        10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  group.label,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: group.key ==
                                                                'overdue'
                                                            ? const Color(
                                                                0xFFE11D48,
                                                              )
                                                            : null,
                                                      ),
                                                ),
                                                Text(
                                                  group.hint,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${group.rows.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...group.rows.map(
                                      (visit) => Column(
                                        children: [
                                          AmcVisitCard(
                                            visit: visit,
                                            onTap: () => _openVisit(visit),
                                          ),
                                          Divider(
                                            height: 1,
                                            color: scheme.outlineVariant
                                                .withValues(alpha: .4),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ] else ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final chip in amcPlantChips)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(chip.label),
                                    selected:
                                        state.plantAmcFilter == chip.id,
                                    onSelected: (_) =>
                                        notifier.setPlantAmcFilter(chip.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (state.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: LoadingState(message: 'Loading plants…'),
                          )
                        else if (state.plants.isEmpty)
                          EmptyState(
                            title: state.search.isNotEmpty ||
                                    state.plantAmcFilter.isNotEmpty
                                ? 'No plants match these filters'
                                : 'No installed plants',
                            subtitle: state.search.isNotEmpty ||
                                    state.plantAmcFilter.isNotEmpty
                                ? 'Clear the filter or search to see every installed site.'
                                : 'AMC starts after installation. Complete a lead’s installation details first.',
                            icon: Icons.solar_power_outlined,
                          )
                        else
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: state.plants
                                  .map(
                                    (plant) => AmcPlantCard(
                                      plant: plant,
                                      canCreate: canCreate,
                                      onOpenHistory: () =>
                                          _openHistory(plant),
                                      onStartAmc: () => _startAmc(plant),
                                      onExtraVisit: () => _extraVisit(plant),
                                      onRenew: () => _renew(plant),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: .6),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

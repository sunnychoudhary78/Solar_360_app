import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';
import 'package:solar_sales/features/amc/presentation/amc_access.dart';
import 'package:solar_sales/features/amc/presentation/providers/amc_providers.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_extra_visit_sheet.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_kpi_row.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_plant_card.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_start_sheet.dart';
import 'package:solar_sales/features/amc/presentation/widgets/amc_visit_card.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class AmcVisitsScreen extends ConsumerStatefulWidget {
  const AmcVisitsScreen({super.key});

  @override
  ConsumerState<AmcVisitsScreen> createState() => _AmcVisitsScreenState();
}

class _AmcVisitsScreenState extends ConsumerState<AmcVisitsScreen> {
  final _visitSearch = TextEditingController();
  final _plantSearch = TextEditingController();
  bool _bootstrapped = false;

  @override
  void dispose() {
    _visitSearch.dispose();
    _plantSearch.dispose();
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
      successMessage: 'AMC started',
      action: () async {
        await ref.read(amcHomeProvider.notifier).startAmc(body);
      },
    );
  }

  Future<void> _extraVisit(AmcPlant plant) async {
    final state = ref.read(amcHomeProvider);
    final body = await showAmcExtraVisitSheet(
      context,
      plant: plant,
      assignees: state.assignees,
    );
    if (body == null || !mounted) return;
    await runAmcAction(
      context,
      successMessage: 'Extra visit added',
      action: () async {
        await ref.read(amcHomeProvider.notifier).createExtraVisit(body);
      },
    );
  }

  Future<void> _renew(AmcPlant plant) async {
    final contractId = plant.contract?.id ?? '';
    if (contractId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew AMC year?'),
        content: Text(
          'Extends the contract by 12 months and schedules another year of visits for ${plant.fullName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runAmcAction(
      context,
      successMessage: 'AMC renewed',
      action: () async {
        await ref.read(amcHomeProvider.notifier).renewAmc(contractId);
      },
    );
  }

  void _openLead(AmcPlant plant) {
    if (!AmcAccess.canOpenLead(ref.read(authProvider))) {
      showAppSnackBar(context, 'No permission to open leads', isError: true);
      return;
    }
    Navigator.of(context).pushNamed('/solar/leads/detail', arguments: plant.leadId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!AmcAccess.canRead(auth)) {
      return Scaffold(
        appBar: const AppAppBar(title: 'AMC Visits'),
        body: const EmptyState(
          title: 'No access',
          subtitle: 'You need amc.read permission to open AMC Visits.',
          icon: Icons.lock_outline,
        ),
      );
    }

    final state = ref.watch(amcHomeProvider);
    final canManage = AmcAccess.canManageContract(auth);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'AMC Visits',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading
                ? null
                : () => ref.read(amcHomeProvider.notifier).refresh(),
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
      body: state.isLoading
          ? const LoadingState(message: 'Loading AMC…')
          : state.error != null &&
                  state.visits.isEmpty &&
                  state.plants.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(amcHomeProvider.notifier).bootstrap(),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(amcHomeProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        'Annual maintenance for installed plants',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      AmcKpiRow(summary: state.summary),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _TabChip(
                              label: 'Visits',
                              selected: state.tab == AmcHomeTab.visits,
                              onTap: () => ref
                                  .read(amcHomeProvider.notifier)
                                  .setTab(AmcHomeTab.visits),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TabChip(
                              label: 'Plants',
                              selected: state.tab == AmcHomeTab.plants,
                              onTap: () => ref
                                  .read(amcHomeProvider.notifier)
                                  .setTab(AmcHomeTab.plants),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (state.tab == AmcHomeTab.visits)
                        ..._visitsSection(state)
                      else
                        ..._plantsSection(state, canManage),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _visitsSection(AmcHomeState state) {
    return [
      TextField(
        controller: _visitSearch,
        decoration: InputDecoration(
          hintText: 'Search visits, plant, mobile…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _visitSearch.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _visitSearch.clear();
                    ref.read(amcHomeProvider.notifier).setVisitSearch('');
                    setState(() {});
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          setState(() {});
          ref.read(amcHomeProvider.notifier).setVisitSearch(v);
        },
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text('Overdue (${state.visitSummary.overdue})'),
              selected: state.overdueOnly,
              onSelected: (v) =>
                  ref.read(amcHomeProvider.notifier).setOverdueOnly(v),
            ),
            const SizedBox(width: 8),
            ...['', 'scheduled', 'in_progress', 'completed'].map((status) {
              final label = status.isEmpty
                  ? 'All'
                  : amcVisitStatusLabel(status);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: !state.overdueOnly &&
                      state.visitStatusFilter == status,
                  onSelected: (_) => ref
                      .read(amcHomeProvider.notifier)
                      .setVisitStatusFilter(status),
                ),
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (state.visits.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            title: 'No visits',
            subtitle: 'Start an AMC on a plant to schedule visits.',
            icon: Icons.event_available_outlined,
          ),
        )
      else
        ...state.visits.map(
          (visit) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AmcVisitCard(
              visit: visit,
              onTap: () => _openVisit(visit),
            ),
          ),
        ),
    ];
  }

  List<Widget> _plantsSection(AmcHomeState state, bool canManage) {
    return [
      TextField(
        controller: _plantSearch,
        decoration: InputDecoration(
          hintText: 'Search name, lead code, mobile, inverter…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _plantSearch.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _plantSearch.clear();
                    ref.read(amcHomeProvider.notifier).setPlantSearch('');
                    setState(() {});
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          setState(() {});
          ref.read(amcHomeProvider.notifier).setPlantSearch(v);
        },
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in const [
              ('', 'All'),
              ('active', 'AMC active'),
              ('none', 'No AMC'),
              ('overdue', 'Overdue'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(entry.$2),
                  selected: state.plantAmcFilter == entry.$1,
                  onSelected: (_) => ref
                      .read(amcHomeProvider.notifier)
                      .setPlantAmcFilter(entry.$1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (state.plants.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            title: 'No plants',
            subtitle:
                'Installed / completed leads in this company will appear here.',
            icon: Icons.solar_power_outlined,
          ),
        )
      else
        ...state.plants.map(
          (plant) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AmcPlantCard(
              plant: plant,
              canManage: canManage,
              onOpenLead: () => _openLead(plant),
              onStartAmc: () => _startAmc(plant),
              onExtraVisit: () => _extraVisit(plant),
              onRenew: () => _renew(plant),
            ),
          ),
        ),
    ];
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

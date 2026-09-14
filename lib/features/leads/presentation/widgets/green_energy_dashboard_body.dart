import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_map_data.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/green_energy_dashboard_providers.dart';
import 'package:solar_sales/features/leads/presentation/widgets/india_heat_map.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/persistent_chart_touch.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

const _sky = Color(0xFF0284C7);
const _violet = Color(0xFF7C3AED);
const _amber = Color(0xFFD97706);
const _emerald = Color(0xFF059669);
const _rose = Color(0xFFE11D48);
const _teal = Color(0xFF0F766E);
const _pipeline = Color(0xFFF59E0B);
const _converted = Color(0xFF10B981);
const _completed = Color(0xFF0D7A5F);
const _rejected = Color(0xFFF43F5E);

class GreenEnergyDashboardBody extends ConsumerWidget {
  const GreenEnergyDashboardBody({
    super.key,
    required this.canReadLeads,
    this.canUseTerritoryFilters = false,
    this.onRetry,
  });

  final bool canReadLeads;
  /// Matches web: only roles granted `territoryFilters` see State/District/Role/User.
  final bool canUseTerritoryFilters;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canReadLeads) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          variant: AppCardVariant.flat,
          child: Text(
            'Your account does not have lead permissions yet. Ask an admin to assign lead.read / lead.create.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ),
      );
    }

    final async = ref.watch(greenEnergyDashboardProvider);
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: LoadingState(message: 'Loading pipeline overview…'),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ErrorState(
          message: cleanError(error),
          onRetry: onRetry == null
              ? null
              : () {
                  onRetry!();
                },
        ),
      ),
      data: (snapshot) => _DashboardLoaded(
        snapshot: snapshot,
        canUseTerritoryFilters: canUseTerritoryFilters,
        onRetry: onRetry,
      ),
    );
  }
}

class _DashboardLoaded extends ConsumerStatefulWidget {
  const _DashboardLoaded({
    required this.snapshot,
    required this.canUseTerritoryFilters,
    this.onRetry,
  });

  final GreenEnergyDashboardSnapshot snapshot;
  final bool canUseTerritoryFilters;
  final Future<void> Function()? onRetry;

  @override
  ConsumerState<_DashboardLoaded> createState() => _DashboardLoadedState();
}

class _DashboardLoadedState extends ConsumerState<_DashboardLoaded> {
  StateAnalytics? _tooltip;

  GreenEnergyDashboardSnapshot get snapshot => widget.snapshot;

  bool get _canUseTerritoryFilters => widget.canUseTerritoryFilters;

  void _showStateTooltip(StateAnalytics data) {
    setState(() => _tooltip = data);
    if (_canUseTerritoryFilters) {
      ref.read(territoryFiltersProvider.notifier).toggleState(data.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.kpis;
    final insights = snapshot.insights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canUseTerritoryFilters) ...[
          _TerritoryFiltersCard(snapshot: snapshot),
          const SizedBox(height: AppSpacing.lg),
        ],
        _IndiaDistributionCard(
          snapshot: snapshot,
          tooltip: _tooltip,
          canFilterByState: _canUseTerritoryFilters,
          onStateTap: _showStateTooltip,
          onDismissTooltip: () => setState(() => _tooltip = null),
        ),
        if (_canUseTerritoryFilters && snapshot.selectedState != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SelectedStateSummary(
            data: snapshot.selectedState!,
            canSeeRejected: true,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _PipelineCommandCenter(
          stats: stats,
          insights: insights,
          canSeeRejected: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _LeadMixCard(stats: stats, canSeeRejected: true),
        const SizedBox(height: AppSpacing.lg),
        _PriorityMixCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _AgingMixCard(insights: insights, openCount: stats.open),
        const SizedBox(height: AppSpacing.lg),
        _DeliveryHealthCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _NamedBarsCard(
          title: 'Top states',
          subtitle: 'Lead volume by territory',
          rows: insights.topStates,
          emptyLabel: 'No state data yet',
        ),
        const SizedBox(height: AppSpacing.lg),
        _NamedBarsCard(
          title: 'Workload',
          subtitle: 'Open leads by assignee',
          rows: insights.topAssignees,
          emptyLabel: 'No assignee data yet',
        ),
        const SizedBox(height: AppSpacing.lg),
        _MonthlyActivityCard(points: insights.monthly),
        const SizedBox(height: AppSpacing.lg),
        _StageVolumeCard(rows: insights.stageBars),
        const SizedBox(height: AppSpacing.lg),
        _NamedBarsCard(
          title: 'By department',
          subtitle: 'Open work distribution',
          rows: insights.byDepartment,
          emptyLabel: 'No open departments',
        ),
        const SizedBox(height: AppSpacing.lg),
        _QuickLinksCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _RecentUpdatesCard(rows: insights.recent),
      ],
    );
  }
}

class _SectionPad extends StatelessWidget {
  const _SectionPad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: child,
    );
  }
}

class _TerritoryFiltersCard extends ConsumerWidget {
  const _TerritoryFiltersCard({required this.snapshot});

  final GreenEnergyDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = snapshot.filters;
    final notifier = ref.read(territoryFiltersProvider.notifier);
    final users = snapshot.availableUsers;

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Territory filters',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Filter by state, district, role or user',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _FilterSelect(
              label: 'State',
              color: _sky,
              value: filters.state,
              hint: 'All states',
              options: snapshot.availableStates,
              onChanged: notifier.setState,
            ),
            const SizedBox(height: 8),
            _FilterSelect(
              label: 'District',
              color: _violet,
              value: filters.district,
              hint: filters.state.isEmpty
                  ? 'First select state'
                  : snapshot.availableDistricts.isEmpty
                      ? 'No districts'
                      : 'Select district',
              options: snapshot.availableDistricts,
              enabled: filters.state.isNotEmpty,
              onChanged: notifier.setDistrict,
            ),
            const SizedBox(height: 8),
            _FilterSelect(
              label: 'Role',
              color: _amber,
              value: filters.role,
              hint: 'All roles',
              options: snapshot.availableRoles,
              onChanged: notifier.setRole,
            ),
            const SizedBox(height: 8),
            _FilterSelect(
              label: 'User',
              color: _emerald,
              value: filters.userId,
              hint: 'Select user',
              options: users.map((u) => u.id).toList(),
              labels: {
                for (final user in users) user.id: _userLabel(user),
              },
              onChanged: notifier.setUser,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: filters.hasAny
                    ? () {
                        notifier.clearAll();
                        ref.invalidate(greenEnergyDashboardLeadsProvider);
                        ref.invalidate(territoryUsersProvider);
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9F1239),
                  side: const BorderSide(color: Color(0xFFFECDD3)),
                  backgroundColor: const Color(0xFFFFF1F2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ),
            if (filters.hasAny) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (filters.state.isNotEmpty)
                    _FilterChip(
                      tone: _sky,
                      prefix: 'State',
                      label: filters.state,
                      onDeleted: () => notifier.setState(''),
                    ),
                  if (filters.district.isNotEmpty)
                    _FilterChip(
                      tone: _violet,
                      prefix: 'District',
                      label: filters.district,
                      onDeleted: () => notifier.setDistrict(''),
                    ),
                  if (filters.role.isNotEmpty)
                    _FilterChip(
                      tone: _amber,
                      prefix: 'Role',
                      label: filters.role,
                      onDeleted: () => notifier.setRole(''),
                    ),
                  if (filters.userId.isNotEmpty)
                    _FilterChip(
                      tone: _emerald,
                      prefix: 'User',
                      label: _selectedUserLabel(snapshot),
                      onDeleted: () => notifier.setUser(''),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _userLabel(TerritoryUser user) {
    if (user.email.isEmpty) return user.name;
    return '${user.name} (${user.email})';
  }

  String _selectedUserLabel(GreenEnergyDashboardSnapshot snapshot) {
    for (final user in snapshot.users) {
      if (user.id == snapshot.filters.userId) return user.name;
    }
    return snapshot.filters.userId;
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.color,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.labels = const {},
    this.enabled = true,
  });

  final String label;
  final Color color;
  final String value;
  final String hint;
  final List<String> options;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value.isEmpty || !options.contains(value) ? null : value,
              hint: Text(
                hint,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All')),
                ...options.map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      labels[option] ?? option,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: !enabled
                  ? null
                  : (next) => onChanged(next ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.tone,
    required this.prefix,
    required this.label,
    required this.onDeleted,
  });

  final Color tone;
  final String prefix;
  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      visualDensity: VisualDensity.compact,
      backgroundColor: tone.withValues(alpha: 0.08),
      side: BorderSide(color: tone.withValues(alpha: 0.28)),
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$prefix  ',
              style: TextStyle(
                color: tone,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
      onDeleted: onDeleted,
      deleteIconColor: tone,
    );
  }
}

class _IndiaDistributionCard extends ConsumerWidget {
  const _IndiaDistributionCard({
    required this.snapshot,
    required this.tooltip,
    required this.canFilterByState,
    required this.onStateTap,
    required this.onDismissTooltip,
  });

  final GreenEnergyDashboardSnapshot snapshot;
  final StateAnalytics? tooltip;
  final bool canFilterByState;
  final ValueChanged<StateAnalytics> onStateTap;
  final VoidCallback onDismissTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapAsync = ref.watch(indiaMapDataProvider);
    final analytics = snapshot.stateAnalytics;
    var totalLeads = 0;
    var totalOpen = 0;
    var totalDone = 0;
    for (final item in analytics.values) {
      totalLeads += item.leads;
      totalOpen += item.open;
      totalDone += item.completed;
    }

    final activeStates = indiaStateNames
        .map((name) => analytics[name] ?? StateAnalytics(name: name))
        .where((item) => item.leads > 0)
        .toList()
      ..sort((a, b) => b.leads.compareTo(a.leads));

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'India State Distribution',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniPill('$totalLeads total leads', const Color(0xFF059669)),
                _MiniPill('$totalOpen open', const Color(0xFF0284C7)),
                _MiniPill('$totalDone done', const Color(0xFF0F766E)),
              ],
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: IndiaMapLegend(),
            ),
            const SizedBox(height: 10),
            Container(
              height: 320,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0F9FF), Colors.white, Color(0xFFECFDF5)],
                ),
                border: Border.all(color: const Color(0xFFE0F2FE)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MAP METRIC',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Lead volume by state',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 42, 8, 8),
                      child: mapAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                ref.invalidate(indiaMapDataProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry map'),
                          ),
                        ),
                        data: (map) {
                          var maxLeads = 1;
                          for (final item in analytics.values) {
                            if (item.leads > maxLeads) maxLeads = item.leads;
                          }
                          return IndiaHeatMap(
                            map: map,
                            analytics: analytics,
                            maxLeads: maxLeads,
                            selectedState: snapshot.filters.state,
                            height: 320,
                            onStateTap: onStateTap,
                          );
                        },
                      ),
                    ),
                  ),
                  if (tooltip != null)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _MapTooltip(
                        data: tooltip!,
                        onClose: onDismissTooltip,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Active States — ${activeStates.length} ${activeStates.length == 1 ? 'state' : 'states'} with leads',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            if (activeStates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No state-level leads yet. States with 0 leads still appear on the map.'),
              )
            else
              ...activeStates.take(12).map(
                    (item) => _ActiveStateTile(
                      data: item,
                      rank: activeStates.indexOf(item) + 1,
                      selected: normalizeStateName(snapshot.filters.state) ==
                          item.name,
                      onTap: () => onStateTap(item),
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              canFilterByState
                  ? 'Click a state on the map or list to apply the same filter.'
                  : 'Tap a state on the map or list to see lead counts.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MapTooltip extends StatelessWidget {
  const _MapTooltip({required this.data, required this.onClose});

  final StateAnalytics data;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${data.leads} leads',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveStateTile extends StatelessWidget {
  const _ActiveStateTile({
    required this.data,
    required this.rank,
    required this.selected,
    required this.onTap,
  });

  final StateAnalytics data;
  final int rank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = rank == 1
        ? const Color(0xFFEA580C)
        : rank == 2
            ? const Color(0xFF0284C7)
            : rank == 3
                ? const Color(0xFF059669)
                : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFECFDF5) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF6EE7B7)
                    : Theme.of(context).colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: accent,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _MiniPill('${data.leads} leads', const Color(0xFF059669)),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${data.users} users · ${data.open} open · ${data.completed} done',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedStateSummary extends StatelessWidget {
  const _SelectedStateSummary({
    required this.data,
    required this.canSeeRejected,
  });

  final StateAnalytics data;
  final bool canSeeRejected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shortCode = indiaMapShortName(data.name);

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECTED STATE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _teal,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (shortCode != data.name)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          shortCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [_emerald, _teal],
                        ),
                      ),
                      child: Text(
                        '${data.leads} leads',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StateStatTile(
                    label: 'Open',
                    value: data.open,
                    color: _amber,
                    icon: Icons.timelapse_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StateStatTile(
                    label: 'Converted',
                    value: data.converted,
                    color: _emerald,
                    icon: Icons.verified_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StateStatTile(
                    label: 'Completed',
                    value: data.completed,
                    color: _teal,
                    icon: Icons.task_alt_outlined,
                  ),
                ),
                if (canSeeRejected) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StateStatTile(
                      label: 'Rejected',
                      value: data.rejected,
                      color: _rose,
                      icon: Icons.block_rounded,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StateStatChip(
                    label: 'Active',
                    value: data.active,
                    color: _violet,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StateStatChip(
                    label: 'Install pending',
                    value: data.installPending,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _StateStatChip(
                    label: 'Users',
                    value: data.users,
                    color: _sky,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateStatTile extends StatelessWidget {
  const _StateStatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateStatChip extends StatelessWidget {
  const _StateStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineCommandCenter extends StatelessWidget {
  const _PipelineCommandCenter({
    required this.stats,
    required this.insights,
    required this.canSeeRejected,
  });

  final DashboardKpis stats;
  final DashboardInsights insights;
  final bool canSeeRejected;

  @override
  Widget build(BuildContext context) {
    final mom = insights.momCreatedPercent;
    final cards = [
      _KpiSpec(
        'Total',
        '${stats.total}',
        Icons.groups_rounded,
        const Color(0xFF334155),
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: '${insights.createdThisMonth} this month',
      ),
      _KpiSpec(
        'Open',
        '${stats.open}',
        Icons.timelapse_rounded,
        _amber,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: '${stats.openPercent}% of all',
      ),
      _KpiSpec(
        'Converted',
        '${stats.converted}',
        Icons.verified_outlined,
        _emerald,
        () => Navigator.pushNamed(context, '/solar/converted-leads'),
        hint: '${stats.conversionPercent}% convert rate',
      ),
      _KpiSpec(
        'Completed',
        '${stats.completed}',
        Icons.task_alt_outlined,
        _teal,
        () => Navigator.pushNamed(context, '/solar/completed-leads'),
        hint: '${stats.completionPercent}% closed',
      ),
      _KpiSpec(
        'New this week',
        '${stats.newThisWeek}',
        Icons.bolt_rounded,
        _sky,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint:
            '${insights.createdToday} today · ${insights.createdYesterday} yesterday',
      ),
      _KpiSpec(
        'MoM created',
        '${mom >= 0 ? '+' : ''}$mom%',
        Icons.trending_up_rounded,
        mom >= 0 ? _emerald : _rose,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint:
            '${insights.createdThisMonth} vs ${insights.createdLastMonth} last month',
      ),
      _KpiSpec(
        'Urgent + High',
        '${stats.urgent + stats.high}',
        Icons.warning_amber_rounded,
        _rose,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: '${stats.urgent} urgent · ${stats.high} high',
      ),
      _KpiSpec(
        'Install pending',
        '${stats.installPending}',
        Icons.build_circle_outlined,
        const Color(0xFFB45309),
        () => Navigator.pushNamed(context, '/solar/converted-leads'),
        hint: 'Missing installation details',
      ),
      _KpiSpec(
        'Approved',
        '${stats.approved}',
        Icons.verified_user_outlined,
        _emerald,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: 'Sales manager approved',
      ),
      _KpiSpec(
        'In pipeline',
        '${stats.inPipeline}',
        Icons.assignment_outlined,
        _amber,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: 'Not completed / rejected',
      ),
      _KpiSpec(
        'Active leads',
        '${stats.active}',
        Icons.groups_2_outlined,
        _violet,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: 'Open & active (excl. rejected)',
      ),
      if (canSeeRejected)
        _KpiSpec(
          'Rejected',
          '${stats.rejected}',
          Icons.block_rounded,
          _rose,
          () => Navigator.pushNamed(context, '/solar/leads'),
          hint: 'Visible to your role',
        )
      else
        _KpiSpec(
          'Stale open',
          '${insights.aging.stale}',
          Icons.schedule_rounded,
          _rose,
          () => Navigator.pushNamed(context, '/solar/leads'),
          hint: 'No update in 45+ days',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionPad(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF059669),
                  Color(0xFF0D9488),
                  Color(0xFF0369A1),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Text(
                    'GREEN ENERGY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pipeline command center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Live view of lead volume, conversion, territory strength and delivery bottlenecks.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(label: 'Open', value: '${stats.open}'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                        label: 'Convert',
                        value: '${stats.conversionPercent}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                        label: 'Done',
                        value: '${stats.completionPercent}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GridView.builder(
            itemCount: cards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              return _KpiCard(spec: cards[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSpec {
  const _KpiSpec(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.onTap, {
    this.hint,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? hint;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.spec});
  final _KpiSpec spec;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: spec.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: spec.color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(spec.icon, color: spec.color, size: 18),
              const Spacer(),
              Text(
                spec.value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spec.color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              if (spec.hint != null)
                Text(
                  spec.hint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadMixCard extends StatelessWidget {
  const _LeadMixCard({
    required this.stats,
    required this.canSeeRejected,
  });
  final DashboardKpis stats;
  final bool canSeeRejected;

  @override
  Widget build(BuildContext context) {
    return _DonutMixCard(
      title: 'Lead mix',
      subtitle: 'Pipeline vs converted vs done',
      centerLabel: 'Total',
      centerValue: stats.total,
      emptyLabel: 'No leads yet',
      slices: [
        for (final slice in buildLeadMixSlices(
          stats,
          canSeeRejected: canSeeRejected,
        ))
          (
            name: slice.name,
            value: slice.value,
            color: switch (slice.key) {
              'pipeline' => _pipeline,
              'converted' => _converted,
              'completed' => _completed,
              _ => _rejected,
            },
          ),
      ],
    );
  }
}

class _PriorityMixCard extends StatelessWidget {
  const _PriorityMixCard({required this.stats});
  final DashboardKpis stats;

  @override
  Widget build(BuildContext context) {
    return _DonutMixCard(
      title: 'Priority mix',
      subtitle: 'Open leads by priority',
      centerLabel: 'Open',
      centerValue: stats.open,
      emptyLabel: 'No open leads',
      slices: [
        (name: 'Urgent', value: stats.urgent, color: _rose),
        (name: 'High', value: stats.high, color: _rejected),
        (name: 'Medium', value: stats.medium, color: _pipeline),
        (name: 'Low', value: stats.low, color: const Color(0xFF94A3B8)),
      ],
    );
  }
}

class _DonutMixCard extends StatefulWidget {
  const _DonutMixCard({
    required this.title,
    required this.subtitle,
    required this.centerLabel,
    required this.emptyLabel,
    required this.slices,
    this.centerValue,
  });

  final String title;
  final String subtitle;
  final String centerLabel;
  final String emptyLabel;
  final int? centerValue;
  final List<({String name, int value, Color color})> slices;

  @override
  State<_DonutMixCard> createState() => _DonutMixCardState();
}

class _DonutMixCardState extends State<_DonutMixCard>
    with TimedChartTooltip {

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final sliceTotal = slices.fold<int>(0, (sum, item) => sum + item.value);
    final centerValue = widget.centerValue ?? sliceTotal;

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (sliceTotal == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text(widget.emptyLabel)),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 42,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                if (!persistChartTap(event)) return;
                                final sectionIndex =
                                    selectedPieSectionIndex(response);
                                if (sectionIndex == null) return;
                                final visible = [
                                  for (var i = 0; i < slices.length; i++)
                                    if (slices[i].value > 0) i,
                                ];
                                if (sectionIndex >= visible.length) return;
                                showChartTooltip(visible[sectionIndex]);
                              },
                            ),
                            sections: [
                              for (var i = 0; i < slices.length; i++)
                                if (slices[i].value > 0)
                                  PieChartSectionData(
                                    color: slices[i].color,
                                    value: slices[i].value.toDouble(),
                                    title: '',
                                    radius: selectedTooltipIndex == i ? 28 : 22,
                                  ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.centerLabel,
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              '$centerValue',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        for (final slice in slices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: slice.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    slice.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${slice.value}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            ' ${_pct(slice.value, sliceTotal)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _pct(int value, int total) {
    if (total <= 0) return '0%';
    return '${pieSlicePercent(value, total)}%';
  }
}

class _AgingMixCard extends StatelessWidget {
  const _AgingMixCard({
    required this.insights,
    required this.openCount,
  });

  final DashboardInsights insights;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    final aging = insights.aging;
    return _DonutMixCard(
      title: 'Open-lead aging',
      subtitle: 'Days since last update',
      centerLabel: 'Open',
      centerValue: openCount,
      emptyLabel: 'No open leads',
      slices: [
        (name: '≤ 7 days', value: aging.fresh, color: _converted),
        (name: '8–21 days', value: aging.warming, color: _sky),
        (name: '22–45 days', value: aging.aging, color: _pipeline),
        (name: '45+ days', value: aging.stale, color: _rejected),
      ],
    );
  }
}

class _DeliveryHealthCard extends StatelessWidget {
  const _DeliveryHealthCard({required this.stats});

  final DashboardKpis stats;

  @override
  Widget build(BuildContext context) {
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery health',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Conversion & completion scorecards',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RadialScore(
                    label: 'Convert',
                    percent: stats.conversionPercent,
                    color: _converted,
                  ),
                ),
                Expanded(
                  child: _RadialScore(
                    label: 'Complete',
                    percent: stats.completionPercent,
                    color: _completed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressRow(
              label: 'Open share',
              percent: stats.openPercent,
              hint: '${stats.open} leads',
              color: _pipeline,
            ),
            const SizedBox(height: 10),
            _ProgressRow(
              label: 'Conversion',
              percent: stats.conversionPercent,
              hint: '${stats.converted}',
              color: _converted,
            ),
            const SizedBox(height: 10),
            _ProgressRow(
              label: 'Completion',
              percent: stats.completionPercent,
              hint: '${stats.completed}',
              color: _completed,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialScore extends StatelessWidget {
  const _RadialScore({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100) / 100;
    return SizedBox(
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 36,
              sections: [
                if (clamped > 0)
                  PieChartSectionData(
                    value: clamped.toDouble(),
                    color: color,
                    radius: 12,
                    showTitle: false,
                  ),
                if (clamped < 1)
                  PieChartSectionData(
                    value: (1 - clamped).toDouble().clamp(0.0001, 1),
                    color: const Color(0xFFF1F5F9),
                    radius: 12,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 10)),
              Text(
                '$percent%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.percent,
    required this.hint,
    required this.color,
  });

  final String label;
  final int percent;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = percent.clamp(0, 100);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$pct% · $hint',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }
}

const _barColors = [
  Color(0xFF0D7A5F),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFF43F5E),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
];

class _NamedBarsCard extends StatelessWidget {
  const _NamedBarsCard({
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.emptyLabel,
  });

  final String title;
  final String subtitle;
  final List<NamedCount> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final maxValue = rows.fold<int>(1, (sum, row) => math.max(sum, row.value));
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text(emptyLabel)),
              )
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _NamedBarRow(
                  name: rows[i].name,
                  display: rows[i].display.isEmpty
                      ? '${rows[i].value}'
                      : rows[i].display,
                  value: rows[i].value,
                  maxValue: maxValue,
                  color: _barColors[i % _barColors.length],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _NamedBarRow extends StatelessWidget {
  const _NamedBarRow({
    required this.name,
    required this.display,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String name;
  final String display;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final width = math.max(6, (value / math.max(maxValue, 1)) * 100);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              display,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: width / 100,
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }
}

class _MonthlyActivityCard extends StatelessWidget {
  const _MonthlyActivityCard({required this.points});

  final List<MonthlyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<int>(
          0,
          (sum, p) => math.max(sum, math.max(p.created, math.max(p.converted, p.completed))),
        )
        .toDouble()
        .clamp(1, double.infinity);
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly activity',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Created · converted flow · completed (6 months)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFE2E8F0),
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[index].month,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].created.toDouble()),
                      ],
                      isCurved: true,
                      color: _sky,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _sky.withValues(alpha: 0.18),
                      ),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].converted.toDouble()),
                      ],
                      isCurved: true,
                      color: _converted,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _converted.withValues(alpha: 0.12),
                      ),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].completed.toDouble()),
                      ],
                      isCurved: true,
                      color: _completed,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Wrap(
              spacing: 12,
              children: [
                _LegendDot(color: _sky, label: 'Created'),
                _LegendDot(color: _converted, label: 'In converted flow'),
                _LegendDot(color: _completed, label: 'Completed'),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _StageVolumeCard extends StatelessWidget {
  const _StageVolumeCard({required this.rows});

  final List<NamedCount> rows;

  @override
  Widget build(BuildContext context) {
    const colors = {
      'early': Color(0xFF94A3B8),
      'sales': Color(0xFF0EA5E9),
      'docs': Color(0xFFF59E0B),
      'finance': Color(0xFF8B5CF6),
      'done': Color(0xFF0D7A5F),
    };
    final maxY = rows
        .fold<int>(0, (sum, row) => math.max(sum, row.value))
        .toDouble()
        .clamp(1, double.infinity);
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stage volume',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Where leads sit today',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: rows.isEmpty
                  ? const Center(child: Text('No stage data yet'))
                  : BarChart(
                      BarChartData(
                        maxY: maxY + 1,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFE2E8F0),
                            strokeWidth: 1,
                            dashArray: [3, 3],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (value, _) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                final index = value.toInt();
                                if (index < 0 || index >= rows.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: 52,
                                    child: Text(
                                      rows[index].name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < rows.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: rows[i].value.toDouble(),
                                  width: 18,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                  color: colors[rows[i].key] ??
                                      _barColors[i % _barColors.length],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({required this.stats});

  final DashboardKpis stats;

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        label: 'Leads',
        hint: 'Create & manage pipeline',
        icon: Icons.assignment_outlined,
        color: _sky,
        route: '/solar/leads',
      ),
      (
        label: 'Converted Lead',
        hint: '${stats.converted} in converted flow',
        icon: Icons.verified_outlined,
        color: _emerald,
        route: '/solar/converted-leads',
      ),
      (
        label: 'Completed Leads',
        hint: '${stats.completed} closed',
        icon: Icons.task_alt_outlined,
        color: _teal,
        route: '/solar/completed-leads',
      ),
      (
        label: 'Territory focus',
        hint: 'Use map & state filters above',
        icon: Icons.place_outlined,
        color: _violet,
        route: '/solar/leads',
      ),
      (
        label: 'Install pending',
        hint: '${stats.installPending} need details',
        icon: Icons.build_circle_outlined,
        color: const Color(0xFFB45309),
        route: '/solar/converted-leads',
      ),
    ];
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick links',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Jump into Green Energy work',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            for (final link in links) ...[
              Material(
                color: link.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, link.route),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(link.icon, color: link.color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                link.hint,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: link.color,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentUpdatesCard extends StatelessWidget {
  const _RecentUpdatesCard({required this.rows});

  final List<RecentLeadRow> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent updates',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Latest lead activity',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No recent leads')),
              )
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              [
                                row.code,
                                if (row.state.trim().isNotEmpty) row.state,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          row.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

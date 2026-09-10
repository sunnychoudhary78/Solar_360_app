import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_map_data.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/green_energy_dashboard_providers.dart';
import 'package:solar_sales/features/leads/presentation/widgets/india_heat_map.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
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
    final canSeeRejected = LeadWorkflow.canViewRejectedLeads(
      ref.watch(authProvider).effectiveRoleName,
    );
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
        if (snapshot.selectedState != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SelectedStateSummary(data: snapshot.selectedState!),
        ],
        const SizedBox(height: AppSpacing.lg),
        _PipelineCommandCenter(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        _LeadMixCard(stats: stats, canSeeRejected: canSeeRejected),
        const SizedBox(height: AppSpacing.lg),
        _AttentionCard(stats: stats),
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
  const _SelectedStateSummary({required this.data});

  final StateAnalytics data;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Selected State', data.name),
      ('Total Leads', '${data.leads}'),
      ('Open', '${data.open}'),
      ('Converted', '${data.converted}'),
      ('Completed', '${data.completed}'),
      ('Active Leads', '${data.active}'),
      ('Rejected', '${data.rejected}'),
      ('Install Pending', '${data.installPending}'),
      ('Users / agents', '${data.users}'),
    ];

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected State Summary',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tile in tiles)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 64) / 2,
                    child: _SummaryMetric(label: tile.$1, value: tile.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PipelineCommandCenter extends StatelessWidget {
  const _PipelineCommandCenter({
    required this.stats,
  });

  final DashboardKpis stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiSpec('Total Lead', '${stats.total}', Icons.groups_rounded, const Color(0xFF334155), () {
        Navigator.pushNamed(context, '/solar/leads');
      }),
      _KpiSpec('Open', '${stats.open}', Icons.timelapse_rounded, _amber, () {
        Navigator.pushNamed(context, '/solar/leads');
      }),
      _KpiSpec('Converted', '${stats.converted}', Icons.verified_outlined, _emerald, () {
        Navigator.pushNamed(context, '/solar/converted-leads');
      }),
      _KpiSpec('Completed', '${stats.completed}', Icons.task_alt_outlined, _teal, () {
        Navigator.pushNamed(context, '/solar/completed-leads');
      }),
      _KpiSpec('Active Leads', '${stats.active}', Icons.bolt_rounded, _violet, () {
        Navigator.pushNamed(context, '/solar/leads');
      }),
      _KpiSpec('Rejected', '${stats.rejected}', Icons.block_rounded, _rose, () {
        Navigator.pushNamed(context, '/solar/leads');
      }),
      _KpiSpec(
        'Install Pending',
        '${stats.installPending}',
        Icons.build_circle_outlined,
        const Color(0xFFB45309),
        () => Navigator.pushNamed(context, '/solar/converted-leads'),
      ),
      _KpiSpec(
        'Urgent + High',
        '${stats.urgent + stats.high}',
        Icons.warning_amber_rounded,
        _rose,
        () => Navigator.pushNamed(context, '/solar/leads'),
        hint: '${stats.urgent} urgent · ${stats.high} high',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pipeline command center',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Live view of lead volume, conversion and delivery bottlenecks.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
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
              childAspectRatio: 1.42,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              return _KpiCard(spec: card);
            },
          ),
        ),
      ],
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

class _LeadMixCard extends StatefulWidget {
  const _LeadMixCard({
    required this.stats,
    required this.canSeeRejected,
  });
  final DashboardKpis stats;
  final bool canSeeRejected;

  @override
  State<_LeadMixCard> createState() => _LeadMixCardState();
}

class _LeadMixCardState extends State<_LeadMixCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final slices = [
      (key: 'pipeline', name: 'Pipeline', value: stats.inPipeline, color: _pipeline),
      (key: 'converted', name: 'Converted', value: stats.converted, color: _converted),
      (key: 'done', name: 'Done', value: stats.completed, color: _completed),
      if (widget.canSeeRejected)
        (key: 'rejected', name: 'Rejected', value: stats.rejected, color: _rejected),
    ];
    final total = slices.fold<int>(0, (sum, item) => sum + item.value);

    return _SectionPad(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lead mix',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              'Pipeline vs converted vs done',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No leads yet')),
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
                                setState(() {
                                  _touched = response
                                      ?.touchedSection?.touchedSectionIndex;
                                });
                              },
                            ),
                            sections: [
                              for (var i = 0; i < slices.length; i++)
                                if (slices[i].value > 0)
                                  PieChartSectionData(
                                    color: slices[i].color,
                                    value: slices[i].value.toDouble(),
                                    title: '',
                                    radius: _touched == i ? 28 : 22,
                                  ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 10)),
                            Text(
                              '$total',
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
                                Expanded(child: Text(slice.name)),
                                Text(
                                  '${slice.value}  ${_pct(slice.value, total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
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
    return '${((value / total) * 100).round()}%';
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.stats});
  final DashboardKpis stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _AttentionItem(
        label: '${stats.urgent} urgent leads need attention',
        color: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF9F1239),
        route: '/solar/leads',
      ),
      _AttentionItem(
        label: '${stats.high} high-priority open leads',
        color: const Color(0xFFFFEDD5),
        foreground: const Color(0xFF9A3412),
        route: '/solar/leads',
      ),
      _AttentionItem(
        label: '${stats.installPending} leads waiting on installation details',
        color: const Color(0xFFFEF9C3),
        foreground: const Color(0xFF854D0E),
        route: '/solar/converted-leads',
      ),
      _AttentionItem(
        label: '${stats.newThisWeek} new open leads this week',
        color: const Color(0xFFE0F2FE),
        foreground: const Color(0xFF075985),
        route: '/solar/leads',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attention',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'Items that may need follow-up',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 520;
              if (!twoCol) {
                return Column(
                  children: [
                    for (final item in items) ...[
                      _AttentionPill(item: item),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: _AttentionPill(item: item),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.label,
    required this.color,
    required this.foreground,
    required this.route,
  });

  final String label;
  final Color color;
  final Color foreground;
  final String route;
}

class _AttentionPill extends StatelessWidget {
  const _AttentionPill({required this.item});
  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: item.foreground, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: item.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

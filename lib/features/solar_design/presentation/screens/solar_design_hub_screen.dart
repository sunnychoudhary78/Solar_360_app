import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_designs_screen.dart';
import 'package:solar_sales/features/solar_design/presentation/solar_design_access.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

/// Entry point matching the web workflow: search a lead → open 3D designs.
class SolarDesignHubScreen extends ConsumerStatefulWidget {
  const SolarDesignHubScreen({super.key});

  @override
  ConsumerState<SolarDesignHubScreen> createState() =>
      _SolarDesignHubScreenState();
}

class _SolarDesignHubScreenState extends ConsumerState<SolarDesignHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _opening = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LeadListNotifier get _notifier =>
      ref.read(leadListProvider(LeadListScope.all).notifier);

  Future<void> _openDesigns(LeadModel lead) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SolarDesignsScreen(lead: lead),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openLeadDetail(LeadModel lead) async {
    await Navigator.of(context).pushNamed(
      '/solar/leads/detail',
      arguments: lead.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canRead = SolarDesignAccess.canRead(auth);
    final state = ref.watch(leadListProvider(LeadListScope.all));
    final scheme = Theme.of(context).colorScheme;

    if (!canRead) {
      return Scaffold(
        appBar: const AppAppBar(title: '3D Solar Design'),
        body: const EmptyState(
          title: 'No access',
          subtitle: 'You need the solar design permission to use this feature.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(
        title: '3D Solar Design',
        subtitle: 'Search a lead, then design the rooftop',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Search lead name, mobile, code…',
              onChanged: (v) {
                _notifier.setSearch(v);
                setState(() {});
              },
              onClear: () {
                _notifier.setSearch('');
                setState(() {});
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Pick a lead to open rooftop designs — same tools as web: '
              'draw roof, place panels, obstacles, 3D sun & shading.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () => _notifier.refresh(),
                      )
                    : PaginatedListView<LeadModel>(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                        items: state.items,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        onRefresh: () => _notifier.refresh(),
                        onLoadMore: () => _notifier.loadMore(),
                        empty: EmptyState(
                          title: 'No leads found',
                          subtitle: state.search.isNotEmpty
                              ? 'Try a different search'
                              : 'Create a lead first, then design their roof',
                          icon: Icons.view_in_ar_outlined,
                        ),
                        itemBuilder: (context, lead, index) {
                          final title = lead.fullName.isEmpty
                              ? (lead.leadCode.isEmpty
                                  ? 'Untitled lead'
                                  : lead.leadCode)
                              : lead.fullName;
                          final location = [
                            if (lead.city.isNotEmpty) lead.city,
                            if (lead.state.isNotEmpty) lead.state,
                          ].join(', ');
                          final hasGps = double.tryParse(lead.latitude.trim()) !=
                                  null &&
                              double.tryParse(lead.longitude.trim()) != null;
                          return EntityTile(
                            index: index,
                            title: title,
                            subtitle: [
                              if (lead.leadCode.isNotEmpty) lead.leadCode,
                              if (lead.mobile.isNotEmpty) lead.mobile,
                              if (location.isNotEmpty) location,
                              if (lead.loadSectionKw.isNotEmpty)
                                lead.loadSectionKw,
                              hasGps ? 'GPS set' : 'No GPS',
                            ].join(' · '),
                            leadingIcon: Icons.solar_power_outlined,
                            status: lead.status.isEmpty ? null : lead.status,
                            onTap: _opening ? null : () => _openDesigns(lead),
                            trailing: IconButton(
                              tooltip: 'Lead details',
                              onPressed: () => _openLeadDetail(lead),
                              icon: const Icon(Icons.info_outline),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

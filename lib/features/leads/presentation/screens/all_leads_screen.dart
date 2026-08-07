import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_form_screen.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class AllLeadsScreen extends ConsumerStatefulWidget {
  final bool completedOnly;

  const AllLeadsScreen({super.key, this.completedOnly = false});

  @override
  ConsumerState<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends ConsumerState<AllLeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _openingLead = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LeadListNotifier get _notifier =>
      ref.read(leadListProvider(widget.completedOnly).notifier);

  Future<void> _refreshLeads() => _notifier.refresh();

  Future<void> _openCreateLead() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeadFormScreen()),
    );
    if (!mounted) return;
    await _refreshLeads();
  }

  Future<void> _openLead(LeadModel lead) async {
    if (_openingLead || !mounted) return;
    setState(() => _openingLead = true);
    await Navigator.of(
      context,
    ).pushNamed('/solar/leads/detail', arguments: lead.id);
    if (!mounted) return;
    setState(() => _openingLead = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadListProvider(widget.completedOnly));
    final canCreate = ref.watch(authProvider).hasPermission('lead.create');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: widget.completedOnly ? 'Completed Leads' : 'All Leads',
        subtitle: 'Green Energy pipeline',
        actions: [
          Tooltip(
            message: 'Refresh leads',
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshLeads,
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate && !widget.completedOnly
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Lead'),
              onPressed: _openCreateLead,
            )
          : null,
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
              hintText: 'Search name, mobile, code, status…',
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
          if (!widget.completedOnly)
            AppFilterBar(
              options: state.statusOptions,
              selected: state.statusFilter ?? 'All',
              onSelected: (v) =>
                  _notifier.setStatusFilter(v == 'All' ? null : v),
            ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: _refreshLeads,
                      )
                    : PaginatedListView<LeadModel>(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                        items: state.items,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        onRefresh: _refreshLeads,
                        onLoadMore: () => _notifier.loadMore(),
                        empty: EmptyState(
                          title: widget.completedOnly
                              ? 'No completed leads found'
                              : 'No leads found',
                          subtitle: state.search.isNotEmpty
                              ? 'Try a different search'
                              : 'Leads will appear here',
                          icon: Icons.handshake_outlined,
                        ),
                        itemBuilder: (context, lead, index) {
                          return EntityTile(
                            index: index,
                            title: lead.fullName.isEmpty
                                ? (lead.leadCode.isEmpty
                                    ? 'Untitled lead'
                                    : lead.leadCode)
                                : lead.fullName,
                            subtitle: [
                              if (lead.leadCode.isNotEmpty) lead.leadCode,
                              if (lead.mobile.isNotEmpty) lead.mobile,
                              if (lead.currentDepartment.isNotEmpty)
                                lead.currentDepartment,
                            ].join(' · '),
                            leadingIcon: Icons.handshake_rounded,
                            status: lead.status.isEmpty ? null : lead.status,
                            onTap: _openingLead
                                ? null
                                : () => _openLead(lead),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
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

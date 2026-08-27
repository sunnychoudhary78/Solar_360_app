import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/support/presentation/providers/support_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_card.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_filters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';

class SupportTicketsScreen extends ConsumerStatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  ConsumerState<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends ConsumerState<SupportTicketsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _selectedStat(SupportTicketListState state) {
    if (state.tab == SupportTicketTab.newRequests) return 'new';
    if (state.statusFilter == 'open') return 'open';
    if (state.statusFilter == 'resolved') return 'resolved';
    if (state.statusFilter == 'closed') return 'closed';
    return 'total';
  }

  void _onStatSelected(String key) {
    final notifier = ref.read(supportTicketListProvider.notifier);
    switch (key) {
      case 'new':
        notifier.setTab(SupportTicketTab.newRequests);
      case 'open':
        notifier.setStatusFilter('open');
      case 'resolved':
        notifier.setStatusFilter('resolved');
      case 'closed':
        notifier.setStatusFilter('closed');
      default:
        notifier.setTab(SupportTicketTab.all);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportTicketListProvider);
    final scheme = Theme.of(context).colorScheme;
    final newCount = state.counts.newRequests;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Support'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Support Requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SupportTicketStatsRow(
                  counts: state.counts,
                  selected: _selectedStat(state),
                  onSelected: _onStatSelected,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TabChip(
                        label: 'New Requests ($newCount)',
                        selected: state.tab == SupportTicketTab.newRequests,
                        onTap: () => ref
                            .read(supportTicketListProvider.notifier)
                            .setTab(SupportTicketTab.newRequests),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TabChip(
                        label: 'All Tickets (${state.counts.total})',
                        selected: state.tab == SupportTicketTab.all,
                        onTap: () => ref
                            .read(supportTicketListProvider.notifier)
                            .setTab(SupportTicketTab.all),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SupportTicketFilterBar(
                  searchController: _search,
                  statusFilter: state.statusFilter,
                  priorityFilter: state.priorityFilter,
                  categoryFilter: state.categoryFilter,
                  onSearchChanged: (value) {
                    ref
                        .read(supportTicketListProvider.notifier)
                        .setSearch(value);
                    setState(() {});
                  },
                  onSearchClear: () {
                    _search.clear();
                    ref.read(supportTicketListProvider.notifier).setSearch('');
                    setState(() {});
                  },
                  onStatusChanged: (value) => ref
                      .read(supportTicketListProvider.notifier)
                      .setStatusFilter(value),
                  onPriorityChanged: (value) => ref
                      .read(supportTicketListProvider.notifier)
                      .setPriorityFilter(value),
                  onCategoryChanged: (value) => ref
                      .read(supportTicketListProvider.notifier)
                      .setCategoryFilter(value),
                  hasActiveFilters: state.hasActiveFilters,
                  onClearFilters: () {
                    _search.clear();
                    ref.read(supportTicketListProvider.notifier).clearFilters();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const LoadingState()
                : state.error != null
                ? ErrorState(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(supportTicketListProvider.notifier).refresh(),
                  )
                : PaginatedListView(
                    items: state.items,
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    onRefresh: () =>
                        ref.read(supportTicketListProvider.notifier).refresh(),
                    onLoadMore: () =>
                        ref.read(supportTicketListProvider.notifier).loadMore(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    empty: EmptyState(
                      title: 'No support requests found',
                      subtitle: state.tab == SupportTicketTab.newRequests
                          ? 'There are currently no customer requests waiting for support.'
                          : 'No tickets match this search.',
                      icon: Icons.headset_mic_outlined,
                    ),
                    itemBuilder: (context, ticket, index) {
                      return SupportTicketCard(
                        ticket: ticket,
                        showCustomer: true,
                        onOpen: () async {
                          await Navigator.pushNamed(
                            context,
                            '/support/detail',
                            arguments: ticket.id,
                          );
                          ref
                              .read(supportTicketListProvider.notifier)
                              .refresh();
                        },
                      );
                    },
                  ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

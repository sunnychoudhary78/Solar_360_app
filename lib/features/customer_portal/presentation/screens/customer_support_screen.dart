import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_card.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_filters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';

class CustomerSupportScreen extends ConsumerStatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  ConsumerState<CustomerSupportScreen> createState() =>
      _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends ConsumerState<CustomerSupportScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _selectedStat(CustomerTicketListState state) {
    if (state.statusFilter == 'open') return 'open';
    if (state.statusFilter == 'resolved') return 'resolved';
    if (state.statusFilter == 'closed') return 'closed';
    if (state.statusFilter == 'complaint_raised') return 'new';
    if (state.statusFilter.isEmpty) return 'total';
    return 'total';
  }

  void _onStatSelected(String key) {
    final notifier = ref.read(customerTicketsProvider.notifier);
    switch (key) {
      case 'new':
        notifier.setStatusFilter('complaint_raised');
      case 'open':
        notifier.setStatusFilter('open');
      case 'resolved':
        notifier.setStatusFilter('resolved');
      case 'closed':
        notifier.setStatusFilter('closed');
      default:
        notifier.setStatusFilter('');
    }
  }

  Future<void> _openNewRequest() async {
    final result = await Navigator.pushNamed(context, '/customer/support/new');
    if (result == true) {
      await ref.read(customerTicketsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerTicketsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Support'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRequest,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Requests',
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
                SupportTicketFilterBar(
                  searchController: _search,
                  statusFilter: state.statusFilter,
                  priorityFilter: state.priorityFilter,
                  categoryFilter: state.categoryFilter,
                  onSearchChanged: (value) {
                    ref.read(customerTicketsProvider.notifier).setSearch(value);
                    setState(() {});
                  },
                  onSearchClear: () {
                    _search.clear();
                    ref.read(customerTicketsProvider.notifier).setSearch('');
                    setState(() {});
                  },
                  onStatusChanged: (value) => ref
                      .read(customerTicketsProvider.notifier)
                      .setStatusFilter(value),
                  onPriorityChanged: (value) => ref
                      .read(customerTicketsProvider.notifier)
                      .setPriorityFilter(value),
                  onCategoryChanged: (value) => ref
                      .read(customerTicketsProvider.notifier)
                      .setCategoryFilter(value),
                  hasActiveFilters: state.hasActiveFilters,
                  onClearFilters: () {
                    _search.clear();
                    ref.read(customerTicketsProvider.notifier).clearFilters();
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
                        ref.read(customerTicketsProvider.notifier).refresh(),
                  )
                : PaginatedListView(
                    items: state.items,
                    isLoadingMore: state.isLoadingMore,
                    hasMore: state.hasMore,
                    onRefresh: () =>
                        ref.read(customerTicketsProvider.notifier).refresh(),
                    onLoadMore: () =>
                        ref.read(customerTicketsProvider.notifier).loadMore(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    empty: EmptyState(
                      title: 'No support requests yet',
                      subtitle:
                          'Raise a request or follow a conversation started by support.',
                      icon: Icons.headset_mic_outlined,
                      action: FilledButton(
                        onPressed: _openNewRequest,
                        child: const Text('New request'),
                      ),
                    ),
                    itemBuilder: (context, ticket, index) {
                      return SupportTicketCard(
                        ticket: ticket,
                        isCustomerView: true,
                        onOpen: () async {
                          await Navigator.pushNamed(
                            context,
                            '/customer/support/detail',
                            arguments: ticket.id,
                          );
                          ref.read(customerTicketsProvider.notifier).refresh();
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

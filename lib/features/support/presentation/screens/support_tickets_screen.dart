import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/support/presentation/providers/support_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_card.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportTicketListProvider);
    final canCreate =
        ref.watch(authProvider).hasPermission('support_ticket.create');
    final scheme = Theme.of(context).colorScheme;
    final newCount = state.tab == SupportTicketTab.newRequests
        ? state.items.length
        : state.items.where((t) => t.isNew).length;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Support'),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'support_tickets_fab',
              onPressed: () async {
                final created = await Navigator.pushNamed(
                  context,
                  '/support/new',
                );
                if (created == true) {
                  ref.read(supportTicketListProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New request'),
            )
          : null,
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
                        label: 'All Tickets',
                        selected: state.tab == SupportTicketTab.all,
                        onTap: () => ref
                            .read(supportTicketListProvider.notifier)
                            .setTab(SupportTicketTab.all),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppSearchField(
                  controller: _search,
                  hintText: 'Search ticket #, subject, category…',
                  onChanged: (value) {
                    ref.read(supportTicketListProvider.notifier).setSearch(value);
                    setState(() {});
                  },
                  onClear: () {
                    ref.read(supportTicketListProvider.notifier).setSearch('');
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
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

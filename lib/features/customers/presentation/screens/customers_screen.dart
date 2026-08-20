import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/customer_model.dart';
import '../providers/customer_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerListProvider);
    final canCreate = ref.watch(authProvider).hasPermission('customer.create');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Customers'),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'customers_screen_fab',
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/customers/form',
                );
                if (result == true ||
                    (result is String && result.isNotEmpty)) {
                  ref.read(customerListProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Add Customer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Search name, phone, GST…',
              onChanged: (value) {
                ref.read(customerListProvider.notifier).setSearch(value);
                setState(() {});
              },
              onClear: () {
                ref.read(customerListProvider.notifier).setSearch('');
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () =>
                            ref.read(customerListProvider.notifier).refresh(),
                      )
                    : PaginatedListView(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                        items: state.items,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        onRefresh: () =>
                            ref.read(customerListProvider.notifier).refresh(),
                        onLoadMore: () =>
                            ref.read(customerListProvider.notifier).loadMore(),
                        empty: const EmptyState(
                          title: 'No customers found',
                          subtitle:
                              'Add your first customer to manage contacts and orders.',
                          icon: Icons.people_outline_rounded,
                        ),
                        itemBuilder: (context, customer, index) {
                          return _CustomerRow(
                            customer: customer,
                            index: index,
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/customers/form',
                                arguments: customer.id,
                              );
                              if (result == true ||
                                  (result is String && result.isNotEmpty)) {
                                ref
                                    .read(customerListProvider.notifier)
                                    .refresh();
                              }
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

class _CustomerRow extends StatelessWidget {
  final CustomerModel customer;
  final int index;
  final VoidCallback onTap;

  const _CustomerRow({
    required this.customer,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone;
    final email = customer.email;
    final hasSubtitle =
        customer.subtitle.isNotEmpty && customer.subtitle != 'No contact info';
    final subtitle = hasSubtitle
        ? customer.subtitle
        : (phone ?? email ?? 'No direct contact info');

    return EntityTile(
      index: index,
      title: customer.name.isEmpty ? 'Unnamed Customer' : customer.name,
      subtitle: subtitle,
      leadingLabel: customer.name.isEmpty ? 'C' : customer.name,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
              alpha: 0.5,
            ),
      ),
    );
  }
}

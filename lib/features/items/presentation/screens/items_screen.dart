import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/constants/item_categories.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../providers/item_providers.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  static const _filters = [
    FilterChipItem(value: '', label: 'All Items'),
    FilterChipItem(value: 'pending', label: 'Pending'),
    FilterChipItem(value: 'approved', label: 'Approved'),
    FilterChipItem(value: 'rejected', label: 'Rejected'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(itemListProvider.notifier).setSearch(query);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemListProvider);
    final authState = ref.watch(authProvider);
    final canCreate = authState.hasPermission('item.create');
    final canApprove = authState.hasPermission('item.approve');
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Inventory Items',
        actions: [
          if (canApprove) ...[
            IconButton(
              tooltip: 'Approvals',
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              onPressed: () => Navigator.pushNamed(context, '/items/approvals'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'items_screen_fab',
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              onPressed: () async {
                final result =
                    await Navigator.pushNamed(context, '/items/form');
                if (result == true) {
                  ref.read(itemListProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Item',
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
              hintText: 'Search by item name, SKU, or category…',
              onChanged: _onSearchChanged,
              onClear: () => _onSearchChanged(''),
            ),
          ),
          FilterChipBar(
            items: _filters,
            selected: state.status ?? '',
            onSelected: (v) => ref
                .read(itemListProvider.notifier)
                .setStatus(v.isEmpty ? null : v),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(itemListProvider.notifier).refresh(),
              child: state.isLoading && state.items.isEmpty
                  ? const LoadingState()
                  : state.error != null && state.items.isEmpty
                      ? ErrorState(
                          message: state.error!,
                          onRetry: () =>
                              ref.read(itemListProvider.notifier).refresh(),
                        )
                      : state.items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 80),
                                EmptyState(
                                  title: 'No items match your criteria',
                                  icon: Icons.inventory_2_outlined,
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                4,
                                AppSpacing.md,
                                80,
                              ),
                              itemCount:
                                  state.items.length + (state.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == state.items.length) {
                                  ref
                                      .read(itemListProvider.notifier)
                                      .loadMore();
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child:
                                          CircularProgressIndicator.adaptive(),
                                    ),
                                  );
                                }

                                final item = state.items[index];
                                return _ItemTileCard(
                                  item: item,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/items/detail',
                                    arguments: item.id,
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTileCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;

  const _ItemTileCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              StatusPill.forStatus(context, item.status as String? ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (item.category != null)
                _MetaChip(
                  icon: Icons.category_outlined,
                  label: ItemCategories.labelFor(item.category),
                ),
              if (item.sku != null)
                _MetaChip(
                  icon: Icons.qr_code_rounded,
                  label: 'SKU: ${item.sku}',
                ),
            ],
          ),
          if (item.status == 'rejected' &&
              item.rejectionReason != null &&
              (item.rejectionReason as String).trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Rejected: ${(item.rejectionReason as String).trim()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELLING PRICE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInr(item.sellingPrice),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  ItemUnits.labelFor(item.unit),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

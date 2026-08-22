import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../providers/item_category_providers.dart';
import '../providers/item_providers.dart';

class ItemApprovalsScreen extends ConsumerWidget {
  const ItemApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingItemsProvider);
    final categories = ref.watch(itemCategoriesProvider).value;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Item Approvals'),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(pendingItemsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(pendingItemsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  PremiumEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'No pending items',
                    subtitle: 'All caught up',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingItemsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.lg,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final subtitle = [
                  if (item.category != null)
                    itemCategoryLabel(categories, item.category),
                  if (item.sku != null) 'SKU: ${item.sku}',
                  formatInr(item.sellingPrice),
                ].join(' · ');

                return PremiumCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          PremiumStatusPill.forStatus(context, item.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _approve(context, ref, item.id),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(context, ref, item.id),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/items/form',
                            arguments: item.id,
                          );
                          if (result == true) {
                            ref.invalidate(pendingItemsProvider);
                            ref.invalidate(itemListProvider);
                          }
                        },
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                ).appFadeSlide(index: index);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve item',
      message: 'Approve this item?',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref.read(itemRepositoryProvider).approve(id);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Approved');
      ref.invalidate(pendingItemsProvider);
      ref.invalidate(itemListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject item',
      hint: 'Reason for rejection',
    );
    if (!context.mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(itemRepositoryProvider).reject(id, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Rejected');
      ref.invalidate(pendingItemsProvider);
      ref.invalidate(itemListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

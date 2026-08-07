import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/constants/item_categories.dart';
import 'package:solar_sales/shared/constants/item_units.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';
import 'package:solar_sales/shared/widgets/rejection_banner.dart';

import '../providers/item_providers.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemDetailProvider(itemId));
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(
        appBar: const AppAppBar(title: 'Item'),
        body: ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(itemDetailProvider(itemId)),
        ),
      ),
      data: (item) {
        final canEdit =
            auth.hasPermission('item.update') && item.status != 'approved';
        final canApprove =
            auth.hasPermission('item.approve') && item.status == 'pending';
        final canDeactivate =
            auth.hasPermission('item.update') && item.status == 'approved';

        final meta = <String>[
          formatInr(item.sellingPrice),
          'GST ${item.gstPercent}%',
          ItemUnits.labelFor(item.unit),
        ];

        final actionButtons = <Widget>[
          if (canEdit)
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/items/form',
                  arguments: item.id,
                );
                if (result == true) {
                  ref.invalidate(itemDetailProvider(itemId));
                }
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          if (canApprove) ...[
            FilledButton(
              onPressed: () => _approve(context, ref),
              child: const Text('Approve'),
            ),
            OutlinedButton(
              onPressed: () => _reject(context, ref),
              child: const Text('Reject'),
            ),
          ],
          if (canDeactivate)
            OutlinedButton.icon(
              onPressed: () => _deactivate(context, ref),
              icon: const Icon(Icons.block_outlined, size: 18),
              label: const Text('Deactivate'),
            ),
        ];

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          appBar: const AppAppBar(title: 'Item'),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  children: [
                    DocumentDetailHeader(
                      title: item.name,
                      subtitle:
                          item.sku ?? ItemCategories.labelFor(item.category),
                      status: item.status,
                      icon: Icons.inventory_2_outlined,
                      meta: meta,
                    ),
                    if (item.rejectionReason != null &&
                        item.rejectionReason!.isNotEmpty)
                      RejectionBanner(reason: item.rejectionReason!),
                    const PremiumSectionTitle(title: 'Details'),
                    PremiumCard(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        children: [
                          _InfoRow('SKU', item.sku ?? '—'),
                          _InfoRow(
                            'Category',
                            ItemCategories.labelFor(item.category),
                          ),
                          _InfoRow('HSN', item.hsnCode ?? '—'),
                          _InfoRow('SAC', item.sacCode ?? '—'),
                          _InfoRow('Unit', ItemUnits.labelFor(item.unit)),
                          _InfoRow('GST', '${item.gstPercent}%'),
                          _InfoRow('Price', formatInr(item.sellingPrice)),
                          _InfoRow('Min stock', '${item.minStockLevel}'),
                          if (item.totalQuantity != null)
                            _InfoRow('Total qty', '${item.totalQuantity}'),
                        ],
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const PremiumSectionTitle(title: 'Description'),
                      PremiumCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(item.description!),
                      ),
                    ],
                    const PremiumSectionTitle(title: 'Stock by warehouse'),
                    if (item.stockLevels.isEmpty)
                      PremiumCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'No stock records yet',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          children: item.stockLevels
                              .map(
                                (s) => LineItemCard(
                                  name: s.warehouseName ?? s.warehouseId,
                                  quantity: '${s.currentQuantity}',
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              if (actionButtons.isNotEmpty)
                StickyActionBar(children: actionButtons),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Approve item',
      message: 'Approve this item for use in quotations and inventory?',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref.read(itemRepositoryProvider).approve(itemId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Item approved');
      ref.invalidate(itemDetailProvider(itemId));
      ref.invalidate(pendingItemsProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject item',
      hint: 'Reason for rejection',
    );
    if (!context.mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(itemRepositoryProvider).reject(itemId, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Item rejected');
      ref.invalidate(itemDetailProvider(itemId));
      ref.invalidate(pendingItemsProvider);
      ref.invalidate(itemListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Deactivate item',
      message:
          'Deactivate this item so it no longer appears in active item flows?',
      confirmLabel: 'Deactivate',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Deactivating...');
    try {
      await ref.read(itemRepositoryProvider).deactivate(itemId);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Item deactivated');
      ref.invalidate(itemDetailProvider(itemId));
      ref.invalidate(itemListProvider);
      ref.invalidate(approvedItemsProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

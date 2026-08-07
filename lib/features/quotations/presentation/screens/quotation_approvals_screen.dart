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

import '../providers/quotation_providers.dart';

class QuotationApprovalsScreen extends ConsumerWidget {
  const QuotationApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingQuotationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Quotation Approvals'),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: () => ref.invalidate(pendingQuotationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(pendingQuotationsProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  PremiumEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'No pending quotations',
                    subtitle: 'All quotations have been reviewed',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingQuotationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.lg,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final q = items[index];
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
                              q.quotationNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          PremiumStatusPill.forStatus(context, q.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q.customerName,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatInr(q.totalAmount),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _approve(context, ref, q.id),
                              child: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(context, ref, q.id),
                              child: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/quotations/form',
                                arguments: q.id,
                              );
                              if (result == true) {
                                ref.invalidate(pendingQuotationsProvider);
                              }
                            },
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/quotations/detail',
                              arguments: q.id,
                            ),
                            child: const Text('View details'),
                          ),
                        ],
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
      title: 'Approve quotation',
      message: 'Approve this quotation?',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Approving...');
    try {
      await ref.read(quotationRepositoryProvider).approve(id);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Approved');
      ref.invalidate(pendingQuotationsProvider);
      ref.invalidate(quotationListProvider);
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
      title: 'Reject quotation',
      hint: 'Reason for rejection',
    );
    if (!context.mounted) return;
    if (reason == null || reason.isEmpty) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Rejecting...');
    try {
      await ref.read(quotationRepositoryProvider).reject(id, reason);
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Rejected');
      ref.invalidate(pendingQuotationsProvider);
      ref.invalidate(quotationListProvider);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }
}

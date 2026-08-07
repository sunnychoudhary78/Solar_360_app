import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';

import '../providers/quotation_providers.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _filters = [
    FilterChipItem(value: '', label: 'All'),
    FilterChipItem(value: 'draft', label: 'Draft'),
    FilterChipItem(value: 'pending_approval', label: 'Pending'),
    FilterChipItem(value: 'sent', label: 'Sent'),
    FilterChipItem(value: 'rejected', label: 'Rejected'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationListProvider);
    final canCreate = ref.watch(authProvider).hasPermission('quotation.create');
    final canApprove =
        ref.watch(authProvider).hasPermission('quotation.approve');
    final scheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final visibleItems = query.isEmpty
        ? state.items
        : state.items.where((q) {
            return q.quotationNumber.toLowerCase().contains(query) ||
                q.customerName.toLowerCase().contains(query) ||
                q.status.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Quotations',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(quotationListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canApprove)
            IconButton(
              tooltip: 'Approvals',
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, '/quotations/approvals'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'quotations_screen_fab',
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/quotations/form',
                );
                if (result == true) {
                  ref.read(quotationListProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Quotation',
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
              hintText: 'Search by ID, customer…',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
          ),
          FilterChipBar(
            items: _filters,
            selected: state.status ?? '',
            onSelected: (v) => ref
                .read(quotationListProvider.notifier)
                .setStatus(v.isEmpty ? null : v),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () =>
                            ref.read(quotationListProvider.notifier).refresh(),
                      )
                    : PaginatedListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          4,
                          AppSpacing.md,
                          80,
                        ),
                        items: visibleItems,
                        isLoadingMore: state.isLoadingMore,
                        hasMore: state.hasMore,
                        onRefresh: () =>
                            ref.read(quotationListProvider.notifier).refresh(),
                        onLoadMore: () =>
                            ref.read(quotationListProvider.notifier).loadMore(),
                        empty: const EmptyState(
                          title: 'No quotations found',
                          subtitle:
                              'Create a new quotation to kick off your workflow.',
                          icon: Icons.request_quote_outlined,
                        ),
                        itemBuilder: (context, q, index) {
                          return _QuotationCard(
                            quotation: q,
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                '/quotations/detail',
                                arguments: q.id,
                              );
                              if (!context.mounted) return;
                              ref
                                  .read(quotationListProvider.notifier)
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

class _QuotationCard extends StatelessWidget {
  final dynamic quotation;
  final VoidCallback onTap;

  const _QuotationCard({required this.quotation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reason = quotation.rejectionReason?.trim();
    final isRejected =
        quotation.status == 'rejected' && reason != null && reason.isNotEmpty;

    return PremiumCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.request_quote_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quotation.quotationNumber ?? 'N/A',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill.forStatus(context, quotation.status ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quotation.customerName ?? 'Unnamed Customer',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Value',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInr(quotation.totalAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isRejected) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: scheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: $reason',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

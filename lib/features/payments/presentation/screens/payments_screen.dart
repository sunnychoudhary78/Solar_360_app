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

import '../providers/payment_providers.dart';
import '../widgets/payment_tiles.dart';
import '../widgets/record_payment_sheet.dart';

/// Billbook → Finance → Payments (collections dashboard + milestone list).
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canRead = auth.hasAny(paymentReadPermissions) ||
        auth.hasPermission('module.billbook.access');
    final scheme = Theme.of(context).colorScheme;

    if (!canRead) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: const AppAppBar(title: 'Payments'),
        body: const EmptyState(
          title: 'No access',
          subtitle: 'You do not have permission to view collections.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppAppBar(
          title: 'Payments',
          subtitle: 'Collections on sent invoices',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(paymentDashboardProvider);
                ref.read(paymentMilestoneListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Milestones'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_OverviewTab(), _MilestonesTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentDashboardProvider);

    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        message: cleanError(e),
        onRetry: () => ref.invalidate(paymentDashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(paymentDashboardProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: PaymentKpiCard(
                          label: 'Collected this month',
                          value: formatInr(data.collectedThisMonth),
                          icon: Icons.savings_outlined,
                          color: const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PaymentKpiCard(
                          label: 'Outstanding',
                          value: formatInr(data.outstanding),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: PaymentKpiCard(
                          label: 'Overdue',
                          value: formatInr(data.overdueAmount),
                          subtitle: '${data.overdueCount} milestone'
                              '${data.overdueCount == 1 ? '' : 's'}',
                          icon: Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PaymentKpiCard(
                          label: 'Due this week',
                          value: formatInr(data.dueThisWeekAmount),
                          subtitle: '${data.dueThisWeekCount} milestone'
                              '${data.dueThisWeekCount == 1 ? '' : 's'}',
                          icon: Icons.event_available_outlined,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PaymentAgingBars(aging: data.aging),
            const PremiumSectionTitle(title: 'Top overdue'),
            if (data.topOverdue.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _EmptyHint(
                  icon: Icons.check_circle_outline,
                  message: 'Nothing overdue right now.',
                ),
              )
            else
              ...data.topOverdue.map(
                (s) => PaymentMilestoneTile(
                  schedule: s,
                  showParty: true,
                  onTap: s.sourceId.isEmpty
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            '/invoices/detail',
                            arguments: s.sourceId,
                          ).then((_) {
                            ref.invalidate(paymentDashboardProvider);
                          }),
                ),
              ),
            const PremiumSectionTitle(title: 'Recent receipts'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PremiumCard(
                child: data.recentPayments.isEmpty
                    ? const _EmptyHint(
                        icon: Icons.receipt_long_outlined,
                        message: 'No receipts recorded yet.',
                      )
                    : Column(
                        children: [
                          for (final receipt in data.recentPayments)
                            PaymentReceiptTile(receipt: receipt),
                        ],
                      ),
              ),
            ),
            const PremiumSectionTitle(title: 'Milestone counts'),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: PremiumCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _CountBlock(
                        label: 'Pending',
                        value: data.pendingCount,
                      ),
                    ),
                    Expanded(
                      child: _CountBlock(
                        label: 'Partial',
                        value: data.partialCount,
                      ),
                    ),
                    Expanded(
                      child: _CountBlock(
                        label: 'Paid',
                        value: data.paidCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestonesTab extends ConsumerStatefulWidget {
  const _MilestonesTab();

  @override
  ConsumerState<_MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends ConsumerState<_MilestonesTab> {
  final TextEditingController _searchController = TextEditingController();

  static const _filters = [
    FilterChipItem(value: '', label: 'All'),
    FilterChipItem(value: 'overdue', label: 'Overdue'),
    FilterChipItem(value: 'pending', label: 'Pending'),
    FilterChipItem(value: 'partial', label: 'Partial'),
    FilterChipItem(value: 'paid', label: 'Paid'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentMilestoneListProvider);
    final auth = ref.watch(authProvider);
    final canWrite = auth.hasAny(paymentWritePermissions);

    return Column(
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
            hintText: 'Search milestone…',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(() {}),
          ),
        ),
        FilterChipBar(
          items: _filters,
          selected: state.status ?? '',
          onSelected: (v) => ref
              .read(paymentMilestoneListProvider.notifier)
              .setStatus(v.isEmpty ? null : v),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: state.isLoading && state.items.isEmpty
              ? const LoadingState()
              : state.error != null && state.items.isEmpty
                  ? ErrorState(
                      message: state.error!,
                      onRetry: () =>
                          ref.read(paymentMilestoneListProvider.notifier).refresh(),
                    )
                  : PaginatedListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      items: state.items,
                      isLoadingMore: state.isLoadingMore,
                      hasMore: state.hasMore,
                      onRefresh: () => ref
                          .read(paymentMilestoneListProvider.notifier)
                          .refresh(),
                      onLoadMore: () =>
                          ref.read(paymentMilestoneListProvider.notifier).loadMore(),
                      empty: const EmptyState(
                        title: 'No milestones found',
                        subtitle:
                            'Milestones appear here once an invoice is approved and sent.',
                        icon: Icons.event_note_outlined,
                      ),
                      itemBuilder: (context, schedule, index) {
                        return PaymentMilestoneTile(
                          schedule: schedule,
                          showParty: true,
                          onTap: schedule.sourceId.isEmpty
                              ? null
                              : () => Navigator.pushNamed(
                                    context,
                                    '/invoices/detail',
                                    arguments: schedule.sourceId,
                                  ),
                          onRecord: canWrite
                              ? () => showRecordPaymentSheet(
                                    context,
                                    ref,
                                    schedule,
                                  )
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

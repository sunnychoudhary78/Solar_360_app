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

import '../providers/invoice_providers.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
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

  static Future<void> _showCreateMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
                child: Text(
                  'Create New Invoice',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: scheme.primary,
                  ),
                ),
                title: const Text(
                  'From quotation',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Convert an existing approved quotation'),
                onTap: () => Navigator.pop(context, 'quotation'),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.add_circle_outline, color: scheme.tertiary),
                ),
                title: const Text(
                  'Direct invoice',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Select customer & line items directly'),
                onTap: () => Navigator.pop(context, 'direct'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || choice == null) return;
    if (choice == 'quotation') {
      final result = await Navigator.pushNamed(context, '/invoices/create');
      if (result == true) {
        ref.read(invoiceListProvider.notifier).refresh();
      }
    } else if (choice == 'direct') {
      await Navigator.pushNamed(context, '/invoices/new');
      ref.read(invoiceListProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceListProvider);
    final canCreate = ref.watch(authProvider).hasPermission('invoice.create');
    final canApprove = ref.watch(authProvider).hasPermission('invoice.approve');
    final scheme = Theme.of(context).colorScheme;
    final query = _searchController.text.trim().toLowerCase();
    final visibleItems = query.isEmpty
        ? state.items
        : state.items.where((inv) {
            return inv.invoiceNumber.toLowerCase().contains(query) ||
                inv.customerName.toLowerCase().contains(query) ||
                inv.status.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Invoices',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(invoiceListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (canApprove)
            IconButton(
              tooltip: 'Approvals',
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, '/invoices/approvals'),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'invoices_screen_fab',
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              onPressed: () => _showCreateMenu(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Invoice',
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
              hintText: 'Search invoice, customer…',
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
          ),
          FilterChipBar(
            items: _filters,
            selected: state.status ?? '',
            onSelected: (v) => ref
                .read(invoiceListProvider.notifier)
                .setStatus(v.isEmpty ? null : v),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingState()
                : state.error != null && state.items.isEmpty
                    ? ErrorState(
                        message: state.error!,
                        onRetry: () =>
                            ref.read(invoiceListProvider.notifier).refresh(),
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
                            ref.read(invoiceListProvider.notifier).refresh(),
                        onLoadMore: () =>
                            ref.read(invoiceListProvider.notifier).loadMore(),
                        empty: const EmptyState(
                          title: 'No invoices found',
                          subtitle:
                              'Create your first invoice directly or convert a quotation.',
                          icon: Icons.receipt_long_outlined,
                        ),
                        itemBuilder: (context, inv, index) {
                          return _InvoiceCard(
                            invoice: inv,
                            onTap: () async {
                              await Navigator.pushNamed(
                                context,
                                '/invoices/detail',
                                arguments: inv.id,
                              );
                              if (!context.mounted) return;
                              ref.read(invoiceListProvider.notifier).refresh();
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

class _InvoiceCard extends StatelessWidget {
  final dynamic invoice;
  final VoidCallback onTap;

  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reason = invoice.rejectionReason?.trim();
    final isRejected =
        invoice.status == 'rejected' && reason != null && reason.isNotEmpty;

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
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  invoice.invoiceNumber ?? 'N/A',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill.forStatus(context, invoice.status ?? ''),
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
                      invoice.customerName ?? 'Unnamed Customer',
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
                    'Invoice Amount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInr(invoice.totalAmount),
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

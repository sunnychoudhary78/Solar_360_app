import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/features/costing/presentation/widgets/costing_section.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/paginated_list_view.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../provider/costing_provider.dart';
import 'costing_bill_dialog.dart';

/// All Costings tab — paginated list backed by `GET /costings`.
class CostingListTab extends ConsumerStatefulWidget {
  const CostingListTab({
    super.key,
    required this.isGreenEnergy,
    required this.canSelectVendor,
    required this.canCreateCosting,
    required this.vendors,
    required this.onEdit,
  });

  final bool isGreenEnergy;
  final bool canSelectVendor;
  final bool canCreateCosting;
  final List<CostingVendor> vendors;

  /// Open the Costing form tab with this row's party selected.
  final void Function(CostingListRow row) onEdit;

  @override
  ConsumerState<CostingListTab> createState() => _CostingListTabState();
}

class _CostingListTabState extends ConsumerState<CostingListTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _downloadingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CostingListNotifier get _notifier =>
      ref.read(costingListProvider(widget.isGreenEnergy).notifier);

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final state = ref.read(costingListProvider(widget.isGreenEnergy));
    final initial = (isFrom ? state.dateFrom : state.dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    _notifier.setDateRange(
      from: isFrom ? picked : state.dateFrom,
      to: isFrom ? state.dateTo : picked,
    );
  }

  Future<void> _download(CostingListRow row) async {
    setState(() => _downloadingId = row.id);
    try {
      final bytes = await ref
          .read(costingRepositoryProvider)
          .downloadPdf(row.id);
      final safeName = row.partyName
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final saved = await saveBytesAsDownload(
        bytes: bytes,
        fileName: 'costing-${safeName.isEmpty ? 'party' : safeName}.pdf',
        openAfterSave: true,
      );
      _snack('PDF saved: $saved');
    } catch (error) {
      _snack(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  void _openBill(CostingListRow row) {
    showCostingBillDialog(
      context,
      costingId: row.id,
      createdAt: row.createdAt,
      canEdit: widget.canCreateCosting,
      onEdit: () => widget.onEdit(row),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(costingListProvider(widget.isGreenEnergy));
    final scheme = Theme.of(context).colorScheme;

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
            hintText: 'Search name, phone, vendor…',
            onChanged: _notifier.setSearch,
            onClear: () => _notifier.setSearch(''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              if (widget.canSelectVendor) ...[
                DropdownButtonFormField<String>(
                  initialValue: state.vendorId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vendor',
                    prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All vendors')),
                    const DropdownMenuItem(
                      value: 'none',
                      child: Text('No vendor'),
                    ),
                    ...widget.vendors.map(
                      (vendor) => DropdownMenuItem(
                        value: vendor.id,
                        child: Text(
                          vendor.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => _notifier.setVendor(
                    value == null || value.isEmpty ? null : value,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: _dateButton(
                      label: state.dateFrom == null
                          ? 'From date'
                          : formatDate(state.dateFrom),
                      active: state.dateFrom != null,
                      onTap: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _dateButton(
                      label: state.dateTo == null
                          ? 'To date'
                          : formatDate(state.dateTo),
                      active: state.dateTo != null,
                      onTap: () => _pickDate(isFrom: false),
                    ),
                  ),
                  if (state.hasFilters)
                    TextButton(
                      onPressed: _notifier.clearFilters,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text(
                    '${state.total} ${state.total == 1 ? 'costing' : 'costings'}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: state.isLoading && state.items.isEmpty
              ? const LoadingState()
              : state.error != null && state.items.isEmpty
              ? ErrorState(message: state.error!, onRetry: _notifier.refresh)
              : PaginatedListView<CostingListRow>(
                  padding: const EdgeInsets.only(bottom: 80),
                  items: state.items,
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  onRefresh: _notifier.refresh,
                  onLoadMore: _notifier.loadMore,
                  empty: const EmptyState(
                    title: 'No costings found',
                    subtitle: 'Create a new costing to get started.',
                    icon: Icons.receipt_long_outlined,
                  ),
                  itemBuilder: (context, row, index) => _CostingRowCard(
                    row: row,
                    index: index,
                    canEdit: widget.canCreateCosting,
                    isDownloading: _downloadingId == row.id,
                    onTap: () => _openBill(row),
                    onEdit: () => widget.onEdit(row),
                    onDownload: () => _download(row),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _dateButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _CostingRowCard extends StatelessWidget {
  const _CostingRowCard({
    required this.row,
    required this.index,
    required this.canEdit,
    required this.isDownloading,
    required this.onTap,
    required this.onEdit,
    required this.onDownload,
  });

  final CostingListRow row;
  final int index;
  final bool canEdit;
  final bool isDownloading;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final createdBy = row.creatorName.trim();

    return PremiumCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  row.isLead ? Icons.person_outline : Icons.business_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.partyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (row.partyContact.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.partyContact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatInr(row.totalAmount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MetaChip(
                row.vendor == null ? 'No vendor' : row.vendor!.name,
                highlight: row.vendor != null,
              ),
              MetaChip(
                '${row.itemCount} ${row.itemCount == 1 ? 'item' : 'items'}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              'Created ${formatDate(row.createdAt)}',
              'Updated ${formatDate(row.updatedAt)}',
              if (createdBy.isNotEmpty) 'By $createdBy',
            ].join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              TextButton.icon(
                onPressed: canEdit ? onEdit : onTap,
                icon: Icon(canEdit ? Icons.edit_outlined : Icons.visibility_outlined, size: 18),
                label: Text(canEdit ? 'Edit' : 'View'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Download PDF',
                onPressed: row.itemCount == 0 || isDownloading ? null : onDownload,
                icon: isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
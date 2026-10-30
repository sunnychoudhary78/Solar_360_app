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

import '../provider/bom_provider.dart';
import '../provider/costing_provider.dart';


/// BOM project list (`GET /boms`) — no prices, one row per project.
class BomListTab extends ConsumerStatefulWidget {
  const BomListTab({
    super.key,
    required this.canCreateBom,
    required this.onOpen,
  });

  final bool canCreateBom;

  /// Open the BOM form tab with this project loaded.
  final void Function(BomListRow row) onOpen;

  @override
  ConsumerState<BomListTab> createState() => _BomListTabState();
}

class _BomListTabState extends ConsumerState<BomListTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _downloadingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BomListNotifier get _notifier => ref.read(bomListProvider.notifier);

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
    final state = ref.read(bomListProvider);
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

  Future<void> _download(BomListRow row) async {
    setState(() => _downloadingId = row.id);
    try {
      final bytes = await ref
          .read(costingRepositoryProvider)
          .downloadBomPdf(row.id);
      final safeName = row.projectName
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final saved = await saveBytesAsDownload(
        bytes: bytes,
        fileName: 'bom-${safeName.isEmpty ? 'project' : safeName}.pdf',
        openAfterSave: true,
      );
      _snack('PDF saved: $saved');
    } catch (error) {
      _snack(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bomListProvider);
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
            hintText: 'Search project or customer…',
            onChanged: _notifier.setSearch,
            onClear: () => _notifier.setSearch(''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
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
                    '${state.total} ${state.total == 1 ? 'project' : 'projects'}',
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
              : PaginatedListView<BomListRow>(
                  padding: const EdgeInsets.only(bottom: 80),
                  items: state.items,
                  isLoadingMore: state.isLoadingMore,
                  hasMore: state.hasMore,
                  onRefresh: _notifier.refresh,
                  onLoadMore: _notifier.loadMore,
                  empty: EmptyState(
                    title: 'No projects found',
                    subtitle:
                        'Select or create a project, then add the materials it needs.',
                    icon: Icons.inventory_2_outlined,
                    action: widget.canCreateBom
                        ? FilledButton.icon(
                            onPressed: () => widget.onOpen(
                              const BomListRow(id: '', projectName: ''),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('New project'),
                          )
                        : null,
                  ),
                  itemBuilder: (context, row, index) => _BomRowCard(
                    row: row,
                    canEdit: widget.canCreateBom,
                    isDownloading: _downloadingId == row.id,
                    onOpen: () => widget.onOpen(row),
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

class _BomRowCard extends StatelessWidget {
  const _BomRowCard({
    required this.row,
    required this.canEdit,
    required this.isDownloading,
    required this.onOpen,
    required this.onDownload,
  });

  final BomListRow row;
  final bool canEdit;
  final bool isDownloading;
  final VoidCallback onOpen;
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
      onTap: row.id.isEmpty ? null : onOpen,
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
                  Icons.inventory_2_outlined,
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
                      row.projectName.isEmpty ? 'Untitled project' : row.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
                '${row.itemCount} ${row.itemCount == 1 ? 'material' : 'materials'}',
                highlight: row.itemCount > 0,
              ),
              const MetaChip('Quantities only'),
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
                onPressed: row.id.isEmpty ? null : onOpen,
                icon: Icon(
                  canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(canEdit ? 'Open' : 'View'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Download PDF',
                onPressed: row.itemCount == 0 || isDownloading
                    ? null
                    : onDownload,
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
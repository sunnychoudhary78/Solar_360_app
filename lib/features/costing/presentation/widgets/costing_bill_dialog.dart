import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../provider/costing_provider.dart';

/// Bill preview dialog for the All Costings table (`GET /costings/:id`).
Future<void> showCostingBillDialog(
  BuildContext context, {
  required String costingId,
  DateTime? createdAt,
  required bool canEdit,
  required VoidCallback onEdit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CostingBillDialog(
      costingId: costingId,
      createdAt: createdAt,
      canEdit: canEdit,
      onEdit: onEdit,
    ),
  );
}

class _CostingBillDialog extends ConsumerStatefulWidget {
  const _CostingBillDialog({
    required this.costingId,
    required this.createdAt,
    required this.canEdit,
    required this.onEdit,
  });

  final String costingId;
  final DateTime? createdAt;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  ConsumerState<_CostingBillDialog> createState() => _CostingBillDialogState();
}

class _CostingBillDialogState extends ConsumerState<_CostingBillDialog> {
  bool _isDownloading = false;

  Future<void> _download(CostingSheet sheet) async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await ref
          .read(costingRepositoryProvider)
          .downloadPdf(sheet.id);
      final partyName = (sheet.customer?.name ?? sheet.lead?.fullName ?? 'party')
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final saved = await saveBytesAsDownload(
        bytes: bytes,
        fileName: 'costing-${partyName.isEmpty ? 'party' : partyName}.pdf',
        openAfterSave: true,
      );
      _snack('PDF saved: $saved');
    } catch (error) {
      _snack(cleanError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final sheet = ref.watch(costingDetailProvider(widget.costingId));
    return sheet.when(
      loading: () => const AlertDialog(
        content: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => AlertDialog(
        title: const Text('COSTING'),
        content: Text('Could not load this costing.\n${cleanError(error)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
      data: _buildBill,
    );
  }

  Widget _buildBill(CostingSheet sheet) {
    final scheme = Theme.of(context).colorScheme;
    final items = sheet.items;
    final vendor = sheet.vendor;
    final partyLabel = sheet.lead != null ? 'LEAD' : 'CUSTOMER';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('COSTING', style: TextStyle(letterSpacing: 1.2)),
          ),
          if (widget.createdAt != null)
            Text(
              formatDate(widget.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _partyBlock(sheet, partyLabel),
              if (vendor != null) ...[
                const SizedBox(height: 14),
                _block(
                  title: 'VENDOR',
                  lines: [
                    vendor.name,
                    vendor.contactNumber,
                    vendor.address,
                  ],
                ),
              ],
              const Divider(height: 26),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No items saved for this ${partyLabel.toLowerCase()} yet.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                for (var index = 0; index < items.length; index++)
                  _lineRow(items[index], index),
              const Divider(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Total price',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatInr(sheet.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.canEdit)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onEdit();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        FilledButton.icon(
          onPressed: items.isEmpty || _isDownloading
              ? null
              : () => _download(sheet),
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('PDF'),
        ),
      ],
    );
  }

  Widget _partyBlock(CostingSheet sheet, String label) {
    final customer = sheet.customer;
    final lead = sheet.lead;
    return _block(
      title: label,
      lines: [
        customer?.name ?? lead?.fullName ?? '—',
        customer?.phone ?? lead?.mobile,
        customer?.email ?? lead?.email,
        customer != null
            ? [customer.city, customer.state]
                  .whereType<String>()
                  .where((p) => p.isNotEmpty)
                  .join(', ')
            : [lead?.city, lead?.state]
                  .whereType<String>()
                  .where((p) => p.isNotEmpty)
                  .join(', '),
      ],
    );
  }

  Widget _block({required String title, required List<String?> lines}) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visible = lines
        .whereType<String>()
        .where((line) => line.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        for (final line in visible)
          Text(
            line,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: visible.first == line
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
      ],
    );
  }

  Widget _lineRow(CostingLine line, int index) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final meta = [
      line.kind == 'catalog' ? 'System' : 'Custom',
      'Qty ${_qty(line.quantity)}',
      formatInr(line.unitPrice),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (line.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Added ${formatDateTime(line.createdAt)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatInr(line.amount),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  static String _qty(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

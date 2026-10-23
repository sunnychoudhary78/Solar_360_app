import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/features/costing/presentation/widgets/costing_section.dart';
import 'package:solar_sales/shared/utils/formatters.dart';



class CostingLineTile extends StatelessWidget {
  final CostingLine line;
  final int index;
  final bool enabled;
  final bool isRemoving;
  final VoidCallback onRemove;

  const CostingLineTile({
    super.key,
    required this.line,
    required this.index,
    required this.enabled,
    this.isRemoving = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = line.unit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MetaChip(
                      line.kind == 'catalog' ? 'System' : 'Custom',
                      highlight: line.kind == 'catalog',
                    ),
                    if (unit != null && unit.isNotEmpty) MetaChip(unit),
                    MetaChip(
                      '${formatInr(line.unitPrice)} × ${formatQty(line.quantity)}',
                    ),
                  ],
                ),
                if (line.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Added ${DateFormat('d MMM yyyy, h:mm a').format(line.createdAt!.toLocal())}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatInr(line.amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove item',
                onPressed: enabled ? onRemove : null,
                icon: isRemoving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 20),
                color: scheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
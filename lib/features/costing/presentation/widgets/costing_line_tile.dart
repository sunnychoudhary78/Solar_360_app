import 'package:flutter/material.dart';
import 'package:solar_sales/features/costing/data/models/costing_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class CostingLineTile extends StatelessWidget {
  final CostingLine line;
  final int index;
  final bool enabled;
  final VoidCallback onRemove;

  const CostingLineTile({
    super.key,
    required this.line,
    required this.index,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text('${index + 1}'),
      ),
      title: Text(
        line.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${line.kind == 'catalog' ? 'System' : 'Custom'}'
        '${line.unit == null || line.unit!.isEmpty ? '' : ' · ${line.unit}'}'
        ' · ${formatInr(line.unitPrice)} × ${line.quantity}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatInr(line.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Remove item',
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.delete_outline_rounded),
            color: scheme.error,
          ),
        ],
      ),
    );
  }
}

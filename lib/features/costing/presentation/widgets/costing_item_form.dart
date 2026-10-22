import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class CostingItemForm extends StatelessWidget {
  final List<ItemModel> items;
  final bool canUseCatalog;
  final String kind;
  final String? selectedItemId;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final bool enabled;
  final bool isSaving;
  final double lineTotal;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String?> onItemChanged;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSubmit;

  const CostingItemForm({
    super.key,
    required this.items,
    required this.canUseCatalog,
    required this.kind,
    required this.selectedItemId,
    required this.nameController,
    required this.priceController,
    required this.quantityController,
    required this.enabled,
    required this.isSaving,
    required this.lineTotal,
    required this.onKindChanged,
    required this.onItemChanged,
    required this.onDraftChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canUseCatalog) ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'catalog',
                label: Text('Select'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
              ButtonSegment(
                value: 'custom',
                label: Text('Type'),
                icon: Icon(Icons.edit_outlined),
              ),
            ],
            selected: {kind},
            onSelectionChanged: enabled
                ? (selection) => onKindChanged(selection.first)
                : null,
          ),
          const SizedBox(height: 16),
        ],
        if (kind == 'catalog')
          DropdownButtonFormField<String>(
            key: ValueKey(selectedItemId),
            initialValue: selectedItemId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Approved item *',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.name} · ${formatInr(item.sellingPrice)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled && items.isNotEmpty ? onItemChanged : null,
            hint: Text(
              items.isEmpty ? 'No approved items available' : 'Select item',
            ),
          )
        else
          TextFormField(
            controller: nameController,
            enabled: enabled,
            onChanged: onDraftChanged,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item name *',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: priceController,
                enabled: enabled,
                onChanged: onDraftChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Unit price *',
                  prefixText: '₹ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: quantityController,
                enabled: enabled,
                onChanged: onDraftChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Line total')),
              Text(
                formatInr(lineTotal),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled && !isSaving ? onSubmit : null,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(isSaving ? 'Saving…' : 'Add & save'),
          ),
        ),
      ],
    );
  }
}

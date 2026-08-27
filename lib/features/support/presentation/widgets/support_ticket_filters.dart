import 'package:flutter/material.dart';

import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SupportTicketStatsRow extends StatelessWidget {
  const SupportTicketStatsRow({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final SupportTicketCounts counts;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatChip(
            label: 'Total',
            value: counts.total,
            icon: Icons.confirmation_number_outlined,
            selected: selected == 'total',
            onTap: () => onSelected('total'),
          ),
          _StatChip(
            label: 'New',
            value: counts.newRequests,
            icon: Icons.mark_email_unread_outlined,
            selected: selected == 'new',
            onTap: () => onSelected('new'),
          ),
          _StatChip(
            label: 'Open',
            value: counts.open,
            icon: Icons.bolt_outlined,
            selected: selected == 'open',
            onTap: () => onSelected('open'),
          ),
          _StatChip(
            label: 'Resolved',
            value: counts.resolved,
            icon: Icons.verified_outlined,
            selected: selected == 'resolved',
            onTap: () => onSelected('resolved'),
          ),
          _StatChip(
            label: 'Closed',
            value: counts.closed,
            icon: Icons.shield_outlined,
            selected: selected == 'closed',
            onTap: () => onSelected('closed'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 112,
        child: AppCard(
          onTap: onTap,
          variant: selected ? AppCardVariant.outlined : AppCardVariant.elevated,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportTicketFilterBar extends StatelessWidget {
  const SupportTicketFilterBar({
    super.key,
    required this.searchController,
    required this.statusFilter,
    required this.priorityFilter,
    required this.categoryFilter,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
    this.onClearFilters,
    this.hasActiveFilters = false,
  });

  final TextEditingController searchController;
  final String statusFilter;
  final String priorityFilter;
  final String categoryFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback? onClearFilters;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: searchController,
          hintText: 'Search ticket #, subject, category…',
          onChanged: onSearchChanged,
          onClear: onSearchClear,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterDropdown(
              value: statusFilter,
              hint: 'All status',
              items: [
                const DropdownMenuItem(value: '', child: Text('All status')),
                for (final item in SupportTicketConstants.statuses)
                  DropdownMenuItem(value: item.value, child: Text(item.label)),
              ],
              onChanged: onStatusChanged,
            ),
            _FilterDropdown(
              value: priorityFilter,
              hint: 'All priority',
              items: [
                const DropdownMenuItem(value: '', child: Text('All priority')),
                for (final item in SupportTicketConstants.priorities)
                  DropdownMenuItem(value: item.value, child: Text(item.label)),
              ],
              onChanged: onPriorityChanged,
            ),
            _FilterDropdown(
              value: categoryFilter,
              hint: 'All category',
              items: [
                const DropdownMenuItem(value: '', child: Text('All category')),
                for (final item in SupportTicketConstants.categories)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: onCategoryChanged,
            ),
            if (hasActiveFilters && onClearFilters != null)
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: items.any((item) => item.value == value) ? value : '',
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          hintText: hint,
        ),
        hint: Text(hint, overflow: TextOverflow.ellipsis),
        items: items,
        onChanged: (next) => onChanged(next ?? ''),
      ),
    );
  }
}

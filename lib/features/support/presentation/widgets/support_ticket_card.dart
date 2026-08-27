import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    super.key,
    required this.ticket,
    required this.onOpen,
    this.showCustomer = false,
    this.isCustomerView = false,
  });

  final SupportTicketModel ticket;
  final VoidCallback onOpen;
  final bool showCustomer;
  final bool isCustomerView;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unreadCount = ticket.unreadIncomingCount(
      isCustomerView: isCustomerView,
    );
    final created = ticket.createdAt == null
        ? null
        : DateFormat('dd MMM yyyy, hh:mm a').format(ticket.createdAt!);

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (ticket.ticketNumber.isNotEmpty)
                      Text(
                        ticket.ticketNumber,
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (ticket.isNewTag)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('NEW'),
                        backgroundColor: Colors.amber.withValues(alpha: 0.18),
                        side: BorderSide.none,
                      ),
                    _PriorityChip(priority: ticket.priority),
                    if (unreadCount > 0)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.amber.withValues(alpha: 0.18),
                        side: BorderSide.none,
                        label: Text('$unreadCount new'),
                      ),
                  ],
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(ticket.statusLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.subject,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (ticket.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ticket.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (showCustomer && ticket.customerName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    ticket.customerName[0].toUpperCase(),
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      ticket.customerName,
                      if ((ticket.customer?.phone ?? ticket.phone ?? '')
                          .isNotEmpty)
                        ticket.customer?.phone ?? ticket.phone,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (ticket.category.isNotEmpty)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(ticket.categoryLabel),
                ),
              const Spacer(),
              if (created != null)
                Text(
                  created,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: onOpen, child: const Text('Open')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final key = priority.toLowerCase();
    final Color color;
    switch (key) {
      case 'urgent':
        color = Colors.red;
      case 'high':
        color = Colors.orange;
      case 'low':
        color = Colors.blueGrey;
      default:
        color = Colors.blue;
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide.none,
      label: Text(
        priority.isEmpty
            ? 'Medium'
            : '${priority[0].toUpperCase()}${priority.substring(1)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

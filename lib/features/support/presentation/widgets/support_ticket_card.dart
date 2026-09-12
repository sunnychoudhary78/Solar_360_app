import 'package:flutter/material.dart';

import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SupportUnreadBanner extends StatelessWidget {
  const SupportUnreadBanner({
    super.key,
    required this.count,
    this.isCustomerView = false,
  });

  final int count;
  final bool isCustomerView;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count == 1 ? '1 unread msg' : '$count unread msgs';
    final from = isCustomerView ? 'from support' : 'from customers';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active_rounded,
              size: 16, color: Color(0xFFE11D48)),
          const SizedBox(width: 6),
          Text(
            '$label · $from',
            style: const TextStyle(
              color: Color(0xFF9F1239),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final hasUnread = unreadCount > 0;
    final created =
        ticket.createdAt == null ? null : formatDateTime(ticket.createdAt);
    final preview = _unreadPreview();

    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: hasUnread
              ? const Color(0xFFFFF1F2).withValues(alpha: 0.9)
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: hasUnread
                      ? const Color(0xFFF43F5E)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
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
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              label: const Text('NEW'),
                              backgroundColor:
                                  Colors.amber.withValues(alpha: 0.18),
                              side: BorderSide.none,
                            ),
                          if (hasUnread)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              backgroundColor: const Color(0xFFFFE4E6),
                              side: BorderSide.none,
                              avatar: const Icon(
                                Icons.notifications_active_rounded,
                                size: 14,
                                color: Color(0xFFE11D48),
                              ),
                              label: Text(
                                unreadCount == 1
                                    ? '1 NEW MSG'
                                    : '$unreadCount NEW MSGS',
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PriorityChip(priority: ticket.priority),
                          if (ticket.requestType.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.10),
                              side: BorderSide.none,
                              label: Text(
                                ticket.requestTypeLabel,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: Text(ticket.statusLabel),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ticket.subject,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'New: ',
                                style: TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: preview),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else if (ticket.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ticket.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (showCustomer && ticket.customerName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.12),
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
                                  if ((ticket.customer?.phone ??
                                              ticket.phone ??
                                              '')
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: onOpen,
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _unreadPreview() {
    final latest = ticket.lastMessage ??
        (ticket.messages.isEmpty ? null : ticket.messages.last);
    if (latest == null || latest.message.trim().isEmpty) return null;
    final incoming = isCustomerView ? !latest.isCustomer : latest.isCustomer;
    if (!incoming || latest.readAt != null) return null;
    return latest.message.trim();
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
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

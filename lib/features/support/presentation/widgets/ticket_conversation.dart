import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class TicketConversation extends StatelessWidget {
  const TicketConversation({
    super.key,
    required this.messages,
    required this.isCustomerView,
    required this.currentUserId,
    required this.customerName,
    this.composer,
  });

  final List<SupportTicketMessage> messages;
  final bool isCustomerView;
  final String currentUserId;
  final String customerName;
  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = messages.where((m) => !m.isInternal).toList();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Conversation',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              '${visible.length} ${visible.length == 1 ? 'message' : 'messages'}',
                            ),
                          ),
                          if (_unreadCount(visible) > 0) ...[
                            const SizedBox(width: 6),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.18,
                              ),
                              side: BorderSide.none,
                              label: Text('${_unreadCount(visible)} unread'),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        isCustomerView
                            ? 'Messages with the support team'
                            : 'Direct conversation with ${customerName.isEmpty ? 'customer' : customerName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  isCustomerView
                      ? 'Send your first message to the support team.'
                      : 'No messages yet. Reply to start the conversation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _MessageBubble(
                      message: visible[i],
                      isMine: _isMine(visible[i]),
                      isCustomerView: isCustomerView,
                      customerName: customerName,
                      deliveryStatus: _deliveryStatus(visible[i]),
                    ),
                  ],
                ],
              ),
            ),
          if (composer != null) ...[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            composer!,
          ],
        ],
      ),
    );
  }

  bool _isMine(SupportTicketMessage message) {
    if (isCustomerView) {
      return message.isCustomer &&
          (currentUserId.isEmpty ||
              message.senderId.isEmpty ||
              message.senderId == currentUserId);
    }
    return !message.isCustomer &&
        (currentUserId.isEmpty ||
            message.senderId.isEmpty ||
            message.senderId == currentUserId);
  }

  int _unreadCount(List<SupportTicketMessage> messages) {
    return messages.where((message) {
      final incoming = isCustomerView
          ? !message.isCustomer
          : message.isCustomer;
      return incoming && message.readAt == null;
    }).length;
  }

  String? _deliveryStatus(SupportTicketMessage message) {
    if (!_isMine(message)) return null;
    if (message.readAt != null) return 'Seen';
    if (message.deliveredAt != null || message.id.isNotEmpty) {
      return 'Delivered';
    }
    return null;
  }
}

class TicketReplyBox extends StatefulWidget {
  const TicketReplyBox({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.hintText,
    this.replyToName,
    this.sending = false,
    this.embedded = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final String hintText;
  final String? replyToName;
  final bool sending;
  final bool embedded;

  @override
  State<TicketReplyBox> createState() => _TicketReplyBoxState();
}

class _TicketReplyBoxState extends State<TicketReplyBox> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant TicketReplyBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.controller.text.length;
    final canSend =
        widget.enabled &&
        !widget.sending &&
        widget.controller.text.trim().isNotEmpty;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                (widget.replyToName == null ||
                        widget.replyToName!.trim().isEmpty)
                    ? 'Reply'
                    : 'Reply to ${widget.replyToName}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$count/4000',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.enabled
              ? 'Share more details or ask a follow-up question'
              : 'This ticket is closed. Messaging is disabled.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled && !widget.sending,
          minLines: 2,
          maxLines: 4,
          maxLength: 4000,
          decoration: InputDecoration(
            hintText: widget.hintText,
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: canSend ? widget.onSend : null,
            icon: widget.sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(widget.sending ? 'Sending...' : 'Send reply'),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: body,
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: body,
    );
  }
}

class TicketTimelineCard extends StatelessWidget {
  const TicketTimelineCard({super.key, required this.history});

  final List<SupportTicketHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFF7C3AED,
                ).withValues(alpha: 0.12),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF7C3AED),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket Timeline',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Track request activity',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                  style: BorderStyle.solid,
                ),
              ),
              child: Text(
                'No timeline activity available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 10, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (item.note.isNotEmpty)
                            Text(
                              item.note,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (item.createdAt != null)
                            Text(
                              formatDateTime(item.createdAt),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isCustomerView,
    required this.customerName,
    this.deliveryStatus,
  });

  final SupportTicketMessage message;
  final bool isMine;
  final bool isCustomerView;
  final String customerName;
  final String? deliveryStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alignEnd = isCustomerView ? message.isCustomer : isMine;
    final name = _displayName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final time = message.createdAt == null
        ? ''
        : formatDateTimeShort(message.createdAt);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: alignEnd && isCustomerView ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: alignEnd && isCustomerView
              ? null
              : Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.55),
                ),
        ),
        child: Text(
          message.message,
          style: TextStyle(
            color: alignEnd && isCustomerView
                ? scheme.onPrimary
                : scheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary.withValues(alpha: 0.16),
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );

    final meta = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        [name, if (time.isNotEmpty) time].join('  ·  '),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: alignEnd && isCustomerView
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final status = deliveryStatus == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deliveryStatus == 'Seen'
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
                  size: 14,
                  color: deliveryStatus == 'Seen'
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  deliveryStatus!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: deliveryStatus == 'Seen'
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

    if (alignEnd) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(child: meta),
              const SizedBox(width: 8),
              avatar,
            ],
          ),
          bubble,
          status,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar,
            const SizedBox(width: 8),
            Flexible(child: meta),
          ],
        ),
        Padding(padding: const EdgeInsets.only(left: 40), child: bubble),
        Padding(padding: const EdgeInsets.only(left: 40), child: status),
      ],
    );
  }

  String _displayName() {
    if (isMine) return 'You';
    if (message.isCustomer) {
      return message.senderName.isNotEmpty
          ? message.senderName
          : (customerName.isEmpty ? 'Customer' : customerName);
    }
    return message.senderName.isNotEmpty ? message.senderName : 'Admin';
  }
}

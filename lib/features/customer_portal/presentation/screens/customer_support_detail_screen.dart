import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/ticket_conversation.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class CustomerSupportDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const CustomerSupportDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<CustomerSupportDetailScreen> createState() =>
      _CustomerSupportDetailScreenState();
}

class _CustomerSupportDetailScreenState
    extends ConsumerState<CustomerSupportDetailScreen> {
  final _reply = TextEditingController();
  SupportTicketModel? _ticket;
  bool _loading = true;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = ref.read(customerPortalApiServiceProvider);
      final ticket = await api.getTicket(widget.ticketId);
      try {
        await api.markMessagesRead(widget.ticketId);
      } catch (_) {}
      var history = ticket.history;
      if (history.isEmpty) {
        try {
          history = await api.getTicketHistory(widget.ticketId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _ticket = _mergeTicket(ticket, history);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _ticket == null) return;
    setState(() => _sending = true);
    try {
      final sent = await ref
          .read(customerPortalApiServiceProvider)
          .addMessage(_ticket!.id, text);
      _reply.clear();
      if (mounted && sent.message.trim().isNotEmpty) {
        setState(() {
          _ticket = _ticket!.copyWith(
            messages: _mergeMessages(_ticket!.messages, [sent]),
          );
        });
      }
      await _load(silent: true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  SupportTicketModel _mergeTicket(
    SupportTicketModel incoming,
    List<SupportTicketHistoryItem> history,
  ) {
    final previous = _ticket;
    return incoming.copyWith(
      history: history.isNotEmpty ? history : incoming.history,
      messages: incoming.messages.isNotEmpty
          ? incoming.messages
          : (previous?.messages ?? incoming.messages),
    );
  }

  List<SupportTicketMessage> _mergeMessages(
    List<SupportTicketMessage> current,
    List<SupportTicketMessage> extra,
  ) {
    final merged = [...current];
    for (final item in extra) {
      final exists = item.id.isNotEmpty && merged.any((m) => m.id == item.id);
      if (!exists) merged.add(item);
    }
    return merged;
  }

  Future<void> _verify(bool verified) async {
    if (_ticket == null) return;
    setState(() => _verifying = true);
    ref
        .read(globalLoadingProvider.notifier)
        .showLoading(
          verified ? 'Verifying resolution...' : 'Reopening ticket...',
        );
    try {
      await ref
          .read(customerPortalApiServiceProvider)
          .verifyResolution(
            _ticket!.id,
            verified: verified,
            rating: verified ? 5 : null,
            feedback: verified ? 'Issue resolved' : 'Issue is not resolved',
          );
      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess(
            verified
                ? 'Thank you. Ticket has been verified.'
                : 'Ticket has been reopened for further support.',
          );
      await _load();
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customer = ref.watch(authProvider).customer;
    final ticket = _ticket;

    if (_loading) {
      return const Scaffold(
        appBar: AppAppBar(title: 'Request details'),
        body: LoadingState(),
      );
    }
    if (_error != null || ticket == null) {
      return Scaffold(
        appBar: const AppAppBar(title: 'Request details'),
        body: ErrorState(
          message: _error ?? 'Unable to load ticket',
          onRetry: _load,
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: ticket.ticketNumber.isEmpty
            ? 'Request details'
            : ticket.ticketNumber,
        subtitle: ticket.subject,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(ticket.statusLabel)),
                      Chip(label: Text(ticket.priorityLabel)),
                      if (ticket.requestType.isNotEmpty)
                        Chip(label: Text(ticket.requestTypeLabel)),
                      if (ticket.category.isNotEmpty)
                        Chip(label: Text(ticket.categoryLabel)),
                    ],
                  ),
                  if (ticket.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(ticket.description),
                  ],
                  if (ticket.createdAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Created ${formatDateTime(ticket.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if ((ticket.resolutionSummary ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resolution',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(ticket.resolutionSummary!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (ticket.isResolved) ...[
              const SizedBox(height: 12),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded, color: scheme.onPrimary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Is your issue resolved?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onPrimary,
                                  ),
                                ),
                                Text(
                                  'Please verify the resolution so we can close your support ticket.',
                                  style: TextStyle(
                                    color: scheme.onPrimary.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _verifying ? null : () => _verify(true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Yes, issue resolved'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _verifying ? null : () => _verify(false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('No, still need help'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TicketConversation(
              messages: ticket.messages,
              isCustomerView: true,
              currentUserId: customer?.id ?? '',
              customerName: customer?.name ?? ticket.customerName,
              composer: TicketReplyBox(
                controller: _reply,
                onSend: _send,
                enabled: !ticket.isClosed,
                sending: _sending,
                embedded: true,
                replyToName: 'support',
                hintText: 'Write your reply...',
              ),
            ),
            const SizedBox(height: 12),
            TicketTimelineCard(history: ticket.history),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/features/support/presentation/providers/support_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/ticket_conversation.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  final String ticketId;

  const SupportTicketDetailScreen({super.key, required this.ticketId});

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final _reply = TextEditingController();
  final _resolution = TextEditingController();
  SupportTicketModel? _ticket;
  String _status = 'open';
  bool _loading = true;
  bool _sending = false;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reply.dispose();
    _resolution.dispose();
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
      final api = ref.read(supportApiServiceProvider);
      final ticket = await api.getById(widget.ticketId);
      try {
        await api.markMessagesRead(widget.ticketId);
      } catch (_) {}
      var history = ticket.history;
      if (history.isEmpty) {
        try {
          history = await api.history(widget.ticketId);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _ticket = ticket.copyWith(history: history);
        _status = ticket.status.isEmpty ? 'open' : ticket.status;
        if (!silent) {
          _resolution.text = ticket.resolutionSummary ?? '';
        }
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
      await ref.read(supportApiServiceProvider).addMessage(_ticket!.id, text);
      _reply.clear();
      await _load(silent: true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus() async {
    if (_ticket == null) return;
    setState(() => _updating = true);
    ref.read(globalLoadingProvider.notifier).showLoading('Updating status...');
    try {
      await ref.read(supportApiServiceProvider).update(_ticket!.id, {
        'status': _status,
        'resolution_summary': _resolution.text.trim().isEmpty
            ? null
            : _resolution.text.trim(),
      });
      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess(
            'Ticket status updated to ${SupportTicketConstants.statusLabel(_status)}.',
          );
      await _load(silent: true);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _solveAndClose() async {
    if (_ticket == null) return;
    final note = _resolution.text.trim();
    if (note.isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showApiError(
            'Please enter a resolution summary before closing the ticket.',
          );
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Close this request?',
      message:
          'The ticket will be marked as closed and the customer will see the resolution.',
      confirmLabel: 'Solve & Close',
    );
    if (!ok || !mounted) return;
    ref.read(globalLoadingProvider.notifier).showLoading('Closing ticket...');
    try {
      await ref.read(supportApiServiceProvider).update(_ticket!.id, {
        'status': 'closed',
        'resolution_summary': note,
      });
      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Ticket solved and closed');
      await _load();
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final canUpdate = auth.hasPermission('support_ticket.update');
    final ticket = _ticket;

    if (_loading) {
      return const Scaffold(
        appBar: AppAppBar(title: 'Support request'),
        body: LoadingState(),
      );
    }
    if (_error != null || ticket == null) {
      return Scaffold(
        appBar: const AppAppBar(title: 'Support request'),
        body: ErrorState(
          message: _error ?? 'Unable to load ticket',
          onRetry: _load,
        ),
      );
    }

    final processStatus =
        SupportTicketConstants.processStatuses.any(
          (item) => item.value == _status,
        )
        ? _status
        : 'open';

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: ticket.ticketNumber.isEmpty
            ? 'Support request'
            : ticket.ticketNumber,
        subtitle: ticket.subject,
      ),
      body: ListView(
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
                    if (ticket.customerName.isNotEmpty)
                      Chip(label: Text(ticket.customerName)),
                    Chip(
                      label: Text(
                        ticket.customerVerified
                            ? 'Customer verified'
                            : 'Not verified',
                      ),
                    ),
                    if (ticket.assignee != null &&
                        ticket.assignee!.name.isNotEmpty)
                      Chip(label: Text(ticket.assignee!.name)),
                  ],
                ),
                if (ticket.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(ticket.description),
                ],
                if (ticket.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Created ${DateFormat('dd MMM yyyy, hh:mm a').format(ticket.createdAt!)}',
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
          if (canUpdate && !ticket.isClosed) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Process Request',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update the current ticket status. Closing is handled separately after customer verification.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(processStatus),
                    initialValue: processStatus,
                    decoration: const InputDecoration(
                      labelText: 'Current status',
                    ),
                    items: [
                      for (final item in SupportTicketConstants.processStatuses)
                        DropdownMenuItem(
                          value: item.value,
                          child: Text(item.label),
                        ),
                    ],
                    onChanged: _updating
                        ? null
                        : (value) =>
                              setState(() => _status = value ?? processStatus),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final step in SupportTicketConstants.processFlow)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: _status == step
                              ? scheme.primaryContainer
                              : null,
                          label: Text(
                            SupportTicketConstants.statusLabel(step),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: _status == step
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _resolution,
                    minLines: 3,
                    maxLines: 5,
                    enabled: !_updating,
                    decoration: const InputDecoration(
                      labelText: 'Resolution / processing note',
                      hintText:
                          'Add a note about what was checked or what action was taken...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _updating ? null : _updateStatus,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_updating ? 'Updating...' : 'Update Status'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (ticket.isClosed) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This support request has been solved and closed.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TicketConversation(
            messages: ticket.messages,
            isCustomerView: false,
            currentUserId: auth.profile?.id ?? auth.authUser?.id ?? '',
            customerName: ticket.customerName,
          ),
          if (canUpdate && !ticket.isClosed) ...[
            const SizedBox(height: 12),
            TicketReplyBox(
              controller: _reply,
              onSend: _send,
              enabled: true,
              sending: _sending,
              replyToName: ticket.customerName,
              hintText:
                  'Write a helpful response to ${ticket.customerName.isEmpty ? 'the customer' : ticket.customerName}...',
            ),
          ],
          const SizedBox(height: 12),
          TicketTimelineCard(history: ticket.history),
          if (canUpdate && !ticket.isClosed) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ready to finish?',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Add resolution and close the request.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _solveAndClose,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Solve & Close'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

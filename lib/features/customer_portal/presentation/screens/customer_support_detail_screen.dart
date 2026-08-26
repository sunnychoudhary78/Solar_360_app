import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class CustomerSupportDetailScreen extends ConsumerWidget {
  final String ticketId;

  const CustomerSupportDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_TicketDetail>(
      future: _load(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            appBar: AppAppBar(title: 'Support request'),
            body: LoadingState(),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: const AppAppBar(title: 'Support request'),
            body: ErrorState(
              message: snapshot.error?.toString() ?? 'Unable to load ticket',
            ),
          );
        }
        final detail = snapshot.data!;
        final ticket = detail.ticket;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          appBar: AppAppBar(
            title: ticket.ticketNumber.isEmpty
                ? 'Support request'
                : ticket.ticketNumber,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
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
                      children: [
                        Chip(label: Text(ticket.statusLabel)),
                        Chip(label: Text(ticket.priority)),
                      ],
                    ),
                    if (ticket.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(ticket.description),
                    ],
                    if (ticket.createdAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Opened ${DateFormat('dd MMM yyyy, hh:mm a').format(ticket.createdAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'History',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (detail.history.isEmpty)
                const AppCard(
                  padding: EdgeInsets.all(16),
                  child: Text('No history yet.'),
                )
              else
                for (final item in detail.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.action.isEmpty ? 'Update' : item.action,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (item.note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(item.note),
                          ],
                          if (item.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a')
                                  .format(item.createdAt!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<_TicketDetail> _load(WidgetRef ref) async {
    final api = ref.read(customerPortalApiServiceProvider);
    final ticket = await api.getTicket(ticketId);
    List<SupportTicketHistoryItem> history = const [];
    try {
      history = await api.getTicketHistory(ticketId);
    } catch (_) {}
    return _TicketDetail(ticket: ticket, history: history);
  }
}

class _TicketDetail {
  final SupportTicketModel ticket;
  final List<SupportTicketHistoryItem> history;

  const _TicketDetail({required this.ticket, required this.history});
}

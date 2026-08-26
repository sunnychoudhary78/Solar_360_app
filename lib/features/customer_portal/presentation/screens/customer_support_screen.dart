import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/support/presentation/widgets/support_ticket_card.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class CustomerSupportScreen extends ConsumerWidget {
  const CustomerSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(customerTicketsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Support'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/customer/support/new',
          );
          if (result == true) {
            ref.invalidate(customerTicketsProvider);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New request'),
      ),
      body: ticketsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(customerTicketsProvider),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return EmptyState(
              title: 'No support requests yet',
              subtitle: 'Raise a request or follow a conversation started by support.',
              icon: Icons.headset_mic_outlined,
              action: FilledButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/customer/support/new',
                ),
                child: const Text('New request'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerTicketsProvider);
              await ref.read(customerTicketsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: tickets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return SupportTicketCard(
                  ticket: ticket,
                  onOpen: () async {
                    await Navigator.pushNamed(
                      context,
                      '/customer/support/detail',
                      arguments: ticket.id,
                    );
                    ref.invalidate(customerTicketsProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

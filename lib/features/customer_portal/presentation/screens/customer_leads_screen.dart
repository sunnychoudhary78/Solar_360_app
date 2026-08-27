import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/customer_portal/presentation/widgets/customer_lead_progress.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class CustomerLeadsScreen extends ConsumerWidget {
  const CustomerLeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(customerLeadsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'My leads'),
      floatingActionButton: leadsAsync.maybeWhen(
        data: (leads) => hasConvertedCustomerLead(leads)
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openForm(context, ref, null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Fill details'),
              ),
        orElse: () => null,
      ),
      body: leadsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(customerLeadsProvider),
        ),
        data: (leads) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerLeadsProvider);
            await ref.read(customerLeadsProvider.future);
          },
          child: ListView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              CustomerLeadProgress(
                leads: leads,
                onFillDetails: hasConvertedCustomerLead(leads)
                    ? null
                    : () => _openForm(context, ref, null),
                onEditDetails: (lead) => _openForm(context, ref, lead),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    LeadModel? lead,
  ) async {
    final result = await Navigator.pushNamed(
      context,
      '/customer/lead-form',
      arguments: lead,
    );
    if (result == true) {
      ref.invalidate(customerLeadsProvider);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/customer_lead_form_nav.dart';
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
        data: (leads) {
          if (!canCustomerFillOrComplete(leads)) return null;
          final incomplete = customerLeadNeedingCompletion(leads);
          final existing = existingEditableCustomerLead(leads);
          return FloatingActionButton.extended(
            onPressed: () => openCustomerLeadForm(
              context,
              ref,
              lead: incomplete ?? existing,
            ),
            icon: Icon(
              incomplete == null && existing == null
                  ? Icons.add_rounded
                  : Icons.edit_document,
            ),
            label: Text(
              incomplete != null
                  ? 'Complete details'
                  : existing != null
                      ? 'Edit details'
                      : 'Fill details',
            ),
          );
        },
        orElse: () => null,
      ),
      body: leadsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(customerLeadsProvider),
        ),
        data: (leads) {
          return RefreshIndicator(
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
                  onFillDetails: canCustomerFillOrComplete(leads)
                      ? () => openCustomerLeadForm(
                            context,
                            ref,
                            lead: customerLeadNeedingCompletion(leads) ??
                                existingEditableCustomerLead(leads),
                          )
                      : null,
                  onEditDetails: (LeadModel lead) =>
                      openCustomerLeadForm(context, ref, lead: lead),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

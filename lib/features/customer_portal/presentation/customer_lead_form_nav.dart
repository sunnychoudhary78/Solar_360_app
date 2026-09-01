import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

/// Opens the customer lead form.
///
/// [lead] == null → basic details (POST). Saving returns the created [LeadModel],
/// which this helper then opens as the complete form (PUT).
/// [lead] != null → complete / edit form.
Future<void> openCustomerLeadForm(
  BuildContext context,
  WidgetRef ref, {
  LeadModel? lead,
}) async {
  var result = await Navigator.pushNamed(
    context,
    '/customer/lead-form',
    arguments: lead,
  );

  LeadModel? createdDraft = result is LeadModel ? result : null;
  if (createdDraft == null && result == true && lead == null) {
    ref.invalidate(customerLeadsProvider);
    if (!context.mounted) return;
    try {
      final leads = await ref.read(customerLeadsProvider.future);
      createdDraft = customerLeadNeedingCompletion(leads);
    } catch (_) {}
  }
  if (createdDraft != null) {
    ref.invalidate(customerLeadsProvider);
    if (!context.mounted) return;
    result = await Navigator.pushNamed(
      context,
      '/customer/lead-form',
      arguments: createdDraft,
    );
  }

  if (result == true || createdDraft != null) {
    ref.invalidate(customerLeadsProvider);
  }
}

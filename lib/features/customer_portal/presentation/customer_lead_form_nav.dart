import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

/// Opens the customer lead form.
///
/// [lead] == null → basic details in memory, then the full form POSTs one new
/// lead (with files) only when this customer has no draft yet.
/// [lead] != null → complete / edit form JSON-PUTs that same lead.
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

  if (lead == null && result is Map) {
    if (!context.mounted) return;
    result = await Navigator.pushNamed(
      context,
      '/customer/lead-form',
      arguments: result,
    );
  }

  if (result == true) {
    ref.invalidate(customerLeadsProvider);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

/// Opens the customer lead form as a single full form (web LeadFormDialog).
///
/// Reuses an existing New Lead / Follow Up / Rejected draft via PUT instead of
/// POSTing a second lead onto the staff list.
Future<void> openCustomerLeadForm(
  BuildContext context,
  WidgetRef ref, {
  LeadModel? lead,
}) async {
  final leads = ref.read(customerLeadsProvider).asData?.value ?? const <LeadModel>[];
  if (hasConvertedCustomerLead(leads) &&
      (lead == null || !canCustomerEditLead(lead))) {
    showAppMessage(
      context,
      LeadWorkflow.convertedLeadLockMessage,
      isError: true,
    );
    return;
  }

  final target = lead ?? existingEditableCustomerLead(leads);
  final result = await Navigator.pushNamed(
    context,
    '/customer/lead-form',
    arguments: target,
  );

  if (result == true) {
    ref.invalidate(customerLeadsProvider);
  }
}

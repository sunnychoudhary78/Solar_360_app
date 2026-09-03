import 'package:flutter/material.dart';

import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/widgets/workflow_stepper.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class CustomerLeadProgress extends StatelessWidget {
  final List<LeadModel> leads;
  final VoidCallback? onFillDetails;
  final void Function(LeadModel lead) onEditDetails;

  const CustomerLeadProgress({
    super.key,
    required this.leads,
    required this.onFillDetails,
    required this.onEditDetails,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draftLeads = customerDraftLeads(leads);
    final pipelineLeads = customerPipelineLeads(leads);
    final canFill = canCustomerFillOrComplete(leads);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your lead progress',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only your own leads are shown here. After conversion you can track the current stage.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (canFill && onFillDetails != null)
              FilledButton.tonal(
                onPressed: onFillDetails,
                child: Text(
                  customerLeadNeedingCompletion(leads) != null
                      ? 'Complete details'
                      : existingEditableCustomerLead(leads) != null
                          ? 'Edit details'
                          : 'Fill lead details',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (leads.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(Icons.assignment_outlined, color: scheme.outline, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Complete your lead details',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fill in your information. Once your lead is converted, fill and update options will be hidden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (canFill && onFillDetails != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onFillDetails,
                    child: const Text('Fill lead details'),
                  ),
                ],
              ],
            ),
          )
        else ...[
          if (draftLeads.isNotEmpty) ...[
            Text(
              'Details to complete',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final lead in draftLeads)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.fullName.isEmpty ? 'Your lead' : lead.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (lead.leadCode.isNotEmpty) lead.leadCode,
                          if (lead.city.isNotEmpty) lead.city,
                        ].join(' · '),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          LeadWorkflow.getStatusDisplayLabel(
                            lead.status.isEmpty ? 'New Lead' : lead.status,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        LeadWorkflow.nextActorHint(lead.status),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (canFill) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onEditDetails(lead),
                            child: Text(
                              isCustomerLeadIncomplete(lead)
                                  ? 'Complete details'
                                  : 'Edit details',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          if (pipelineLeads.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Converted leads — current stage',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final lead in pipelineLeads)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.fullName.isEmpty ? 'Your lead' : lead.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (lead.leadCode.isNotEmpty) lead.leadCode,
                          if (lead.city.isNotEmpty) lead.city,
                        ].join(' · '),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      WorkflowStepper(currentStatus: lead.status),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

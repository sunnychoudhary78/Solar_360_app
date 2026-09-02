import 'package:solar_sales/features/leads/data/models/lead_model.dart';

bool canCustomerEditLead(LeadModel? lead) {
  final status = (lead?.status ?? '').trim().toLowerCase();
  if (status.isEmpty) return true;
  return status == 'new lead' || status == 'follow up' || status == 'rejected';
}

bool hasConvertedCustomerLead(List<LeadModel> leads) {
  return leads.any((lead) => lead.isActive && !canCustomerEditLead(lead));
}

/// True when connection/site fields from the full form are still missing.
bool isCustomerLeadIncomplete(LeadModel lead) {
  return lead.caNumber.trim().isEmpty ||
      lead.discom.trim().isEmpty ||
      lead.address.trim().isEmpty ||
      lead.loadSectionKw.trim().isEmpty;
}

bool canCustomerCreateLead(List<LeadModel> leads) {
  return !hasConvertedCustomerLead(leads) &&
      existingEditableCustomerLead(leads) == null;
}

/// Draft lead the customer should update (New Lead / Follow Up / Rejected).
/// If older duplicate drafts exist from a previous save, keep the oldest
/// complete one so Edit Details always targets a single lead.
LeadModel? existingEditableCustomerLead(List<LeadModel> leads) {
  final editable = leads
      .where((lead) => lead.isActive && canCustomerEditLead(lead))
      .toList();
  if (editable.isEmpty) return null;
  editable.sort((a, b) {
    final completeCmp = (isCustomerLeadIncomplete(a) ? 1 : 0).compareTo(
      isCustomerLeadIncomplete(b) ? 1 : 0,
    );
    if (completeCmp != 0) return completeCmp;
    return a.createdAt.compareTo(b.createdAt);
  });
  return editable.first;
}

LeadModel? customerLeadNeedingCompletion(List<LeadModel> leads) {
  for (final lead in leads) {
    if (!lead.isActive) continue;
    if (canCustomerEditLead(lead) && isCustomerLeadIncomplete(lead)) {
      return lead;
    }
  }
  return null;
}

bool canCustomerFillOrComplete(List<LeadModel> leads) {
  return canCustomerCreateLead(leads) ||
      existingEditableCustomerLead(leads) != null;
}

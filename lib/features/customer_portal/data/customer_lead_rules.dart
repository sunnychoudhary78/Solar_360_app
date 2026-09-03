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

int _customerDraftRank(LeadModel a, LeadModel b) {
  final activeCmp = (a.isActive ? 0 : 1).compareTo(b.isActive ? 0 : 1);
  if (activeCmp != 0) return activeCmp;
  final completeCmp = (isCustomerLeadIncomplete(a) ? 1 : 0).compareTo(
    isCustomerLeadIncomplete(b) ? 1 : 0,
  );
  if (completeCmp != 0) return completeCmp;
  final createdCmp = a.createdAt.compareTo(b.createdAt);
  if (createdCmp != 0) return createdCmp;
  return a.id.compareTo(b.id);
}

/// Draft lead the customer should update (New Lead / Follow Up / Rejected).
/// Includes inactive leftovers from an older save so Edit Details updates
/// that same row instead of POSTing another lead onto the staff web list.
LeadModel? existingEditableCustomerLead(List<LeadModel> leads) {
  final editable = leads.where(canCustomerEditLead).toList();
  if (editable.isEmpty) return null;
  editable.sort(_customerDraftRank);
  return editable.first;
}

/// Id to PUT on save. Prefers the open form's lead, then any reusable draft.
/// Never returns a converted/pipeline lead.
String? reusableCustomerLeadId({
  String? existingLeadId,
  required List<LeadModel> existingLeads,
}) {
  final fromForm = (existingLeadId ?? '').trim();
  if (fromForm.isNotEmpty) {
    LeadModel? match;
    for (final lead in existingLeads) {
      if (lead.id == fromForm) {
        match = lead;
        break;
      }
    }
    if (match == null || canCustomerEditLead(match)) return fromForm;
  }
  return existingEditableCustomerLead(existingLeads)?.id.trim();
}

LeadModel? customerLeadNeedingCompletion(List<LeadModel> leads) {
  final draft = existingEditableCustomerLead(leads);
  if (draft != null && isCustomerLeadIncomplete(draft)) return draft;
  return null;
}

List<LeadModel> customerDraftLeads(List<LeadModel> leads) {
  return leads
      .where((lead) => lead.isActive && canCustomerEditLead(lead))
      .toList();
}

List<LeadModel> customerPipelineLeads(List<LeadModel> leads) {
  return leads
      .where((lead) => lead.isActive && !canCustomerEditLead(lead))
      .toList();
}

bool canCustomerFillOrComplete(List<LeadModel> leads) {
  return !hasConvertedCustomerLead(leads);
}

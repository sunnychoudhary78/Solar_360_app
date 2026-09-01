import 'package:solar_sales/features/leads/data/models/lead_model.dart';

bool canCustomerEditLead(LeadModel? lead) {
  final status = (lead?.status ?? '').trim().toLowerCase();
  if (status.isEmpty) return true;
  return status == 'new lead' || status == 'follow up' || status == 'rejected';
}

bool hasConvertedCustomerLead(List<LeadModel> leads) {
  return leads.any((lead) => !canCustomerEditLead(lead));
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
      !leads.any(canCustomerEditLead);
}

LeadModel? customerLeadNeedingCompletion(List<LeadModel> leads) {
  for (final lead in leads) {
    if (canCustomerEditLead(lead) && isCustomerLeadIncomplete(lead)) {
      return lead;
    }
  }
  return null;
}

bool canCustomerFillOrComplete(List<LeadModel> leads) {
  return canCustomerCreateLead(leads) ||
      customerLeadNeedingCompletion(leads) != null;
}

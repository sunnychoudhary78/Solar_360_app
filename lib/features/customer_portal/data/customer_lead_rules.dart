import 'package:solar_sales/features/leads/data/models/lead_model.dart';

bool canCustomerEditLead(LeadModel? lead) {
  final status = (lead?.status ?? '').trim().toLowerCase();
  if (status.isEmpty) return true;
  return status == 'new lead' || status == 'follow up' || status == 'rejected';
}

bool hasConvertedCustomerLead(List<LeadModel> leads) {
  return leads.any((lead) => !canCustomerEditLead(lead));
}

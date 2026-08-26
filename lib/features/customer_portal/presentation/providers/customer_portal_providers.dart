import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/customer_portal/data/customer_portal_api_service.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/leads/data/lead_api_service.dart';
import 'package:solar_sales/features/leads/data/lead_repository.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

final customerLeadApiServiceProvider = Provider<LeadApiService>((ref) {
  return LeadApiService(
    ref.watch(apiServiceProvider),
    ref.watch(dioClientProvider).dio,
    leadsPath: ApiEndpoints.customerLeads,
    leadPath: ApiEndpoints.customerLead,
  );
});

final customerLeadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(ref.watch(customerLeadApiServiceProvider));
});

final customerLeadsProvider =
    FutureProvider.autoDispose<List<LeadModel>>((ref) {
  return ref.watch(customerLeadRepositoryProvider).getAllLeads();
});

final customerPortalApiServiceProvider =
    Provider<CustomerPortalApiService>((ref) {
  return CustomerPortalApiService(ref.watch(apiServiceProvider));
});

final customerTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicketModel>>((ref) {
  return ref.watch(customerPortalApiServiceProvider).listTickets();
});

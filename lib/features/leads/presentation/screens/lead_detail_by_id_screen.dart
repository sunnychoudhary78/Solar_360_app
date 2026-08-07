import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_detail_screen.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

/// Loads a lead by id then shows [LeadDetailScreen]. Used by named route
/// `/solar/leads/detail` so notifications and lists can deep-open a lead.
class LeadDetailByIdScreen extends ConsumerWidget {
  final String leadId;

  const LeadDetailByIdScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leadDetailProvider(leadId));

    return async.when(
      loading: () =>
          const Scaffold(body: LoadingState(message: 'Loading lead…')),
      error: (error, _) => Scaffold(
        body: ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(leadDetailProvider(leadId)),
        ),
      ),
      data: (lead) => LeadDetailScreen(lead: lead),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/lead_model.dart';
import '../repositories/lead_repository.dart';

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(ref.watch(dioProvider));
});

final allLeadsProvider = FutureProvider<List<LeadModel>>((ref) async {
  final repository = ref.watch(leadRepositoryProvider);
  return repository.getAllLeads();
});

final leadActionLoadingProvider = StateProvider<bool>((ref) => false);

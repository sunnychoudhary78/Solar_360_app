import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/lead_model.dart';
import '../repositories/lead_repository.dart';

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  final dio = ref.read(dioProvider);
  return LeadRepository(dio);
});

final allLeadsProvider = FutureProvider.autoDispose<List<LeadModel>>((ref) async {
  final repository = ref.read(leadRepositoryProvider);
  return repository.getAllLeads();
});

final leadActionLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../repositories/installation_repository.dart';

final installationRepositoryProvider = Provider<InstallationRepository>((ref) {
  return InstallationRepository(ref.watch(dioProvider));
});

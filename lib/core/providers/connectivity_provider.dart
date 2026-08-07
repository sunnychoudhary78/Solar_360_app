import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool connectivityResultsOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  return results.any((r) => r != ConnectivityResult.none);
}

/// Emits `true` when the device has a usable network interface.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield connectivityResultsOnline(initial);

  await for (final results in connectivity.onConnectivityChanged) {
    yield connectivityResultsOnline(results);
  }
});

/// Force a fresh connectivity check (used by the offline banner Retry).
final connectivityRecheckProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final results = await Connectivity().checkConnectivity();
  return connectivityResultsOnline(results);
});

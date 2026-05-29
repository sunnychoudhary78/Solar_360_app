import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final loginLoadingProvider = StateProvider<bool>((ref) => false);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState(loading: true)) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repository.restoreSession();
      state = AuthState(
        user: result.user,
        permissions: result.permissions,
        loading: false,
        initialized: true,
      );
    } catch (e) {
      state = AuthState(
        loading: false,
        initialized: true,
        error: e.toString(),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    // Do not set global loading — avoids full-app spinner on login screen.
    try {
      final result = await _repository.login(
        email: email,
        password: password,
      );
      state = AuthState(
        user: result.user,
        permissions: result.permissions,
        loading: false,
        initialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        initialized: true,
        error: e.toString(),
        clearUser: true,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(
      loading: false,
      initialized: true,
    );
  }
}

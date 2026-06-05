import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../../profile/repositories/profile_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(profileRepositoryProvider),
  );
});

final loginLoadingProvider = StateProvider<bool>((ref) => false);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final ProfileRepository _profileRepository;

  AuthNotifier(
    this._repository,
    this._profileRepository,
  ) : super(const AuthState(loading: true)) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final result = await _repository.restoreSession();

      var user = result.user;

      if (user != null) {
        final latestPhoto =
            await _profileRepository.fetchProfilePictureFilename();

        if (latestPhoto != null && latestPhoto.trim().isNotEmpty) {
          user = _copyUserWithProfilePicture(user, latestPhoto);
        }
      }

      state = AuthState(
        user: user,
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
    try {
      final result = await _repository.login(
        email: email,
        password: password,
      );

      var user = result.user;

      if (user != null) {
        final latestPhoto =
            await _profileRepository.fetchProfilePictureFilename();

        if (latestPhoto != null && latestPhoto.trim().isNotEmpty) {
          user = _copyUserWithProfilePicture(user, latestPhoto);
        }
      }

      state = AuthState(
        user: user,
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

  Future<void> refreshProfile() async {
    try {
      final currentUser = state.user;
      if (currentUser == null) return;

      final latestPhoto =
          await _profileRepository.fetchProfilePictureFilename();

      if (latestPhoto != null && latestPhoto.trim().isNotEmpty) {
        state = state.copyWith(
          user: _copyUserWithProfilePicture(currentUser, latestPhoto),
        );
      }
    } catch (_) {
      // silent fail to avoid red snackbar / UI break
    }
  }

  void updateProfilePicture(String filename) {
    final user = state.user;
    if (user == null) return;

    state = state.copyWith(
      user: _copyUserWithProfilePicture(user, filename),
    );
  }

  AuthUser _copyUserWithProfilePicture(
    AuthUser user,
    String profilePicture,
  ) {
    return AuthUser(
      id: user.id,
      email: user.email,
      name: user.name,
      roleId: user.roleId,
      roleName: user.roleName,
      companyName: user.companyName,
      profilePicture: profilePicture,
    );
  }
}
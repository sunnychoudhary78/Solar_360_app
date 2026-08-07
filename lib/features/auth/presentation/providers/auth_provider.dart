import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/app/navigator.dart';
import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/module/presentation/providers/module_provider.dart';

import '../../data/auth_api_service.dart';
import '../../data/auth_repository.dart';
import '../../data/models/auth_models.dart';
import 'auth_state.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(apiServiceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authApiServiceProvider),
    ref.watch(tokenStorageProvider),
  );
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    return const AuthState();
  }

  Future<void> tryAutoLogin() async {
    final jwt = await _repo.getStoredToken();
    if (jwt == null || jwt.isEmpty) {
      state = const AuthState(isLoading: false, isInitializing: false);
      return;
    }

    try {
      state = state.copyWith(isLoading: true);
      final profile = await _repo.getMe();
      final permissions = await _repo.getPermissions();
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        profile: profile,
        permissions: permissions,
        subscriptionInactive: false,
      );
      await ref
          .read(moduleProvider.notifier)
          .syncFromAuth(
            permissions: permissions,
            role: profile.effectiveRoleName,
            companyBillbook: profile.companyModules.billbook,
            companySolar: profile.companyModules.solar,
            companyAdmin: profile.isCompanyAdmin,
            platformAdmin: profile.isPlatformSuperAdmin,
          );
    } catch (e) {
      final inactive = _isSubscriptionInactive(e);
      if (inactive) {
        state = state.copyWith(
          isLoading: false,
          isInitializing: false,
          subscriptionInactive: true,
        );
        return;
      }
      await _repo.logoutLocal();
      state = const AuthState(isLoading: false, isInitializing: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, subscriptionInactive: false);
    ref.read(globalLoadingProvider.notifier).showLoading('Signing in...');

    try {
      final result = await _repo.login(email, password);
      final profile = await _repo.getMe();
      final permissions = await _repo.getPermissions();

      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        authUser: result.user,
        profile: profile,
        permissions: permissions,
        subscriptionInactive: false,
      );

      await ref
          .read(moduleProvider.notifier)
          .syncFromAuth(
            permissions: permissions,
            role: profile.effectiveRoleName,
            companyBillbook: profile.companyModules.billbook,
            companySolar: profile.companyModules.solar,
            companyAdmin: profile.isCompanyAdmin,
            platformAdmin: profile.isPlatformSuperAdmin,
          );

      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showMessage('Welcome back, ${profile.name.split(' ').first}');

      final home = ref.read(moduleProvider).homeRoute;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        home,
        (route) => false,
      );
    } catch (e) {
      final inactive = _isSubscriptionInactive(e);
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        subscriptionInactive: inactive,
      );
      ref.read(globalLoadingProvider.notifier).hide();
      if (!inactive) {
        ref.read(globalLoadingProvider.notifier).showApiError(e);
      }
      rethrow;
    }
  }

  Future<void> switchRole(String role) async {
    ref.read(globalLoadingProvider.notifier).showLoading('Switching role...');
    try {
      final result = await _repo.switchRole(role);
      // Prefer fresh profile; fall back to switch payload.
      UserProfile profile;
      try {
        profile = await _repo.getMe();
      } catch (_) {
        profile = UserProfile(
          id: result.user.id,
          name: result.user.name,
          email: result.user.email,
          roleName: result.user.roleName,
          activeRole: result.user.activeRole,
          roles: result.user.roles,
          hierarchyLevel: result.user.hierarchyLevel,
          companyId: result.user.companyId,
          companyName: result.user.companyName,
          companyModules: result.user.companyModules,
          photo: result.user.photo,
        );
      }

      var permissions = result.permissions;
      if (permissions.isEmpty) {
        permissions = await _repo.getPermissions();
      }

      state = state.copyWith(
        authUser: result.user,
        profile: profile,
        permissions: permissions,
        isLoading: false,
        isInitializing: false,
      );

      await ref
          .read(moduleProvider.notifier)
          .syncFromAuth(
            permissions: permissions,
            role: profile.effectiveRoleName,
            companyBillbook: profile.companyModules.billbook,
            companySolar: profile.companyModules.solar,
            companyAdmin: profile.isCompanyAdmin,
            platformAdmin: profile.isPlatformSuperAdmin,
          );

      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Switched to ${profile.effectiveRoleName}');

      final home = ref.read(moduleProvider).homeRoute;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        home,
        (route) => false,
      );
      // Full provider wipe so role-scoped caches cannot leak.
      triggerAppRestart();
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    ref
        .read(globalLoadingProvider.notifier)
        .showLoading('Updating password...');
    try {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Password updated');
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.logoutLocal();
    state = const AuthState(isLoading: false, isInitializing: false);
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
    triggerAppRestart();
  }

  void forceLogout() {
    state = const AuthState(isLoading: false, isInitializing: false);
  }

  bool _isSubscriptionInactive(Object e) {
    final text = e.toString().toUpperCase();
    return text.contains('SUBSCRIPTION_INACTIVE') ||
        text.contains('SUBSCRIPTION INACTIVE');
  }
}

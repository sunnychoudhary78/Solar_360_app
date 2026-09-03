import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/app/navigator.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/providers/global_loading_provider.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/core/providers/role_refresh.dart';
import 'package:solar_sales/core/storage/token_storage.dart';
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

  List<String> _normalizeRoles(Iterable<String> roles) {
    return roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _mergeRoles(Iterable<Iterable<String>> sources) {
    final merged = <String>{};
    for (final source in sources) {
      for (final role in source) {
        final trimmed = role.trim();
        if (trimmed.isNotEmpty) merged.add(trimmed);
      }
    }
    return merged.toList();
  }

  Future<List<String>> _persistAssignedRoles(
    List<String> roles, {
    List<String> fallback = const [],
  }) async {
    final merged = _normalizeRoles(
      _mergeRoles([roles, fallback, state.assignedRoles, state.roles]),
    );
    if (merged.isEmpty) {
      return _repo.getStoredAssignedRoles();
    }
    // Persist without blocking callers that already have the merged list.
    // ignore: unawaited_futures
    _repo.saveAssignedRoles(merged);
    return merged;
  }

  List<String> _mergeAssignedRolesInMemory({
    required List<String> previousRoles,
    required List<String> fromUser,
    required List<String> fromProfile,
    String? activeRole,
    String? selectedRole,
  }) {
    return _normalizeRoles(
      _mergeRoles([
        previousRoles,
        fromUser,
        fromProfile,
        state.assignedRoles,
        if (activeRole != null && activeRole.trim().isNotEmpty) [activeRole],
        if (selectedRole != null && selectedRole.trim().isNotEmpty)
          [selectedRole],
      ]),
    );
  }

  UserProfile _profileFromSwitchUser(
    AuthUser user, {
    UserProfile? previous,
  }) {
    return UserProfile(
      id: user.id,
      name: user.name,
      email: user.email,
      roleName: user.roleName,
      activeRole: user.activeRole,
      roles: user.roles,
      hierarchyLevel: user.hierarchyLevel,
      companyId: user.companyId ?? previous?.companyId,
      companyName: user.companyName ?? previous?.companyName,
      // Switch-role payload usually omits company modules — keep prior values.
      companyModules: previous?.companyModules ?? user.companyModules,
      photo: user.photo ?? previous?.photo,
    );
  }

  Future<AuthState> _buildSessionFromProfile({
    required UserProfile profile,
    AuthUser? authUser,
    List<String> fallbackRoles = const [],
  }) async {
    final storedRoles = await _repo.getStoredAssignedRoles();
    final assignedRoles = await _persistAssignedRoles(
      _mergeRoles([
        storedRoles,
        fallbackRoles,
        profile.roles,
        if (authUser?.roles != null) authUser!.roles,
        if (profile.effectiveRoleName.isNotEmpty)
          [profile.effectiveRoleName],
        if (authUser?.effectiveRoleName.isNotEmpty == true)
          [authUser!.effectiveRoleName],
      ]),
      fallback: fallbackRoles,
    );

    final permissions = await _repo.getPermissions();
    final enrichedProfile = profile.copyWith(roles: assignedRoles);

    return state.copyWith(
      authUser: authUser,
      profile: enrichedProfile,
      permissions: permissions,
      assignedRoles: assignedRoles,
      sessionKind: SessionKind.staff,
      isLoading: false,
      isInitializing: false,
      subscriptionInactive: false,
    );
  }

  Future<void> tryAutoLogin() async {
    final kind = await _repo.getSessionKind();
    if (kind == SessionKind.customer) {
      final jwt = await _repo.getStoredCustomerToken();
      if (jwt == null || jwt.isEmpty) {
        state = const AuthState(isLoading: false, isInitializing: false);
        return;
      }
      try {
        state = state.copyWith(isLoading: true);
        final customer = await _repo.getCustomerMe();
        state = AuthState(
          customer: customer,
          sessionKind: SessionKind.customer,
          isLoading: false,
          isInitializing: false,
        );
      } catch (_) {
        await _repo.logoutLocal();
        state = const AuthState(isLoading: false, isInitializing: false);
      }
      return;
    }

    final jwt = await _repo.getStoredToken();
    if (jwt == null || jwt.isEmpty) {
      state = const AuthState(isLoading: false, isInitializing: false);
      return;
    }

    try {
      state = state.copyWith(isLoading: true);
      final storedRoles = await _repo.getStoredAssignedRoles();
      final profile = await _repo.getMe();
      final nextState = await _buildSessionFromProfile(
        profile: profile,
        fallbackRoles: storedRoles,
      );
      state = nextState.copyWith(sessionKind: SessionKind.staff);
      await ref
          .read(moduleProvider.notifier)
          .syncFromAuth(
            permissions: nextState.permissions,
            role: nextState.profile!.effectiveRoleName,
            companyBillbook: nextState.profile!.companyModules.billbook,
            companySolar: nextState.profile!.companyModules.solar,
            companyAdmin: nextState.profile!.isCompanyAdmin,
            platformAdmin: nextState.profile!.isPlatformSuperAdmin,
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
      LoginResult? staffResult;
      try {
        staffResult = await _repo.login(email, password);
      } catch (e) {
        if (_isSubscriptionInactive(e) || !_canFallbackToCustomer(e)) {
          rethrow;
        }
      }

      if (staffResult != null) {
        await _completeStaffSession(staffResult);
      } else {
        await _completeCustomerLogin(email, password);
      }
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

  Future<void> _completeStaffSession(LoginResult result) async {
    final profile = await _repo.getMe();
    final nextState = await _buildSessionFromProfile(
      profile: profile,
      authUser: result.user,
      fallbackRoles: _mergeRoles([
        result.user.roles,
        profile.roles,
        if (result.user.effectiveRoleName.isNotEmpty)
          [result.user.effectiveRoleName],
        if (profile.effectiveRoleName.isNotEmpty)
          [profile.effectiveRoleName],
      ]),
    );
    state = nextState.copyWith(sessionKind: SessionKind.staff);

    await ref
        .read(moduleProvider.notifier)
        .syncFromAuth(
          permissions: nextState.permissions,
          role: nextState.profile!.effectiveRoleName,
          companyBillbook: nextState.profile!.companyModules.billbook,
          companySolar: nextState.profile!.companyModules.solar,
          companyAdmin: nextState.profile!.isCompanyAdmin,
          platformAdmin: nextState.profile!.isPlatformSuperAdmin,
        );

    ref.read(globalLoadingProvider.notifier).hide();
    ref
        .read(globalLoadingProvider.notifier)
        .showMessage(
          'Welcome back, ${nextState.profile!.name.split(' ').first}',
        );

    final home = ref.read(moduleProvider).homeRoute;
    await safeResetToRoute(home);
  }

  Future<void> _completeCustomerLogin(String email, String password) async {
    final result = await _repo.customerLogin(email, password);
    var customer = result.customer;
    try {
      customer = await _repo.getCustomerMe();
    } catch (_) {
      // Login payload is enough to enter the portal.
    }

    state = AuthState(
      customer: customer,
      sessionKind: SessionKind.customer,
      isLoading: false,
      isInitializing: false,
    );

    ref.read(globalLoadingProvider.notifier).hide();
    ref
        .read(globalLoadingProvider.notifier)
        .showMessage('Welcome back, ${customer.firstName}');

    await safeResetToRoute('/');
  }

  bool _canFallbackToCustomer(Object e) {
    if (e is ApiException) {
      final status = e.statusCode;
      if (status == null) return true;
      return status == 400 ||
          status == 401 ||
          status == 403 ||
          status == 404;
    }
    return true;
  }

  Future<void> switchRole(String role) async {
    ref.read(globalLoadingProvider.notifier).showLoading('Switching role...');
    try {
      final previousRoles = state.roles;
      final previousProfile = state.profile;

      // Critical path: one network call (switch-role returns user + permissions).
      final result = await _repo.switchRole(role);

      var profile = _profileFromSwitchUser(
        result.user,
        previous: previousProfile,
      );

      // Prefer permissions from the switch response; only fetch if empty.
      var permissions = result.permissions;
      if (permissions.isEmpty) {
        permissions = await _repo.getPermissions();
      }

      final assignedRoles = _mergeAssignedRolesInMemory(
        previousRoles: previousRoles,
        fromUser: result.user.roles,
        fromProfile: profile.roles,
        activeRole: result.user.effectiveRoleName.isNotEmpty
            ? result.user.effectiveRoleName
            : profile.effectiveRoleName,
        selectedRole: role,
      );

      // Fire-and-forget local persistence — do not block UI.
      // ignore: unawaited_futures
      _repo.saveAssignedRoles(assignedRoles);

      final enrichedProfile = profile.copyWith(roles: assignedRoles);

      state = state.copyWith(
        authUser: result.user,
        profile: enrichedProfile,
        permissions: permissions,
        assignedRoles: assignedRoles,
        isLoading: false,
        isInitializing: false,
      );

      // Module sync is now in-memory first — no need to await prefs I/O.
      // ignore: discarded_futures
      ref.read(moduleProvider.notifier).syncFromAuth(
            permissions: permissions,
            role: enrichedProfile.effectiveRoleName,
            companyBillbook: enrichedProfile.companyModules.billbook,
            companySolar: enrichedProfile.companyModules.solar,
            companyAdmin: enrichedProfile.isCompanyAdmin,
            platformAdmin: enrichedProfile.isPlatformSuperAdmin,
          );

      ref.read(globalLoadingProvider.notifier).hide();
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess('Switched to ${enrichedProfile.effectiveRoleName}');

      final home = ref.read(moduleProvider).homeRoute;
      await safeResetToRoute(home);

      // Defer cache invalidation until after the new route is mounted.
      scheduleRoleScopedInvalidation(ref);

      // Soft background refresh of profile (company fields, photo, etc.).
      // Does not block the switch UX.
      // ignore: unawaited_futures
      _refreshProfileAfterSwitch(assignedRoles);
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      rethrow;
    }
  }

  Future<void> _refreshProfileAfterSwitch(List<String> assignedRoles) async {
    try {
      final profile = await _repo.getMe();
      final mergedRoles = _normalizeRoles(
        _mergeRoles([assignedRoles, profile.roles, state.assignedRoles]),
      );
      // ignore: unawaited_futures
      _repo.saveAssignedRoles(mergedRoles);
      if (!ref.mounted) return;
      state = state.copyWith(
        profile: profile.copyWith(roles: mergedRoles),
        assignedRoles: mergedRoles,
      );
    } catch (_) {
      // Keep the switch-role payload; background enrichment is best-effort.
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
      if (state.isCustomerSession) {
        await _repo.changeCustomerPassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
      } else {
        await _repo.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
      }
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showSuccess('Password updated');
    } catch (e) {
      ref.read(globalLoadingProvider.notifier).hide();
      ref.read(globalLoadingProvider.notifier).showApiError(e);
      rethrow;
    }
  }

  Future<void> logout() async {
    if (state.isCustomerSession) {
      await _repo.customerLogout();
    }
    await _repo.logoutLocal();
    state = const AuthState(isLoading: false, isInitializing: false);
    await safeResetToRoute('/login');
    // ProviderScope restart is deferred inside triggerAppRestart so the
    // login route can mount before the old InheritedWidget tree is disposed.
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

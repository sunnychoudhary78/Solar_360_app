import 'package:solar_sales/core/storage/token_storage.dart';
import 'package:solar_sales/features/auth/data/models/auth_models.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing;
  final AuthUser? authUser;
  final UserProfile? profile;
  final CustomerProfile? customer;
  final SessionKind? sessionKind;
  final List<String> permissions;
  final bool subscriptionInactive;

  /// Cached assigned roles (login /me / switch + local persistence).
  /// Keeps Switch Role usable after every successful switch.
  final List<String> assignedRoles;

  const AuthState({
    this.isLoading = false,
    this.isInitializing = true,
    this.authUser,
    this.profile,
    this.customer,
    this.sessionKind,
    this.permissions = const [],
    this.subscriptionInactive = false,
    this.assignedRoles = const [],
  });

  bool get isCustomerSession => sessionKind == SessionKind.customer;

  bool get isStaffSession => sessionKind == SessionKind.staff;

  bool get isAuthenticated {
    if (isCustomerSession) {
      return customer != null && !isInitializing;
    }
    return profile != null || (authUser != null && !isInitializing);
  }

  bool hasPermission(String permission) => permissions.contains(permission);

  bool hasAny(List<String> perms) =>
      perms.any((p) => permissions.contains(p));

  CompanyModules get companyModules =>
      profile?.companyModules ??
      authUser?.companyModules ??
      const CompanyModules();

  /// Full set of roles the user can switch between.
  List<String> get roles {
    if (isCustomerSession) return const [];

    if (assignedRoles.isNotEmpty) {
      final merged = <String>{...assignedRoles};
      final active = effectiveRoleName.trim();
      if (active.isNotEmpty) merged.add(active);
      return merged.toList();
    }

    final merged = <String>{};

    void addAll(Iterable<String> source) {
      for (final role in source) {
        final trimmed = role.trim();
        if (trimmed.isNotEmpty) merged.add(trimmed);
      }
    }

    addAll(profile?.roles ?? const []);
    addAll(authUser?.roles ?? const []);

    final active = effectiveRoleName.trim();
    if (active.isNotEmpty) merged.add(active);

    return merged.toList();
  }

  bool get canSwitchRoles => !isCustomerSession && roles.length > 1;

  String get effectiveRoleName {
    if (isCustomerSession) return customer?.roleName ?? 'Customer';
    return profile?.effectiveRoleName ?? authUser?.effectiveRoleName ?? '';
  }

  bool get isPlatformSuperAdmin =>
      !isCustomerSession && (profile?.isPlatformSuperAdmin ?? false);

  bool get isCompanyAdmin =>
      !isCustomerSession && (profile?.isCompanyAdmin ?? false);

  AuthState copyWith({
    bool? isLoading,
    bool? isInitializing,
    AuthUser? authUser,
    UserProfile? profile,
    CustomerProfile? customer,
    SessionKind? sessionKind,
    List<String>? permissions,
    bool? subscriptionInactive,
    List<String>? assignedRoles,
    bool clearUser = false,
  }) {
    final nextKind = clearUser ? null : (sessionKind ?? this.sessionKind);
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      authUser: clearUser || nextKind == SessionKind.customer
          ? null
          : (authUser ?? this.authUser),
      profile: clearUser || nextKind == SessionKind.customer
          ? null
          : (profile ?? this.profile),
      customer: clearUser || nextKind == SessionKind.staff
          ? null
          : (customer ?? this.customer),
      sessionKind: nextKind,
      permissions: clearUser || nextKind == SessionKind.customer
          ? const []
          : (permissions ?? this.permissions),
      subscriptionInactive:
          subscriptionInactive ?? this.subscriptionInactive,
      assignedRoles: clearUser || nextKind == SessionKind.customer
          ? const []
          : (assignedRoles ?? this.assignedRoles),
    );
  }
}

import 'package:solar_sales/features/auth/data/models/auth_models.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing;
  final AuthUser? authUser;
  final UserProfile? profile;
  final List<String> permissions;
  final bool subscriptionInactive;

  const AuthState({
    this.isLoading = false,
    this.isInitializing = true,
    this.authUser,
    this.profile,
    this.permissions = const [],
    this.subscriptionInactive = false,
  });

  bool get isAuthenticated =>
      profile != null || (authUser != null && !isInitializing);

  bool hasPermission(String permission) => permissions.contains(permission);

  bool hasAny(List<String> perms) =>
      perms.any((p) => permissions.contains(p));

  CompanyModules get companyModules =>
      profile?.companyModules ??
      authUser?.companyModules ??
      const CompanyModules();

  List<String> get roles {
    final fromProfile = profile?.roles ?? const [];
    if (fromProfile.isNotEmpty) return fromProfile;
    return authUser?.roles ?? const [];
  }

  String get effectiveRoleName =>
      profile?.effectiveRoleName ?? authUser?.effectiveRoleName ?? '';

  bool get isPlatformSuperAdmin =>
      profile?.isPlatformSuperAdmin ?? false;

  bool get isCompanyAdmin => profile?.isCompanyAdmin ?? false;

  AuthState copyWith({
    bool? isLoading,
    bool? isInitializing,
    AuthUser? authUser,
    UserProfile? profile,
    List<String>? permissions,
    bool? subscriptionInactive,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      authUser: clearUser ? null : (authUser ?? this.authUser),
      profile: clearUser ? null : (profile ?? this.profile),
      permissions: clearUser ? const [] : (permissions ?? this.permissions),
      subscriptionInactive:
          subscriptionInactive ?? this.subscriptionInactive,
    );
  }
}

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String roleId;
  final String roleName;
  final String? companyName;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.roleId,
    required this.roleName,
    this.companyName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    String roleName = '';
    String roleId = json['roleId']?.toString() ?? '';

    if (role is Map) {
      roleName = role['name']?.toString() ?? '';
      roleId = role['id']?.toString() ?? roleId;
    } else if (role is String) {
      roleName = role;
    }

    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roleId: roleId,
      roleName: roleName,
      companyName: json['companyName']?.toString(),
    );
  }
}

class AuthState {
  final AuthUser? user;
  final List<String> permissions;
  final bool loading;
  final bool initialized;
  final String? error;

  const AuthState({
    this.user,
    this.permissions = const [],
    this.loading = false,
    this.initialized = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  bool hasPermission(String permission) => permissions.contains(permission);

  bool hasAnyPermission(List<String> perms) {
    return perms.any((p) => permissions.contains(p));
  }

  String get appRole {
    final name = user?.roleName ?? '';
    final lower = name.trim().toLowerCase();

    if (lower.contains('admin') || lower.contains('super')) {
      return 'admin';
    }

    if (lower == 'sales') {
      return 'sales';
    }

    if (lower == 'support') {
      return 'support';
    }

    if (lower == 'liaising' ||
        lower == 'liaison officer' ||
        lower == 'liaison' ||
        lower == 'leasing') {
      return 'liaison';
    }

    if (lower == 'finance') {
      return 'finance';
    }

    if (lower == 'installation team' || lower == 'installation') {
      return 'installation';
    }

    return 'sales';
  }

  AuthState copyWith({
    AuthUser? user,
    List<String>? permissions,
    bool? loading,
    bool? initialized,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      permissions: permissions ?? this.permissions,
      loading: loading ?? this.loading,
      initialized: initialized ?? this.initialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
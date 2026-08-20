class CompanyModules {
  final bool billbook;
  final bool solar;

  const CompanyModules({this.billbook = true, this.solar = true});

  factory CompanyModules.fromJson(dynamic json) {
    if (json is! Map) return const CompanyModules();
    return CompanyModules(
      billbook: json['billbook'] != false,
      solar: json['solar'] != false,
    );
  }

  Map<String, dynamic> toJson() => {'billbook': billbook, 'solar': solar};
}

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? roleId;
  final String? roleName;
  final String? activeRole;
  final List<String> roles;
  final int? hierarchyLevel;
  final String? companyId;
  final String? companyName;
  final CompanyModules companyModules;
  final String? photo;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.roleId,
    this.roleName,
    this.activeRole,
    this.roles = const [],
    this.hierarchyLevel,
    this.companyId,
    this.companyName,
    this.companyModules = const CompanyModules(),
    this.photo,
  });

  String get effectiveRoleName =>
      (activeRole?.trim().isNotEmpty == true)
          ? activeRole!.trim()
          : (roleName?.trim() ?? '');

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['Role'] ?? json['role'];
    String? roleName;
    int? hierarchy;
    if (role is Map) {
      roleName = role['name']?.toString();
      hierarchy = role['hierarchy_level'] is num
          ? (role['hierarchy_level'] as num).toInt()
          : null;
    } else if (role is String) {
      roleName = role;
    }

    final rolesRaw = json['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        if (r is String && r.trim().isNotEmpty) {
          roles.add(r.trim());
        } else if (r is Map) {
          final n = (r['name'] ?? r['role'])?.toString().trim();
          if (n != null && n.isNotEmpty) roles.add(n);
        }
      }
    }

    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleId: (json['roleId'] ?? json['role_id'])?.toString(),
      roleName: roleName,
      activeRole: (json['activeRole'] ?? json['active_role'])?.toString(),
      roles: roles,
      hierarchyLevel: hierarchy,
      companyId: (json['companyId'] ?? json['company_id'])?.toString(),
      companyName: json['companyName']?.toString() ??
          json['company_name']?.toString(),
      companyModules: CompanyModules.fromJson(json['companyModules']),
      photo: json['photo']?.toString(),
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? roleName;
  final String? activeRole;
  final List<String> roles;
  final int? hierarchyLevel;
  final String? companyId;
  final String? companyName;
  final CompanyModules companyModules;
  final String? photo;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.roleName,
    this.activeRole,
    this.roles = const [],
    this.hierarchyLevel,
    this.companyId,
    this.companyName,
    this.companyModules = const CompanyModules(),
    this.photo,
  });

  String get effectiveRoleName =>
      (activeRole?.trim().isNotEmpty == true)
          ? activeRole!.trim()
          : (roleName?.trim() ?? '');

  bool get isPlatformSuperAdmin {
    final name = effectiveRoleName.toLowerCase();
    if (name == 'superadmin' || name == 'super admin') return true;
    final level = hierarchyLevel;
    return level != null && level <= 50 && (companyId == null || companyId!.isEmpty);
  }

  bool get isCompanyAdmin {
    final name = effectiveRoleName.toLowerCase();
    if (name == 'admin' || name == 'company admin' || name == 'companyadmin') {
      return true;
    }
    final level = hierarchyLevel;
    return level != null && level <= 200 && level > 50;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? roleName,
    String? activeRole,
    List<String>? roles,
    int? hierarchyLevel,
    String? companyId,
    String? companyName,
    CompanyModules? companyModules,
    String? photo,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      roleName: roleName ?? this.roleName,
      activeRole: activeRole ?? this.activeRole,
      roles: roles ?? this.roles,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyModules: companyModules ?? this.companyModules,
      photo: photo ?? this.photo,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    final role = user['Role'] ?? user['role'] ?? json['Role'] ?? json['role'];
    String? roleName;
    int? hierarchy;
    if (role is Map) {
      roleName = role['name']?.toString();
      hierarchy = role['hierarchy_level'] is num
          ? (role['hierarchy_level'] as num).toInt()
          : null;
    } else if (role is String) {
      roleName = role;
    }

    final rolesRaw = user['roles'] ?? json['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final r in rolesRaw) {
        if (r is String && r.trim().isNotEmpty) {
          roles.add(r.trim());
        } else if (r is Map) {
          final n = (r['name'] ?? r['role'])?.toString().trim();
          if (n != null && n.isNotEmpty) roles.add(n);
        }
      }
    }

    final company = user['employee_detail'] is Map
        ? (user['employee_detail'] as Map)['company']
        : null;
    String? companyId = (user['companyId'] ?? user['company_id'])?.toString();
    String? companyName =
        (user['companyName'] ?? user['company_name'])?.toString();
    dynamic companyModulesRaw = user['companyModules'] ?? json['companyModules'];
    if (company is Map) {
      companyId ??= company['id']?.toString();
      companyName ??= company['name']?.toString();
      companyModulesRaw ??= {
        'billbook': company['billbook_enabled'],
        'solar': company['solar_enabled'],
      };
    }

    return UserProfile(
      id: (user['id'] ?? json['id'])?.toString() ?? '',
      name: (user['name'] ?? json['name'])?.toString() ?? '',
      email: (user['email'] ?? json['email'])?.toString() ?? '',
      roleName: roleName,
      activeRole:
          (user['activeRole'] ?? user['active_role'] ?? json['activeRole'])
              ?.toString(),
      roles: roles,
      hierarchyLevel: hierarchy,
      companyId: companyId,
      companyName: companyName,
      companyModules: CompanyModules.fromJson(companyModulesRaw),
      photo: (user['photo'] ?? json['photo'])?.toString(),
    );
  }
}

class LoginResult {
  final String token;
  final AuthUser user;

  const LoginResult({required this.token, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      token: json['token']?.toString() ?? '',
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
    );
  }
}

class SwitchRoleResult {
  final String token;
  final AuthUser user;
  final List<String> permissions;

  const SwitchRoleResult({
    required this.token,
    required this.user,
    required this.permissions,
  });

  factory SwitchRoleResult.fromJson(Map<String, dynamic> json) {
    final permsRaw = json['permissions'];
    final permissions = <String>[];
    if (permsRaw is List) {
      for (final e in permsRaw) {
        if (e is String && e.isNotEmpty) {
          permissions.add(e);
        } else if (e is Map) {
          final n = (e['name'] ?? e['permission'])?.toString();
          if (n != null && n.isNotEmpty) permissions.add(n);
        }
      }
    }
    return SwitchRoleResult(
      token: json['token']?.toString() ?? '',
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
      permissions: permissions,
    );
  }
}

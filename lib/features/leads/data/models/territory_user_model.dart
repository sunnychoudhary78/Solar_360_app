class TerritoryUser {
  const TerritoryUser({
    required this.id,
    required this.name,
    this.email = '',
    this.state = '',
    this.district = '',
    this.roles = const [],
  });

  final String id;
  final String name;
  final String email;
  final String state;
  final String district;
  final List<String> roles;

  String get displayLabel {
    if (email.isEmpty) return name;
    return '$name ($email)';
  }

  bool matchesRole(String? role) {
    final target = (role ?? '').trim().toLowerCase();
    if (target.isEmpty) return true;
    return roles.any((item) => item.trim().toLowerCase() == target);
  }

  factory TerritoryUser.fromJson(Map<String, dynamic> json) {
    final employee = _asMap(
      json['employee_detail'] ??
          json['employeeDetail'] ??
          json['EmployeeDetail'],
    );

    return TerritoryUser(
      id: _str(json['id']),
      name: _str(
        json['name'] ?? json['full_name'] ?? json['fullName'] ?? json['username'],
      ),
      email: _str(json['email']),
      state: _str(
        json['state'] ?? employee['state'],
      ),
      district: _str(
        json['district'] ?? employee['district'],
      ),
      roles: _extractRoles(json),
    );
  }

  static List<String> _extractRoles(Map<String, dynamic> json) {
    final found = <String>{};

    void add(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) found.add(trimmed);
        return;
      }
      if (value is Map) {
        final name = _str(value['name'] ?? value['role'] ?? value['role_name']);
        if (name.isNotEmpty) found.add(name);
        return;
      }
      if (value is List) {
        for (final item in value) {
          add(item);
        }
      }
    }

    add(json['roles']);
    add(json['role']);
    add(json['Role']);
    add(json['designation']);
    add(json['activeRole']);
    add(json['active_role']);
    return found.toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String _str(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}

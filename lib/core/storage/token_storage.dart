import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  /// Keep compatible with web/session naming across Solar 360 clients.
  static const _jwtKey = 'LMS_accessToken';
  static const _assignedRolesKey = 'LMS_assignedRoles';
  static const _assignedRolesPrefKey = 'imt_assigned_roles';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveJwt(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  Future<String?> getJwt() async {
    return _storage.read(key: _jwtKey);
  }

  /// Persist every role assigned to the signed-in user so Switch Role stays
  /// available after role switches even if a transient API payload omits them.
  Future<void> saveAssignedRoles(List<String> roles) async {
    final cleaned = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return;

    final encoded = jsonEncode(cleaned);

    // Prefs first (fast path for restore after switch).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignedRolesPrefKey, encoded);

    // Secure storage is slower — write in the background.
    // ignore: unawaited_futures
    _storage.write(key: _assignedRolesKey, value: encoded);
  }

  Future<List<String>> getAssignedRoles() async {
    final fromPrefs = await _readRolesFromPrefs();
    if (fromPrefs.isNotEmpty) return fromPrefs;

    final raw = await _storage.read(key: _assignedRolesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return _decodeRoles(raw);
  }

  Future<List<String>> _readRolesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assignedRolesPrefKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return _decodeRoles(raw);
  }

  List<String> _decodeRoles(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _assignedRolesKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_assignedRolesPrefKey);
  }
}

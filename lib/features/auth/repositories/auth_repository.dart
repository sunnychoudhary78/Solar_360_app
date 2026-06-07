import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/token_storage.dart';
import '../models/auth_user.dart';

class AuthRepository {
  final Dio dio;

  AuthRepository(this.dio);

  static const _cachedUserKey = 'cachedUser';
  static const _permissionsKey = 'permissions';

  Future<({AuthUser user, List<String> permissions})> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      final token = _extractToken(data);
      final userJson = data['user'];

      if (token == null || userJson == null || userJson is! Map) {
        throw Exception('Invalid Email or Password');
      }

      await TokenStorage.save(token);
      await _persistUserMeta(userJson);

      final user = AuthUser.fromJson(Map<String, dynamic>.from(userJson));

      List<String> permissions = [];
      try {
        permissions = await fetchPermissions();
      } catch (_) {
        permissions = [];
      }

      await _persistPermissions(permissions);

      return (user: user, permissions: permissions);
    } on DioException catch (e) {
      throw Exception(_mapLoginError(e));
    }
  }

  Future<({AuthUser? user, List<String> permissions})> restoreSession() async {
    final token = await TokenStorage.load();

    if (token == null || token.isEmpty || _isTokenExpired(token)) {
      await _clearSession();
      return (user: null, permissions: <String>[]);
    }

    final cachedUser = await _loadCachedUser();
    final cachedPermissions = await _loadCachedPermissions();

    try {
      final results = await Future.wait([
        dio.get('/auth/me'),
        dio.get('/auth/permissions'),
      ]);

      final meData = results[0].data;
      final permsData = results[1].data;

      final userJson = meData is Map ? (meData['user'] ?? meData) : null;

      if (userJson is! Map) {
        if (cachedUser != null) {
          return (user: cachedUser, permissions: cachedPermissions);
        }
        throw Exception('Could not load user profile');
      }

      final user = AuthUser.fromJson(Map<String, dynamic>.from(userJson));
      final permissions = _normalizePermissions(permsData);

      await _persistUserMeta(userJson);
      await _persistPermissions(permissions);

      return (user: user, permissions: permissions);
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 401 || code == 403) {
        await _clearSession();
        return (user: null, permissions: <String>[]);
      }

      if (cachedUser != null) {
        return (user: cachedUser, permissions: cachedPermissions);
      }

      return (user: null, permissions: <String>[]);
    } catch (_) {
      if (cachedUser != null) {
        return (user: cachedUser, permissions: cachedPermissions);
      }

      return (user: null, permissions: <String>[]);
    }
  }

  Future<List<String>> fetchPermissions() async {
    final response = await dio.get('/auth/permissions');
    return _normalizePermissions(response.data);
  }

  Future<void> logout() async {
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await TokenStorage.clear();
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_cachedUserKey);
    await prefs.remove(_permissionsKey);
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userRole');
    await prefs.remove('roleName');
    await prefs.remove('roleId');
  }

  String? _extractToken(dynamic data) {
    if (data is Map) {
      final token = data['token'] ?? data['accessToken'];
      if (token is String && token.trim().isNotEmpty) {
        return token;
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return null;
  }

  String _mapLoginError(DioException e) {
    final code = e.response?.statusCode;

    if (code == 401 || code == 403) {
      return 'Invalid Email or Password';
    }

    final data = e.response?.data;

    if (data is Map && data['message'] != null) {
      final msg = data['message'].toString();

      if (msg.toLowerCase().contains('invalid')) {
        return 'Invalid Email or Password';
      }

      return msg;
    }

    return e.message ?? 'Login failed. Please try again.';
  }

  List<String> _normalizePermissions(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data
          .map((p) {
            if (p is String) return p;
            if (p is Map) return p['name']?.toString() ?? '';
            return p.toString();
          })
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }

    if (data is Map) {
      final permissions = data['permissions'];
      if (permissions is List) {
        return _normalizePermissions(permissions);
      }
    }

    return [];
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');

      if (parts.length < 2) {
        return false;
      }

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];

      if (exp is int) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return expiryDate.isBefore(DateTime.now());
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistUserMeta(Map userJson) async {
    final prefs = await SharedPreferences.getInstance();

    final safeUserJson = Map<String, dynamic>.from(userJson);
    await prefs.setString(_cachedUserKey, jsonEncode(safeUserJson));

    final role = userJson['role'];
    final roleName = role is Map ? role['name']?.toString() : role?.toString();

    await prefs.setString('userId', userJson['id']?.toString() ?? '');
    await prefs.setString('userEmail', userJson['email']?.toString() ?? '');
    await prefs.setString('userName', userJson['name']?.toString() ?? '');
    await prefs.setString('userRole', roleName ?? '');
    await prefs.setString('roleName', roleName ?? '');
    await prefs.setString('roleId', userJson['roleId']?.toString() ?? '');
  }

  Future<AuthUser?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);

      if (raw == null || raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);

      if (decoded is! Map) return null;

      return AuthUser.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistPermissions(List<String> permissions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_permissionsKey, jsonEncode(permissions));
  }

  Future<List<String>> _loadCachedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_permissionsKey);

      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);

      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }
}
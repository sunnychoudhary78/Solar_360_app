import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/auth_models.dart';

class AuthApiService {
  final ApiService _api;

  AuthApiService(this._api);

  Future<LoginResult> login(String email, String password) async {
    final res = await _api.post(ApiEndpoints.login, {
      'email': email.trim(),
      'password': password,
    });
    return LoginResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<UserProfile> fetchMe() async {
    final res = await _api.get(ApiEndpoints.me);
    return UserProfile.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<String>> fetchPermissions() async {
    final res = await _api.get(ApiEndpoints.permissions);
    if (res is List) {
      return res
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['name'] ?? e['permission'] ?? '').toString();
            }
            return e.toString();
          })
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (res is Map) {
      final perms = res['permissions'] ?? res['data'];
      if (perms is List) {
        return perms
            .map((e) {
              if (e is String) return e;
              if (e is Map) return (e['name'] ?? '').toString();
              return e.toString();
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  Future<SwitchRoleResult> switchRole(String role) async {
    final res = await _api.post(ApiEndpoints.switchRole, {'role': role});
    return SwitchRoleResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _api.post(ApiEndpoints.changePassword, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }
}

import 'package:solar_sales/core/storage/token_storage.dart';

import 'auth_api_service.dart';
import 'models/auth_models.dart';

class AuthRepository {
  final AuthApiService _api;
  final TokenStorage _tokenStorage;

  AuthRepository(this._api, this._tokenStorage);

  Future<LoginResult> login(String email, String password) async {
    final result = await _api.login(email, password);
    await _tokenStorage.saveJwt(result.token);
    return result;
  }

  Future<UserProfile> getMe() => _api.fetchMe();

  Future<List<String>> getPermissions() => _api.fetchPermissions();

  Future<SwitchRoleResult> switchRole(String role) async {
    final result = await _api.switchRole(role);
    await _tokenStorage.saveJwt(result.token);
    return result;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<void> logoutLocal() => _tokenStorage.clear();

  Future<String?> getStoredToken() => _tokenStorage.getJwt();
}

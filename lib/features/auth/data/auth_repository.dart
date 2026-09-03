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

  Future<CustomerLoginResult> customerLogin(
    String email,
    String password,
  ) async {
    final result = await _api.customerLogin(email, password);
    await _tokenStorage.saveCustomerToken(result.token);
    return result;
  }

  Future<UserProfile> getMe() => _api.fetchMe();

  Future<CustomerProfile> getCustomerMe() => _api.fetchCustomerMe();

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

  Future<void> changeCustomerPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _api.changeCustomerPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<void> customerLogout() async {
    try {
      await _api.customerLogout();
    } catch (_) {}
  }

  Future<void> logoutLocal() => _tokenStorage.clear();

  Future<String?> getStoredToken() => _tokenStorage.getJwt();

  Future<String?> getStoredCustomerToken() => _tokenStorage.getCustomerToken();

  Future<SessionKind?> getSessionKind() => _tokenStorage.getSessionKind();

  Future<void> saveAssignedRoles(List<String> roles) =>
      _tokenStorage.saveAssignedRoles(roles);

  Future<List<String>> getStoredAssignedRoles() =>
      _tokenStorage.getAssignedRoles();
}

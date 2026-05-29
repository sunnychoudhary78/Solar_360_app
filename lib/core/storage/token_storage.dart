import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class TokenStorage {
  TokenStorage._();

  static String? _memoryToken;

  static String? get token => _memoryToken;

  static Future<void> save(String token) async {
    _memoryToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.tokenKey, token);
    await prefs.setBool('isLoggedIn', true);
  }

  static Future<String?> load() async {
    if (_memoryToken != null && _memoryToken!.isNotEmpty) {
      return _memoryToken;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(AppConfig.tokenKey);
    _memoryToken = stored;
    return stored;
  }

  static Future<void> clear() async {
    _memoryToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.tokenKey);
    await prefs.remove('isLoggedIn');
    await prefs.remove('token');
    await prefs.remove('userRole');
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('roleName');
    await prefs.remove('roleId');
    await prefs.remove('permissions');
  }
}

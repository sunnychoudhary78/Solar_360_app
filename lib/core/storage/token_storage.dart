import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  /// Keep compatible with web/session naming across Solar 360 clients.
  static const _jwtKey = 'LMS_accessToken';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveJwt(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  Future<String?> getJwt() async {
    return _storage.read(key: _jwtKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _jwtKey);
  }
}

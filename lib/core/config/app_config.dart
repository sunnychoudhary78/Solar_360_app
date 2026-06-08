/// API base URL — must include `/api` suffix (matches csplsolar-frontend `VITE_BASE_URL`).
///
/// - Android emulator: `http://10.0.2.2:3011/api`
/// - Physical device on same LAN: use your PC IP, e.g. `http://192.168.1.16:3011/api`
/// - iOS simulator: `http://localhost:3011/api`
class AppConfig {
  AppConfig._();
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.16:3011/api',
);
// http://192.168.1.16:3011/api'
// https://greenenergy.immortalgroup.in/api
  
  static const String tokenKey = 'LMS_accessToken';
}


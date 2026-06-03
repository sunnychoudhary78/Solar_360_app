import '../config/app_config.dart';

/// Resolves employee profile picture path to a full URL.
String resolveProfilePictureUrl(String? value) {
  if (value == null || value.trim().isEmpty) return '';

  final s = value.trim().replaceAll('\\', '/');

  if (s.startsWith('http://') || s.startsWith('https://')) {
    return s;
  }

  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');
  var path = s.replaceFirst(RegExp(r'^/'), '');

  if (!path.startsWith('uploads/')) {
    path = 'uploads/$path';
  }

  return '$base/api/$path';
}

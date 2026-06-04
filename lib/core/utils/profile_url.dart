import '../config/app_config.dart';

List<String> resolveProfilePictureUrls(String? value) {
  if (value == null || value.trim().isEmpty) return [];

  final s = value.trim().replaceAll('\\', '/');

  if (s.startsWith('http://') || s.startsWith('https://')) {
    return [s];
  }

  final baseWithoutApi =
      AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  var path = s.replaceFirst(RegExp(r'^/+'), '');

  if (path.startsWith('api/uploads/')) {
    path = path.replaceFirst('api/', '');
  }

  if (!path.startsWith('uploads/')) {
    path = 'uploads/$path';
  }

  return [
    '$baseWithoutApi/$path',
    '${AppConfig.apiBaseUrl}/$path',
  ];
}

String resolveProfilePictureUrl(String? value) {
  final urls = resolveProfilePictureUrls(value);
  return urls.isEmpty ? '' : urls.first;
}
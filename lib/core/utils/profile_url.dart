import 'package:solar_sales/core/network/api_constants.dart';

List<String> resolveProfilePictureUrls(String? value) {
  if (value == null || value.trim().isEmpty) return [];

  final s = value.trim().replaceAll('\\', '/');

  if (s.startsWith('http://') || s.startsWith('https://')) {
    if (s.contains('/api/uploads/')) return [s];
    return [s.replaceFirst('/uploads/', '/api/uploads/')];
  }

  final baseWithoutApi = ApiConstants.baseUrl.replaceFirst(
    RegExp(r'/api/?$'),
    '',
  );

  final path = s
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'^api/uploads/'), '')
      .replaceFirst(RegExp(r'^uploads/'), '');

  return ['$baseWithoutApi/api/uploads/$path'];
}

String resolveProfilePictureUrl(String? value) {
  final urls = resolveProfilePictureUrls(value);
  return urls.isEmpty ? '' : urls.first;
}

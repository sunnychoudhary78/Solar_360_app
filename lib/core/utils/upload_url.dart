import 'package:solar_sales/core/network/api_constants.dart';

String resolveUploadUrl(String? value) {
  if (value == null) return '';

  final s = value.toString().trim();
  if (s.isEmpty) return '';

  if (s.startsWith('http://') || s.startsWith('https://')) {
    if (s.contains('/api/uploads/')) return s;
    return s.replaceFirst('/uploads/', '/api/uploads/');
  }

  final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api$'), '');

  var normalized = s.replaceAll('\\', '/').trim();

  normalized = normalized.replaceFirst(RegExp(r'^/'), '');
  normalized = normalized.replaceFirst(RegExp(r'^api/uploads/'), '');
  normalized = normalized.replaceFirst(RegExp(r'^uploads/'), '');

  if (!normalized.startsWith('leads/')) {
    normalized = 'leads/$normalized';
  }

  return '$base/api/uploads/$normalized';
}

bool isImagePath(String? path) {
  if (path == null || path.isEmpty) return false;

  return RegExp(
    r'\.(jpg|jpeg|png|gif|webp)$',
    caseSensitive: false,
  ).hasMatch(path);
}

bool isPdfPath(String? path) {
  if (path == null || path.isEmpty) return false;
  return path.toLowerCase().endsWith('.pdf');
}

String fileDisplayName(String? path) {
  if (path == null || path.isEmpty) return 'File';

  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').last;
}

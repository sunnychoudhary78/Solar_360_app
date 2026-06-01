import '../config/app_config.dart';

String resolveUploadUrl(String? value) {
  if (value == null) return '';

  final s = value.toString().trim();
  if (s.isEmpty) return '';

  if (s.startsWith('http://') || s.startsWith('https://')) {
    return s.replaceAll('/uploads/', '/api/uploads/');
  }

  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api$'), '');

  var normalized = s.replaceAll('\\', '/').trim();

  normalized = normalized.replaceFirst(RegExp(r'^/'), '');
  normalized = normalized.replaceFirst(RegExp(r'^api/uploads/'), '');
  normalized = normalized.replaceFirst(RegExp(r'^uploads/'), '');

  // Lead files are stored under uploads/leads/ on the server.
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

  final s = path.replaceAll('\\', '/');
  return s.split('/').last;
}
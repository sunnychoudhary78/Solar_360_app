import 'dart:convert';

import 'package:solar_sales/core/utils/upload_url.dart';

import 'models/lead_model.dart';

class LeadFileItem {
  final String label;
  final String path;
  final String url;
  final bool isImage;
  final bool isPdf;

  const LeadFileItem({
    required this.label,
    required this.path,
    required this.url,
    required this.isImage,
    required this.isPdf,
  });

  String get displayName {
    final clean = path.split('/').last.split('\\').last;
    return clean.isEmpty ? label : clean;
  }
}

class TitledFileEntry {
  final String title;
  final String path;

  const TitledFileEntry({required this.title, required this.path});
}

String _fixedUploadUrl(String path) {
  var url = resolveUploadUrl(path).trim().replaceAll('\\', '/');

  if (url.isEmpty) return '';

  // Backend only supports /api/uploads, not /uploads
  url = url.replaceFirst('/uploads/', '/api/uploads/');

  // Avoid duplicate api
  url = url.replaceAll('/api/api/uploads/', '/api/uploads/');

  return url;
}

List<LeadFileItem> collectLeadFiles(LeadModel lead) {
  final items = <LeadFileItem>[];
  final seen = <String>{};

  void addItem(String label, String? path) {
    final p = LeadModel.filePathFrom(path);
    if (p.isEmpty) return;

    final url = _fixedUploadUrl(p);
    if (url.isEmpty) return;

    final key = p.replaceAll('\\', '/').toLowerCase();
    if (!seen.add(key)) return;

    items.add(
      LeadFileItem(
        label: label,
        path: p,
        url: url,
        isImage: isImagePath(p),
        isPdf: isPdfPath(p),
      ),
    );
  }

  addItem('Cheque / Passbook', lead.chequePassbookCopy);
  addItem('Bank Clear Photo', lead.bankClearPhoto);
  addItem('Roof Photo', lead.roofPhoto);
  addItem('Pre-Installation', lead.preInstallationPhoto);
  addItem('Quotation', lead.quotationDocument);
  addItem('Installation Report', lead.installationReport);

  final installationPaths = LeadModel.filePathsFrom(lead.installationImages);
  for (var i = 0; i < installationPaths.length; i++) {
    addItem(
      installationPaths.length == 1
          ? 'Installation Images'
          : 'Installation Image ${i + 1}',
      installationPaths[i],
    );
  }

  void addExtra(String prefix, dynamic raw) {
    for (final item in _parseExtraField(prefix, raw)) {
      final key = item.path.replaceAll('\\', '/').toLowerCase();
      if (!seen.add(key)) continue;
      items.add(item);
    }
  }

  addExtra('Additional Document', lead.additionalDocuments);
  addExtra('Additional Image', lead.additionalImages);

  return items;
}

/// Parses every titled file the API may send: JSON arrays, JSON objects with
/// numeric keys, double-encoded strings, and `{title, file|path|url}` maps.
/// Never truncates the list.
List<TitledFileEntry> parseTitledFileEntries(dynamic raw) {
  final decoded = _decodeToList(raw);
  final out = <TitledFileEntry>[];

  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i];
    var title = '';
    var file = '';

    if (entry is Map) {
      title = (entry['title'] ??
              entry['label'] ??
              entry['name'] ??
              entry['document_title'] ??
              '')
          .toString()
          .trim();
      file = LeadModel.filePathFrom(entry);
    } else {
      file = LeadModel.filePathFrom(entry);
    }

    if (file.isEmpty) continue;

    out.add(
      TitledFileEntry(
        title: title.isEmpty ? 'File ${i + 1}' : title,
        path: file,
      ),
    );
  }

  return out;
}

List<LeadFileItem> _parseExtraField(String prefix, dynamic raw) {
  final entries = parseTitledFileEntries(raw);
  final out = <LeadFileItem>[];

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final url = _fixedUploadUrl(entry.path);
    if (url.isEmpty) continue;

    final fallbackTitle = '$prefix ${i + 1}';
    final label = entry.title.trim().isEmpty ||
            RegExp(r'^File \d+$').hasMatch(entry.title.trim())
        ? fallbackTitle
        : entry.title.trim();

    out.add(
      LeadFileItem(
        label: label,
        path: entry.path,
        url: url,
        isImage: isImagePath(entry.path),
        isPdf: isPdfPath(entry.path),
      ),
    );
  }

  return out;
}

dynamic _unwrapJson(dynamic raw, [int depth = 0]) {
  if (raw == null || depth > 6) return raw;

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return _unwrapJson(jsonDecode(trimmed), depth + 1);
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }

  return raw;
}

List<dynamic> _decodeToList(dynamic raw) {
  final value = _unwrapJson(raw);
  if (value == null) return const [];

  if (value is List) return List<dynamic>.from(value);

  if (value is Map) {
    for (final key in const [
      'data',
      'files',
      'documents',
      'images',
      'items',
      'entries',
      'additional_documents',
      'additional_images',
      'additionalDocuments',
      'additionalImages',
    ]) {
      if (value[key] != null) {
        final nested = _decodeToList(value[key]);
        if (nested.isNotEmpty) return nested;
      }
    }

    final keys = value.keys.map((key) => key.toString()).toList();
    final numeric = keys.isNotEmpty &&
        keys.every((key) => int.tryParse(key) != null);
    if (numeric) {
      keys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      return [for (final key in keys) value[key] ?? value[int.tryParse(key)]];
    }

    if (LeadModel.filePathFrom(value).isNotEmpty ||
        (value['title']?.toString().trim().isNotEmpty ?? false)) {
      return [value];
    }
  }

  if (value is String && value.trim().isNotEmpty) return [value];

  return const [];
}

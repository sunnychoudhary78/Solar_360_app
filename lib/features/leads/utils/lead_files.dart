import 'dart:convert';

import '../../../core/utils/upload_url.dart';
import '../models/lead_model.dart';

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

List<LeadFileItem> collectLeadFiles(LeadModel lead) {
  final items = <LeadFileItem>[];

  void addSingle(String label, String? path) {
    if (path == null || path.trim().isEmpty) return;

    final p = path.trim();
    final url = resolveUploadUrl(p);

    if (url.trim().isEmpty) return;

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

  addSingle('Cheque / Passbook', lead.chequePassbookCopy);
  addSingle('Bank Clear Photo', lead.bankClearPhoto);
  addSingle('Roof Photo', lead.roofPhoto);
  addSingle('Pre-Installation', lead.preInstallationPhoto);
  addSingle('Quotation', lead.quotationDocument);
  addSingle('Installation Report', lead.installationReport);
  addSingle('Installation Images', lead.installationImages);

  items.addAll(
    _parseExtraField('Additional Document', lead.additionalDocuments),
  );

  items.addAll(
    _parseExtraField('Additional Image', lead.additionalImages),
  );

  return items;
}

List<LeadFileItem> _parseExtraField(String prefix, dynamic raw) {
  if (raw == null) return [];

  dynamic decoded = raw;

  if (raw is String && raw.trim().isNotEmpty) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      final url = resolveUploadUrl(raw);

      if (url.trim().isEmpty) return [];

      return [
        LeadFileItem(
          label: prefix,
          path: raw,
          url: url,
          isImage: isImagePath(raw),
          isPdf: isPdfPath(raw),
        ),
      ];
    }
  }

  if (decoded is! List) return [];

  final out = <LeadFileItem>[];

  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i];

    if (entry is! Map) continue;

    final title = entry['title']?.toString().trim();
    final file = entry['file']?.toString().trim() ??
        entry['path']?.toString().trim() ??
        '';

    if (file.isEmpty) continue;

    final url = resolveUploadUrl(file);

    if (url.trim().isEmpty) continue;

    out.add(
      LeadFileItem(
        label: title == null || title.isEmpty ? '$prefix ${i + 1}' : title,
        path: file,
        url: url,
        isImage: isImagePath(file),
        isPdf: isPdfPath(file),
      ),
    );
  }

  return out;
}
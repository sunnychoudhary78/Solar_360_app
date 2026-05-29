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
}

List<LeadFileItem> collectLeadFiles(LeadModel lead) {
  final items = <LeadFileItem>[];

  void addSingle(String label, String? path) {
    if (path == null || path.trim().isEmpty) return;
    final p = path.trim();
    items.add(
      LeadFileItem(
        label: label,
        path: p,
        url: resolveUploadUrl(p),
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

  items.addAll(_parseExtraField('Additional Documents', lead.additionalDocuments));
  items.addAll(_parseExtraField('Additional Images', lead.additionalImages));

  return items.where((e) => e.url.isNotEmpty).toList();
}

List<LeadFileItem> _parseExtraField(String prefix, dynamic raw) {
  if (raw == null) return [];

  dynamic decoded = raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return [
        if (resolveUploadUrl(raw).isNotEmpty)
          LeadFileItem(
            label: prefix,
            path: raw,
            url: resolveUploadUrl(raw),
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
    final title = entry['title']?.toString() ?? '$prefix ${i + 1}';
    final file = entry['file']?.toString() ?? entry['path']?.toString() ?? '';
    if (file.isEmpty) continue;
    out.add(
      LeadFileItem(
        label: title,
        path: file,
        url: resolveUploadUrl(file),
        isImage: isImagePath(file),
        isPdf: isPdfPath(file),
      ),
    );
  }
  return out;
}

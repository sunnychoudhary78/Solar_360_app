import 'package:flutter/material.dart';

import '../../../core/utils/file_download.dart';
import '../../../core/utils/upload_url.dart';
import '../screens/document_preview_screen.dart';
import '../screens/image_viewer_screen.dart';
import '../utils/lead_files.dart';

class LeadAttachmentsView extends StatelessWidget {
  final List<LeadFileItem> files;

  const LeadAttachmentsView({super.key, required this.files});

  static const _primaryColor = Color(0xFF5663A0);

  String _resolveUrl(LeadFileItem item) {
    final fromItem = item.url.trim();
    if (fromItem.isNotEmpty) return fromItem;
    return resolveUploadUrl(item.path);
  }

  Future<void> _preview(BuildContext context, LeadFileItem item) async {
    final url = _resolveUrl(item);
    if (url.isEmpty) {
      _snack(context, 'File URL not found');
      return;
    }

    if (!context.mounted) return;

    if (item.isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            imageUrl: url,
            label: item.label,
            fileName: item.displayName,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          fileUrl: url,
          label: item.label,
          fileName: item.displayName,
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context, LeadFileItem item) async {
    final url = _resolveUrl(item);
    if (url.isEmpty) {
      _snack(context, 'File URL not found');
      return;
    }

    try {
      final path = await downloadRemoteFile(
        url: url,
        fileName: item.displayName,
        openAfterSave: false,
      );
      if (!context.mounted) return;
      _snack(context, 'Saved: $path');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString());
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No uploaded files for this lead',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: files.map((item) {
        final fixedUrl = _resolveUrl(item);

        return Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E1EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: SizedBox(
                  height: 96,
                  child: item.isImage && fixedUrl.isNotEmpty
                      ? Image.network(
                          fixedUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fileIcon(item),
                        )
                      : _fileIcon(item),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: fixedUrl.isEmpty
                            ? null
                            : () => _preview(context, item),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          foregroundColor: _primaryColor,
                        ),
                        child: const Text('Preview', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: fixedUrl.isEmpty
                            ? null
                            : () => _download(context, item),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: const Text('Download', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _fileIcon(LeadFileItem item) {
    return ColoredBox(
      color: const Color(0xFFEEF0F8),
      child: Center(
        child: Icon(
          item.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
          size: 40,
          color: item.isPdf ? Colors.red : _primaryColor,
        ),
      ),
    );
  }
}

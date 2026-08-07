import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/features/leads/data/lead_files.dart';
import 'package:solar_sales/features/leads/presentation/screens/document_preview_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/image_viewer_screen.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class LeadAttachmentsView extends StatelessWidget {
  final List<LeadFileItem> files;

  const LeadAttachmentsView({super.key, required this.files});

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (files.isEmpty) {
      return const EmptyState(
        title: 'No uploaded files',
        subtitle: 'Documents and images for this lead will show up here.',
        icon: Icons.attach_file_rounded,
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
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg - 2),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .55),
            ),
            boxShadow: AppShadows.card(scheme),
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
                      ? CachedNetworkImage(
                          imageUrl: fixedUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _fileIcon(context, item),
                        )
                      : _fileIcon(context, item),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
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
                          foregroundColor: scheme.primary,
                        ),
                        child: const Text(
                          'Preview',
                          style: TextStyle(fontSize: 11),
                        ),
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
                        child: const Text(
                          'Download',
                          style: TextStyle(fontSize: 11),
                        ),
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

  Widget _fileIcon(BuildContext context, LeadFileItem item) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          item.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
          size: 40,
          color: item.isPdf ? scheme.error : scheme.primary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/lead_files.dart';

class LeadAttachmentsView extends StatelessWidget {
  final List<LeadFileItem> files;

  const LeadAttachmentsView({
    super.key,
    required this.files,
  });

  Future<void> _openFile(BuildContext context, LeadFileItem item) async {
    final uri = Uri.tryParse(item.url);

    if (uri == null || item.url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File URL not found')),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
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
        return InkWell(
          onTap: () => _openFile(context, item),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4E1EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: SizedBox(
                    height: 100,
                    child: item.isImage && item.url.isNotEmpty
                        ? Image.network(
                            item.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fileIcon(item),
                          )
                        : _fileIcon(item),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
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
              ],
            ),
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
          size: 42,
          color: item.isPdf ? Colors.red : const Color(0xFF5663A0),
        ),
      ),
    );
  }
}
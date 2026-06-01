import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/image_viewer_screen.dart';
import '../utils/lead_files.dart';

class LeadAttachmentsView extends StatelessWidget {
  final List<LeadFileItem> files;

  const LeadAttachmentsView({super.key, required this.files});

  static const String _serverBaseUrl = 'http://192.168.1.16:3011';

  String _fixedUrl(String url) {
    var u = url.trim().replaceAll('\\', '/');

    if (u.isEmpty) return '';

    u = u.replaceFirst(RegExp(r'^https?://[^/]+/api/uploads/'), '/uploads/');
    u = u.replaceFirst(RegExp(r'^https?://[^/]+/uploads/'), '/uploads/');

    u = u.replaceFirst('/api/uploads/', '/uploads/');

    if (u.startsWith('api/uploads/')) {
      u = u.replaceFirst('api/uploads/', 'uploads/');
    }

    if (u.startsWith('uploads/')) {
      u = '/$u';
    }

    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      if (!u.startsWith('/')) u = '/$u';
      u = '$_serverBaseUrl$u';
    }

    return u;
  }

  Future<void> _openFile(BuildContext context, LeadFileItem item) async {
    final fixedUrl = _fixedUrl(item.url);
    debugPrint('Opening file: ${item.displayName}, url: $fixedUrl');

    if (fixedUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File URL not found')));
      return;
    }

    final uri = Uri.tryParse(fixedUrl);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid file URL')));
      return;
    }

    if (item.isImage) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            imageUrl: fixedUrl,
            label: item.label,
            fileName: item.displayName,
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final canLaunch = await canLaunchUrl(uri);
    debugPrint('Can launch PDF/attachment: $canLaunch for uri: $uri');

    if (!canLaunch) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app available to open this file')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
    debugPrint('Launch result: $opened for uri: $uri');

    if (!opened) {
      messenger.showSnackBar(
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
        final fixedUrl = _fixedUrl(item.url);

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
                    child: item.isImage && fixedUrl.isNotEmpty
                        ? Image.network(
                            fixedUrl,
                            fit: BoxFit.cover,
                            headers: const {'Accept': 'image/*,*/*'},
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

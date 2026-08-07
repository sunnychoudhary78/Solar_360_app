import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String label;
  final String fileName;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.label,
    required this.fileName,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _downloading = false;
  String? _downloadError;

  Future<void> _downloadImage() async {
    setState(() {
      _downloading = true;
      _downloadError = null;
    });

    try {
      final path = await downloadRemoteFile(
        url: widget.imageUrl,
        fileName: widget.fileName,
        openAfterSave: false,
      );

      if (!mounted) return;

      setState(() => _downloading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image saved to $path')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadError = e.toString();
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.label),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _downloading ? null : _downloadImage,
            icon: _downloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download image',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const LoadingState(message: 'Loading image…'),
                  errorWidget: (context, url, error) => const EmptyState(
                    title: 'Failed to load image',
                    subtitle: 'Check your connection and try again.',
                    icon: Icons.broken_image_outlined,
                    iconColor: Colors.white54,
                    iconBackground: Color(0x33FFFFFF),
                  ),
                ),
              ),
            ),
          ),
          if (_downloadError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade900,
              child: Text(
                _downloadError!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

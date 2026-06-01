import 'package:flutter/material.dart';

import '../../../core/utils/file_download.dart';
import '../../../core/utils/upload_url.dart';

/// In-app preview for PDF and other documents (opens locally after download).
class DocumentPreviewScreen extends StatefulWidget {
  final String fileUrl;
  final String label;
  final String fileName;

  const DocumentPreviewScreen({
    super.key,
    required this.fileUrl,
    required this.label,
    required this.fileName,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  Future<void> _preparePreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = await downloadRemoteFile(
        url: widget.fileUrl,
        fileName: widget.fileName,
        openAfterSave: true,
      );
      if (!mounted) return;
      setState(() {
        _savedPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadOnly() async {
    setState(() {
      _downloading = true;
      _error = null;
    });

    try {
      final path = await downloadRemoteFile(
        url: widget.fileUrl,
        fileName: widget.fileName,
        openAfterSave: false,
      );
      if (!mounted) return;
      setState(() {
        _savedPath = path;
        _downloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = isPdfPath(widget.fileName);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: const Color(0xFF1F2028),
        elevation: 0,
        title: Text(widget.label),
        actions: [
          IconButton(
            onPressed: _downloading ? null : _downloadOnly,
            icon: _downloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'Download',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4E1EA)),
              ),
              child: Column(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                    size: 56,
                    color: isPdf ? Colors.red : const Color(0xFF5663A0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fileDisplayName(widget.fileName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    _savedPath != null
                        ? 'Document opened with your device viewer.\nYou can download again from the toolbar.'
                        : 'Ready',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            if (!_loading)
              FilledButton.icon(
                onPressed: _preparePreview,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open again'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5663A0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved to $path')));
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppAppBar(
        title: widget.label,
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
        padding: const EdgeInsets.all(AppSpacing.md + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              variant: AppCardVariant.outlined,
              padding: const EdgeInsets.all(AppSpacing.md + 4),
              child: Column(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                    size: 56,
                    color: isPdf ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md - 4),
                  Text(
                    fileDisplayName(widget.fileName),
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            if (_loading)
              const Expanded(child: LoadingState(message: 'Opening document…'))
            else if (_error != null)
              Expanded(
                child: ErrorState(message: _error!, onRetry: _preparePreview),
              )
            else
              Expanded(
                child: EmptyState(
                  title: 'Document ready',
                  subtitle: _savedPath != null
                      ? 'Opened with your device viewer. Download again from the toolbar if needed.'
                      : 'Ready to open.',
                  icon: isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                ),
              ),
            if (!_loading)
              FilledButton.icon(
                onPressed: _preparePreview,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md - 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

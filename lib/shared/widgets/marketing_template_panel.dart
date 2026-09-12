import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/leads/presentation/screens/document_preview_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/image_viewer_screen.dart';
import 'package:solar_sales/shared/widgets/marketing_template_picker.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class MarketingTemplatePanel extends ConsumerStatefulWidget {
  const MarketingTemplatePanel({super.key, required this.template});

  final MarketingTemplate? template;

  @override
  ConsumerState<MarketingTemplatePanel> createState() =>
      _MarketingTemplatePanelState();
}

class _MarketingTemplatePanelState
    extends ConsumerState<MarketingTemplatePanel> {
  bool _busy = false;

  MarketingTemplate? get _template {
    final tpl = widget.template;
    if (tpl == null || tpl.id.isEmpty) return null;
    return tpl;
  }

  String get _fileName {
    final tpl = _template;
    if (tpl == null) return 'marketing-template';
    if (tpl.originalName.trim().isNotEmpty) return tpl.originalName;
    return '${tpl.name}${tpl.isPdf ? '.pdf' : ''}';
  }

  Future<void> _preview() async {
    final tpl = _template;
    if (tpl == null) return;
    final url = tpl.previewUrl;
    if (url.isEmpty) {
      await _download(open: true);
      return;
    }
    if (tpl.isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentPreviewScreen(
            fileUrl: url,
            label: tpl.name,
            fileName: _fileName,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          imageUrl: url,
          label: tpl.name,
          fileName: _fileName,
        ),
      ),
    );
  }

  Future<void> _download({required bool open}) async {
    final tpl = _template;
    if (tpl == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(marketingTemplateApiProvider).download(
            tpl.id,
          );
      await saveBytesAsDownload(
        bytes: bytes,
        fileName: _fileName,
        openAfterSave: open,
      );
      if (!mounted) return;
      showAppMessage(context, open ? 'Opening template' : 'Template downloaded');
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final tpl = _template;
    if (tpl == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(marketingTemplateApiProvider).download(
            tpl.id,
          );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: tpl.name,
          text: tpl.description.trim().isEmpty ? tpl.name : tpl.description,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tpl = _template;
    if (tpl == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return PremiumCard(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  tpl.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MARKETING TEMPLATE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tpl.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (tpl.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tpl.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _download(open: false),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/file_download.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/leads/presentation/screens/document_preview_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/image_viewer_screen.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/marketing_template_picker.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class MarketingTemplatesScreen extends ConsumerStatefulWidget {
  const MarketingTemplatesScreen({super.key});

  @override
  ConsumerState<MarketingTemplatesScreen> createState() =>
      _MarketingTemplatesScreenState();
}

class _MarketingTemplatesScreenState
    extends ConsumerState<MarketingTemplatesScreen> {
  bool _busy = false;

  bool get _canUpdate =>
      ref.read(authProvider).hasPermission('companySettings.update');

  Future<void> _reload() async {
    ref.invalidate(marketingTemplatesAdminProvider);
    ref.invalidate(marketingTemplatesProvider('quotation'));
    ref.invalidate(marketingTemplatesProvider('invoice'));
    await ref.read(marketingTemplatesAdminProvider.future);
  }

  Future<void> _upload() async {
    if (!_canUpdate) return;
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadMarketingTemplateDialog(),
    );
    if (created == true && mounted) {
      await _reload();
    }
  }

  Future<void> _toggle(MarketingTemplate row) async {
    if (!_canUpdate || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(marketingTemplateApiProvider).updateActive(
            id: row.id,
            isActive: !row.isActive,
          );
      if (!mounted) return;
      showAppMessage(
        context,
        row.isActive ? 'Template disabled' : 'Template enabled',
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MarketingTemplate row) async {
    if (!_canUpdate || _busy) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete template',
      message: 'Delete template "${row.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(marketingTemplateApiProvider).remove(row.id);
      if (!mounted) return;
      showAppMessage(context, 'Template deleted');
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFile(MarketingTemplate row, {required bool open}) async {
    try {
      final bytes = await ref.read(marketingTemplateApiProvider).download(
            row.id,
          );
      final name = row.originalName.trim().isEmpty
          ? '${row.name}${row.isPdf ? '.pdf' : ''}'
          : row.originalName;
      await saveBytesAsDownload(
        bytes: bytes,
        fileName: name,
        openAfterSave: open,
      );
      if (!mounted) return;
      showAppMessage(
        context,
        open ? 'Opening template' : 'Template downloaded',
      );
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _preview(MarketingTemplate row) async {
    final url = row.previewUrl;
    final fileName = row.originalName.trim().isEmpty
        ? '${row.name}${row.isPdf ? '.pdf' : '.png'}'
        : row.originalName;
    if (url.isEmpty) {
      if (row.isPdf) {
        await _saveFile(row, open: true);
        return;
      }
      showAppMessage(context, 'Preview is not available', isError: true);
      return;
    }
    if (row.isPdf) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentPreviewScreen(
            fileUrl: url,
            label: row.name,
            fileName: fileName,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          imageUrl: url,
          label: row.name,
          fileName: fileName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketingTemplatesAdminProvider);
    final scheme = Theme.of(context).colorScheme;
    final canUpdate = ref.watch(authProvider).hasPermission(
          'companySettings.update',
        );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Templates',
        subtitle: 'Upload and manage marketing templates for quotations & invoices',
        actions: [
          if (canUpdate)
            IconButton(
              tooltip: 'Upload Template',
              onPressed: _upload,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      floatingActionButton: canUpdate
          ? FloatingActionButton.extended(
              onPressed: _upload,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Template'),
            )
          : null,
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingState(message: 'Loading templates…'),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(marketingTemplatesAdminProvider),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyState(
              title: 'No marketing templates yet',
              subtitle: 'Upload a PDF or image to get started.',
              icon: Icons.layers_outlined,
              action: canUpdate
                  ? FilledButton.icon(
                      onPressed: _upload,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload Template'),
                    )
                  : null,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: templates.length + 1,
              separatorBuilder: (_, index) =>
                  SizedBox(height: index == 0 ? 6 : 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketing Templates',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload brochures or marketing PDFs/images. Attach them to quotations and invoices when sharing or downloading.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  );
                }
                final row = templates[index - 1];
                return _TemplateCard(
                  template: row,
                  canUpdate: canUpdate,
                  onPreview: () => _preview(row),
                  onDownload: () => _saveFile(row, open: false),
                  onToggle: () => _toggle(row),
                  onDelete: () => _delete(row),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.canUpdate,
    required this.onPreview,
    required this.onDownload,
    required this.onToggle,
    required this.onDelete,
  });

  final MarketingTemplate template;
  final bool canUpdate;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  template.isPdf
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
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (template.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${template.appliesLabel}  ·  ${template.originalName.isEmpty ? '—' : template.originalName}  ·  ${template.formattedSize}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.isActive ? 'Active' : 'Disabled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: template.isActive
                            ? const Color(0xFF047857)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            children: [
              IconButton(
                tooltip: 'Preview',
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined),
              ),
              IconButton(
                tooltip: 'Download',
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined),
              ),
              if (canUpdate) ...[
                TextButton(
                  onPressed: onToggle,
                  child: Text(template.isActive ? 'Disable' : 'Enable'),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadMarketingTemplateDialog extends ConsumerStatefulWidget {
  const _UploadMarketingTemplateDialog();

  @override
  ConsumerState<_UploadMarketingTemplateDialog> createState() =>
      _UploadMarketingTemplateDialogState();
}

class _UploadMarketingTemplateDialogState
    extends ConsumerState<_UploadMarketingTemplateDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _appliesTo = 'both';
  String? _filePath;
  String? _fileName;
  bool _saving = false;

  static const _maxBytes = 15 * 1024 * 1024;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
      withData: false,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    if (file.size > _maxBytes) {
      if (!mounted) return;
      showAppMessage(context, 'File (PDF or image, max 15 MB)', isError: true);
      return;
    }
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppMessage(context, 'Template name is required', isError: true);
      return;
    }
    if (_filePath == null) {
      showAppMessage(
        context,
        'Please choose a PDF or image file',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(marketingTemplateApiProvider).create(
            name: name,
            description: _description.text,
            appliesTo: _appliesTo,
            filePath: _filePath!,
          );
      if (!mounted) return;
      showAppMessage(context, 'Template uploaded');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Upload marketing template'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. Residential solar brochure',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional note',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _appliesTo,
                decoration: const InputDecoration(labelText: 'Applies to'),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('Quotations & Invoices'),
                  ),
                  DropdownMenuItem(
                    value: 'quotation',
                    child: Text('Quotations only'),
                  ),
                  DropdownMenuItem(
                    value: 'invoice',
                    child: Text('Invoices only'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _appliesTo = value);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'File (PDF or image, max 15 MB) *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saving ? null : _pickFile,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.upload_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fileName ?? 'Click to choose file',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Uploading…' : 'Upload'),
        ),
      ],
    );
  }
}

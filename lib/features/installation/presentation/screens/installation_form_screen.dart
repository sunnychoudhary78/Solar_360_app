import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/features/installation/presentation/providers/installation_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class InstallationFormScreen extends ConsumerStatefulWidget {
  final LeadModel lead;
  final bool materialOnly;

  const InstallationFormScreen({
    super.key,
    required this.lead,
    this.materialOnly = false,
  });

  @override
  ConsumerState<InstallationFormScreen> createState() =>
      _InstallationFormScreenState();
}

class _InstallationFormScreenState
    extends ConsumerState<InstallationFormScreen> {
  final fileNo = TextEditingController();
  final capacity = TextEditingController();
  final panelBrand = TextEditingController();
  final panelCount = TextEditingController();
  final invoiceNo = TextEditingController();

  final inverterSerialNumber = TextEditingController();
  final batterySerialNumber = TextEditingController();

  final dcrCertificateNo = TextEditingController();
  final applicationNo = TextEditingController();

  final List<TextEditingController> spControllers = [TextEditingController()];
  final ImagePicker _imagePicker = ImagePicker();

  /// Newly picked local image paths (camera / gallery).
  List<String> selectedInstallationImages = [];

  /// Already-uploaded remote/local paths from the server.
  List<String> existingInstallationImages = [];

  bool loading = false;
  String? existingId;
  String panelType = 'DCR';

  @override
  void initState() {
    super.initState();
    _prefillFrom(widget.lead.installationDetails);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFormFromApi();
    });
  }

  Future<void> _loadFormFromApi() async {
    try {
      final details = await ref
          .read(installationRepositoryProvider)
          .getForm(widget.lead.id);
      if (!mounted || details == null || details.isEmpty) return;
      final hasSavedDetails =
          (details['id']?.toString() ?? '').trim().isNotEmpty ||
          (details['file_no']?.toString() ?? '').trim().isNotEmpty ||
          (details['solar_panel_brand']?.toString() ?? '').trim().isNotEmpty;
      if (!hasSavedDetails) return;
      setState(() => _prefillFrom(details));
    } catch (_) {
      // Keep values already prefilled from the lead payload.
    }
  }

  void _prefillFrom(Map<String, dynamic>? d) {
    if (d == null) return;

    existingId = d['id']?.toString();

    fileNo.text = d['file_no']?.toString() ?? '';
    capacity.text =
        d['panel_capacity']?.toString() ?? d['capacity']?.toString() ?? '';
    panelBrand.text = d['solar_panel_brand']?.toString() ?? '';
    panelCount.text = d['number_of_solar_panels']?.toString() ?? '';
    invoiceNo.text = d['invoice_no']?.toString() ?? '';

    panelType = d['panel_type']?.toString() == 'NON_DCR' ? 'NON_DCR' : 'DCR';

    inverterSerialNumber.text = d['inverter_serial_number']?.toString() ?? '';
    batterySerialNumber.text = d['battery_serial_number']?.toString() ?? '';

    dcrCertificateNo.text = d['dcr_certificate_no']?.toString() ?? '';
    applicationNo.text = d['application_no']?.toString() ?? '';

    final rawSpNumbers = d['sp_numbers'];

    if (rawSpNumbers is List && rawSpNumbers.isNotEmpty) {
      final values = rawSpNumbers.map((item) => item?.toString() ?? '').toList();
      while (spControllers.length > values.length) {
        final extra = spControllers.removeLast();
        extra.dispose();
      }
      for (var i = 0; i < values.length; i++) {
        if (i < spControllers.length) {
          spControllers[i].text = values[i];
        } else {
          spControllers.add(TextEditingController(text: values[i]));
        }
      }
    }

    final rawImages = d['installation_images'] ?? d['installationImages'];
    if (rawImages is List) {
      existingInstallationImages = rawImages
          .map((item) {
            if (item is Map) {
              return (item['url'] ??
                      item['path'] ??
                      item['file'] ??
                      item.toString())
                  .toString();
            }
            return item?.toString() ?? '';
          })
          .where((path) => path.trim().isNotEmpty)
          .toList();
    }
  }

  @override
  void dispose() {
    fileNo.dispose();
    capacity.dispose();
    panelBrand.dispose();
    panelCount.dispose();
    invoiceNo.dispose();

    inverterSerialNumber.dispose();
    batterySerialNumber.dispose();

    dcrCertificateNo.dispose();
    applicationNo.dispose();

    for (final controller in spControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _addSpField() {
    setState(() {
      spControllers.add(TextEditingController());
    });
  }

  void _removeSpField(int index) {
    if (spControllers.length <= 1) return;

    setState(() {
      final controller = spControllers.removeAt(index);
      controller.dispose();
    });
  }

  bool _materialRequiredMissing() {
    return [
      fileNo,
      capacity,
      panelBrand,
      panelCount,
      dcrCertificateNo,
      applicationNo,
    ].any((controller) => controller.text.trim().isEmpty);
  }

  bool get _hasAnyInstallationImages =>
      selectedInstallationImages.isNotEmpty ||
      existingInstallationImages.isNotEmpty;

  Future<void> _save({bool markAsDone = false}) async {
    FocusScope.of(context).unfocus();

    if (widget.materialOnly) {
      if (_materialRequiredMissing()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')),
        );
        return;
      }

      final panelCountValue = int.tryParse(panelCount.text.trim());

      if (panelCountValue == null || panelCountValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number of panels'),
          ),
        );
        return;
      }

      final spNumbers = spControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (spNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one SP number')),
        );
        return;
      }

      await _persist({
        'file_no': fileNo.text.trim(),
        'panel_capacity': capacity.text.trim(),
        'capacity': capacity.text.trim(),
        'solar_panel_brand': panelBrand.text.trim(),
        'number_of_solar_panels': panelCountValue,
        'invoice_no': invoiceNo.text.trim(),
        'panel_type': panelType,
        'dcr_certificate_no': dcrCertificateNo.text.trim(),
        'application_no': applicationNo.text.trim(),
        'sp_numbers': spNumbers,
      });
      return;
    }

    // Electrical Engineer: photos-only UI. Preserve material fields in payload.
    if (_materialRequiredMissing()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Material details are incomplete. Ask Material Engineer to fill them first.',
          ),
        ),
      );
      return;
    }

    if (!_hasAnyInstallationImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one installation photo'),
        ),
      );
      return;
    }

    final panelCountValue = int.tryParse(panelCount.text.trim()) ?? 0;
    final spNumbers = spControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    // Do NOT send installation_status: Completed — that jumps to Installation Done.
    await _persist({
      'file_no': fileNo.text.trim(),
      'panel_capacity': capacity.text.trim(),
      'capacity': capacity.text.trim(),
      'solar_panel_brand': panelBrand.text.trim(),
      'number_of_solar_panels': panelCountValue,
      'invoice_no': invoiceNo.text.trim(),
      'panel_type': panelType,
      'inverter_serial_number': inverterSerialNumber.text.trim(),
      'battery_serial_number': batterySerialNumber.text.trim(),
      'dcr_certificate_no': dcrCertificateNo.text.trim(),
      'application_no': applicationNo.text.trim(),
      'sp_numbers': spNumbers,
      'installation_status': 'In Progress',
    }, markAsDone: markAsDone);
  }

  Future<void> _syncLeadStatusAfterSave({required bool markAsDone}) async {
    try {
      final repo = ref.read(leadRepositoryProvider);
      if (markAsDone) {
        await repo.updateLeadStatus(
          leadId: widget.lead.id,
          status: 'Installation Done',
          remarks: 'Installation completed via form.',
        );
        return;
      }
      if (widget.lead.status.trim() == 'Amount Received') {
        await repo.updateLeadStatus(
          leadId: widget.lead.id,
          status: 'Installation In Progress',
          remarks: 'Installation details filled, moving to in progress.',
        );
      }
    } catch (_) {
      // Match web: save still succeeds if auto-status patch is rejected.
    }
  }

  Future<void> _persist(
    Map<String, dynamic> body, {
    bool markAsDone = false,
  }) async {
    setState(() => loading = true);

    try {
      final repo = ref.read(installationRepositoryProvider);

      if (existingId != null && existingId!.isNotEmpty) {
        await repo.update(
          existingId!,
          body,
          installationImagePaths: selectedInstallationImages,
        );
      } else {
        await repo.createForLead(
          widget.lead.id,
          body,
          installationImagePaths: selectedInstallationImages,
        );
      }

      if (!mounted) return;

      await _syncLeadStatusAfterSave(markAsDone: markAsDone);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            markAsDone
                ? 'Lead sent to next step successfully'
                : widget.materialOnly
                    ? 'Material details saved successfully'
                    : 'Installation photos saved successfully',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));

      setState(() => loading = false);
    }
  }

  Future<void> _showImageSourceSheet() async {
    if (loading) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select one or more images'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    FocusScope.of(context).unfocus();

    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;

    setState(() {
      if (!selectedInstallationImages.contains(file.path)) {
        selectedInstallationImages = [...selectedInstallationImages, file.path];
      }
    });
  }

  Future<void> _pickFromGallery() async {
    FocusScope.of(context).unfocus();

    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (!mounted || files.isEmpty) return;

    setState(() {
      final next = [...selectedInstallationImages];
      for (final file in files) {
        if (!next.contains(file.path)) next.add(file.path);
      }
      selectedInstallationImages = next;
    });
  }

  void _removeSelectedImage(int index) {
    setState(() {
      selectedInstallationImages = [...selectedInstallationImages]
        ..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lead.fullName.trim().isEmpty
        ? 'Lead ${widget.lead.leadCode}'
        : widget.lead.fullName;
    final screenTitle =
        widget.materialOnly ? 'Material Details' : 'Installation Form';
    final saveLabel =
        widget.materialOnly ? 'Save Material Details' : 'Save Photos';

    return Scaffold(
      appBar: AppAppBar(title: screenTitle, subtitle: title),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md + 4),
        children: [
          if (widget.materialOnly) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            _sectionTitle('Basic Details'),
            _field('Inverter Serial No *', fileNo),
            _field('Inverter Panel Capacity *', capacity),
            _field('Inverter Solar Panel Brand *', panelBrand),
            _field(
              'Number of Panels *',
              panelCount,
              keyboard: TextInputType.number,
              digitsOnly: true,
            ),
            _field('Invoice No', invoiceNo),
            const SizedBox(height: 12),
            _sectionTitle('DCR / Non DCR Panel Subsidy'),
            _panelTypeDropdown(),
            _field('DCR Certificate No.', dcrCertificateNo),
            _field('Application No.', applicationNo),
            const SizedBox(height: 12),
            _spSection(editable: true),
          ] else ...[
            Text(
              'Installation Form',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload installation photos (required)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppSpacing.md + 4),
            _sectionTitle('Installation Photos *'),
            _installationPhotosUploader(),
            if (selectedInstallationImages.isNotEmpty ||
                existingInstallationImages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _installationPhotosPreview(),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: loading ? null : () => _save(),
              child: loading
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      saveLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (!widget.materialOnly) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: loading ? null : () => _save(markAsDone: true),
                child: const Text(
                  'Mark installation done',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _installationPhotosUploader() {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : _showImageSourceSheet,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: scheme.outlineVariant,
            radius: AppRadius.lg,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 36,
                  color: scheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Click to upload installation photos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Camera or gallery — PNG, JPG or WEBP\nSingle or multiple images',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: loading ? null : _pickFromCamera,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Camera'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: loading ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _installationPhotosPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected photos (${selectedInstallationImages.length + existingInstallationImages.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              selectedInstallationImages.length +
              existingInstallationImages.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final isLocal = index < selectedInstallationImages.length;
            final path = isLocal
                ? selectedInstallationImages[index]
                : existingInstallationImages[
                    index - selectedInstallationImages.length];

            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: isLocal
                      ? Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        )
                      : Image.network(
                          resolveUploadUrl(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: isLocal
                      ? Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: loading
                                ? null
                                : () => _removeSelectedImage(index),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _imageFallback() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
  }

  Widget _sectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
      ),
    );
  }

  Widget _panelTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      child: DropdownButtonFormField<String>(
        value: panelType,
        decoration: const InputDecoration(labelText: 'Panel Type *'),
        items: const [
          DropdownMenuItem(value: 'DCR', child: Text('DCR')),
          DropdownMenuItem(value: 'NON_DCR', child: Text('Non DCR')),
        ],
        onChanged: loading
            ? null
            : (value) {
                if (value == null) return;
                setState(() => panelType = value);
              },
      ),
    );
  }

  Widget _spSection({required bool editable}) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Solar Panel Serial Numbers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          for (int i = 0; i < spControllers.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'S.P. No. ${i + 1}',
                    spControllers[i],
                    bottom: 10,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconButton(
                    onPressed: loading || spControllers.length <= 1
                        ? null
                        : () => _removeSpField(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: loading ? null : _addSpField,
            icon: const Icon(Icons.add),
            label: const Text('Add More S.P. No.'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool digitsOnly = false,
    double bottom = 14,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: TextField(
        controller: controller,
        enabled: !loading,
        keyboardType: keyboard,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

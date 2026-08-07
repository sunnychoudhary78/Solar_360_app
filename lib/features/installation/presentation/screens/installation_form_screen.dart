import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/installation/presentation/providers/installation_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
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
  List<String> selectedInstallationImages = [];

  bool loading = false;
  String? existingId;
  String panelType = 'DCR';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final d = widget.lead.installationDetails;
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
      for (final controller in spControllers) {
        controller.dispose();
      }

      spControllers.clear();

      for (final item in rawSpNumbers) {
        spControllers.add(TextEditingController(text: item?.toString() ?? ''));
      }
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

  bool _requiredMissing() {
    return [
      fileNo,
      capacity,
      panelBrand,
      panelCount,
      dcrCertificateNo,
      applicationNo,
    ].any((controller) => controller.text.trim().isEmpty);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_requiredMissing()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final panelCountValue = int.tryParse(panelCount.text.trim());

    if (panelCountValue == null || panelCountValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of panels')),
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

    final body = {
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
    };
    if (!widget.materialOnly) {
      body['installation_status'] = 'Completed';
    }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.materialOnly
                ? 'Material details saved successfully'
                : 'Installation details saved successfully',
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

  Future<void> _pickInstallationImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (!mounted || result == null) return;

    setState(() {
      selectedInstallationImages = result.files
          .map((file) => file.path ?? '')
          .where((path) => path.trim().isNotEmpty)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lead.fullName.trim().isEmpty
        ? 'Lead ${widget.lead.leadCode}'
        : widget.lead.fullName;
    final screenTitle = widget.materialOnly
        ? 'Material Details'
        : 'Installation Details';
    final saveLabel = widget.materialOnly
        ? 'Save Material Details'
        : 'Save Installation Details';

    return Scaffold(
      appBar: AppAppBar(title: screenTitle, subtitle: title),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md + 4),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md + 4),

          _sectionTitle('Basic Details'),
          _field('File No *', fileNo),
          _field('Panel Capacity *', capacity),
          _field('Solar Panel Brand *', panelBrand),
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

          if (!widget.materialOnly) ...[
            _sectionTitle('Installation Serial Numbers'),
            _field('Inverter Serial Number', inverterSerialNumber),
            _field('Battery Serial Number', batterySerialNumber),
          ],
          _spSection(),
          if (!widget.materialOnly) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: loading ? null : _pickInstallationImages,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Add installation images'),
              ),
            ),
            if (selectedInstallationImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...selectedInstallationImages.map(
                (path) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(path.split('\\').last.split('/').last),
                ),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: loading ? null : _save,
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
        ],
      ),
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

  Widget _spSection() {
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

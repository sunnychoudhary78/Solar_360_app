import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leads/models/lead_model.dart';
import '../providers/installation_provider.dart';

class InstallationFormScreen extends ConsumerStatefulWidget {
  final LeadModel lead;

  const InstallationFormScreen({
    super.key,
    required this.lead,
  });

  @override
  ConsumerState<InstallationFormScreen> createState() =>
      _InstallationFormScreenState();
}

class _InstallationFormScreenState
    extends ConsumerState<InstallationFormScreen> {
  static const primaryColor = Color(0xFF5663A0);
  static const bgColor = Color(0xFFF7F8FC);
  static const fieldColor = Color(0xFFFAF8FF);
  static const textColor = Color(0xFF1F2028);

  final fileNo = TextEditingController();
  final capacity = TextEditingController();
  final panelBrand = TextEditingController();
  final panelCount = TextEditingController();
  final invoiceNo = TextEditingController();

  final inverterSerialNumber = TextEditingController();
  final batterySerialNumber = TextEditingController();

  final dcrCertificateNo = TextEditingController();
  final applicationNo = TextEditingController();

  final List<TextEditingController> spControllers = [
    TextEditingController(),
  ];

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
    capacity.text = d['capacity']?.toString() ?? '';
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
        spControllers.add(
          TextEditingController(text: item?.toString() ?? ''),
        );
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
      invoiceNo,
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

    final body = {
      'file_no': fileNo.text.trim(),
      'capacity': capacity.text.trim(),
      'solar_panel_brand': panelBrand.text.trim(),
      'number_of_solar_panels': panelCountValue,
      'invoice_no': invoiceNo.text.trim(),
      'panel_type': panelType,

      // Backend uses this value to auto-update lead status:
      // Installation In Progress -> Installation Done -> Support
      'installation_status': 'Completed',

      'inverter_serial_number': inverterSerialNumber.text.trim(),
      'battery_serial_number': batterySerialNumber.text.trim(),
      'dcr_certificate_no': dcrCertificateNo.text.trim(),
      'application_no': applicationNo.text.trim(),
      'sp_numbers': spNumbers,
    };

    setState(() => loading = true);

    try {
      final repo = ref.read(installationRepositoryProvider);

      if (existingId != null && existingId!.isNotEmpty) {
        await repo.update(existingId!, body);
      } else {
        await repo.createForLead(widget.lead.id, body);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installation details saved successfully'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );

      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lead.fullName.trim().isEmpty
        ? 'Lead ${widget.lead.leadCode}'
        : widget.lead.fullName;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Installation Details'),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('Basic Details'),
          _field('File No *', fileNo),
          _field('Capacity *', capacity),
          _field('Solar Panel Brand *', panelBrand),
          _field(
            'Number of Panels *',
            panelCount,
            keyboard: TextInputType.number,
            digitsOnly: true,
          ),
          _field('Invoice No *', invoiceNo),

          const SizedBox(height: 12),

          _sectionTitle('DCR / Non DCR Panel Subsidy'),
          _panelTypeDropdown(),
          _field('DCR Certificate No.', dcrCertificateNo),
          _field('Application No.', applicationNo),

          const SizedBox(height: 12),

          _sectionTitle('Installation Serial Numbers'),
          _field('Inverter Serial Number', inverterSerialNumber),
          _field('Battery Serial Number', batterySerialNumber),
          _spSection(),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Save Installation Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _panelTypeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: panelType,
        decoration: InputDecoration(
          labelText: 'Panel Type *',
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'DCR',
            child: Text('DCR'),
          ),
          DropdownMenuItem(
            value: 'NON_DCR',
            child: Text('Non DCR'),
          ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solar Panel Serial Numbers',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
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
        inputFormatters:
            digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
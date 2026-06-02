import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leads/models/lead_model.dart';
import '../providers/installation_provider.dart';

class InstallationFormScreen extends ConsumerStatefulWidget {
  final LeadModel lead;

  const InstallationFormScreen({super.key, required this.lead});

  @override
  ConsumerState<InstallationFormScreen> createState() =>
      _InstallationFormScreenState();
}

class _InstallationFormScreenState
    extends ConsumerState<InstallationFormScreen> {
  static const primaryColor = Color(0xFF5663A0);

  final fileNo = TextEditingController();
  final capacity = TextEditingController();
  final panelBrand = TextEditingController();
  final panelCount = TextEditingController();
  final invoiceNo = TextEditingController();

  final dcrCertificateNo = TextEditingController();
  final applicationNo = TextEditingController();
  final stampPaperRs100 = TextEditingController();

  final centralGovtSubsidyDate = TextEditingController();
  final stateGovtSubsidyDate = TextEditingController();
  final installNetMeterDate = TextEditingController();
  final inspectDiscomDate = TextEditingController();

  final spNo1 = TextEditingController();
  final spNo2 = TextEditingController();
  final spNo3 = TextEditingController();
  final spNo4 = TextEditingController();
  final spNo5 = TextEditingController();

  bool loading = false;
  String? existingId;

  int selectedSpCount = 1;

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
    panelCount.text = d['number_of_solar_panel']?.toString() ?? '';
    invoiceNo.text = d['invoice_no']?.toString() ?? '';

    dcrCertificateNo.text = d['dcr_certificate_no']?.toString() ?? '';
    applicationNo.text = d['application_no']?.toString() ?? '';
    stampPaperRs100.text = d['stamp_paper_rs_100']?.toString() ?? '';

    centralGovtSubsidyDate.text =
        _dateOnly(d['central_govt_subsidy_date']?.toString());
    stateGovtSubsidyDate.text =
        _dateOnly(d['state_govt_subsidy_date']?.toString());
    installNetMeterDate.text =
        _dateOnly(d['install_net_meter_date']?.toString());
    inspectDiscomDate.text =
        _dateOnly(d['inspect_discom_date']?.toString());

    spNo1.text = d['sp_no_1']?.toString() ?? '';
    spNo2.text = d['sp_no_2']?.toString() ?? '';
    spNo3.text = d['sp_no_3']?.toString() ?? '';
    spNo4.text = d['sp_no_4']?.toString() ?? '';
    spNo5.text = d['sp_no_5']?.toString() ?? '';

    final filled = [spNo1, spNo2, spNo3, spNo4, spNo5]
        .where((c) => c.text.trim().isNotEmpty)
        .length;

    if (filled > 0) selectedSpCount = filled;
  }

  String _dateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return value.split('T').first;
  }

  @override
  void dispose() {
    fileNo.dispose();
    capacity.dispose();
    panelBrand.dispose();
    panelCount.dispose();
    invoiceNo.dispose();

    dcrCertificateNo.dispose();
    applicationNo.dispose();
    stampPaperRs100.dispose();

    centralGovtSubsidyDate.dispose();
    stateGovtSubsidyDate.dispose();
    installNetMeterDate.dispose();
    inspectDiscomDate.dispose();

    spNo1.dispose();
    spNo2.dispose();
    spNo3.dispose();
    spNo4.dispose();
    spNo5.dispose();

    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');

    setState(() {
      controller.text = '${picked.year}-$month-$day';
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if ([fileNo, capacity, panelBrand, panelCount, invoiceNo]
        .any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final body = {
      'file_no': fileNo.text.trim(),
      'capacity': capacity.text.trim(),
      'solar_panel_brand': panelBrand.text.trim(),
      'number_of_solar_panel': panelCount.text.trim(),
      'invoice_no': invoiceNo.text.trim(),

      'dcr_certificate_no': dcrCertificateNo.text.trim(),
      'application_no': applicationNo.text.trim(),
      'stamp_paper_rs_100': stampPaperRs100.text.trim(),

      'central_govt_subsidy_date': centralGovtSubsidyDate.text.trim(),
      'state_govt_subsidy_date': stateGovtSubsidyDate.text.trim(),

      'sp_no_1': spNo1.text.trim(),
      'sp_no_2': spNo2.text.trim(),
      'sp_no_3': spNo3.text.trim(),
      'sp_no_4': spNo4.text.trim(),
      'sp_no_5': spNo5.text.trim(),

      'install_net_meter_date': installNetMeterDate.text.trim(),
      'inspect_discom_date': inspectDiscomDate.text.trim(),
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
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Installation Details'),
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: const Color(0xFF1F2028),
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
          _sectionTitle('DCR Panel Subsidy'),
          _field('DCR Certificate No.', dcrCertificateNo),
          _field('Application No.', applicationNo),
          _field('Stamp Paper Rs.100', stampPaperRs100),
          _dateField('Central Govt Subsidy Date', centralGovtSubsidyDate),
          _dateField('State Govt Subsidy Date', stateGovtSubsidyDate),

          const SizedBox(height: 12),
          _spSection(),

          const SizedBox(height: 12),
          _sectionTitle('Meter / DISCOM'),
          _dateField('Install Net Meter Date', installNetMeterDate),
          _dateField('Inspect of DISCOM Date', inspectDiscomDate),

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
          color: Color(0xFF1F2028),
        ),
      ),
    );
  }

  Widget _spSection() {
    final controllers = [spNo1, spNo2, spNo3, spNo4, spNo5];

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
              color: Color(0xFF1F2028),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedSpCount,
                  decoration: InputDecoration(
                    labelText: 'How many S.P. No?',
                    filled: true,
                    fillColor: const Color(0xFFFAF8FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 S.P. No')),
                    DropdownMenuItem(value: 2, child: Text('2 S.P. No')),
                    DropdownMenuItem(value: 3, child: Text('3 S.P. No')),
                    DropdownMenuItem(value: 4, child: Text('4 S.P. No')),
                    DropdownMenuItem(value: 5, child: Text('5 S.P. No')),
                  ],
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            selectedSpCount = value;
                            for (int i = value; i < controllers.length; i++) {
                              controllers[i].clear();
                            }
                          });
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < selectedSpCount; i++)
            _field('S.P. No. ${i + 1}', controllers[i]),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool digitsOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !loading,
        keyboardType: keyboard,
        inputFormatters:
            digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAF8FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !loading,
        readOnly: true,
        onTap: loading ? null : () => _pickDate(controller),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          filled: true,
          fillColor: const Color(0xFFFAF8FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
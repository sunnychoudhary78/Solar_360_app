import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
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

  bool loading = false;
  String? existingId;

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
  }

  @override
  void dispose() {
    fileNo.dispose();
    capacity.dispose();
    panelBrand.dispose();
    panelCount.dispose();
    invoiceNo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    };

    setState(() => loading = true);
    try {
      final repo = ref.read(installationRepositoryProvider);
      if (existingId != null && existingId!.isNotEmpty) {
        await repo.update(existingId!, body);
      } else {
        await repo.createForLead(widget.lead.id, body);
      }
      ref.invalidate(allLeadsProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            widget.lead.fullName.isEmpty
                ? 'Lead ${widget.lead.leadCode}'
                : widget.lead.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _field('File No *', fileNo),
          _field('Capacity *', capacity),
          _field('Solar Panel Brand *', panelBrand),
          _field('Number of Panels *', panelCount, keyboard: TextInputType.number),
          _field('Invoice No *', invoiceNo),
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
                  ? const CircularProgressIndicator(color: Colors.white)
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

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !loading,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFFAF8FF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

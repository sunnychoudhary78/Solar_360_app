import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/workflow/lead_workflow.dart';
import '../../auth/providers/auth_provider.dart';
import '../../installation/screens/installation_form_screen.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';
import '../utils/lead_files.dart';
import '../widgets/lead_attachments_view.dart';
import '../widgets/workflow_stepper.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  final LeadModel lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  static const primaryColor = Color(0xFF5663A0);
  late LeadModel _lead;
  bool loading = false;
  String? loadError;
  List<Map<String, dynamic>> history = [];
  List<String> allowedNext = [];

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final repo = ref.read(leadRepositoryProvider);
      final fresh = await repo.getLeadById(_lead.id);
      final hist = await repo.getLeadHistory(_lead.id);
      final next = await repo.getAllowedNextStatuses(_lead.id);
      if (mounted) {
        setState(() {
          _lead = fresh;
          history = hist;
          allowedNext = next;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loadError = e.toString());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> _resolveNextStatuses(String roleName) {
    if (allowedNext.isNotEmpty) return allowedNext;
    return LeadWorkflow.getAllowedNextStatuses(_lead.status, roleName);
  }

  Future<void> _advanceStatus(String nextStatus) async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update to "$nextStatus"?'),
        content: TextField(
          controller: remarksController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Remarks (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    setState(() => loading = true);
    try {
      await ref.read(leadRepositoryProvider).updateLeadStatus(
            leadId: _lead.id,
            status: nextStatus,
            remarks: remarksController.text.trim(),
          );
      ref.invalidate(allLeadsProvider);
      remarksController.dispose();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $nextStatus')),
      );
    } catch (e) {
      remarksController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveRegistration() async {
    final regId = TextEditingController(text: _lead.registrationId);
    final regDate = TextEditingController(text: _lead.registrationDate);
    final regTime = TextEditingController(text: _lead.registrationTime);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: regId,
              decoration: const InputDecoration(labelText: 'Registration ID'),
            ),
            TextField(
              controller: regDate,
              decoration: const InputDecoration(labelText: 'Registration Date'),
            ),
            TextField(
              controller: regTime,
              decoration: const InputDecoration(labelText: 'Registration Time'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final idVal = regId.text.trim();
    final dateVal = regDate.text.trim();
    final timeVal = regTime.text.trim();
    regId.dispose();
    regDate.dispose();
    regTime.dispose();

    if (saved != true) return;

    try {
      await ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'registration_id': idVal,
        'registration_date': dateVal,
        'registration_time': timeVal,
      });
      ref.invalidate(allLeadsProvider);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final roleName = auth.user?.roleName ?? '';
    final nextStatuses = _resolveNextStatuses(roleName);
    final files = collectLeadFiles(_lead);
    final customerName =
        _lead.fullName.trim().isEmpty ? 'Customer' : _lead.fullName;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2028),
        title: Text(
          customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading && history.isEmpty && loadError == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(loadError!),
                  ),
                _headerCard(customerName),
                const SizedBox(height: 14),
                WorkflowStepper(currentStatus: _lead.status),
                const SizedBox(height: 14),
                if (auth.appRole == 'installation') ...[
                  OutlinedButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InstallationFormScreen(lead: _lead),
                              ),
                            );
                            if (ok == true) _load();
                          },
                    icon: const Icon(Icons.build_circle_outlined),
                    label: Text(
                      _lead.hasInstallationDetails
                          ? 'Edit Installation Details'
                          : 'Fill Installation Details (required)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (auth.appRole == 'support' &&
                    !_lead.hasRegistrationDetails) ...[
                  OutlinedButton(
                    onPressed: _saveRegistration,
                    child: const Text('Add registration details'),
                  ),
                  const SizedBox(height: 12),
                ],
                _section('Customer Details', [
                  _row('Full Name', _lead.fullName),
                  _row('Lead Code', _lead.leadCode),
                  _row('Mobile', _lead.mobile),
                  _row('Email', _lead.email),
                  _row('Address', _lead.address),
                  _row('City', _lead.city),
                  _row('State', _lead.state),
                  _row('Pincode', _lead.pincode),
                ]),
                _section('Workflow', [
                  _row('Status', _lead.status),
                  _row('Department', _lead.currentDepartment),
                  _row('Stage', _lead.leadStage),
                  _row('Priority', _lead.priority),
                  _row('Workflow Step', _lead.workflowStep),
                ]),
                _section('Connection & Bank', [
                  _row('CA Number', _lead.caNumber),
                  _row('K Number', _lead.kNumber),
                  _row('Discom', _lead.discom),
                  _row('Bank', _lead.bankName),
                  _row('Account', _lead.accountNumber),
                  _row('IFSC', _lead.ifscCode),
                ]),
                _section('Uploaded Files & Images', [
                  LeadAttachmentsView(files: files),
                ]),
                if (_lead.notes.isNotEmpty)
                  _section('Notes', [_row('Notes', _lead.notes)]),
                if (nextStatuses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Status actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...nextStatuses.map((status) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () => _advanceStatus(status),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            LeadWorkflow.nextActionLabel(status),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Status history',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const Text(
                    'No history yet',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...history.map(_historyTile),
              ],
            ),
    );
  }

  Widget _headerCard(String customerName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5663A0), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lead.status.isEmpty ? 'No status' : _lead.status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _lead.currentDepartment.isEmpty
                ? 'Department pending'
                : 'Department: ${_lead.currentDepartment}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> h) {
    final status = h['new_status']?.toString() ??
        h['status']?.toString() ??
        'Update';
    final old = h['old_status']?.toString();
    final remarks =
        h['remarks']?.toString() ?? h['notes']?.toString() ?? '';
    final when = h['created_at']?.toString() ?? '';
    final user = h['user'] is Map
        ? (h['user'] as Map)['name']?.toString()
        : h['user_name']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha: 0.12),
          child: const Icon(Icons.history, color: primaryColor, size: 20),
        ),
        title: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (old != null && old.isNotEmpty)
              Text('From: $old', style: const TextStyle(fontSize: 12)),
            if (remarks.isNotEmpty) Text(remarks),
            if (user != null && user.isNotEmpty)
              Text('By: $user', style: const TextStyle(fontSize: 11)),
            if (when.isNotEmpty)
              Text(when, style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

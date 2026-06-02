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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      await _fetchFreshData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
      });
    }
  }

  Future<void> _reloadSilently() async {
    try {
      await _fetchFreshData();
    } catch (e) {
      debugPrint('Silent reload failed: $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _fetchFreshData() async {
    final repo = ref.read(leadRepositoryProvider);

    final fresh = await repo.getLeadById(_lead.id);
    final hist = await repo.getLeadHistory(_lead.id);
    final next = await repo.getAllowedNextStatuses(_lead.id);

    if (!mounted) return;

    setState(() {
      _lead = fresh;
      history = hist;
      allowedNext = next;
      loading = false;
      loadError = null;
    });
  }

  List<String> _resolveNextStatuses(String roleName) {
    final localAllowed = LeadWorkflow.getAllowedNextStatuses(
      _lead.status,
      roleName,
    );

    if (allowedNext.isEmpty) return localAllowed;

    final matched = allowedNext.where(localAllowed.contains).toList();
    return matched.isNotEmpty ? matched : localAllowed;
  }

  Future<void> _advanceStatus(String nextStatus) async {
    if (loading) return;

    final remarks = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _StatusRemarksDialog(nextStatus: nextStatus);
      },
    );

    if (remarks == null || !mounted) return;

    setState(() => loading = true);

    try {
      await ref.read(leadRepositoryProvider).updateLeadStatus(
            leadId: _lead.id,
            status: nextStatus,
            remarks: remarks,
          );

      if (!mounted) return;

      await _reloadSilently();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $nextStatus')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _saveRegistration() async {
    if (loading) return;

    final result = await showDialog<_RegistrationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RegistrationDialog(
        initialRegId: _lead.registrationId,
        initialRegDate: _lead.registrationDate,
        initialRegTime: _lead.registrationTime,
      ),
    );

    if (result == null || !mounted) return;

    if (result.regDate.trim().isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select registration date')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'registration_id': result.regId,
        'registration_date': result.regDate,
        'registration_time': result.regTime,
      });

      if (!mounted) return;

      await _reloadSilently();

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration details saved')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openInstallationForm() async {
    if (loading) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InstallationFormScreen(lead: _lead),
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => loading = true);

    await _reloadSilently();

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Installation details saved')),
    );
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
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
                  WorkflowStepper(
                    currentStatus: _lead.status.trim().isNotEmpty
                        ? _lead.status
                        : _lead.workflowStep,
                  ),
                  const SizedBox(height: 14),
                  if (auth.appRole == 'installation') ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : _openInstallationForm,
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
                      onPressed: loading ? null : _saveRegistration,
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
                  if (_lead.hasRegistrationDetails)
                    _section('Registration', [
                      _row('Registration ID', _lead.registrationId),
                      _row('Registration Date', _lead.registrationDate),
                      _row('Registration Time', _lead.registrationTime),
                    ]),
                  if (_lead.hasInstallationDetails)
  _section('Installation Details', [
    _row('File No', _installationValue('file_no')),
    _row('Capacity', _installationValue('capacity')),

    _row(
      'DCR Certificate No',
      _installationValue('dcr_certificate_no'),
    ),

    _row(
      'Application No',
      _installationValue('application_no'),
    ),

    _row(
      'Stamp Paper Rs.100',
      _installationValue('stamp_paper_rs_100'),
    ),

    _row(
      'Central Govt Subsidy Date',
      _installationValue('central_govt_subsidy_date'),
    ),

    _row(
      'State Govt Subsidy Date',
      _installationValue('state_govt_subsidy_date'),
    ),

    _row(
      'Solar Panel Brand',
      _installationValue('solar_panel_brand'),
    ),

    _row(
      'No. Of Solar Panels',
      _installationValue('number_of_solar_panel'),
    ),

    _row(
      'Install Net Meter Date',
      _installationValue('install_net_meter_date'),
    ),

    _row(
      'Inspect DISCOM Date',
      _installationValue('inspect_discom_date'),
    ),

    _row(
      'Invoice No',
      _installationValue('invoice_no'),
    ),

    const Divider(),

    _row('S.P. No. 1', _installationValue('sp_no_1')),
    _row('S.P. No. 2', _installationValue('sp_no_2')),
    _row('S.P. No. 3', _installationValue('sp_no_3')),
    _row('S.P. No. 4', _installationValue('sp_no_4')),
    _row('S.P. No. 5', _installationValue('sp_no_5')),
  ]),
                  _section('Uploaded Files & Images', [
                    LeadAttachmentsView(files: files),
                  ]),
                  if (_lead.notes.trim().isNotEmpty)
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
                            onPressed:
                                loading ? null : () => _advanceStatus(status),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              nextStatuses.length == 1
                                  ? LeadWorkflow.nextActionLabel(_lead.status)
                                  : status,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Status history',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            ),
    );
  }

  String _installationValue(String key) {
    final d = _lead.installationDetails;
    if (d == null) return '';
    return d[key]?.toString() ?? '';
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
    final status =
        h['new_status']?.toString() ?? h['status']?.toString() ?? 'Update';

    final old = h['old_status']?.toString();
    final remarks = h['remarks']?.toString() ?? h['notes']?.toString() ?? '';
    final when = h['created_at']?.toString() ?? '';

    final user = h['user'] is Map
        ? (h['user'] as Map)['name']?.toString()
        : h['user_name']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.12),
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
              Text(
                when,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final visibleChildren =
        children.where((child) => child is! SizedBox).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

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
          ...visibleChildren,
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
            width: 125,
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

/// Owns [TextEditingController] lifecycle so it is not disposed while the route pops.
class _StatusRemarksDialog extends StatefulWidget {
  final String nextStatus;

  const _StatusRemarksDialog({required this.nextStatus});

  @override
  State<_StatusRemarksDialog> createState() => _StatusRemarksDialogState();
}

class _StatusRemarksDialogState extends State<_StatusRemarksDialog> {
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_remarksController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Update to "${widget.nextStatus}"?'),
      content: TextField(
        controller: _remarksController,
        maxLines: 3,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Remarks / Comment',
          hintText: 'Add a note for this status change (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _LeadDetailScreenState.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _RegistrationResult {
  final String regId;
  final String regDate;
  final String regTime;

  const _RegistrationResult({
    required this.regId,
    required this.regDate,
    required this.regTime,
  });
}

class _RegistrationDialog extends StatefulWidget {
  final String initialRegId;
  final String initialRegDate;
  final String initialRegTime;

  const _RegistrationDialog({
    required this.initialRegId,
    required this.initialRegDate,
    required this.initialRegTime,
  });

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  late final TextEditingController regIdController;
  late final TextEditingController regDateController;

  String selectedHour = '1';
  String selectedMinute = '00';
  String selectedPeriod = 'AM';

  @override
  void initState() {
    super.initState();

    regIdController = TextEditingController(text: widget.initialRegId);
    regDateController = TextEditingController(text: widget.initialRegDate);

    final oldTime = widget.initialRegTime.trim();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(oldTime);

    if (match != null) {
      selectedHour = match.group(1)!;
      selectedMinute = match.group(2)!;
      selectedPeriod = match.group(3)!.toUpperCase();
    }
  }

  @override
  void dispose() {
    regIdController.dispose();
    regDateController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || picked == null) return;

    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      regDateController.text = formatted;
    });
  }

  void save() {
    Navigator.of(context).pop(
      _RegistrationResult(
        regId: regIdController.text.trim(),
        regDate: regDateController.text.trim(),
        regTime: '$selectedHour:$selectedMinute $selectedPeriod',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registration details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: regIdController,
              decoration: const InputDecoration(
                labelText: 'Registration ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: regDateController,
              readOnly: true,
              onTap: pickDate,
              decoration: InputDecoration(
                labelText: 'Registration Date',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: pickDate,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedHour,
                    decoration: const InputDecoration(
                      labelText: 'Hour',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (i) {
                      final v = '${i + 1}';
                      return DropdownMenuItem(value: v, child: Text(v));
                    }),
                    onChanged: (v) {
                      if (v == null || !mounted) return;
                      setState(() => selectedHour = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMinute,
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(60, (i) {
                      final v = i.toString().padLeft(2, '0');
                      return DropdownMenuItem(value: v, child: Text(v));
                    }),
                    onChanged: (v) {
                      if (v == null || !mounted) return;
                      setState(() => selectedMinute = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'AM/PM',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AM', child: Text('AM')),
                      DropdownMenuItem(value: 'PM', child: Text('PM')),
                    ],
                    onChanged: (v) {
                      if (v == null || !mounted) return;
                      setState(() => selectedPeriod = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
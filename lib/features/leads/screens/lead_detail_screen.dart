import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_message.dart';
import '../../../core/workflow/lead_workflow.dart';
import '../screens/lead_form_screen.dart';
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

  Map<String, String> _registrationFromNotes() {
    final match = RegExp(
      r'\[REGISTRATION_DETAILS\]([\s\S]*?)\[/REGISTRATION_DETAILS\]',
      multiLine: true,
    ).firstMatch(_lead.notes);

    if (match == null) return {};

    final block = match.group(1) ?? '';
    final data = <String, String>{};

    for (final line in block.split('\n')) {
      final index = line.indexOf('=');
      if (index <= 0) continue;

      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1).trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        data[key] = value;
      }
    }

    return data;
  }

  String _removeOldRegistrationBlock(String notes) {
    return notes
        .replaceAll(
          RegExp(
            r'\[REGISTRATION_DETAILS\][\s\S]*?\[/REGISTRATION_DETAILS\]',
            multiLine: true,
          ),
          '',
        )
        .trim();
  }

  String _visibleNotes() {
    return _removeOldRegistrationBlock(_lead.notes);
  }

  String get _displayRegistrationId {
    if (_lead.registrationId.trim().isNotEmpty) return _lead.registrationId;
    return _registrationFromNotes()['registration_id'] ?? '';
  }

  String get _displayRegistrationDate {
    if (_lead.registrationDate.trim().isNotEmpty) {
      return _lead.registrationDate;
    }
    return _registrationFromNotes()['registration_date'] ?? '';
  }

  String get _displayRegistrationTime {
    if (_lead.registrationTime.trim().isNotEmpty) {
      return _lead.registrationTime;
    }
    return _registrationFromNotes()['registration_time'] ?? '';
  }

  bool get _hasRegistrationDetailsFrontend {
    return _displayRegistrationId.trim().isNotEmpty &&
        _displayRegistrationDate.trim().isNotEmpty &&
        _displayRegistrationTime.trim().isNotEmpty;
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

  bool _canUploadDocuments(List<String> nextStatuses) {
    final status = _lead.status.trim().toLowerCase();

    return status == 'loan application initiated' ||
        status == 'documents submitted' ||
        nextStatuses.contains('Documents Submitted');
  }

  Future<void> _advanceStatus(String nextStatus) async {
    if (loading) return;

    if (nextStatus == 'Documents Submitted' &&
        !_hasRegistrationDetailsFrontend) {
      showAppMessage(
        context,
        'Please add registration details first',
        isError: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      await ref.read(leadRepositoryProvider).updateLeadStatus(
            leadId: _lead.id,
            status: nextStatus,
          );

      if (!mounted) return;

      setState(() {
        _lead = _lead.copyWith(status: nextStatus);
        allowedNext = [];
      });
      ref.invalidate(allLeadsProvider);

      await _reloadSilently();

      if (!mounted) return;

      showAppMessage(context, 'Status updated to $nextStatus');
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _addNote() async {
    if (loading) return;

    final note = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddNoteDialog(),
    );

    if (note == null || note.trim().isEmpty || !mounted) return;

    setState(() => loading = true);

    try {
      final oldNotes = _lead.notes.trim();
      final updatedNotes =
          oldNotes.isEmpty ? note.trim() : '$oldNotes\n\n${note.trim()}';

      await ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'notes': updatedNotes,
      });

      if (!mounted) return;

      await _reloadSilently();

      if (!mounted) return;

      showAppMessage(context, 'Note added successfully');
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _uploadDocuments() async {
    if (loading) return;

    final result = await showDialog<_UploadDocumentsResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UploadDocumentsDialog(),
    );

    if (result == null || !mounted) return;

    if (result.images.isEmpty && result.documents.isEmpty) {
      showAppMessage(context, 'Please add at least one file', isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      await ref.read(leadRepositoryProvider).uploadLeadDocuments(
            leadId: _lead.id,
            additionalImageEntries:
                result.images.map((item) => item.toPayload()).toList(),
            additionalDocumentEntries:
                result.documents.map((item) => item.toPayload()).toList(),
          );

      if (!mounted) return;

      await _reloadSilently();

      if (!mounted) return;

      showAppMessage(context, 'Documents uploaded successfully');
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _saveRegistration() async {
    if (loading) return;

    final result = await showDialog<_RegistrationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RegistrationDialog(
        initialRegId: _displayRegistrationId,
        initialRegDate: _displayRegistrationDate,
        initialRegTime: _displayRegistrationTime,
      ),
    );

    if (result == null || !mounted) return;

    if (result.regId.trim().isEmpty ||
        result.regDate.trim().isEmpty ||
        result.regTime.trim().isEmpty) {
      showAppMessage(
        context,
        'Please fill all registration details',
        isError: true,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final oldNotes = _removeOldRegistrationBlock(_lead.notes);

      final registrationBlock = '''
[REGISTRATION_DETAILS]
registration_id=${result.regId.trim()}
registration_date=${result.regDate.trim()}
registration_time=${result.regTime.trim()}
[/REGISTRATION_DETAILS]
''';

      final updatedNotes = oldNotes.trim().isEmpty
          ? registrationBlock.trim()
          : '${oldNotes.trim()}\n\n${registrationBlock.trim()}';

      await ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'registration_id': result.regId.trim(),
        'registration_date': result.regDate.trim(),
        'registration_time': result.regTime.trim(),
        'notes': updatedNotes,
      });

      if (!mounted) return;

      await _reloadSilently();

      if (!mounted) return;

      showAppMessage(context, 'Registration details saved');
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _openCompleteLeadForm() async {
    if (loading) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(
          mode: LeadFormMode.completeDetails,
          existingLead: _lead,
        ),
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => loading = true);
    await _reloadSilently();

    if (!mounted) return;
    showAppMessage(context, 'Lead details saved successfully');
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
    showAppMessage(context, 'Installation details saved');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final roleName = auth.user?.roleName ?? '';
    final nextStatuses = _resolveNextStatuses(roleName);
    final files = collectLeadFiles(_lead);
    final showUploadButton = _canUploadDocuments(nextStatuses);
    final customerName =
        _lead.fullName.trim().isEmpty ? 'Customer' : _lead.fullName;

    final visibleNotes = _visibleNotes();

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
                      !_hasRegistrationDetailsFrontend) ...[
                    OutlinedButton(
                      onPressed: loading ? null : _saveRegistration,
                      child: const Text('Add registration details'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (auth.appRole == 'support' ||
                      (auth.appRole == 'sales' &&
                          LeadWorkflow.canSalesCompleteDetails(_lead.status))) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : _openCompleteLeadForm,
                        icon: const Icon(Icons.edit_document),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        label: Text(
                          auth.appRole == 'support'
                              ? 'Edit lead basic details'
                              : 'Complete remaining lead details',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
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
                    _row('KW', _lead.loadSectionKw),
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
                  if (_hasRegistrationDetailsFrontend)
                    _section('Registration', [
                      _row('Registration ID', _displayRegistrationId),
                      _row('Registration Date', _displayRegistrationDate),
                      _row('Registration Time', _displayRegistrationTime),
                    ]),
                  if (_hasRegistrationDetailsFrontend &&
                      auth.appRole == 'support') ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : _saveRegistration,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit registration details'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_lead.hasInstallationDetails)
                    _section('Installation Details', [
                      _row('File No', _installationValue('file_no')),
                      _row('Capacity', _installationValue('capacity')),
                      _row(
                        'DCR Certificate No',
                        _installationValue('dcr_certificate_no'),
                      ),
                      _row('Application No', _installationValue('application_no')),
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
                      _row('Invoice No', _installationValue('invoice_no')),
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
                  if (visibleNotes.trim().isNotEmpty)
                    _section('Notes', [_row('Notes', visibleNotes)]),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _addNote,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Add Note'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  if (showUploadButton) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : _uploadDocuments,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (nextStatuses.isNotEmpty) ...[
                    const SizedBox(height: 14),
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

class TitledLocalFile {
  final String title;
  final String path;

  const TitledLocalFile({
    required this.title,
    required this.path,
  });

  Map<String, String> toPayload() {
    return {
      'title': title.trim(),
      'path': path,
    };
  }

  TitledLocalFile copyWith({
    String? title,
    String? path,
  }) {
    return TitledLocalFile(
      title: title ?? this.title,
      path: path ?? this.path,
    );
  }
}

class _UploadDocumentsResult {
  final List<TitledLocalFile> images;
  final List<TitledLocalFile> documents;

  const _UploadDocumentsResult({
    required this.images,
    required this.documents,
  });
}

class _UploadDocumentsDialog extends StatefulWidget {
  const _UploadDocumentsDialog();

  @override
  State<_UploadDocumentsDialog> createState() => _UploadDocumentsDialogState();
}

class _UploadDocumentsDialogState extends State<_UploadDocumentsDialog> {
  static const primaryColor = _LeadDetailScreenState.primaryColor;
  static const bgColor = Color(0xFFF7F8FC);

  final ImagePicker _imagePicker = ImagePicker();

  final List<TitledLocalFile> additionalImages = [];
  final List<TitledLocalFile> additionalDocs = [];

  bool saving = false;

  bool _isImagePath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }

  bool _isPdfPath(String path) {
    return path.toLowerCase().endsWith('.pdf');
  }

  String _fileDisplayName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<String?> _pickSingleFile({required bool imageOnly}) async {
    FocusScope.of(context).unfocus();

    if (imageOnly) {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      return file?.path;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
    );

    return result?.files.single.path;
  }

  Future<void> _showAddTitledFileDialog({
    required String dialogTitle,
    required String titleLabel,
    required String uploadLabel,
    required String defaultTitlePrefix,
    required bool imageOnly,
    required List<TitledLocalFile> target,
  }) async {
    final titleController = TextEditingController(
      text: '$defaultTitlePrefix ${target.length + 1}',
    );

    String? selectedPath;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: titleLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final path =
                              await _pickSingleFile(imageOnly: imageOnly);

                          if (path == null) return;
                          if (!mounted) return;

                          setDialogState(() {
                            selectedPath = path;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE4E1EA),
                            ),
                          ),
                          child: selectedPath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      imageOnly
                                          ? Icons.add_photo_alternate_outlined
                                          : Icons.upload_file_outlined,
                                      color: primaryColor,
                                      size: 38,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(uploadLabel),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _isImagePath(selectedPath!)
                                      ? Image.file(
                                          File(selectedPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : _docPreview(selectedPath!),
                                ),
                        ),
                      ),
                      if (selectedPath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _fileDisplayName(selectedPath!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();

                    final title = titleController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$titleLabel is required')),
                      );
                      return;
                    }

                    if (selectedPath == null || selectedPath!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$uploadLabel is required')),
                      );
                      return;
                    }

                    setState(() {
                      target.add(
                        TitledLocalFile(
                          title: title,
                          path: selectedPath!,
                        ),
                      );
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _docPreview(String path) {
    final pdf = _isPdfPath(path);

    return Container(
      color: const Color(0xFFEEF0F8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 42,
              color: pdf ? Colors.red : primaryColor,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                _fileDisplayName(path),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _multiFilePicker({
    required String title,
    required List<TitledLocalFile> files,
    required VoidCallback onAdd,
    required void Function(int index) onRemove,
    required void Function(int index) onReplace,
    bool imagesOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${files.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2028),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onAdd,
                style: FilledButton.styleFrom(backgroundColor: primaryColor),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (files.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E1EA)),
              ),
              child: Text(
                imagesOnly ? 'No images added.' : 'No documents added.',
                style: const TextStyle(color: Colors.black45),
              ),
            ),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: files.asMap().entries.map((entry) {
                final item = entry.value;
                final idx = entry.key;
                final image = _isImagePath(item.path);

                return SizedBox(
                  width: 120,
                  height: 178,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 105,
                              width: 120,
                              child: image
                                  ? Image.file(
                                      File(item.path),
                                      fit: BoxFit.cover,
                                    )
                                  : _docPreview(item.path),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: saving ? null : () => onRemove(idx),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: TextButton(
                          onPressed: saving ? null : () => onReplace(idx),
                          child: const Text(
                            'Replace',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _replaceFileAt(
    List<TitledLocalFile> target,
    int index, {
    required bool imageOnly,
  }) async {
    final path = await _pickSingleFile(imageOnly: imageOnly);
    if (path == null) return;
    if (!mounted) return;

    setState(() {
      target[index] = target[index].copyWith(path: path);
    });
  }

  void _submit() {
    if (additionalImages.isEmpty && additionalDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one file')),
      );
      return;
    }

    Navigator.of(context).pop(
      _UploadDocumentsResult(
        images: List<TitledLocalFile>.from(additionalImages),
        documents: List<TitledLocalFile>.from(additionalDocs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Document'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _multiFilePicker(
                title: 'Images',
                files: additionalImages,
                imagesOnly: true,
                onAdd: () => _showAddTitledFileDialog(
                  dialogTitle: 'Add Image',
                  titleLabel: 'Image title',
                  uploadLabel: 'Choose Image',
                  defaultTitlePrefix: 'Image',
                  imageOnly: true,
                  target: additionalImages,
                ),
                onRemove: (i) => setState(() => additionalImages.removeAt(i)),
                onReplace: (i) =>
                    _replaceFileAt(additionalImages, i, imageOnly: true),
              ),
              _multiFilePicker(
                title: 'Documents',
                files: additionalDocs,
                imagesOnly: false,
                onAdd: () => _showAddTitledFileDialog(
                  dialogTitle: 'Add Document',
                  titleLabel: 'Document title',
                  uploadLabel: 'Choose File',
                  defaultTitlePrefix: 'Document',
                  imageOnly: false,
                  target: additionalDocs,
                ),
                onRemove: (i) => setState(() => additionalDocs.removeAt(i)),
                onReplace: (i) =>
                    _replaceFileAt(additionalDocs, i, imageOnly: false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Upload'),
        ),
      ],
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_noteController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Note'),
      content: TextField(
        controller: _noteController,
        maxLines: 3,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Note / Comment',
          hintText: 'Enter note',
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
          child: const Text('Save'),
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
        ElevatedButton(
          onPressed: save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _LeadDetailScreenState.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ), 
      ],
    );
  }
}

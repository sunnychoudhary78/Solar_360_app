import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/installation/presentation/providers/installation_providers.dart';
import 'package:solar_sales/features/installation/presentation/screens/installation_form_screen.dart';
import 'package:solar_sales/features/leads/data/lead_files.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/leads/presentation/screens/image_viewer_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_form_screen.dart';
import 'package:solar_sales/features/leads/presentation/widgets/lead_attachments_view.dart';
import 'package:solar_sales/features/leads/presentation/widgets/workflow_stepper.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

bool _isLoanPaymentType(String? type) {
  final value = (type ?? '').trim().toLowerCase();
  return value == 'loan' || value == 'subsidy';
}

String _paymentTypeUiValue(String type) {
  if (type.trim().isEmpty) return '';
  return _isLoanPaymentType(type) ? 'Loan' : type.trim();
}

class LeadDetailScreen extends ConsumerStatefulWidget {
  final LeadModel lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  late LeadModel _lead;
  bool loading = false;
  bool assignLoading = false;
  String? loadError;

  /// Hides Upload Document after a successful Documents Submitted action,
  /// even if a follow-up reload cannot re-fetch the lead (access handoff).
  bool _documentsSubmittedUi = false;

  List<Map<String, dynamic>> history = [];
  List<_WorkflowUserOption> _documentAdmins = const [];
  List<_WorkflowUserOption> _liaisonOfficers = const [];
  List<_WorkflowUserOption> _financeUsers = const [];
  List<_WorkflowUserOption> _materialEngineers = const [];
  List<_WorkflowUserOption> _electricalEngineers = const [];

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _documentsSubmittedUi = _isDocumentsSubmittedStatus(_lead.status);

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
    final roleKey = ref.read(authProvider).workflowRoleKey;

    final fresh = await repo.getLeadById(_lead.id);
    final hist = await repo.getLeadHistory(_lead.id);
    final workflowUsers = await _fetchWorkflowUsers(roleKey);

    if (!mounted) return;

    setState(() {
      _lead = fresh;
      history = hist;
      _documentAdmins = workflowUsers.documentAdmins;
      _liaisonOfficers = workflowUsers.liaisonOfficers;
      _financeUsers = workflowUsers.financeUsers;
      _materialEngineers = workflowUsers.materialEngineers;
      _electricalEngineers = workflowUsers.electricalEngineers;
      _syncDocumentsSubmittedUiFromStatus(fresh.status);
      loading = false;
      loadError = null;
    });
  }

  Future<_WorkflowUsersBundle> _fetchWorkflowUsers(String roleKey) async {
    final repo = ref.read(leadRepositoryProvider);

    if (roleKey == 'Finance Manager') {
      final responses = await Future.wait([
        repo.getUsersByRole(const ['Document Administrator']),
        repo.getUsersByRole(const ['Bank Process']),
        repo.getUsersByRole(const ['Finance User']),
      ]);

      return _WorkflowUsersBundle(
        documentAdmins: _mapWorkflowUsers(responses[0]),
        liaisonOfficers: _mapWorkflowUsers(responses[1]),
        financeUsers: _mapWorkflowUsers(responses[2]),
      );
    }

    if (roleKey == 'Installation Manager') {
      final responses = await Future.wait([
        repo.getUsersByRole(const ['Material Engineer']),
        repo.getUsersByRole(const ['Electrical Engineer']),
      ]);

      return _WorkflowUsersBundle(
        materialEngineers: _mapWorkflowUsers(responses[0]),
        electricalEngineers: _mapWorkflowUsers(responses[1]),
      );
    }

    return const _WorkflowUsersBundle();
  }

  List<_WorkflowUserOption> _mapWorkflowUsers(List<Map<String, dynamic>> rows) {
    return rows
        .map(
          (row) => _WorkflowUserOption(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString().trim() ?? '',
          ),
        )
        .where((user) => user.id.isNotEmpty && user.name.isNotEmpty)
        .toList();
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

  List<_LeadNoteEntry> _parseLeadNotes(String raw) {
    final text = _removeOldRegistrationBlock(raw).trim();
    if (text.isEmpty) return const [];

    final hasStructured = RegExp(
      r'(^|\n)@note\|',
      multiLine: true,
    ).hasMatch(text);

    if (!hasStructured) {
      return text
          .split(RegExp(r'\n\s*\n'))
          .map((chunk) => chunk.trim())
          .where((chunk) => chunk.isNotEmpty)
          .map((chunk) => _LeadNoteEntry(body: chunk))
          .toList();
    }

    final entries = <_LeadNoteEntry>[];
    final parts = text.split(RegExp(r'(?=^@note\|)', multiLine: true));

    for (final part in parts) {
      final chunk = part.trim();
      if (chunk.isEmpty) continue;

      final match = RegExp(
        r'^@note\|([^|]*)\|([^|]*)\|([^\n]*)\n?([\s\S]*)$',
      ).firstMatch(chunk);

      if (match == null) {
        for (final plain in chunk.split(RegExp(r'\n\s*\n'))) {
          final body = plain.trim();
          if (body.isNotEmpty) entries.add(_LeadNoteEntry(body: body));
        }
        continue;
      }

      entries.add(
        _LeadNoteEntry(
          role: match.group(1)?.trim(),
          userName: match.group(2)?.trim(),
          atIso: match.group(3)?.trim(),
          body: (match.group(4) ?? '').trim(),
        ),
      );
    }

    return entries;
  }

  String _formatNoteEntry({
    required String role,
    required String userName,
    required String body,
  }) {
    final safeRole = role.replaceAll('|', '/').trim();
    final safeUser = userName.replaceAll('|', '/').trim();
    final at = DateTime.now().toUtc().toIso8601String();
    return '@note|$safeRole|$safeUser|$at\n${body.trim()}';
  }

  String _formatNoteTimestamp(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) return iso.trim();
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  Widget _notesSection(List<_LeadNoteEntry> notes) {
    if (notes.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Divider(height: 16, color: scheme.outlineVariant),
          ...notes.asMap().entries.map((entry) {
            final note = entry.value;
            final isLast = entry.key == notes.length - 1;
            final author = [
              if ((note.role ?? '').trim().isNotEmpty) note.role!.trim(),
              if ((note.userName ?? '').trim().isNotEmpty) note.userName!.trim(),
            ].join(' — ');
            final when = _formatNoteTimestamp(note.atIso);

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author.isNotEmpty)
                    Text(
                      author,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                  if (note.body.isNotEmpty) ...[
                    if (author.isNotEmpty) const SizedBox(height: 2),
                    Text(
                      note.body,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
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
    return LeadWorkflow.getAllowedNextStatuses(_lead.status, roleName);
  }

  bool _isDocumentsSubmittedStatus(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    return value == 'documents submitted' || value == 'document submitted';
  }

  void _syncDocumentsSubmittedUiFromStatus(String status) {
    final value = status.trim().toLowerCase();
    if (_isDocumentsSubmittedStatus(value)) {
      _documentsSubmittedUi = true;
      return;
    }

    // Workflow reopened / still before submit → allow Upload Document again.
    if (value == 'loan application initiated' ||
        value == 'portal processing started' ||
        value == 'documents verification started' ||
        value == 'assigned to document administrator') {
      _documentsSubmittedUi = false;
    }
  }

  bool _canUploadDocuments(List<String> nextStatuses) {
    if (_documentsSubmittedUi) return false;

    final status = _lead.status.trim().toLowerCase();
    if (_isDocumentsSubmittedStatus(status)) return false;

    // After handoff to Bank Process (and later), upload must stay hidden.
    const postSubmitStatuses = {
      'banking process start',
      'bank coordination in progress',
      'bank process complete',
      'finance verification started',
      'amount received',
    };
    if (postSubmitStatuses.contains(status)) return false;

    return status == 'loan application initiated' ||
        nextStatuses.contains('Documents Submitted');
  }

  bool get _documentsAlreadySubmitted {
    return _documentsSubmittedUi ||
        _isDocumentsSubmittedStatus(_lead.status);
  }

  List<String> _installationSpNumbers() {
    final d = _lead.installationDetails;
    if (d == null) return const [];

    final raw = d['sp_numbers'];
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    }

    final values = <String>[];
    for (int i = 1; i <= 20; i++) {
      final value = d['sp_no_$i']?.toString().trim() ?? '';
      if (value.isNotEmpty) values.add(value);
    }
    return values;
  }

  List<String> _installationImagePaths() {
    final d = _lead.installationDetails;
    if (d == null) return const [];

    final raw = d['installation_images'] ?? d['installationImages'];
    if (raw is! List) return const [];

    return raw
        .map((item) {
          if (item is Map) {
            return (item['url'] ??
                    item['path'] ??
                    item['file'] ??
                    item.toString())
                .toString()
                .trim();
          }
          return item?.toString().trim() ?? '';
        })
        .where((path) => path.isNotEmpty)
        .toList();
  }

  bool get _hasMaterialDetails {
    final d = _lead.installationDetails;
    if (d == null || d.isEmpty) return false;

    return _installationValue('file_no').trim().isNotEmpty &&
        _installationValue('capacity').trim().isNotEmpty &&
        _installationValue('solar_panel_brand').trim().isNotEmpty &&
        _installationValue('number_of_solar_panels').trim().isNotEmpty &&
        _installationValue('panel_type').trim().isNotEmpty &&
        _installationValue('dcr_certificate_no').trim().isNotEmpty &&
        _installationValue('application_no').trim().isNotEmpty &&
        _installationSpNumbers().isNotEmpty;
  }

  /// Electrical Engineer installation photos (not material data).
  bool get _hasElectricalInstallationDetails {
    return _installationImagePaths().isNotEmpty;
  }

  bool _isCompleteInstallationStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'installation done';
  }

  String _installationButtonLabel(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'assigned to material engineer') {
      return 'Assign to Installation Team';
    }

    if (normalized == 'installation started') {
      return 'Start Installation';
    }

    if (normalized == 'installation completed') {
      return 'Complete Installation';
    }

    if (normalized == 'installation done') return 'Mark Installation Done';

    return status;
  }

  String _statusActionLabel(String status, bool isInstallationUser) {
    if (isInstallationUser) {
      return _installationButtonLabel(status);
    }

    return status;
  }

  Future<String?> _requestStatusRemarks(String status) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$status remarks'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              hintText: 'Enter the reason or follow-up details',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Remarks are required'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, controller.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    // Dialog route is still unmounting when showDialog completes. Disposing the
    // controller immediately triggers: '_dependents.isEmpty': is not true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    });

    // Let the route finish tearing down before the caller setStates / invalidates.
    await Future<void>.delayed(Duration.zero);
    return result;
  }

  /// Backend KYC checks `account_type`. Older saves only stored Saving/Current
  /// in `bank_account_name`, so copy that across before the status change.
  Future<void> _syncAccountTypeForKyc() async {
    final repo = ref.read(leadRepositoryProvider);
    LeadModel lead = _lead;
    try {
      lead = await repo.getLeadById(_lead.id);
    } catch (_) {}
    if (!mounted) return;
    _lead = lead;

    final inferred = lead.resolvedBankAccountType;
    if (inferred == null) return;
    if (lead.accountType.trim().isNotEmpty) return;

    await repo.updateLead(lead.id, {'account_type': inferred});
    if (!mounted) return;
    _lead = _lead.copyWith(accountType: inferred);
  }

  Future<void> _advanceStatus(String nextStatus) async {
    if (loading) return;

    if (nextStatus == 'Assigned To Document Administrator' &&
        (_lead.assignedToDocumentAdmin.trim().isEmpty ||
            _lead.assignedToLiaisonOfficer.trim().isEmpty ||
            _lead.assignedToFinanceUser.trim().isEmpty)) {
      showAppMessage(
        context,
        'Please assign document admin, bank process, and finance user first',
        isError: true,
      );
      return;
    }

    if (nextStatus == 'Assigned To Material Engineer' &&
        (_lead.assignedToMaterialEngineer.trim().isEmpty ||
            _lead.assignedToElectricalEngineer.trim().isEmpty)) {
      showAppMessage(
        context,
        'Please assign material and electrical engineers first',
        isError: true,
      );
      return;
    }

    if (nextStatus == 'Material Completed' && !_hasMaterialDetails) {
      showAppMessage(
        context,
        'Please fill material details first',
        isError: true,
      );
      return;
    }

    if (nextStatus == 'Installation Started' && !_hasMaterialDetails) {
      showAppMessage(
        context,
        'Please fill material details first',
        isError: true,
      );
      return;
    }

    if ((nextStatus == 'Installation Completed' ||
            _isCompleteInstallationStatus(nextStatus)) &&
        !_hasElectricalInstallationDetails) {
      showAppMessage(
        context,
        'Please fill installation details and upload photos first',
        isError: true,
      );
      return;
    }

    if (nextStatus == 'Documents Submitted' &&
        !_hasRegistrationDetailsFrontend) {
      showAppMessage(
        context,
        'Please add registration details first',
        isError: true,
      );
      return;
    }

    String? remarks;
    if (nextStatus == 'Follow Up' || nextStatus == 'Rejected') {
      remarks = await _requestStatusRemarks(nextStatus);
      if (remarks == null || !mounted) return;
    }

    setState(() => loading = true);

    try {
      if (nextStatus == 'KYC Collected') {
        await _syncAccountTypeForKyc();
        if (!mounted) return;
      }

      await ref
          .read(leadRepositoryProvider)
          .updateLeadStatus(
            leadId: _lead.id,
            status: nextStatus,
            remarks: remarks,
          );

      if (!mounted) return;

      final normalizedNextStatus = nextStatus.trim().toLowerCase();
      final submittedDocuments = _isDocumentsSubmittedStatus(nextStatus);

      setState(() {
        if (normalizedNextStatus == 'installation done') {
          _lead = _lead.copyWith(
            status: nextStatus,
            currentDepartment: 'Finance',
          );
        } else {
          _lead = _lead.copyWith(status: nextStatus);
        }

        if (submittedDocuments) {
          _documentsSubmittedUi = true;
        }

        loading = false;
        loadError = null;
      });

      // Refresh list/detail after success; never surface refresh failures as a
      // status-update error (that caused a brief red flash after Follow Up).
      ref.invalidate(allLeadsProvider);
      try {
        await _reloadSilently();
      } catch (_) {}

      // Document Administrator loses list/detail access after Documents Submitted.
      // If reload fails or returns an older status, keep the submitted UI state.
      if (mounted &&
          submittedDocuments &&
          !_isDocumentsSubmittedStatus(_lead.status)) {
        setState(() {
          _lead = _lead.copyWith(status: nextStatus);
          _documentsSubmittedUi = true;
        });
      }

      if (!mounted) return;

      if (normalizedNextStatus == 'installation done') {
        showAppMessage(context, 'Installation Completed Successfully');
      } else {
        showAppMessage(context, 'Status updated to $nextStatus');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = null;
      });
      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Exception:', '')
          .trim();
      showAppMessage(
        context,
        message.isEmpty ? 'Failed to update status' : message,
        isError: true,
      );
    }
  }

  Future<void> _assignLead(Map<String, dynamic> payload) async {
    if (assignLoading) return;

    setState(() => assignLoading = true);

    try {
      final updated = await ref
          .read(leadRepositoryProvider)
          .assignLead(_lead.id, payload);

      if (!mounted) return;

      setState(() {
        _lead = updated;
        assignLoading = false;
      });

      ref.invalidate(allLeadsProvider);
      await _reloadSilently();

      if (!mounted) return;
      showAppMessage(context, 'Assignment updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => assignLoading = false);
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
      final auth = ref.read(authProvider);
      final role = auth.workflowRoleKey.trim().isNotEmpty
          ? auth.workflowRoleKey.trim()
          : auth.effectiveRoleName.trim();
      final userName =
          (auth.profile?.name ?? auth.authUser?.name ?? '').trim();
      final stamped = _formatNoteEntry(
        role: role.isEmpty ? 'User' : role,
        userName: userName.isEmpty ? 'Unknown' : userName,
        body: note.trim(),
      );

      final oldNotes = _lead.notes.trim();
      final updatedNotes = oldNotes.isEmpty
          ? stamped
          : '$oldNotes\n\n$stamped';

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
      await ref
          .read(leadRepositoryProvider)
          .uploadLeadDocuments(
            leadId: _lead.id,
            additionalImageEntries: result.images
                .map((item) => item.toPayload())
                .toList(),
            additionalDocumentEntries: result.documents
                .map((item) => item.toPayload())
                .toList(),
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
        existingImages: _lead.registrationImages,
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

      final registrationBlock =
          '''
[REGISTRATION_DETAILS]
registration_id=${result.regId.trim()}
registration_date=${result.regDate.trim()}
registration_time=${result.regTime.trim()}
[/REGISTRATION_DETAILS]
''';

      final updatedNotes = oldNotes.trim().isEmpty
          ? registrationBlock.trim()
          : '${oldNotes.trim()}\n\n${registrationBlock.trim()}';

      await ref.read(leadRepositoryProvider).updateLeadWithFiles(_lead.id, {
        'registration_id': result.regId.trim(),
        'registration_date': result.regDate.trim(),
        'registration_time': result.regTime.trim(),
        'notes': updatedNotes,
      }, registrationImagePaths: result.imagePaths);

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

  Future<void> _savePaymentDetails(_PaymentResult result) async {
    if (loading) return;

    setState(() => loading = true);

    final isLoan = _isLoanPaymentType(result.paymentType);
    final percent = result.subsidyPercentage.trim();
    final amount = result.paymentAmount.trim();

    Future<void> persist(String paymentType) {
      return ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'payment_type': paymentType,
        'payment_amount': amount,
        if (isLoan) 'subsidy_percentage': percent,
      });
    }

    try {
      // Backend lead ENUM is Cash|Subsidy (UI label is Loan).
      // Some environments may use Cash|Loan — fall back if Subsidy is rejected.
      var savedType = isLoan ? 'Subsidy' : 'Cash';
      try {
        await persist(savedType);
      } catch (_) {
        if (!isLoan) rethrow;
        savedType = 'Loan';
        await persist(savedType);
      }

      if (!mounted) return;

      setState(() {
        _lead = _lead.copyWith(
          paymentType: savedType,
          subsidyPercentage: isLoan ? percent : '',
          paymentAmount: amount,
        );
      });

      await _reloadSilently();
      if (!mounted) return;
      showAppMessage(
        context,
        'Payment details saved. You can now mark Amount Received.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _toggleFinalAmountReceived(bool value) async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final data = <String, dynamic>{
        'final_amount_received': value,
      };
      if (value && _isLoanPaymentType(_lead.paymentType)) {
        data['subsidy_percentage'] = '100';
      }

      await ref.read(leadRepositoryProvider).updateLead(_lead.id, data);

      await _reloadSilently();
      if (!mounted) return;
      showAppMessage(
        context,
        value
            ? 'Final amount received marked'
            : 'Final amount received cleared',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showAppMessage(context, e.toString(), isError: true);
    }
  }

  Future<void> _updateSubsidyStatus(String? value) async {
    if (value == null || value.trim().isEmpty || loading) return;

    setState(() => loading = true);

    try {
      await ref.read(leadRepositoryProvider).updateLead(_lead.id, {
        'subsidy_apply_status': value,
      });

      await _reloadSilently();
      if (!mounted) return;
      showAppMessage(context, 'Subsidy status updated');
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
    final roleKey = ref.read(authProvider).workflowRoleKey;
    final materialOnly = roleKey == 'Material Engineer';

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            InstallationFormScreen(lead: _lead, materialOnly: materialOnly),
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => loading = true);

    try {
      await _reloadSilently();

      final installationRepo = ref.read(installationRepositoryProvider);
      try {
        final inst = await installationRepo.getByLeadId(_lead.id);
        if (inst != null && mounted) {
          setState(() {
            _lead = _lead.copyWith(installationDetails: inst);
          });
        }
      } catch (_) {}

      if (!mounted) return;
      showAppMessage(
        context,
        roleKey == 'Material Engineer'
            ? 'Material details saved'
            : 'Installation photos saved',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final roleKey = auth.workflowRoleKey;
    final nextStatuses = _resolveNextStatuses(roleKey);
    final files = collectLeadFiles(_lead);
    final customerName = _lead.fullName.trim().isEmpty
        ? 'Customer'
        : _lead.fullName;

    final visibleNotes = _visibleNotes();
    final parsedNotes = _parseLeadNotes(visibleNotes);

    final normalizedDepartment = _lead.currentDepartment.trim().toLowerCase();
    final normalizedStatus = _lead.status.trim().toLowerCase();

    final isSalesUser = roleKey == 'Sales';

    final isLeadStillWithSales =
        normalizedDepartment.isEmpty || normalizedDepartment == 'sales';

    final canSalesEditLeadDetails =
        isSalesUser &&
        isLeadStillWithSales &&
        LeadWorkflow.canSalesCompleteDetails(_lead.status);

    final isDocumentAdministrator = roleKey == 'Document Administrator';
    final showUploadButton =
        isDocumentAdministrator && _canUploadDocuments(nextStatuses);
    final showDocumentsSubmittedState =
        isDocumentAdministrator &&
        _documentsAlreadySubmitted &&
        !showUploadButton;

    final isLeadWithDocumentAdmin = normalizedDepartment == 'finance';

    final isRegistrationEditableStage =
        normalizedStatus == 'assigned to document administrator' ||
        normalizedStatus == 'documents verification started' ||
        normalizedStatus == 'portal processing started' ||
        normalizedStatus == 'loan application initiated';

    final canSupportManageRegistration =
        isDocumentAdministrator &&
        isLeadWithDocumentAdmin &&
        isRegistrationEditableStage;

    final showAddRegistrationButton =
        canSupportManageRegistration && !_hasRegistrationDetailsFrontend;

    final showEditRegistrationButton =
        canSupportManageRegistration && _hasRegistrationDetailsFrontend;

    final isInstallationUser =
        roleKey == 'Installation Manager' ||
        roleKey == 'Material Engineer' ||
        roleKey == 'Electrical Engineer';

    final isInstallationDoneAndMovedToSupport =
        normalizedStatus == 'installation done' &&
        normalizedDepartment == 'finance';

    final canInstallationAccessLead =
        isInstallationUser && !isInstallationDoneAndMovedToSupport;
    // Installation Manager assigns engineers; material/installation forms are
    // for Material Engineer and Electrical Engineer only.
    final canOpenInstallationForm =
        canInstallationAccessLead && roleKey != 'Installation Manager';
    final showMaterialDetailsSection =
        _hasMaterialDetails && roleKey != 'Installation Manager';
    final hasPaymentType = _lead.paymentType.trim().isNotEmpty;
    final hasLoanPercentage =
        !_isLoanPaymentType(_lead.paymentType) ||
        _lead.subsidyPercentage.trim().isNotEmpty;
    final hasPaymentAmount = _lead.paymentAmount.trim().isNotEmpty;
    final paymentLocked =
        hasPaymentType && hasLoanPercentage && hasPaymentAmount;
    final registrationImageFiles = _registrationImageFiles();
    final materialDetailsFilled = _hasMaterialDetails;
    final filteredNextStatuses =
        isInstallationUser && isInstallationDoneAndMovedToSupport
        ? <String>[]
        : nextStatuses.where((status) {
            if (status == 'Material Completed' &&
                roleKey == 'Material Engineer' &&
                !materialDetailsFilled) {
              return false;
            }
            if (status == 'Installation Started' &&
                roleKey == 'Electrical Engineer' &&
                !_hasMaterialDetails) {
              return false;
            }
            if (status == 'Installation Completed' &&
                (roleKey == 'Installation Manager' ||
                    roleKey == 'Electrical Engineer') &&
                !_hasElectricalInstallationDetails) {
              return false;
            }
            if (status == 'Documents Submitted' &&
                !_hasRegistrationDetailsFrontend) {
              return false;
            }
            if (status == 'Amount Received' &&
                roleKey == 'Finance User' &&
                !paymentLocked) {
              return false;
            }
            if (status == 'Final Complete' && !_lead.finalAmountReceived) {
              return false;
            }
            return true;
          }).toList();
    final showFinanceAssignments =
        roleKey == 'Finance Manager' &&
        (_lead.status == 'Approved By Sales Manager' ||
            _lead.status == 'Assigned To Document Administrator');
    final showInstallationAssignments =
        roleKey == 'Installation Manager' &&
        (_lead.status == 'Amount Received' ||
            _lead.status == 'Assigned To Material Engineer');
    final showFinancePaymentSection = roleKey == 'Finance User';
    final showFinalAmountSection =
        isDocumentAdministrator &&
        (_lead.finalAmountReceived ||
            _lead.status == 'Installation Done' ||
            _lead.status == 'Lead Closed' ||
            _lead.status == 'DCR Reports Completed' ||
            _lead.status == 'Discom Status' ||
            _lead.status == 'Final Complete');
    final showSubsidySection =
        _lead.status == 'Final Complete' ||
        _lead.status == 'Lead Closed' ||
        _lead.subsidyApplyStatus.trim().isNotEmpty;

    return Scaffold(
      appBar: AppAppBar(
        title: customerName,
        subtitle: _lead.leadCode.trim().isEmpty ? null : _lead.leadCode,
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading && history.isEmpty && loadError == null
          ? const LoadingState(message: 'Loading lead…')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (loadError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md - 4),
                      padding: const EdgeInsets.all(AppSpacing.md - 4),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: scheme.error.withValues(alpha: .25),
                        ),
                      ),
                      child: Text(
                        loadError!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  _headerCard(customerName),
                  const SizedBox(height: 14),
                  WorkflowStepper(
                    currentStatus: _lead.status.trim().isNotEmpty
                        ? _lead.status
                        : _lead.workflowStep,
                  ),
                  const SizedBox(height: 14),
                  if (canOpenInstallationForm) ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : _openInstallationForm,
                      icon: const Icon(Icons.build_circle_outlined),
                      label: Text(
                        roleKey == 'Material Engineer'
                            ? (_hasMaterialDetails
                                  ? 'Edit Material Details'
                                  : 'Fill Material Details (required)')
                            : (_hasElectricalInstallationDetails
                                  ? 'Edit Installation Form'
                                  : 'Fill Installation Form'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showAddRegistrationButton) ...[
                    OutlinedButton(
                      onPressed: loading ? null : _saveRegistration,
                      child: const Text('Add registration details'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (canSalesEditLeadDetails) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _openCompleteLeadForm,
                        icon: const Icon(Icons.edit_document),
                        label: const Text(
                          'Edit / Complete Lead Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                    _row('Project Type', _lead.projectType),
                    _row('Source', _lead.source),
                  ]),
                  _section('Workflow', [
                    _statusRow('Status', _lead.status),
                    _row('Department', _lead.currentDepartment),
                    _row('Stage', _lead.leadStage),
                    _row('Priority', _lead.priority),
                    _row('Workflow Step', _lead.workflowStep),
                  ]),
                  _section('Connection & Bank', [
                    _row('CA Number', _lead.caNumber),
                    _row('K Number', _lead.kNumber),
                    _row('Reference Number', _lead.referenceNumber),
                    _row('Discom', _lead.discom),
                    _row(
                      'Account Type',
                      _lead.resolvedBankAccountType ?? _lead.accountType,
                    ),
                    _row('Bank', _lead.bankName),
                    _row('Account', _lead.accountNumber),
                    _row('IFSC', _lead.ifscCode),
                  ]),
                  _section('Location', [
                    _row('Geo Location', _lead.geoLocation),
                    _row('Latitude', _lead.latitude),
                    _row('Longitude', _lead.longitude),
                  ]),
                  _section('Site Details', [
                    _row(
                      'Available Shadow Free Area',
                      _lead.availableShadowFreeArea.trim().isEmpty
                          ? ''
                          : '${_lead.availableShadowFreeArea} sqmtr',
                    ),
                    _row('Quotation Amount', _lead.quotationAmount),
                    _row('Visited Employee Name', _lead.visitedEmployeeName),
                    _row(
                      'Visited Employee Contact',
                      _lead.visitedEmployeeContact,
                    ),
                    _row(
                      'Roof Load Bearing Capacity',
                      _lead.roofLoadBearingCapacity ? 'Yes' : 'No',
                    ),
                    _row(
                      'Shadow Free Roof',
                      _lead.shadowFreeRoof ? 'Yes' : 'No',
                    ),
                    _row(
                      'Vendor Visited Site',
                      _lead.vendorVisitedSite ? 'Yes' : 'No',
                    ),
                  ]),
                  if (_hasRegistrationDetailsFrontend)
                    _section('Registration', [
                      _row('Registration ID', _displayRegistrationId),
                      _row('Registration Date', _displayRegistrationDate),
                      _row('Registration Time', _displayRegistrationTime),
                      if (registrationImageFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Registration Images',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LeadAttachmentsView(files: registrationImageFiles),
                      ],
                    ]),
                  if (showEditRegistrationButton) ...[
                    OutlinedButton.icon(
                      onPressed: loading ? null : _saveRegistration,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit registration details'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (showFinalAmountSection)
                    _section('Final Amount', [
                      SwitchListTile(
                        value: _lead.finalAmountReceived,
                        onChanged: loading || _lead.status == 'Final Complete'
                            ? null
                            : _toggleFinalAmountReceived,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Final amount received'),
                        subtitle: const Text('Required before Final Complete'),
                      ),
                    ]),
                  if (showSubsidySection)
                    _section('Subsidy Status', [
                      DropdownButtonFormField<String>(
                        value: _lead.subsidyApplyStatus.trim().isEmpty
                            ? null
                            : _lead.subsidyApplyStatus,
                        decoration: const InputDecoration(
                          labelText: 'Subsidy Apply Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Apply',
                            child: Text('Apply'),
                          ),
                          DropdownMenuItem(
                            value: 'Processing',
                            child: Text('Processing'),
                          ),
                          DropdownMenuItem(
                            value: 'Pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'Complete',
                            child: Text('Complete'),
                          ),
                        ],
                        onChanged: loading ? null : _updateSubsidyStatus,
                      ),
                    ]),
                  if (showMaterialDetailsSection)
                    _section('Material Engineer Details', [
                      _row('Inverter Serial No', _installationValue('file_no')),
                      _row(
                        'Inverter Panel Capacity',
                        _installationValue('capacity'),
                      ),
                      _row('Panel Type', _installationValue('panel_type')),
                      _row(
                        'DCR Certificate No',
                        _installationValue('dcr_certificate_no'),
                      ),
                      _row(
                        'Application No',
                        _installationValue('application_no'),
                      ),
                      _row(
                        'Inverter Solar Panel Brand',
                        _installationValue('solar_panel_brand'),
                      ),
                      _row(
                        'No. Of Solar Panels',
                        _installationValue('number_of_solar_panels'),
                      ),
                      _row('Invoice No', _installationValue('invoice_no')),
                      _spNumbersRows(),
                    ]),
                  if (_hasElectricalInstallationDetails)
                    _section(
                      'Electrical Engineer — Installation',
                      [_installationPhotosGallery()],
                    ),
                  _section('Uploaded Files & Images', [
                    LeadAttachmentsView(files: files),
                  ]),
                  if (parsedNotes.isNotEmpty) _notesSection(parsedNotes),
                  if (showFinancePaymentSection) ...[
                    _section('Payment', [
                      if (paymentLocked) ...[
                        _row(
                          'Payment Type',
                          _paymentTypeUiValue(_lead.paymentType).isEmpty
                              ? '—'
                              : _paymentTypeUiValue(_lead.paymentType),
                        ),
                        if (_isLoanPaymentType(_lead.paymentType))
                          _row(
                            'Loan Percentage',
                            _lead.subsidyPercentage.isEmpty
                                ? '—'
                                : '${_lead.subsidyPercentage}%',
                          ),
                        _row(
                          'Payment Amount',
                          _lead.paymentAmount.isEmpty
                              ? '—'
                              : _lead.paymentAmount,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Payment already saved'),
                          ),
                        ),
                      ] else
                        _InlinePaymentFields(
                          enabled: !loading,
                          quotationAmount: _lead.quotationAmount,
                          onSave: _savePaymentDetails,
                        ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _addNote,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Add Note'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.primary,
                        side: BorderSide(
                          color: scheme.primary.withValues(alpha: .4),
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
                          foregroundColor: scheme.primary,
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: .4),
                          ),
                        ),
                      ),
                    ),
                  ] else if (showDocumentsSubmittedState) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Document submitted'),
                      ),
                    ),
                  ],
                  if (showFinanceAssignments) ...[
                    const SizedBox(height: 14),
                    _assignmentSection(
                      title: 'Assign Team Members',
                      children: [
                        _assignmentPicker(
                          label: 'Document Administrator',
                          currentValue: _lead.assignedToDocumentAdmin,
                          currentName: _lead.assignedToDocumentAdminName,
                          options: _documentAdmins,
                          onChanged: (value) => _assignLead({
                            'assigned_to_document_admin': value ?? '',
                          }),
                        ),
                        _assignmentPicker(
                          label: 'Bank Process',
                          currentValue: _lead.assignedToLiaisonOfficer,
                          currentName: _lead.assignedToLiaisonOfficerName,
                          options: _liaisonOfficers,
                          onChanged: (value) => _assignLead({
                            'assigned_to_liaison_officer': value ?? '',
                          }),
                        ),
                        _assignmentPicker(
                          label: 'Finance User',
                          currentValue: _lead.assignedToFinanceUser,
                          currentName: _lead.assignedToFinanceUserName,
                          options: _financeUsers,
                          onChanged: (value) => _assignLead({
                            'assigned_to_finance_user': value ?? '',
                          }),
                        ),
                      ],
                    ),
                  ],
                  if (showInstallationAssignments) ...[
                    const SizedBox(height: 14),
                    _assignmentSection(
                      title: 'Assign Installation Team',
                      children: [
                        _assignmentPicker(
                          label: 'Material Engineer',
                          currentValue: _lead.assignedToMaterialEngineer,
                          currentName: _lead.assignedToMaterialEngineerName,
                          options: _materialEngineers,
                          onChanged: (value) => _assignLead({
                            'assigned_to_material_engineer': value ?? '',
                          }),
                        ),
                        _assignmentPicker(
                          label: 'Electrical Engineer',
                          currentValue: _lead.assignedToElectricalEngineer,
                          currentName: _lead.assignedToElectricalEngineerName,
                          options: _electricalEngineers,
                          onChanged: (value) => _assignLead({
                            'assigned_to_electrical_engineer': value ?? '',
                          }),
                        ),
                      ],
                    ),
                  ],
                  if (filteredNextStatuses.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Status actions',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    ...filteredNextStatuses.map((status) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.sm + 2,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: loading
                                ? null
                                : () => _advanceStatus(status),
                            child: Text(
                              _statusActionLabel(status, isInstallationUser),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Status history',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (history.isEmpty)
                    Text(
                      'No history yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
    if (d == null || d.isEmpty) return '';

    final direct = d[key];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final aliasKeys = <String, List<String>>{
      'file_no': ['fileNo', 'file_number', 'fileNumber'],
      'capacity': ['panel_capacity', 'panelCapacity', 'load_capacity'],
      'panel_type': ['panelType'],
      'dcr_certificate_no': ['dcrCertificateNo', 'dcr_no', 'dcrNo'],
      'application_no': ['applicationNo', 'application_number'],
      'solar_panel_brand': ['solarPanelBrand', 'panel_brand'],
      'number_of_solar_panels': [
        'numberOfSolarPanels',
        'no_of_solar_panels',
        'solar_panel_count',
      ],
      'invoice_no': ['invoiceNo', 'invoice_number'],
      'inverter_serial_number': ['inverterSerialNumber', 'inverter_serial_no'],
      'battery_serial_number': ['batterySerialNumber', 'battery_serial_no'],
    };

    for (final alias in aliasKeys[key] ?? const <String>[]) {
      final value = d[alias];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  Widget _spNumbersRows() {
    final d = _lead.installationDetails;
    if (d == null) return const SizedBox.shrink();

    final raw = d['sp_numbers'];

    if (raw is List && raw.isNotEmpty) {
      final rows = <Widget>[];
      for (int i = 0; i < raw.length; i++) {
        final value = raw[i]?.toString() ?? '';
        if (value.trim().isNotEmpty) {
          rows.add(_row('S.P. No. ${i + 1}', value));
        }
      }

      if (rows.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    final rows = <Widget>[];
    for (int i = 1; i <= 20; i++) {
      final value = d['sp_no_$i']?.toString() ?? '';
      if (value.trim().isNotEmpty) {
        rows.add(_row('S.P. No. $i', value));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _installationPhotosGallery() {
    final paths = _installationImagePaths();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Installation Photos — ${paths.length}',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: paths.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final raw = paths[index];
            final url = resolveUploadUrl(raw);
            final fileName = fileDisplayName(
              raw.split('\\').last.split('/').last.isEmpty
                  ? 'installation_${index + 1}.jpg'
                  : raw.split('\\').last.split('/').last,
            );

            return Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: url.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ImageViewerScreen(
                              imageUrl: url,
                              label: 'Installation Photo ${index + 1}',
                              fileName: fileName,
                            ),
                          ),
                        );
                      },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isEmpty)
                      Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.zoom_in_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a photo to preview or download',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _assignmentSection({
    required String title,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          ...children,
        ],
      ),
    );
  }

  Widget _assignmentPicker({
    required String label,
    required String currentValue,
    required String currentName,
    required List<_WorkflowUserOption> options,
    required ValueChanged<String?> onChanged,
  }) {
    final hasCurrent = currentValue.trim().isNotEmpty;
    final dropdownValue =
        hasCurrent && options.any((option) => option.id == currentValue.trim())
        ? currentValue.trim()
        : null;

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: dropdownValue,
            isExpanded: true,
            hint: Text('Select $label'),
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(option.name),
                  ),
                )
                .toList(),
            onChanged: assignLoading ? null : onChanged,
          ),
          if (currentName.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Current: $currentName',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  List<LeadFileItem> _registrationImageFiles() {
    return _lead.registrationImages
        .where((path) => path.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => LeadFileItem(
            label: 'Registration Image ${entry.key + 1}',
            path: entry.value,
            url: resolveUploadUrl(entry.value),
            isImage: true,
            isPdf: false,
          ),
        )
        .toList();
  }

  Widget _headerCard(String customerName) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = _lead.status.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      decoration: BoxDecoration(
        gradient: AppGradients.brand(scheme),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.header(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customerName,
            style: textTheme.headlineSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            status.isEmpty ? 'No status' : status,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _lead.currentDepartment.isEmpty
                ? 'Department pending'
                : 'Department: ${_lead.currentDepartment}',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: .78),
            ),
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

    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(Icons.history, color: scheme.primary, size: 20),
        ),
        title: Text(
          status,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final visibleChildren = children
        .where((child) => child is! SizedBox)
        .toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Divider(height: 20, color: scheme.outlineVariant),
          ...visibleChildren,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: PremiumStatusPill(
                      label: value,
                      color: AppStatusColors.forStatus(context, value),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TitledLocalFile {
  final String title;
  final String path;

  const TitledLocalFile({required this.title, required this.path});

  Map<String, String> toPayload() {
    return {'title': title.trim(), 'path': path};
  }

  TitledLocalFile copyWith({String? title, String? path}) {
    return TitledLocalFile(title: title ?? this.title, path: path ?? this.path);
  }
}

class _UploadDocumentsResult {
  final List<TitledLocalFile> images;
  final List<TitledLocalFile> documents;

  const _UploadDocumentsResult({required this.images, required this.documents});
}

class _UploadDocumentsDialog extends StatefulWidget {
  const _UploadDocumentsDialog();

  @override
  State<_UploadDocumentsDialog> createState() => _UploadDocumentsDialogState();
}

class _UploadDocumentsDialogState extends State<_UploadDocumentsDialog> {
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
        final scheme = Theme.of(dialogContext).colorScheme;

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
                        decoration: InputDecoration(labelText: titleLabel),
                      ),
                      const SizedBox(height: AppSpacing.md - 2),
                      InkWell(
                        onTap: () async {
                          final path = await _pickSingleFile(
                            imageOnly: imageOnly,
                          );

                          if (path == null) return;
                          if (!mounted) return;

                          setDialogState(() {
                            selectedPath = path;
                          });
                        },
                        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppRadius.lg - 2,
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: .75,
                              ),
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
                                      color: scheme.primary,
                                      size: 38,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(uploadLabel),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg - 2,
                                  ),
                                  child: _isImagePath(selectedPath!)
                                      ? Image.file(
                                          File(selectedPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : _docPreview(context, selectedPath!),
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
                        TitledLocalFile(title: title, path: selectedPath!),
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

  Widget _docPreview(BuildContext context, String path) {
    final pdf = _isPdfPath(path);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs + 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 42,
              color: pdf ? scheme.error : scheme.primary,
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
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${files.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (files.isEmpty) ...[
            const SizedBox(height: AppSpacing.md - 4),
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
              ),
              child: Text(
                imagesOnly ? 'No images added.' : 'No documents added.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 14,
              children: files.asMap().entries.map((entry) {
                final item = entry.value;
                final idx = entry.key;
                final image = _isImagePath(item.path);

                return SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  : _docPreview(context, item.path),
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
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TextButton(
                        onPressed: saving ? null : () => onReplace(idx),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: const Text(
                          'Replace',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 4),
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
        FilledButton.icon(
          onPressed: saving ? null : _submit,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Upload'),
        ),
      ],
    );
  }
}

class _LeadNoteEntry {
  final String? role;
  final String? userName;
  final String? atIso;
  final String body;

  const _LeadNoteEntry({
    this.role,
    this.userName,
    this.atIso,
    required this.body,
  });
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _RegistrationResult {
  final String regId;
  final String regDate;
  final String regTime;
  final List<String> imagePaths;

  const _RegistrationResult({
    required this.regId,
    required this.regDate,
    required this.regTime,
    required this.imagePaths,
  });
}

class _WorkflowUsersBundle {
  final List<_WorkflowUserOption> documentAdmins;
  final List<_WorkflowUserOption> liaisonOfficers;
  final List<_WorkflowUserOption> financeUsers;
  final List<_WorkflowUserOption> materialEngineers;
  final List<_WorkflowUserOption> electricalEngineers;

  const _WorkflowUsersBundle({
    this.documentAdmins = const [],
    this.liaisonOfficers = const [],
    this.financeUsers = const [],
    this.materialEngineers = const [],
    this.electricalEngineers = const [],
  });
}

class _WorkflowUserOption {
  final String id;
  final String name;

  const _WorkflowUserOption({required this.id, required this.name});
}

class _PaymentResult {
  final String paymentType;
  final String subsidyPercentage;
  final String paymentAmount;

  const _PaymentResult({
    required this.paymentType,
    required this.subsidyPercentage,
    required this.paymentAmount,
  });
}

class _InlinePaymentFields extends StatefulWidget {
  final bool enabled;
  final String quotationAmount;
  final Future<void> Function(_PaymentResult result) onSave;

  const _InlinePaymentFields({
    required this.enabled,
    required this.quotationAmount,
    required this.onSave,
  });

  @override
  State<_InlinePaymentFields> createState() => _InlinePaymentFieldsState();
}

class _InlinePaymentFieldsState extends State<_InlinePaymentFields> {
  String paymentType = '';
  String subsidyPercentage = '';
  String? saveError;
  late final TextEditingController amountController;

  String get _normalizedQuotationAmount {
    final raw = widget.quotationAmount.trim().replaceAll(',', '');
    if (raw.isEmpty) return '';
    final parsed = num.tryParse(raw);
    if (parsed == null) return raw;
    // Keep a clean numeric string for the Amount field / API.
    return parsed % 1 == 0
        ? parsed.toInt().toString()
        : parsed.toString();
  }

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void _applyPaymentType(String value) {
    setState(() {
      paymentType = value;
      if (!_isLoanPaymentType(value)) {
        subsidyPercentage = '';
        // Cash → auto-fill from quotation amount.
        amountController.text = _normalizedQuotationAmount;
      } else {
        // Loan → Finance User enters amount manually.
        amountController.clear();
      }
      saveError = null;
    });
  }

  Future<void> _submit() async {
    if (!widget.enabled) return;

    if (paymentType.trim().isEmpty) {
      setState(() => saveError = 'Select payment type');
      return;
    }
    if (_isLoanPaymentType(paymentType) && subsidyPercentage.trim().isEmpty) {
      setState(() => saveError = 'Select 70% or 100%');
      return;
    }

    if (!_isLoanPaymentType(paymentType) &&
        _normalizedQuotationAmount.isEmpty) {
      setState(
        () => saveError = 'Quotation amount is missing on this lead',
      );
      return;
    }

    final amount = amountController.text.trim();
    if (amount.isEmpty ||
        num.tryParse(amount.replaceAll(',', '')) == null ||
        num.parse(amount.replaceAll(',', '')) <= 0) {
      setState(() => saveError = 'Enter a valid amount');
      return;
    }

    setState(() => saveError = null);
    await widget.onSave(
      _PaymentResult(
        paymentType: paymentType,
        subsidyPercentage: subsidyPercentage,
        paymentAmount: amount.replaceAll(',', ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoan = _isLoanPaymentType(paymentType);
    final isCash = paymentType.trim().toLowerCase() == 'cash';
    final quotation = _normalizedQuotationAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quotation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Quotation Amount: ₹$quotation',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        DropdownButtonFormField<String>(
          value: paymentType.trim().isEmpty ? null : paymentType,
          decoration: const InputDecoration(labelText: 'Payment Type'),
          items: const [
            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            DropdownMenuItem(value: 'Loan', child: Text('Loan')),
          ],
          onChanged: widget.enabled
              ? (value) {
                  if (value == null) return;
                  _applyPaymentType(value);
                }
              : null,
        ),
        if (isLoan) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: subsidyPercentage.trim().isEmpty ? null : subsidyPercentage,
            decoration: const InputDecoration(
              labelText: 'Loan Percentage',
              hintText: 'Select loan percentage',
            ),
            items: const [
              DropdownMenuItem(value: '70', child: Text('70%')),
              DropdownMenuItem(value: '100', child: Text('100%')),
            ],
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) return;
                    setState(() {
                      subsidyPercentage = value;
                      saveError = null;
                    });
                  }
                : null,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          // Cash amount comes from quotation; keep editable only for Loan.
          enabled: widget.enabled && !isCash,
          readOnly: isCash,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: isCash ? 'Amount (from Quotation)' : 'Amount',
            hintText: isLoan ? 'Enter loan amount' : null,
          ),
          onChanged: (_) {
            if (saveError != null) setState(() => saveError = null);
          },
        ),
        if (saveError != null) ...[
          const SizedBox(height: 8),
          Text(
            saveError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.enabled ? _submit : null,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Save payment details'),
          ),
        ),
      ],
    );
  }
}

class _RegistrationDialog extends StatefulWidget {
  final String initialRegId;
  final String initialRegDate;
  final String initialRegTime;
  final List<String> existingImages;

  const _RegistrationDialog({
    required this.initialRegId,
    required this.initialRegDate,
    required this.initialRegTime,
    required this.existingImages,
  });

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  late final TextEditingController regIdController;
  late final TextEditingController regDateController;
  List<String> selectedImages = [];

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
        imagePaths: List<String>.from(selectedImages),
      ),
    );
  }

  Future<void> _pickRegistrationImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );

    if (!mounted || result == null) return;

    setState(() {
      selectedImages = result.files
          .map((file) => file.path ?? '')
          .where((path) => path.trim().isNotEmpty)
          .toList();
    });
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
              decoration: const InputDecoration(labelText: 'Registration ID'),
            ),
            const SizedBox(height: AppSpacing.md - 4),
            TextField(
              controller: regDateController,
              readOnly: true,
              onTap: pickDate,
              decoration: InputDecoration(
                labelText: 'Registration Date',
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
                    decoration: const InputDecoration(labelText: 'Hour'),
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
                    decoration: const InputDecoration(labelText: 'Min'),
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
                    decoration: const InputDecoration(labelText: 'AM/PM'),
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickRegistrationImages,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Add registration images'),
              ),
            ),
            if (widget.existingImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Existing images: ${widget.existingImages.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (selectedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...selectedImages.map(
                (path) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      path.split('\\').last.split('/').last,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}

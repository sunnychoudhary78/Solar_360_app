import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_progress.dart';
import 'package:solar_sales/features/site_survey/presentation/providers/site_survey_providers.dart';
import 'package:solar_sales/features/site_survey/presentation/site_survey_access.dart';
import 'package:solar_sales/features/site_survey/presentation/survey_image.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/signature_pad.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/survey_form_view.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';

class SiteSurveyScreen extends ConsumerStatefulWidget {
  const SiteSurveyScreen({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.projectType,
  });

  final String leadId;
  final String leadName;
  final String projectType;

  @override
  ConsumerState<SiteSurveyScreen> createState() => _SiteSurveyScreenState();
}

class _SiteSurveyScreenState extends ConsumerState<SiteSurveyScreen>
    with WidgetsBindingObserver {
  LeadSurveyLookup? _lookup;
  SiteSurveyRecord? _survey;
  Map<String, dynamic> _answers = {};
  Map<String, String> _errors = {};
  final Map<String, GlobalKey> _keys = {};
  String? _selectedTemplateId;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  bool _editing = false;
  int _formEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoSaveDraft();
    }
  }

  Future<void> _autoSaveDraft() async {
    final survey = _survey;
    if (!_dirty || survey == null || _busy || _readOnly) return;
    if (!survey.isDraft && !_editing) return;
    try {
      final updated = await ref.read(siteSurveyRepositoryProvider).saveAnswers(
        surveyId: survey.id,
        answers: _answers,
        submit: false,
        actor: surveyActor(ref.read(authProvider)),
        canUpdateSubmitted: SiteSurveyAccess.canEditSubmitted(ref.read(authProvider)),
      );
      if (!mounted) return;
      setState(() {
        _survey = updated;
        _answers = Map<String, dynamic>.from(updated.answers);
        _dirty = false;
      });
    } catch (_) {
      // Keep dirty; user can retry manually.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = ref.read(authProvider);
      final lookup = await ref.read(siteSurveyRepositoryProvider).getForLead(
        leadId: widget.leadId,
        projectType: widget.projectType,
        canCreate: SiteSurveyAccess.canFillSurvey(auth),
      );
      if (!mounted) return;
      setState(() {
        _lookup = lookup;
        _survey = lookup.survey;
        _answers = Map<String, dynamic>.from(lookup.survey?.answers ?? {});
        _selectedTemplateId =
            lookup.templates.isEmpty ? null : lookup.templates.first.id;
        _loading = false;
        _dirty = false;
        _editing = false;
        _errors = {};
        _formEpoch++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, '$error', isError: true);
    }
  }

  bool get _canFill => SiteSurveyAccess.canFillSurvey(ref.read(authProvider));

  bool get _canEditSubmitted =>
      SiteSurveyAccess.canEditSubmitted(ref.read(authProvider));

  bool get _readOnly {
    final survey = _survey;
    if (survey == null) return true;
    if (!_canFill) return true;
    if (survey.isDraft) return false;
    return !_editing;
  }

  Future<void> _start() async {
    final templateId = _selectedTemplateId;
    if (templateId == null) return;
    setState(() => _busy = true);
    try {
      final survey = await ref.read(siteSurveyRepositoryProvider).startSurvey(
        leadId: widget.leadId,
        templateId: templateId,
        actor: surveyActor(ref.read(authProvider)),
      );
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _answers = {};
        _busy = false;
        _dirty = false;
        _formEpoch++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (error is SiteSurveyFailure && error.statusCode == 409) {
        await _load();
        return;
      }
      showAppMessage(context, '$error', isError: true);
    }
  }

  Future<bool> _save({required bool submit}) async {
    final survey = _survey;
    if (survey == null) return false;
    if (submit || !survey.isDraft) {
      final missing = missingRequired(survey.schema, _answers);
      if (missing.isNotEmpty) {
        setState(() => _errors = missing);
        showAppMessage(
          context,
          'Please complete ${missing.length} required field${missing.length == 1 ? '' : 's'}',
          isError: true,
        );
        _scrollToFirstError(missing.keys);
        return false;
      }
    }
    setState(() => _busy = true);
    try {
      final updated = await ref.read(siteSurveyRepositoryProvider).saveAnswers(
        surveyId: survey.id,
        answers: _answers,
        submit: submit,
        actor: surveyActor(ref.read(authProvider)),
        canUpdateSubmitted: _canEditSubmitted,
      );
      if (!mounted) return false;
      setState(() {
        _survey = updated;
        _answers = Map<String, dynamic>.from(updated.answers);
        _errors = {};
        _dirty = false;
        _busy = false;
        _editing = false;
        _formEpoch++;
      });
      showAppMessage(
        context,
        submit || !updated.isDraft ? 'Survey submitted' : 'Draft saved',
      );
      return true;
    } on SiteSurveyFailure catch (error) {
      if (!mounted) return false;
      setState(() {
        _busy = false;
        _errors = error.fieldErrors;
      });
      showAppMessage(context, error.message, isError: true);
      _scrollToFirstError(error.fieldErrors.keys);
      return false;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _busy = false);
      showAppMessage(context, '$error', isError: true);
      return false;
    }
  }

  void _scrollToFirstError(Iterable<String> ids) {
    final first = ids.cast<String?>().firstWhere(
      (id) => id != null && _keys[id]?.currentContext != null,
      orElse: () => null,
    );
    final key = first == null ? null : _keys[first];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.2);
    }
  }

  Future<void> _discard() async {
    final survey = _survey;
    if (survey == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text(
          'This removes the draft so you can start again with another template.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(siteSurveyRepositoryProvider).discard(survey.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  Future<void> _addPhoto(SurveyField field) async {
    final survey = _survey;
    if (survey == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    try {
      final prepared = await prepareSurveyImage(await picked.readAsBytes());
      final file = await ref.read(siteSurveyRepositoryProvider).saveFile(
        surveyId: survey.id,
        fieldId: field.id,
        kind: 'photo',
        bytes: prepared.$1,
        mimeType: prepared.$2,
      );
      final current = _answers[field.id];
      final ids = current is List ? current.map((e) => '$e').toList() : <String>[];
      ids.add(file.id);
      setState(() {
        _answers[field.id] = ids;
        _dirty = true;
      });
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  Future<void> _sign(SurveyField field) async {
    final survey = _survey;
    if (survey == null) return;
    final padKey = GlobalKey<SignaturePadState>();
    final bytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(field.label),
        content: SizedBox(width: 360, child: SignaturePad(key: padKey)),
        actions: [
          TextButton(
            onPressed: () => padKey.currentState?.clear(),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final png = await padKey.currentState?.export();
              if (png == null || !context.mounted) return;
              Navigator.pop(context, png);
            },
            child: const Text('Use signature'),
          ),
        ],
      ),
    );
    if (bytes == null) return;
    try {
      final prepared = await prepareSurveyImage(bytes);
      final file = await ref.read(siteSurveyRepositoryProvider).saveFile(
        surveyId: survey.id,
        fieldId: field.id,
        kind: 'signature',
        bytes: prepared.$1,
        mimeType: prepared.$2,
      );
      setState(() {
        _answers[field.id] = file.id;
        _dirty = true;
      });
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  Future<void> _location(SurveyField field) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      showAppMessage(
        context,
        'Location permission is needed to capture the site',
        isError: true,
      );
      return;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    setState(() {
      _answers[field.id] = {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      };
      _dirty = true;
    });
  }

  Future<void> _pdf({bool share = false}) async {
    final survey = _survey;
    if (survey == null) return;
    try {
      final bytes = await ref.read(siteSurveyRepositoryProvider).downloadPdf(
        survey: survey.copyWith(answers: _answers),
        leadName: widget.leadName,
      );
      final safe = widget.leadName
          .replaceAll(RegExp(r'[^a-zA-Z0-9\-]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final filename = 'site-survey-${safe.isEmpty ? 'lead' : safe}.pdf';
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/pdf')],
            subject: 'Site survey',
            text: widget.leadName,
          ),
        );
      } else {
        await PdfHelper.saveAndOpen(bytes, filename: filename);
      }
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, '$error', isError: true);
    }
  }

  String _person(SurveyActor? actor) =>
      (actor?.name.trim().isNotEmpty == true)
          ? actor!.name
          : (actor?.email.trim().isNotEmpty == true ? actor!.email : 'Unknown');

  String _when(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final survey = _survey;
    if (survey == null) return _picker();
    final readOnly = _readOnly;
    final submitted = !survey.isDraft;
    for (final field in survey.schema.fields) {
      _keys.putIfAbsent(field.id, GlobalKey.new);
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _autoSaveDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(survey.templateName),
          actions: [
            IconButton(
              tooltip: 'Download PDF',
              onPressed: () => _pdf(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'Share PDF',
              onPressed: () => _pdf(share: true),
              icon: const Icon(Icons.share_outlined),
            ),
            if (submitted && _canEditSubmitted && !_editing)
              IconButton(
                tooltip: 'Edit',
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: Column(
        children: [
          Material(
            color: submitted
                ? const Color(0xFFE7F6EE)
                : const Color(0xFFFFF7E8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submitted
                        ? 'Submitted by ${_person(survey.submitter)} on ${_when(survey.submittedAt)}'
                        : 'Draft started by ${_person(survey.creator)} on ${_when(survey.createdAt)}',
                  ),
                  if (survey.updater != null)
                    Text(
                      'Last saved by ${_person(survey.updater)} on ${_when(survey.updatedAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  Text(
                    '${survey.templateName} · version ${survey.version}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                SurveyFormView(
                  schema: survey.schema,
                  answers: _answers,
                  fieldErrors: _errors,
                  readOnly: readOnly,
                  fieldKeys: _keys,
                  formEpoch: _formEpoch,
                  onChanged: (id, value) => setState(() {
                    if (value == null) {
                      _answers.remove(id);
                    } else {
                      _answers[id] = value;
                    }
                    _dirty = true;
                    _errors.remove(id);
                  }),
                  onAddPhoto: _addPhoto,
                  onRemovePhoto: (field, fileId) {
                    final current = _answers[field.id];
                    if (current is! List) return;
                    setState(() {
                      _answers[field.id] =
                          current.where((id) => '$id' != fileId).toList();
                      _dirty = true;
                    });
                  },
                  onSign: _sign,
                  onCaptureLocation: _location,
                  imageBytes: (fileId) => ref
                      .read(siteSurveyRepositoryProvider)
                      .readFile(survey.id, fileId),
                ),
              ],
            ),
          ),
          if (!readOnly)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _dirty ? 'Unsaved changes' : 'All changes saved',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _dirty
                            ? const Color(0xFFB45309)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (survey.isDraft) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _discard,
                              child: const Text('Discard'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy || !_dirty
                                  ? null
                                  : () => _save(submit: false),
                              child: const Text('Save draft'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Submit survey?'),
                                          content: const Text(
                                            'After submitting, only a manager can edit it.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Submit'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) await _save(submit: true);
                                    },
                              child: Text(_busy ? 'Saving…' : 'Submit'),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _answers = Map<String, dynamic>.from(
                                          survey.answers,
                                        );
                                        _editing = false;
                                        _dirty = false;
                                        _errors = {};
                                        _formEpoch++;
                                      });
                                    },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy || !_dirty
                                  ? null
                                  : () => _save(submit: true),
                              child: Text(_busy ? 'Saving…' : 'Save changes'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _picker() {
    final templates = _lookup?.templates ?? const <TemplateChoice>[];
    final canCreate = _canFill;
    return Scaffold(
      appBar: AppBar(title: const Text('Site survey')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !canCreate
            ? const Center(child: Text('No site survey yet'))
            : templates.isEmpty
            ? const Center(
                child: Text('Ask your admin to publish a survey template.'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose a template. The recommended one is pre-selected.',
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _selectedTemplateId,
                    onChanged: (value) =>
                        setState(() => _selectedTemplateId = value),
                    child: Column(
                      children: [
                        for (final template in templates)
                          RadioListTile<String>(
                            value: template.id,
                            title: Text(template.name),
                            subtitle: Text(
                              '${template.projectTypeLabel} · v${template.currentVersion}'
                              '${template.recommended ? ' · Recommended' : ''}'
                              '${template.isDefault ? ' · Default' : ''}',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _start,
                    child: Text(_busy ? 'Starting…' : 'Start survey'),
                  ),
                ],
              ),
      ),
    );
  }
}

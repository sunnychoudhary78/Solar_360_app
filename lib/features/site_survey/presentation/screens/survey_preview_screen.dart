import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_progress.dart';
import 'package:solar_sales/features/site_survey/data/survey_validation.dart';
import 'package:solar_sales/features/site_survey/presentation/survey_capture.dart';
import 'package:solar_sales/features/site_survey/presentation/widgets/survey_form_view.dart';

class SurveyPreviewScreen extends StatefulWidget {
  const SurveyPreviewScreen({super.key, required this.name, required this.schema});

  final String name;
  final SurveySchema schema;

  @override
  State<SurveyPreviewScreen> createState() => _SurveyPreviewScreenState();
}

class _SurveyPreviewScreenState extends State<SurveyPreviewScreen> {
  final Map<String, dynamic> _answers = {};
  final Map<String, Uint8List> _files = {};
  final Map<String, GlobalKey> _keys = {};
  Map<String, String> _errors = {};
  var _fileSeq = 0;
  var _formEpoch = 0;

  @override
  void initState() {
    super.initState();
    for (final field in widget.schema.fields) {
      _keys[field.id] = GlobalKey();
    }
  }

  String _nextFileId() => 'preview_${++_fileSeq}';

  Future<void> _addPhoto(SurveyField field) async {
    final bytes = await SurveyCapture.pickPreparedImage(context);
    if (bytes == null || !mounted) return;
    final id = _nextFileId();
    final current = _answers[field.id];
    final ids = current is List ? current.map((e) => '$e').toList() : <String>[];
    ids.add(id);
    setState(() {
      _files[id] = bytes;
      _answers[field.id] = ids;
      _errors.remove(field.id);
    });
  }

  void _removePhoto(SurveyField field, String fileId) {
    final current = _answers[field.id];
    if (current is! List) return;
    setState(() {
      _files.remove(fileId);
      _answers[field.id] = current.where((id) => '$id' != fileId).toList();
      _errors.remove(field.id);
    });
  }

  Future<void> _sign(SurveyField field) async {
    final bytes = await SurveyCapture.captureSignature(
      context,
      title: field.label,
    );
    if (bytes == null || !mounted) return;
    final previous = _answers[field.id];
    if (previous is String) _files.remove(previous);
    final id = _nextFileId();
    setState(() {
      _files[id] = bytes;
      _answers[field.id] = id;
      _errors.remove(field.id);
    });
  }

  Future<void> _location(SurveyField field) async {
    final value = await SurveyCapture.captureLocation(context);
    if (value == null || !mounted) return;
    setState(() {
      _answers[field.id] = value;
      _errors.remove(field.id);
    });
  }

  void _testSubmit() {
    final errors = validateAnswers(
      schema: widget.schema,
      answers: _answers,
      submit: true,
      fileBelongs: (fieldId, fileId) => _files.containsKey(fileId),
    );
    setState(() {
      _errors = errors;
      _formEpoch++;
    });

    if (errors.isEmpty) {
      final progress = answerProgress(widget.schema, _answers);
      showAppMessage(
        context,
        progress.total == 0
            ? 'Template has no fields to test yet'
            : 'All fields look good — ready to save or publish',
      );
      return;
    }

    showAppMessage(
      context,
      '${errors.length} field${errors.length == 1 ? '' : 's'} need attention',
      isError: true,
    );

    final firstId = errors.keys.first;
    final contextForField = _keys[firstId]?.currentContext;
    if (contextForField != null) {
      Scrollable.ensureVisible(
        contextForField,
        duration: const Duration(milliseconds: 280),
        alignment: 0.15,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name.trim().isEmpty ? 'Test form' : widget.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Test your fields here before publishing. Answers are not saved.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SurveyFormView(
                  schema: widget.schema,
                  answers: _answers,
                  fieldErrors: _errors,
                  readOnly: false,
                  fieldKeys: _keys,
                  formEpoch: _formEpoch,
                  onChanged: (id, value) => setState(() {
                    if (value == null) {
                      _answers.remove(id);
                    } else {
                      _answers[id] = value;
                    }
                    _errors.remove(id);
                  }),
                  onAddPhoto: _addPhoto,
                  onRemovePhoto: _removePhoto,
                  onSign: _sign,
                  onCaptureLocation: _location,
                  imageBytes: (fileId) async => _files[fileId],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _testSubmit,
                        icon: const Icon(Icons.playlist_add_check_rounded),
                        label: const Text('Test submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

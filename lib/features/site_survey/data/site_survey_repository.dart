import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/site_survey_config.dart';
import 'package:solar_sales/features/site_survey/data/site_survey_local_store.dart';
import 'package:solar_sales/features/site_survey/data/starter_templates.dart';
import 'package:solar_sales/features/site_survey/data/survey_validation.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';

class SiteSurveyRepository {
  SiteSurveyRepository(this._api);

  final ApiService _api;
  final Map<String, Uint8List> _fileCache = {};

  bool get useLocal => kSiteSurveyUseLocalStore;

  SiteSurveyFailure _asSurveyFailure(Object error) {
    if (error is SiteSurveyFailure) return error;
    if (error is ApiException) {
      return SiteSurveyFailure(
        error.message,
        statusCode: error.statusCode,
        fieldErrors: error.fieldErrors,
      );
    }
    return SiteSurveyFailure('$error');
  }

  Future<List<SurveyTemplate>> listTemplates() async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      return db.templates.where((t) => t.isActive).toList();
    }
    final data = await _api.get(ApiEndpoints.surveyTemplates);
    final list = data is List
        ? data
        : (data is Map ? (data['templates'] ?? data['data']) : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => SurveyTemplate.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.isActive)
        .toList();
  }

  Future<SurveyTemplate> createTemplate({
    required String name,
    String description = '',
    String? projectType,
    required SurveyActor actor,
  }) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final now = DateTime.now().toUtc().toIso8601String();
      final template = SurveyTemplate(
        id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        description: description.trim(),
        projectType: projectType,
        draftSchema: const SurveySchema(
          sections: [SurveySection(id: 'section_1', title: 'Section 1')],
        ),
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      );
      db.templates.insert(0, template);
      await SiteSurveyLocalStore.instance.save(db);
      return template;
    }
    try {
      final data = await _api.post(ApiEndpoints.surveyTemplates, {
        'name': name.trim(),
        'description': description.trim(),
        'project_type': projectType,
      });
      return SurveyTemplate.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<SurveyTemplate> getTemplate(String id) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final template = db.templates.cast<SurveyTemplate?>().firstWhere(
        (t) => t!.id == id && t.isActive,
        orElse: () => null,
      );
      if (template == null) {
        throw const SiteSurveyFailure('Template not found', statusCode: 404);
      }
      return template;
    }
    try {
      final data = await _api.get(ApiEndpoints.surveyTemplate(id));
      return SurveyTemplate.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<SurveyTemplate> saveDraft({
    required String id,
    required String name,
    required String description,
    String? projectType,
    required SurveySchema schema,
    required SurveyActor actor,
  }) async {
    final schemaError = validateSchema(schema);
    if (useLocal && schemaError != null) {
      throw SiteSurveyFailure(schemaError);
    }
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final index = db.templates.indexWhere((t) => t.id == id);
      if (index < 0) throw const SiteSurveyFailure('Template not found', statusCode: 404);
      final current = db.templates[index];
      final updated = current.copyWith(
        name: name.trim(),
        description: description.trim(),
        projectType: projectType,
        clearProjectType: projectType == null || projectType.isEmpty,
        draftSchema: schema,
        hasUnpublishedChanges: current.isPublished,
        updater: actor,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      db.templates[index] = updated;
      await SiteSurveyLocalStore.instance.save(db);
      return updated;
    }
    try {
      final data = await _api.put(ApiEndpoints.surveyTemplate(id), {
        'name': name.trim(),
        'description': description.trim(),
        'project_type': projectType,
        'draft_schema': schema.toJson(),
      });
      return SurveyTemplate.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<SurveyTemplate> publish(String id, SurveyActor actor) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final index = db.templates.indexWhere((t) => t.id == id);
      if (index < 0) throw const SiteSurveyFailure('Template not found', statusCode: 404);
      final current = db.templates[index];
      final schemaError = validateSchema(current.draftSchema);
      if (schemaError != null) throw SiteSurveyFailure(schemaError);
      if (current.draftSchema.fieldCount == 0) {
        throw const SiteSurveyFailure('Add at least one field before publishing');
      }
      final nextVersion = current.currentVersion + 1;
      final typeKey = current.projectType ?? '';
      final hasDefault = db.templates.any(
        (t) =>
            t.id != id &&
            t.isActive &&
            t.isPublished &&
            t.isDefault &&
            (t.projectType ?? '') == typeKey,
      );
      final updated = current.copyWith(
        currentVersion: nextVersion,
        isPublished: true,
        hasUnpublishedChanges: false,
        publishedSchema: current.draftSchema,
        isDefault: current.isDefault || !hasDefault,
        updater: actor,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      db.templates[index] = updated;
      await SiteSurveyLocalStore.instance.save(db);
      return updated;
    }
    try {
      final data = await _api.post(ApiEndpoints.surveyTemplatePublish(id));
      return SurveyTemplate.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<void> addStarterTemplates(SurveyActor actor) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final now = DateTime.now().toUtc().toIso8601String();
      final existingNames = db.templates.map((t) => t.name.toLowerCase()).toSet();
      void add(String name, String description, String projectType, SurveySchema schema) {
        if (existingNames.contains(name.toLowerCase())) return;
        final hasDefault = db.templates.any(
          (t) => t.isActive && t.isPublished && t.isDefault && t.projectType == projectType,
        );
        db.templates.insert(
          0,
          SurveyTemplate(
            id: 'tpl_${DateTime.now().microsecondsSinceEpoch}_${projectType.toLowerCase()}',
            name: name,
            description: description,
            projectType: projectType,
            isDefault: !hasDefault,
            currentVersion: 1,
            isPublished: true,
            draftSchema: schema,
            publishedSchema: schema,
            creator: actor,
            updater: actor,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      add(
        'Residential Site Survey',
        'Rooftop survey for homes',
        'Residential',
        residentialStarterSchema(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      add(
        'Commercial Site Survey',
        'Survey for shops, offices and commercial buildings',
        'Commercial',
        commercialStarterSchema(),
      );
      await SiteSurveyLocalStore.instance.save(db);
      return;
    }
    await _api.post(ApiEndpoints.surveyTemplateStarter);
  }

  Future<SurveyTemplate> duplicate(String id, SurveyActor actor) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final source = db.templates.cast<SurveyTemplate?>().firstWhere(
        (t) => t!.id == id,
        orElse: () => null,
      );
      if (source == null) throw const SiteSurveyFailure('Template not found', statusCode: 404);
      final now = DateTime.now().toUtc().toIso8601String();
      final copy = SurveyTemplate(
        id: 'tpl_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Copy of ${source.name}',
        description: source.description,
        projectType: source.projectType,
        draftSchema: source.draftSchema,
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      );
      db.templates.insert(0, copy);
      await SiteSurveyLocalStore.instance.save(db);
      return copy;
    }
    final data = await _api.post(ApiEndpoints.surveyTemplateDuplicate(id));
    return SurveyTemplate.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> setDefault(String id) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final index = db.templates.indexWhere((t) => t.id == id);
      if (index < 0) throw const SiteSurveyFailure('Template not found', statusCode: 404);
      final current = db.templates[index];
      if (!current.isPublished) {
        throw const SiteSurveyFailure('Publish the template before making it the default');
      }
      final typeKey = current.projectType ?? '';
      db.templates = [
        for (final template in db.templates)
          if ((template.projectType ?? '') == typeKey)
            template.copyWith(isDefault: template.id == id)
          else
            template,
      ];
      await SiteSurveyLocalStore.instance.save(db);
      return;
    }
    await _api.post(ApiEndpoints.surveyTemplateSetDefault(id));
  }

  Future<void> deactivate(String id) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final index = db.templates.indexWhere((t) => t.id == id);
      if (index < 0) return;
      db.templates[index] = db.templates[index].copyWith(isActive: false, isDefault: false);
      await SiteSurveyLocalStore.instance.save(db);
      return;
    }
    await _api.post(ApiEndpoints.surveyTemplateDeactivate(id));
  }

  Future<LeadSurveyLookup> getForLead({
    required String leadId,
    required String projectType,
    required bool canCreate,
  }) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final survey = db.surveys.cast<SiteSurveyRecord?>().firstWhere(
        (s) => s!.leadId == leadId,
        orElse: () => null,
      );
      if (survey != null) {
        return LeadSurveyLookup(leadId: leadId, projectType: projectType, survey: survey);
      }
      if (!canCreate) {
        return LeadSurveyLookup(leadId: leadId, projectType: projectType);
      }
      final choices = _sortedChoices(db.templates, projectType);
      return LeadSurveyLookup(
        leadId: leadId,
        projectType: projectType,
        templates: choices,
      );
    }
    try {
      final data = await _api.get(ApiEndpoints.siteSurveyByLead(leadId));
      final map = Map<String, dynamic>.from(data as Map);
      final surveyJson = map['survey'];
      final templatesJson = map['templates'];
      final lead = map['lead'] is Map ? map['lead'] as Map : const {};
      return LeadSurveyLookup(
        leadId: leadId,
        projectType: '${lead['project_type'] ?? projectType}',
        survey: surveyJson is Map
            ? SiteSurveyRecord.fromJson(Map<String, dynamic>.from(surveyJson))
            : null,
        templates: templatesJson is List
            ? templatesJson
                  .whereType<Map>()
                  .map((e) => TemplateChoice.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
            : const [],
      );
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<SiteSurveyRecord> startSurvey({
    required String leadId,
    required String templateId,
    required SurveyActor actor,
  }) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      if (db.surveys.any((s) => s.leadId == leadId)) {
        throw const SiteSurveyFailure('This lead already has a site survey', statusCode: 409);
      }
      final template = db.templates.cast<SurveyTemplate?>().firstWhere(
        (t) => t!.id == templateId && t.isActive,
        orElse: () => null,
      );
      if (template == null) {
        throw const SiteSurveyFailure('Template not found', statusCode: 404);
      }
      if (!template.isPublished || template.publishedSchema == null) {
        throw const SiteSurveyFailure('Template is not published', statusCode: 400);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final survey = SiteSurveyRecord(
        id: 'svy_${DateTime.now().microsecondsSinceEpoch}',
        leadId: leadId,
        status: 'draft',
        answers: const {},
        templateId: template.id,
        templateName: template.name,
        templateProjectType: template.projectType,
        version: template.currentVersion,
        schema: template.publishedSchema!,
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      );
      db.surveys.add(survey);
      await SiteSurveyLocalStore.instance.save(db);
      return survey;
    }
    try {
      final data = await _api.post(ApiEndpoints.siteSurveyByLead(leadId), {
        'templateId': templateId,
      });
      return SiteSurveyRecord.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<SiteSurveyRecord> saveAnswers({
    required String surveyId,
    required Map<String, dynamic> answers,
    required bool submit,
    required SurveyActor actor,
    required bool canUpdateSubmitted,
  }) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final index = db.surveys.indexWhere((s) => s.id == surveyId);
      if (index < 0) throw const SiteSurveyFailure('Survey not found', statusCode: 404);
      final current = db.surveys[index];
      final alreadySubmitted = !current.isDraft;
      if (alreadySubmitted && !canUpdateSubmitted) {
        throw const SiteSurveyFailure(
          'You cannot edit a submitted survey',
          statusCode: 403,
        );
      }
      final cleaned = dropHiddenAnswers(current.schema, answers);
      final mustValidate = submit || alreadySubmitted;
      final errors = validateAnswers(
        schema: current.schema,
        answers: cleaned,
        submit: mustValidate,
        fileBelongs: (fieldId, fileId) => db.files.any(
          (file) => file.id == fileId && file.surveyId == surveyId && file.fieldId == fieldId,
        ),
      );
      if (errors.isNotEmpty) {
        throw SiteSurveyFailure(
          'Please complete ${errors.length} highlighted field${errors.length == 1 ? '' : 's'}',
          statusCode: 400,
          fieldErrors: errors,
        );
      }
      if (mustValidate) _deleteUnreferencedFiles(db, surveyId, cleaned);
      final now = DateTime.now().toUtc().toIso8601String();
      final updated = current.copyWith(
        answers: cleaned,
        status: mustValidate ? 'submitted' : 'draft',
        submittedAt: mustValidate ? (current.submittedAt ?? now) : null,
        submitter: mustValidate ? (current.submitter ?? actor) : null,
        clearSubmittedAt: !mustValidate,
        clearSubmitter: !mustValidate,
        updater: actor,
        updatedAt: now,
      );
      db.surveys[index] = updated;
      await SiteSurveyLocalStore.instance.save(db);
      return updated;
    }
    try {
      final data = await _api.put(ApiEndpoints.siteSurvey(surveyId), {
        'answers': answers,
        'submit': submit,
      });
      return SiteSurveyRecord.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<void> discard(String surveyId) async {
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final survey = db.surveys.cast<SiteSurveyRecord?>().firstWhere(
        (s) => s!.id == surveyId,
        orElse: () => null,
      );
      if (survey == null) return;
      if (!survey.isDraft) {
        throw const SiteSurveyFailure('Only a draft can be discarded');
      }
      db.surveys.removeWhere((s) => s.id == surveyId);
      final doomed = db.files.where((f) => f.surveyId == surveyId).toList();
      db.files.removeWhere((f) => f.surveyId == surveyId);
      await SiteSurveyLocalStore.instance.save(db);
      for (final file in doomed) {
        final io = File(file.path);
        if (await io.exists()) await io.delete();
      }
      return;
    }
    await _api.post(ApiEndpoints.siteSurveyDiscard(surveyId));
  }

  Future<SurveyFileRecord> saveFile({
    required String surveyId,
    required String fieldId,
    required String kind,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.length > 8 * 1024 * 1024) {
      throw const SiteSurveyFailure('Each photo must be 8 MB or smaller', statusCode: 413);
    }
    if (mimeType != 'image/jpeg' && mimeType != 'image/png') {
      throw const SiteSurveyFailure('Use a JPEG or PNG image');
    }
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      if (db.files.where((f) => f.surveyId == surveyId).length >= 300) {
        throw const SiteSurveyFailure('This survey already has 300 files');
      }
      final id = 'file_${DateTime.now().microsecondsSinceEpoch}';
      final dir = await SiteSurveyLocalStore.instance.filesDirectory();
      final ext = mimeType == 'image/png' ? 'png' : 'jpg';
      final path = '${dir.path}/$id.$ext';
      await File(path).writeAsBytes(bytes, flush: true);
      final record = SurveyFileRecord(
        id: id,
        surveyId: surveyId,
        fieldId: fieldId,
        kind: kind,
        path: path,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
      db.files.add(record);
      await SiteSurveyLocalStore.instance.save(db);
      return record;
    }
    try {
      final form = FormData.fromMap({
        'fieldId': fieldId,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: mimeType == 'image/png' ? 'upload.png' : 'upload.jpg',
        ),
      });
      final data = await _api.postFormData(ApiEndpoints.siteSurveyFiles(surveyId), form);
      final map = Map<String, dynamic>.from(data as Map);
      final record = SurveyFileRecord(
        id: '${map['id']}',
        surveyId: surveyId,
        fieldId: '${map['field_id'] ?? fieldId}',
        kind: '${map['kind'] ?? kind}',
        path: '',
        mimeType: '${map['mime_type'] ?? mimeType}',
        sizeBytes: map['size_bytes'] is num
            ? (map['size_bytes'] as num).toInt()
            : bytes.length,
      );
      _fileCache['$surveyId:${record.id}'] = bytes;
      return record;
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<Uint8List?> readFile(String surveyId, String fileId) async {
    final cacheKey = '$surveyId:$fileId';
    final cached = _fileCache[cacheKey];
    if (cached != null) return cached;
    if (useLocal) {
      final db = await SiteSurveyLocalStore.instance.load();
      final file = db.files.cast<SurveyFileRecord?>().firstWhere(
        (f) => f!.id == fileId && f.surveyId == surveyId,
        orElse: () => null,
      );
      if (file == null) return null;
      final io = File(file.path);
      if (!await io.exists()) return null;
      final bytes = await io.readAsBytes();
      _fileCache[cacheKey] = bytes;
      return bytes;
    }
    try {
      final bytes = await _api.getBytes(ApiEndpoints.siteSurveyFile(surveyId, fileId));
      _fileCache[cacheKey] = bytes;
      return bytes;
    } catch (error) {
      throw _asSurveyFailure(error);
    }
  }

  Future<Uint8List> downloadPdf({
    required SiteSurveyRecord survey,
    required String leadName,
  }) async {
    if (!useLocal) {
      return _api.getBytes(ApiEndpoints.siteSurveyPdf(survey.id));
    }
    return _buildPdf(survey, leadName);
  }

  Future<Uint8List> _buildPdf(SiteSurveyRecord survey, String leadName) async {
    final db = await SiteSurveyLocalStore.instance.load();
    final visible = visibleFieldIds(survey.schema, survey.answers);
    final doc = pw.Document();
    final widgets = <pw.Widget>[
      pw.Text('Site survey', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(leadName),
      pw.Text('${survey.templateName} · v${survey.version}'),
      pw.Text('Status: ${survey.status}'),
      pw.SizedBox(height: 12),
    ];
    for (final section in survey.schema.sections) {
      if (!sectionIsVisible(section, survey.answers, visible)) continue;
      widgets.add(
        pw.Text(section.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );
      widgets.add(pw.SizedBox(height: 4));
      for (final field in section.fields) {
        if (!visible.contains(field.id)) continue;
        final value = survey.answers[field.id];
        widgets.add(pw.Text('${field.label}: ${_pdfValue(value)}'));
        if (field.type == 'photo' && value is List) {
          for (final id in value) {
            final image = await _pdfImage(db, survey.id, '$id');
            if (image != null) {
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(pw.Image(image, height: 140, fit: pw.BoxFit.contain));
            }
          }
        }
        if (field.type == 'signature' && value is String) {
          final image = await _pdfImage(db, survey.id, value);
          if (image != null) {
            widgets.add(pw.SizedBox(height: 4));
            widgets.add(pw.Image(image, height: 80, fit: pw.BoxFit.contain));
          }
        }
      }
      widgets.add(pw.SizedBox(height: 10));
    }
    doc.addPage(pw.MultiPage(build: (context) => widgets));
    return doc.save();
  }

  Future<pw.MemoryImage?> _pdfImage(SiteSurveyDatabase db, String surveyId, String fileId) async {
    final file = db.files.cast<SurveyFileRecord?>().firstWhere(
      (item) => item!.id == fileId && item.surveyId == surveyId,
      orElse: () => null,
    );
    if (file == null) return null;
    final io = File(file.path);
    if (!await io.exists()) return null;
    return pw.MemoryImage(await io.readAsBytes());
  }

  String _pdfValue(dynamic value) {
    if (isEmptyAnswer(value)) return 'Not answered';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.isEmpty ? 'Not answered' : '${value.length} file(s)';
    if (value is Map && value['lat'] != null) return '${value['lat']}, ${value['lng']}';
    return '$value';
  }

  List<TemplateChoice> _sortedChoices(List<SurveyTemplate> templates, String projectType) {
    final published = templates.where((t) => t.isActive && t.isPublished).toList();
    int rank(SurveyTemplate template) {
      final type = template.projectType ?? '';
      final same = type.isNotEmpty && type.toLowerCase() == projectType.toLowerCase();
      final any = type.isEmpty;
      if (template.isDefault && same) return 0;
      if (same) return 1;
      if (template.isDefault && any) return 2;
      if (any) return 3;
      return 4;
    }

    published.sort((a, b) => rank(a).compareTo(rank(b)));
    final best = published.isEmpty ? 99 : rank(published.first);
    return [
      for (final template in published)
        TemplateChoice(
          id: template.id,
          name: template.name,
          projectType: template.projectType,
          isDefault: template.isDefault,
          currentVersion: template.currentVersion,
          recommended: rank(template) == best && template.isDefault,
        ),
    ];
  }

  void _deleteUnreferencedFiles(
    SiteSurveyDatabase db,
    String surveyId,
    Map<String, dynamic> answers,
  ) {
    final referenced = <String>{};
    for (final value in answers.values) {
      if (value is List) {
        referenced.addAll(value.map((e) => '$e'));
      } else if (value is String) {
        referenced.add(value);
      }
    }
    final doomed = db.files
        .where((f) => f.surveyId == surveyId && !referenced.contains(f.id))
        .toList();
    db.files.removeWhere((f) => doomed.any((d) => d.id == f.id));
    for (final file in doomed) {
      final io = File(file.path);
      if (io.existsSync()) io.deleteSync();
    }
  }
}


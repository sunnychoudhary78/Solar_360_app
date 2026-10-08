import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/starter_templates.dart';

class SiteSurveyDatabase {
  SiteSurveyDatabase();
  List<SurveyTemplate> templates = [];
  List<SiteSurveyRecord> surveys = [];
  List<SurveyFileRecord> files = [];

  Map<String, dynamic> toJson() => {
    'templates': templates.map((t) => t.toJson()).toList(),
    'surveys': surveys.map((s) => s.toJson()).toList(),
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory SiteSurveyDatabase.fromJson(Map<String, dynamic> json) {
    final db = SiteSurveyDatabase();
    final templates = json['templates'];
    final surveys = json['surveys'];
    final files = json['files'];
    if (templates is List) {
      db.templates = templates
          .whereType<Map>()
          .map((e) => SurveyTemplate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (surveys is List) {
      db.surveys = surveys
          .whereType<Map>()
          .map((e) => SiteSurveyRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (files is List) {
      db.files = files
          .whereType<Map>()
          .map((e) => SurveyFileRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return db;
  }
}

class SiteSurveyLocalStore {
  SiteSurveyLocalStore._();
  static final SiteSurveyLocalStore instance = SiteSurveyLocalStore._();

  Future<SiteSurveyDatabase>? _loading;

  Future<SiteSurveyDatabase> load() {
    return _loading ??= _read();
  }

  Future<void> save(SiteSurveyDatabase db) async {
    final file = await _dbFile();
    await file.writeAsString(jsonEncode(db.toJson()));
    _loading = Future.value(db);
  }

  Future<Directory> filesDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/site_survey_files');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _dbFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/site_survey_db.json');
  }

  Future<SiteSurveyDatabase> _read() async {
    final file = await _dbFile();
    if (!await file.exists()) {
      final seeded = _seed();
      await file.writeAsString(jsonEncode(seeded.toJson()));
      return seeded;
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) return SiteSurveyDatabase.fromJson(raw);
      if (raw is Map) return SiteSurveyDatabase.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {}
    return _seed();
  }

  SiteSurveyDatabase _seed() {
    final now = DateTime.now().toUtc().toIso8601String();
    final actor = const SurveyActor(id: 'local', name: 'Deepanshu', email: '');
    final residential = residentialStarterSchema();
    final commercial = commercialStarterSchema();
    final db = SiteSurveyDatabase();
    db.templates = [
      SurveyTemplate(
        id: 'tpl_commercial',
        name: 'Commercial Site Survey',
        description: 'Survey for shops, offices and commercial buildings',
        projectType: 'Commercial',
        isDefault: true,
        currentVersion: 1,
        isPublished: true,
        draftSchema: commercial,
        publishedSchema: commercial,
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      ),
      SurveyTemplate(
        id: 'tpl_residential',
        name: 'Residential Site Survey',
        description: 'Rooftop survey for homes',
        projectType: 'Residential',
        isDefault: true,
        currentVersion: 1,
        isPublished: true,
        draftSchema: residential,
        publishedSchema: residential,
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      ),
      SurveyTemplate(
        id: 'tpl_test',
        name: 'test',
        description: '',
        projectType: null,
        isDefault: false,
        currentVersion: 0,
        isPublished: false,
        draftSchema: const SurveySchema(
          sections: [SurveySection(id: 'section_1', title: 'Section 1')],
        ),
        creator: actor,
        updater: actor,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    return db;
  }
}

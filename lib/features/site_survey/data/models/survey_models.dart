class SurveyActor {
  final String id;
  final String name;
  final String email;

  const SurveyActor({
    required this.id,
    required this.name,
    required this.email,
  });

  factory SurveyActor.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    return SurveyActor(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      email: '${map['email'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class ShowIfRule {
  final String field;
  final String op;
  final Object? value;

  const ShowIfRule({required this.field, required this.op, this.value});

  factory ShowIfRule.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    return ShowIfRule(
      field: '${map['field'] ?? ''}',
      op: '${map['op'] ?? 'equals'}',
      value: map['value'],
    );
  }

  Map<String, dynamic> toJson() => {
    'field': field,
    'op': op,
    if (value != null) 'value': value,
  };

  ShowIfRule copyWith({String? field, String? op, Object? value, bool clearValue = false}) {
    return ShowIfRule(
      field: field ?? this.field,
      op: op ?? this.op,
      value: clearValue ? null : (value ?? this.value),
    );
  }
}

class SurveyField {
  final String id;
  final String type;
  final String label;
  final bool required;
  final String? helpText;
  final String? placeholder;
  final num? min;
  final num? max;
  final String? unit;
  final List<String> options;
  final int? maxPhotos;
  final ShowIfRule? showIf;

  const SurveyField({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.helpText,
    this.placeholder,
    this.min,
    this.max,
    this.unit,
    this.options = const [],
    this.maxPhotos,
    this.showIf,
  });

  factory SurveyField.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return SurveyField(
      id: '${json['id'] ?? ''}',
      type: '${json['type'] ?? 'text'}',
      label: '${json['label'] ?? ''}',
      required: json['required'] == true,
      helpText: _nullableString(json['helpText']),
      placeholder: _nullableString(json['placeholder']),
      min: json['min'] is num ? json['min'] as num : num.tryParse('${json['min'] ?? ''}'),
      max: json['max'] is num ? json['max'] as num : num.tryParse('${json['max'] ?? ''}'),
      unit: _nullableString(json['unit']),
      options: rawOptions is List
          ? rawOptions.map((e) => '$e').where((e) => e.isNotEmpty).toList()
          : const [],
      maxPhotos: json['maxPhotos'] is num ? (json['maxPhotos'] as num).toInt() : null,
      showIf: json['showIf'] is Map ? ShowIfRule.fromJson(json['showIf']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    'required': required,
    if (helpText != null && helpText!.isNotEmpty) 'helpText': helpText,
    if (placeholder != null && placeholder!.isNotEmpty) 'placeholder': placeholder,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (unit != null && unit!.isNotEmpty) 'unit': unit,
    if (options.isNotEmpty) 'options': options,
    if (type == 'photo') 'maxPhotos': maxPhotos ?? 5,
    if (showIf != null) 'showIf': showIf!.toJson(),
  };

  SurveyField copyWith({
    String? id,
    String? type,
    String? label,
    bool? required,
    String? helpText,
    String? placeholder,
    num? min,
    num? max,
    String? unit,
    List<String>? options,
    int? maxPhotos,
    ShowIfRule? showIf,
    bool clearShowIf = false,
    bool clearMin = false,
    bool clearMax = false,
  }) {
    return SurveyField(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      required: required ?? this.required,
      helpText: helpText ?? this.helpText,
      placeholder: placeholder ?? this.placeholder,
      min: clearMin ? null : (min ?? this.min),
      max: clearMax ? null : (max ?? this.max),
      unit: unit ?? this.unit,
      options: options ?? this.options,
      maxPhotos: maxPhotos ?? this.maxPhotos,
      showIf: clearShowIf ? null : (showIf ?? this.showIf),
    );
  }
}

class SurveySection {
  final String id;
  final String title;
  final String? description;
  final ShowIfRule? showIf;
  final List<SurveyField> fields;

  const SurveySection({
    required this.id,
    required this.title,
    this.description,
    this.showIf,
    this.fields = const [],
  });

  factory SurveySection.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    return SurveySection(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      description: _nullableString(json['description']),
      showIf: json['showIf'] is Map ? ShowIfRule.fromJson(json['showIf']) : null,
      fields: rawFields is List
          ? rawFields
                .whereType<Map>()
                .map((e) => SurveyField.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (description != null && description!.isNotEmpty) 'description': description,
    if (showIf != null) 'showIf': showIf!.toJson(),
    'fields': fields.map((f) => f.toJson()).toList(),
  };

  SurveySection copyWith({
    String? id,
    String? title,
    String? description,
    ShowIfRule? showIf,
    List<SurveyField>? fields,
    bool clearShowIf = false,
  }) {
    return SurveySection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      showIf: clearShowIf ? null : (showIf ?? this.showIf),
      fields: fields ?? this.fields,
    );
  }
}

class SurveySchema {
  final List<SurveySection> sections;

  const SurveySchema({this.sections = const []});

  factory SurveySchema.fromJson(dynamic json) {
    final map = json is Map ? json : const {};
    final raw = map['sections'];
    return SurveySchema(
      sections: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => SurveySection.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  int get fieldCount => sections.fold(0, (sum, s) => sum + s.fields.length);

  List<SurveyField> get fields => [
    for (final section in sections) ...section.fields,
  ];

  SurveySchema copyWith({List<SurveySection>? sections}) {
    return SurveySchema(sections: sections ?? this.sections);
  }
}

class SurveyTemplate {
  final String id;
  final String name;
  final String description;
  final String? projectType;
  final bool isDefault;
  final int currentVersion;
  final bool isPublished;
  final bool hasUnpublishedChanges;
  final bool isActive;
  final SurveySchema draftSchema;
  final SurveySchema? publishedSchema;
  final SurveyActor? creator;
  final SurveyActor? updater;
  final String createdAt;
  final String updatedAt;

  const SurveyTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.projectType,
    this.isDefault = false,
    this.currentVersion = 0,
    this.isPublished = false,
    this.hasUnpublishedChanges = false,
    this.isActive = true,
    this.draftSchema = const SurveySchema(),
    this.publishedSchema,
    this.creator,
    this.updater,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SurveyTemplate.fromJson(Map<String, dynamic> json) {
    return SurveyTemplate(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      projectType: _nullableString(json['project_type'] ?? json['projectType']),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      currentVersion: json['current_version'] is num
          ? (json['current_version'] as num).toInt()
          : int.tryParse('${json['current_version'] ?? 0}') ?? 0,
      isPublished: json['is_published'] == true || json['isPublished'] == true,
      hasUnpublishedChanges:
          json['has_unpublished_changes'] == true ||
          json['hasUnpublishedChanges'] == true,
      isActive: json['is_active'] != false && json['isActive'] != false,
      draftSchema: SurveySchema.fromJson(json['draft_schema'] ?? json['draftSchema']),
      publishedSchema: json['published_schema'] == null && json['publishedSchema'] == null
          ? null
          : SurveySchema.fromJson(json['published_schema'] ?? json['publishedSchema']),
      creator: json['creator'] is Map ? SurveyActor.fromJson(json['creator']) : null,
      updater: json['updater'] is Map ? SurveyActor.fromJson(json['updater']) : null,
      createdAt: '${json['created_at'] ?? json['createdAt'] ?? ''}',
      updatedAt: '${json['updated_at'] ?? json['updatedAt'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'project_type': projectType,
    'is_default': isDefault,
    'current_version': currentVersion,
    'is_published': isPublished,
    'has_unpublished_changes': hasUnpublishedChanges,
    'is_active': isActive,
    'field_count': draftSchema.fieldCount,
    'draft_schema': draftSchema.toJson(),
    'published_schema': publishedSchema?.toJson(),
    'creator': creator?.toJson(),
    'updater': updater?.toJson(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  String get projectTypeLabel =>
      (projectType == null || projectType!.trim().isEmpty) ? 'Any project' : projectType!;

  SurveyTemplate copyWith({
    String? name,
    String? description,
    String? projectType,
    bool clearProjectType = false,
    bool? isDefault,
    int? currentVersion,
    bool? isPublished,
    bool? hasUnpublishedChanges,
    bool? isActive,
    SurveySchema? draftSchema,
    SurveySchema? publishedSchema,
    SurveyActor? updater,
    String? updatedAt,
  }) {
    return SurveyTemplate(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      projectType: clearProjectType ? null : (projectType ?? this.projectType),
      isDefault: isDefault ?? this.isDefault,
      currentVersion: currentVersion ?? this.currentVersion,
      isPublished: isPublished ?? this.isPublished,
      hasUnpublishedChanges: hasUnpublishedChanges ?? this.hasUnpublishedChanges,
      isActive: isActive ?? this.isActive,
      draftSchema: draftSchema ?? this.draftSchema,
      publishedSchema: publishedSchema ?? this.publishedSchema,
      creator: creator,
      updater: updater ?? this.updater,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TemplateChoice {
  final String id;
  final String name;
  final String? projectType;
  final bool isDefault;
  final int currentVersion;
  final bool recommended;

  const TemplateChoice({
    required this.id,
    required this.name,
    this.projectType,
    this.isDefault = false,
    this.currentVersion = 1,
    this.recommended = false,
  });

  factory TemplateChoice.fromJson(Map<String, dynamic> json) {
    return TemplateChoice(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      projectType: _nullableString(json['project_type'] ?? json['projectType']),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      currentVersion: json['current_version'] is num
          ? (json['current_version'] as num).toInt()
          : int.tryParse('${json['current_version'] ?? 1}') ?? 1,
      recommended: json['recommended'] == true || json['recommended'] == 1,
    );
  }

  String get projectTypeLabel =>
      (projectType == null || projectType!.trim().isEmpty) ? 'Any project' : projectType!;
}

class SiteSurveyRecord {
  final String id;
  final String leadId;
  final String status;
  final Map<String, dynamic> answers;
  final String templateId;
  final String templateName;
  final String? templateProjectType;
  final int version;
  final SurveySchema schema;
  final String? submittedAt;
  final SurveyActor? submitter;
  final SurveyActor? creator;
  final SurveyActor? updater;
  final String createdAt;
  final String updatedAt;

  const SiteSurveyRecord({
    required this.id,
    required this.leadId,
    required this.status,
    required this.answers,
    required this.templateId,
    required this.templateName,
    this.templateProjectType,
    required this.version,
    required this.schema,
    this.submittedAt,
    this.submitter,
    this.creator,
    this.updater,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status != 'submitted';

  factory SiteSurveyRecord.fromJson(Map<String, dynamic> json) {
    final template = json['template'] is Map ? json['template'] as Map : const {};
    final answers = json['answers'];
    return SiteSurveyRecord(
      id: '${json['id'] ?? ''}',
      leadId: '${json['lead_id'] ?? json['leadId'] ?? ''}',
      status: '${json['status'] ?? 'draft'}',
      answers: answers is Map
          ? Map<String, dynamic>.from(answers)
          : <String, dynamic>{},
      templateId: '${template['id'] ?? json['template_id'] ?? ''}',
      templateName: '${template['name'] ?? ''}',
      templateProjectType: _nullableString(template['project_type'] ?? template['projectType']),
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      schema: SurveySchema.fromJson(json['schema']),
      submittedAt: _nullableString(json['submitted_at'] ?? json['submittedAt']),
      submitter: json['submitter'] is Map ? SurveyActor.fromJson(json['submitter']) : null,
      creator: json['creator'] is Map ? SurveyActor.fromJson(json['creator']) : null,
      updater: json['updater'] is Map ? SurveyActor.fromJson(json['updater']) : null,
      createdAt: '${json['created_at'] ?? json['createdAt'] ?? ''}',
      updatedAt: '${json['updated_at'] ?? json['updatedAt'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lead_id': leadId,
    'status': status,
    'answers': answers,
    'template': {
      'id': templateId,
      'name': templateName,
      'project_type': templateProjectType,
    },
    'version': version,
    'schema': schema.toJson(),
    'submitted_at': submittedAt,
    'submitter': submitter?.toJson(),
    'creator': creator?.toJson(),
    'updater': updater?.toJson(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  SiteSurveyRecord copyWith({
    String? status,
    Map<String, dynamic>? answers,
    String? submittedAt,
    bool clearSubmittedAt = false,
    SurveyActor? submitter,
    bool clearSubmitter = false,
    SurveyActor? updater,
    String? updatedAt,
  }) {
    return SiteSurveyRecord(
      id: id,
      leadId: leadId,
      status: status ?? this.status,
      answers: answers ?? this.answers,
      templateId: templateId,
      templateName: templateName,
      templateProjectType: templateProjectType,
      version: version,
      schema: schema,
      submittedAt: clearSubmittedAt ? null : (submittedAt ?? this.submittedAt),
      submitter: clearSubmitter ? null : (submitter ?? this.submitter),
      creator: creator,
      updater: updater ?? this.updater,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LeadSurveyLookup {
  final String leadId;
  final String projectType;
  final SiteSurveyRecord? survey;
  final List<TemplateChoice> templates;

  const LeadSurveyLookup({
    required this.leadId,
    required this.projectType,
    this.survey,
    this.templates = const [],
  });
}

class SurveyFileRecord {
  final String id;
  final String surveyId;
  final String fieldId;
  final String kind;
  final String path;
  final String mimeType;
  final int sizeBytes;

  const SurveyFileRecord({
    required this.id,
    required this.surveyId,
    required this.fieldId,
    required this.kind,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory SurveyFileRecord.fromJson(Map<String, dynamic> json) {
    return SurveyFileRecord(
      id: '${json['id'] ?? ''}',
      surveyId: '${json['survey_id'] ?? ''}',
      fieldId: '${json['field_id'] ?? ''}',
      kind: '${json['kind'] ?? 'photo'}',
      path: '${json['path'] ?? ''}',
      mimeType: '${json['mime_type'] ?? 'image/jpeg'}',
      sizeBytes: json['size_bytes'] is num ? (json['size_bytes'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'survey_id': surveyId,
    'field_id': fieldId,
    'kind': kind,
    'path': path,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
  };
}

class SiteSurveyFailure implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  const SiteSurveyFailure(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  @override
  String toString() => message;
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null') return null;
  return text;
}

const surveyProjectTypes = [
  'Residential',
  'Commercial',
  'Industrial',
  'Agriculture',
];

class SurveyFieldTypeInfo {
  final String key;
  final String label;
  final String hint;

  const SurveyFieldTypeInfo(this.key, this.label, this.hint);
}

const surveyFieldTypes = [
  SurveyFieldTypeInfo('text', 'Short text', 'Name, model, short note'),
  SurveyFieldTypeInfo('textarea', 'Long text', 'Remarks, descriptions'),
  SurveyFieldTypeInfo('number', 'Number', 'Load, area, height'),
  SurveyFieldTypeInfo('date', 'Date', 'Visit or due date'),
  SurveyFieldTypeInfo('boolean', 'Yes / No', 'Quick check'),
  SurveyFieldTypeInfo('select', 'Single choice', 'Pick one option'),
  SurveyFieldTypeInfo('multiselect', 'Multiple choice', 'Pick many options'),
  SurveyFieldTypeInfo('photo', 'Photos', 'Camera or gallery'),
  SurveyFieldTypeInfo('signature', 'Signature', 'Customer sign-off'),
  SurveyFieldTypeInfo('location', 'GPS location', 'Capture coordinates'),
];

const surveyFieldTypeGroups = [
  ('Basic', ['text', 'textarea', 'number', 'date']),
  ('Choices', ['boolean', 'select', 'multiselect']),
  ('On-site capture', ['photo', 'signature', 'location']),
];

SurveyFieldTypeInfo? surveyFieldTypeInfo(String key) {
  for (final item in surveyFieldTypes) {
    if (item.key == key) return item;
  }
  return null;
}

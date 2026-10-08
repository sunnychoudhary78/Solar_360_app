import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';

final _idPattern = RegExp(r'^[a-z][a-z0-9_]{0,49}$');

String? validateSchema(SurveySchema schema) {
  if (schema.sections.length > 30) return 'A template can have at most 30 sections';
  if (schema.fieldCount > 200) return 'A template can have at most 200 fields';
  final seen = <String>{};
  final ordered = <String>[];
  for (final section in schema.sections) {
    if (section.title.trim().isEmpty) return 'Every section needs a title';
    if (section.title.length > 150) return 'Section titles must be 150 characters or less';
    if (!_idPattern.hasMatch(section.id)) {
      return 'Section id "${section.id}" must start with a letter and use only a-z, 0-9, _';
    }
    if (!seen.add(section.id)) return 'Duplicate id "${section.id}"';
    final sectionError = _ruleError(section.showIf, ordered);
    if (sectionError != null) return sectionError;
    for (final field in section.fields) {
      if (field.label.trim().isEmpty) return 'Every field needs a label';
      if (!_idPattern.hasMatch(field.id)) {
        return 'Field id "${field.id}" must start with a letter and use only a-z, 0-9, _';
      }
      if (!seen.add(field.id)) return 'Duplicate id "${field.id}"';
      final fieldError = _ruleError(field.showIf, ordered);
      if (fieldError != null) return fieldError;
      if (field.type == 'select' || field.type == 'multiselect') {
        if (field.options.isEmpty) return '${field.label} needs at least one option';
        if (field.options.toSet().length != field.options.length) {
          return '${field.label} has duplicate options';
        }
      }
      ordered.add(field.id);
    }
  }
  return null;
}

String? _ruleError(ShowIfRule? rule, List<String> earlierFields) {
  if (rule == null) return null;
  if (!earlierFields.contains(rule.field)) {
    return 'A show-if rule can only use a field that appears earlier in the form';
  }
  return null;
}

Map<String, String> validateAnswers({
  required SurveySchema schema,
  required Map<String, dynamic> answers,
  required bool submit,
  required bool Function(String fieldId, String fileId) fileBelongs,
}) {
  final errors = <String, String>{};
  final visible = visibleFieldIds(schema, answers);
  final fields = schema.fields.where((field) => visible.contains(field.id));
  for (final field in fields) {
    final value = answers[field.id];
    final empty = isEmptyAnswer(value);
    if (empty) {
      if (submit && field.required) errors[field.id] = 'This field is required';
      continue;
    }
    final message = _typeError(field, value, fileBelongs);
    if (message != null) errors[field.id] = message;
  }
  return errors;
}

String? _typeError(
  SurveyField field,
  dynamic value,
  bool Function(String fieldId, String fileId) fileBelongs,
) {
  switch (field.type) {
    case 'text':
    case 'textarea':
      final text = '$value'.trim();
      if (text.length > 2000) return 'Must be 2000 characters or less';
      return null;
    case 'number':
      final number = value is num ? value : num.tryParse('$value');
      if (number == null) return 'Enter a number';
      if (field.min != null && number < field.min!) return 'Must be at least ${field.min}';
      if (field.max != null && number > field.max!) return 'Must be at most ${field.max}';
      return null;
    case 'boolean':
      if (value is bool) return null;
      if (value == 'true' || value == 'false') return null;
      return 'Choose Yes or No';
    case 'select':
      if (!field.options.contains('$value')) return 'Choose one of the options';
      return null;
    case 'multiselect':
      if (value is! List) return 'Choose one or more options';
      for (final item in value) {
        if (!field.options.contains('$item')) return 'Choose only listed options';
      }
      return null;
    case 'date':
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('$value')) return 'Choose a valid date';
      return null;
    case 'photo':
      if (value is! List) return 'Add a photo';
      final maxPhotos = field.maxPhotos ?? 5;
      if (value.length > maxPhotos) return 'You can add up to $maxPhotos photos';
      for (final id in value) {
        if (!fileBelongs(field.id, '$id')) return 'Photo is missing. Add it again';
      }
      return null;
    case 'signature':
      if (!fileBelongs(field.id, '$value')) return 'Signature is missing. Add it again';
      return null;
    case 'location':
      if (value is! Map) return 'Capture the location';
      final lat = value['lat'];
      final lng = value['lng'];
      final latNum = lat is num ? lat : num.tryParse('$lat');
      final lngNum = lng is num ? lng : num.tryParse('$lng');
      if (latNum == null || lngNum == null) return 'Capture the location';
      if (latNum < -90 || latNum > 90 || lngNum < -180 || lngNum > 180) {
        return 'Location is out of range';
      }
      return null;
    default:
      return null;
  }
}

String slugify(String input, {String fallback = 'field'}) {
  var slug = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  slug = slug.replaceAll(RegExp(r'^_+|_+$'), '');
  if (slug.isEmpty || !RegExp(r'^[a-z]').hasMatch(slug)) {
    slug = '${fallback}_$slug'.replaceAll(RegExp(r'_+$'), '');
  }
  if (slug.length > 50) slug = slug.substring(0, 50).replaceAll(RegExp(r'_+$'), '');
  if (slug.isEmpty) slug = fallback;
  return slug;
}

String uniqueId(String base, Set<String> taken) {
  var id = base;
  var n = 2;
  while (taken.contains(id)) {
    final suffix = '_$n';
    final trimmed = base.length + suffix.length > 50
        ? base.substring(0, 50 - suffix.length)
        : base;
    id = '$trimmed$suffix';
    n++;
  }
  return id;
}

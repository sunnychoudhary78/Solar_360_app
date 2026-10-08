import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';

bool isEmptyAnswer(dynamic value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  if (value is List && value.isEmpty) return true;
  return false;
}

bool matchesValue(dynamic actual, dynamic expected) {
  if (actual is List) {
    return actual.map((e) => '$e').contains('$expected');
  }
  if (expected is bool) {
    return actual == expected || '$actual' == '$expected';
  }
  if (expected is num) return num.tryParse('$actual') == expected;
  return '$actual'.trim().toLowerCase() == '$expected'.trim().toLowerCase();
}

bool ruleMatches(ShowIfRule? rule, Map<String, dynamic> answers, Set<String> visible) {
  if (rule == null || rule.field.isEmpty) return true;
  if (!visible.contains(rule.field)) return false;
  final value = answers[rule.field];
  final empty = isEmptyAnswer(value);
  switch (rule.op) {
    case 'answered':
      return !empty;
    case 'not_answered':
      return empty;
    case 'gt':
      final gtActual = num.tryParse('$value');
      final gtBound = rule.value is num ? rule.value as num : num.tryParse('${rule.value}');
      return !empty && gtActual != null && gtBound != null && gtActual > gtBound;
    case 'lt':
      final ltActual = num.tryParse('$value');
      final ltBound = rule.value is num ? rule.value as num : num.tryParse('${rule.value}');
      return !empty && ltActual != null && ltBound != null && ltActual < ltBound;
    case 'equals':
      return !empty && matchesValue(value, rule.value);
    case 'not_equals':
      return !empty && !matchesValue(value, rule.value);
    default:
      return true;
  }
}

/// Visible field ids, top to bottom. Re-run after every answer change.
Set<String> visibleFieldIds(SurveySchema schema, Map<String, dynamic> answers) {
  final visible = <String>{};
  for (final section in schema.sections) {
    if (!ruleMatches(section.showIf, answers, visible)) continue;
    for (final field in section.fields) {
      if (ruleMatches(field.showIf, answers, visible)) visible.add(field.id);
    }
  }
  return visible;
}

bool sectionIsVisible(SurveySection section, Map<String, dynamic> answers, Set<String> visible) {
  if (!ruleMatches(section.showIf, answers, visible)) return false;
  return section.fields.any((field) => visible.contains(field.id));
}

Map<String, dynamic> dropHiddenAnswers(SurveySchema schema, Map<String, dynamic> answers) {
  final visible = visibleFieldIds(schema, answers);
  return Map<String, dynamic>.fromEntries(
    answers.entries.where((entry) => visible.contains(entry.key) && !isEmptyAnswer(entry.value)),
  );
}

import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';

/// Same ops / labels as web (`surveyFields.js`) and backend (`surveySchema.js`).
const ruleOpOrder = <String>[
  'equals',
  'not_equals',
  'gt',
  'lt',
  'answered',
  'not_answered',
];

const ruleOpLabels = <String, String>{
  'equals': 'is',
  'not_equals': 'is not',
  'gt': 'is greater than',
  'lt': 'is less than',
  'answered': 'is answered',
  'not_answered': 'is not answered',
};

const _equalitySourceTypes = {
  'text',
  'number',
  'boolean',
  'select',
  'multiselect',
};

bool ruleOpNeedsValue(String op) =>
    op == 'equals' || op == 'not_equals' || op == 'gt' || op == 'lt';

/// Operators a source field of this type can be tested with (matches web).
List<String> opsForSourceType(String type) {
  return [
    for (final op in ruleOpOrder)
      if (op == 'gt' || op == 'lt'
          ? type == 'number'
          : (!ruleOpNeedsValue(op) || _equalitySourceTypes.contains(type)))
        op,
  ];
}

Object? defaultRuleValue(SurveyField source) {
  if (source.type == 'boolean') return true;
  if (source.options.isNotEmpty) return source.options.first;
  return '';
}

/// Human-readable badge text matching web `describeRule`.
String? describeShowIf(
  ShowIfRule? rule,
  Map<String, SurveyField> fieldsById, {
  String subject = 'field',
}) {
  if (rule == null) return null;
  final source = fieldsById[rule.field]?.label ?? rule.field;
  final op = ruleOpLabels[rule.op] ?? rule.op;
  if (!ruleOpNeedsValue(rule.op)) return 'Show $subject when $source $op';
  final value = rule.value is bool
      ? (rule.value == true ? 'Yes' : 'No')
      : '${rule.value ?? ''}';
  return 'Show $subject when $source $op $value';
}

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

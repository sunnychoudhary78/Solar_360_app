import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';

class SurveyAnswerProgress {
  const SurveyAnswerProgress({
    required this.answered,
    required this.total,
    required this.requiredLeft,
  });

  final int answered;
  final int total;
  final int requiredLeft;

  double get percent => total == 0 ? 0 : answered / total;
}

SurveyAnswerProgress answerProgress(SurveySchema schema, Map<String, dynamic> answers) {
  final visible = visibleFieldIds(schema, answers);
  var answered = 0;
  var requiredLeft = 0;
  var total = 0;
  for (final field in schema.fields) {
    if (!visible.contains(field.id)) continue;
    total++;
    final empty = isEmptyAnswer(answers[field.id]);
    if (!empty) answered++;
    if (field.required && empty) requiredLeft++;
  }
  return SurveyAnswerProgress(
    answered: answered,
    total: total,
    requiredLeft: requiredLeft,
  );
}

Map<String, String> missingRequired(SurveySchema schema, Map<String, dynamic> answers) {
  final visible = visibleFieldIds(schema, answers);
  final errors = <String, String>{};
  for (final field in schema.fields) {
    if (!visible.contains(field.id) || !field.required) continue;
    if (isEmptyAnswer(answers[field.id])) {
      errors[field.id] = 'This field is required';
    }
  }
  return errors;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/site_survey/data/models/survey_models.dart';
import 'package:solar_sales/features/site_survey/data/survey_visibility.dart';

void main() {
  const schema = SurveySchema(
    sections: [
      SurveySection(
        id: 'visit',
        title: 'Visit',
        fields: [
          SurveyField(id: 'customer_present', type: 'boolean', label: 'Present'),
          SurveyField(
            id: 'customer_signature',
            type: 'signature',
            label: 'Signature',
            showIf: ShowIfRule(field: 'customer_present', op: 'equals', value: true),
          ),
        ],
      ),
      SurveySection(
        id: 'hidden',
        title: 'Hidden',
        showIf: ShowIfRule(field: 'customer_present', op: 'equals', value: false),
        fields: [
          SurveyField(id: 'reason', type: 'text', label: 'Reason'),
        ],
      ),
    ],
  );

  test('signature shows only when customer is present', () {
    final hidden = visibleFieldIds(schema, {'customer_present': false});
    expect(hidden.contains('customer_signature'), isFalse);
    expect(hidden.contains('reason'), isTrue);

    final shown = visibleFieldIds(schema, {'customer_present': true});
    expect(shown.contains('customer_signature'), isTrue);
    expect(shown.contains('reason'), isFalse);
  });

  test('hidden answers are dropped', () {
    final cleaned = dropHiddenAnswers(schema, {
      'customer_present': true,
      'customer_signature': 'file-1',
      'reason': 'left',
    });
    expect(cleaned.containsKey('reason'), isFalse);
    expect(cleaned['customer_signature'], 'file-1');
  });
}

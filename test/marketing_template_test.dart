import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/shared/widgets/marketing_template_picker.dart';

import 'helpers/recording_adapter.dart';

void main() {
  group('MarketingTemplate', () {
    test('fromJson reads backend DTO fields', () {
      final row = MarketingTemplate.fromJson({
        'id': 'tpl-1',
        'name': 'Residential brochure',
        'description': 'For quotes',
        'file_path': 'marketing-templates/template.pdf',
        'file_url': '/api/uploads/marketing-templates/template.pdf',
        'original_name': 'brochure.pdf',
        'mime_type': 'application/pdf',
        'file_size': 2048,
        'applies_to': 'quotation',
        'is_active': false,
      });

      expect(row.id, 'tpl-1');
      expect(row.name, 'Residential brochure');
      expect(row.description, 'For quotes');
      expect(row.appliesTo, 'quotation');
      expect(row.appliesLabel, 'Quotations');
      expect(row.isActive, isFalse);
      expect(row.isPdf, isTrue);
      expect(row.formattedSize, '2.0 KB');
      expect(
        row.previewUrl,
        resolveStoredUploadUrl('/api/uploads/marketing-templates/template.pdf'),
      );
    });

    test('appliesLabel matches web wording', () {
      expect(
        const MarketingTemplate(id: '1', name: 'A', appliesTo: 'both')
            .appliesLabel,
        'Both',
      );
      expect(
        const MarketingTemplate(id: '1', name: 'A', appliesTo: 'invoice')
            .appliesLabel,
        'Invoices',
      );
    });
  });

  group('MarketingTemplateApi', () {
    test('list sends appliesTo and activeOnly like the web picker', () async {
      final pair = createTestApi();
      pair.adapter.on('GET', 'marketing-templates', (request) {
        expect(request.queryParameters['appliesTo'], 'quotation');
        expect(request.queryParameters['activeOnly'], 'true');
        return [
          {
            'id': 'tpl-1',
            'name': 'Brochure',
            'applies_to': 'both',
            'is_active': true,
          },
        ];
      });

      final list = await MarketingTemplateApi(ApiService(pair.dio)).list(
        appliesTo: 'quotation',
        activeOnly: true,
      );
      expect(list, hasLength(1));
      expect(list.first.id, 'tpl-1');
    });

    test('admin list fetches every template without filters', () async {
      final pair = createTestApi();
      pair.adapter.on('GET', 'marketing-templates', (request) {
        expect(request.queryParameters, isEmpty);
        return [
          {
            'id': 'tpl-2',
            'name': 'Disabled',
            'applies_to': 'invoice',
            'is_active': 0,
          },
        ];
      });

      final list = await MarketingTemplateApi(ApiService(pair.dio)).list();
      expect(list.single.isActive, isFalse);
      expect(list.single.appliesLabel, 'Invoices');
    });
  });

  test('create payload uses marketingTemplateId like the web form', () {
    expect(marketingTemplateIdBody('tpl-1'), 'tpl-1');
    expect(marketingTemplateIdBody('  '), isNull);
    expect(marketingTemplateIdBody(null), isNull);
  });

  test('Billbook Templates dest matches web Settings → Templates', () {
    final dest = NavDestinations.billbook.firstWhere(
      (d) => d.id == 'bb_templates',
    );
    expect(dest.label, 'Templates');
    expect(dest.route, '/settings/templates');
    expect(dest.permission, 'companySettings.read');
    expect(dest.visibleFor((p) => p == 'companySettings.read'), isTrue);
    expect(dest.visibleFor((p) => p == 'quotation.read'), isFalse);
  });
}

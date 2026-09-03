import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/installation/data/installation_api_service.dart';
import 'package:solar_sales/features/installation/data/installation_repository.dart';

import '../helpers/recording_adapter.dart';

void main() {
  group('Installation API', () {
    late ApiServicePair pair;
    late InstallationApiService service;

    setUp(() {
      pair = createTestApi();
      service = InstallationApiService(ApiService(pair.dio), pair.dio);
    });

    test('sends multipart installation images on create', () async {
      final tempDir = await Directory.systemTemp.createTemp('installation-api');
      final image = File('${tempDir.path}\\install.jpg');
      await image.writeAsBytes([1, 2, 3, 4]);

      pair.adapter.on('POST', 'installations/lead/lead-1', (req) {
        expect(req.data, isNotNull);
        return {'success': true};
      });

      await service.createForLead(
        'lead-1',
        {
          'file_no': 'FILE-1',
          'panel_capacity': '5',
          'solar_panel_brand': 'Waaree',
          'number_of_solar_panels': 10,
          'panel_type': 'DCR',
          'dcr_certificate_no': 'DCR-1',
          'application_no': 'APP-1',
          'sp_numbers': ['SP-1'],
        },
        installationImagePaths: [image.path],
      );

      expect(
        pair.adapter.of('POST', 'installations/lead/lead-1'),
        hasLength(1),
      );
    });

    test('getForm reads nested installationDetails from the lead payload', () async {
      pair.adapter.on('GET', 'installations/form/lead-1', (_) {
        return {
          'success': true,
          'data': {
            'id': 'lead-1',
            'full_name': 'Test Lead',
            'installationDetails': {
              'id': 'inst-1',
              'file_no': 'FILE-1',
              'solar_panel_brand': 'Waaree',
              'number_of_solar_panels': 10,
            },
          },
        };
      });

      final details = await service.getForm('lead-1');
      expect(details?['id'], 'inst-1');
      expect(details?['file_no'], 'FILE-1');
      expect(details?['solar_panel_brand'], 'Waaree');
      expect(
        pair.adapter.of('GET', 'installations/form/lead-1'),
        hasLength(1),
      );
    });

    test('getForm returns null when the lead has no installation row', () async {
      pair.adapter.on('GET', 'installations/form/lead-1', (_) {
        return {
          'success': true,
          'data': {
            'id': 'lead-1',
            'full_name': 'Test Lead',
            'installationDetails': null,
          },
        };
      });

      final details = await service.getForm('lead-1');
      expect(details, isNull);
    });

    test('saveForLead creates when the id is missing or is the lead id', () async {
      final repo = InstallationRepository(service);
      var posts = 0;
      pair.adapter.on('POST', 'installations/lead/lead-1', (_) {
        posts += 1;
        return {'success': true};
      });

      await repo.saveForLead(
        leadId: 'lead-1',
        installationId: 'lead-1',
        body: {'file_no': 'INV-1', 'panel_type': 'DCR'},
      );
      await repo.saveForLead(
        leadId: 'lead-1',
        installationId: null,
        body: {'file_no': 'INV-1', 'panel_type': 'DCR'},
      );

      expect(posts, 2);
      expect(pair.adapter.of('PUT', 'installations/'), isEmpty);
    });
  });
}

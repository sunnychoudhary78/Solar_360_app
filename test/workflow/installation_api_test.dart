import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/installation/data/installation_api_service.dart';

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
  });
}

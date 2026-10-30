import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/quotations/data/quotation_api_service.dart';
import 'package:solar_sales/features/quotations/data/quotation_repository.dart';

import 'helpers/recording_adapter.dart';

void main() {
  group('QuotationRepository solar design requests', () {
    test('includes the selected design when creating a quotation', () async {
      final pair = createTestApi();
      pair.adapter.on('POST', 'quotations', (_) => _quotation);
      final repository = _repository(pair);

      await repository.create(
        customerId: 'customer-1',
        items: const [],
        solarDesignId: 'design-1',
      );

      expect(
        pair.adapter.of('POST', 'quotations').single.data,
        containsPair('solarDesignId', 'design-1'),
      );
    });

    test('includes selected design when editing a quotation', () async {
      final pair = createTestApi();
      pair.adapter.on('PUT', 'quotations/quotation-1', (_) => _quotation);
      final repository = _repository(pair);

      await repository.update(
        id: 'quotation-1',
        customerId: 'customer-1',
        items: const [],
        includeSolarDesignId: true,
        solarDesignId: 'design-1',
      );

      expect(
        pair.adapter.of('PUT', 'quotations/quotation-1').single.data,
        containsPair('solarDesignId', 'design-1'),
      );
    });

    test('sends null when clearing a design on quotation update', () async {
      final pair = createTestApi();
      pair.adapter.on('PUT', 'quotations/quotation-1', (_) => _quotation);
      final repository = _repository(pair);

      await repository.update(
        id: 'quotation-1',
        customerId: 'customer-1',
        items: const [],
        includeSolarDesignId: true,
      );

      expect(
        pair.adapter.of('PUT', 'quotations/quotation-1').single.data,
        containsPair('solarDesignId', null),
      );
    });
  });
}

QuotationRepository _repository(ApiServicePair pair) {
  return QuotationRepository(QuotationApiService(ApiService(pair.dio)));
}

const _quotation = {
  'id': 'quotation-1',
  'quotation_number': 'QT-1',
  'customer_id': 'customer-1',
  'status': 'draft',
};

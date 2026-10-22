import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/costing/data/costing_api_service.dart';

import 'helpers/recording_adapter.dart';

void main() {
  group('CostingApiService', () {
    final sheet = {
      'id': 'costing-1',
      'customer_id': 'customer-1',
      'total_amount': '25000.00',
      'items': [
        {
          'id': 'line-1',
          'name': 'Panel',
          'kind': 'catalog',
          'unit_price': '12500.00',
          'quantity': '2.000',
          'amount': '25000.00',
        },
      ],
    };

    test('uses the documented read and mutation routes and payloads', () async {
      final pair = createTestApi();
      pair.adapter
        ..on('GET', 'costings/customer/customer-1', (_) => sheet)
        ..on('POST', 'costings/customer/customer-1/lines', (request) {
          expect(request.data, {
            'kind': 'catalog',
            'item_id': 'item-1',
            'unit_price': 12000.0,
            'quantity': 2.0,
          });
          return sheet;
        })
        ..on('DELETE', 'costings/costing-1/lines/line-1', (_) => sheet)
        ..on('POST', 'costings/costing-1/clear', (request) {
          expect(request.data, isNull);
          return {
            ...sheet,
            'total_amount': '0.00',
            'items': <Map<String, dynamic>>[],
          };
        });

      final service = CostingApiService(ApiService(pair.dio));
      final loaded = await service.getForCustomer('customer-1');
      expect(loaded.totalAmount, 25000);
      expect(loaded.items.single.quantity, 2);

      await service.addLine('customer-1', {
        'kind': 'catalog',
        'item_id': 'item-1',
        'unit_price': 12000.0,
        'quantity': 2.0,
      });
      await service.removeLine('costing-1', 'line-1');
      final cleared = await service.clear('costing-1');

      expect(cleared.items, isEmpty);
      expect(
        pair.adapter.of('GET', 'costings/customer/customer-1'),
        hasLength(1),
      );
      expect(
        pair.adapter.of('POST', 'costings/customer/customer-1/lines'),
        hasLength(1),
      );
      expect(
        pair.adapter.of('DELETE', 'costings/costing-1/lines/line-1'),
        hasLength(1),
      );
      expect(pair.adapter.of('POST', 'costings/costing-1/clear'), hasLength(1));
    });

    test('downloads PDF bytes with the documented Accept header', () async {
      final pair = createTestApi();
      pair.adapter.on(
        'GET',
        'costings/costing-1/pdf',
        (_) => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      );

      final bytes = await CostingApiService(
        ApiService(pair.dio),
      ).downloadPdf('costing-1');

      expect(bytes, [0x25, 0x50, 0x44, 0x46]);
      expect(
        pair.adapter
            .of('GET', 'costings/costing-1/pdf')
            .single
            .headers['Accept'],
        'application/pdf',
      );
    });

    test('uses lead costing and vendor management routes', () async {
      final pair = createTestApi();
      final leadSheet = {
        'id': 'costing-lead-1',
        'customer_id': null,
        'lead_id': 'lead-1',
        'vendor_id': 'vendor-1',
        'total_amount': '0.00',
        'lead': {
          'id': 'lead-1',
          'lead_code': 'LD-1',
          'full_name': 'Ravi Sharma',
        },
        'vendor': {
          'id': 'vendor-1',
          'name': 'SunPower Traders',
          'contact_number': '9822000000',
        },
        'items': <Map<String, dynamic>>[],
      };
      final vendor = {
        'id': 'vendor-1',
        'name': 'SunPower Traders',
        'address': 'Warehouse 4, Pune',
        'contact_number': '9822000000',
        'is_active': true,
      };
      pair.adapter
        ..on('GET', 'costings/lead/lead-1', (_) => leadSheet)
        ..on('POST', 'costings/lead/lead-1/lines', (request) {
          expect(request.data, {
            'kind': 'custom',
            'name': 'Site scaffolding hire',
            'unit_price': 1500.0,
            'quantity': 3.0,
          });
          return leadSheet;
        })
        ..on('PUT', 'costings/costing-lead-1/vendor', (request) {
          expect(request.data, {'vendor_id': 'vendor-1'});
          return leadSheet;
        })
        ..on('GET', 'vendors', (_) => [vendor])
        ..on('POST', 'vendors', (request) {
          expect(request.data, {
            'name': 'SunPower Traders',
            'contact_number': '9822000000',
          });
          return vendor;
        })
        ..on('PUT', 'vendors/vendor-1', (request) {
          expect(request.data, {'name': 'SunPower Traders'});
          return vendor;
        })
        ..on('DELETE', 'vendors/vendor-1', (_) => {'success': true})
        ..on(
          'GET',
          'leads',
          (_) => {
            'success': true,
            'count': 1,
            'data': [
              {'id': 'lead-1', 'lead_code': 'LD-1', 'full_name': 'Ravi Sharma'},
            ],
          },
        );

      final service = CostingApiService(ApiService(pair.dio));
      final loadedLead = await service.getForLead('lead-1');
      expect(loadedLead.leadId, 'lead-1');
      expect(loadedLead.lead?.fullName, 'Ravi Sharma');
      expect(loadedLead.vendorId, 'vendor-1');
      expect((await service.listLeads()).single.leadCode, 'LD-1');
      expect((await service.listVendors()).single.name, 'SunPower Traders');
      await service.createVendor({
        'name': 'SunPower Traders',
        'contact_number': '9822000000',
      });
      await service.updateVendor('vendor-1', {'name': 'SunPower Traders'});
      await service.deleteVendor('vendor-1');
      await service.setVendor('costing-lead-1', 'vendor-1');
      await service.addLeadLine('lead-1', {
        'kind': 'custom',
        'name': 'Site scaffolding hire',
        'unit_price': 1500.0,
        'quantity': 3.0,
      });

      expect(pair.adapter.of('GET', 'costings/lead/lead-1'), hasLength(1));
      expect(
        pair.adapter.of('POST', 'costings/lead/lead-1/lines'),
        hasLength(1),
      );
      expect(
        pair.adapter.of('PUT', 'costings/costing-lead-1/vendor'),
        hasLength(1),
      );
      expect(pair.adapter.of('GET', 'vendors'), hasLength(1));
      expect(pair.adapter.of('POST', 'vendors'), hasLength(1));
      expect(pair.adapter.of('PUT', 'vendors/vendor-1'), hasLength(1));
      expect(pair.adapter.of('DELETE', 'vendors/vendor-1'), hasLength(1));
      expect(pair.adapter.of('GET', 'leads'), hasLength(1));
    });
  });
}

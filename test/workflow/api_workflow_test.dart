import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/inventory/data/inventory_api_service.dart';
import 'package:solar_sales/features/inventory/data/inventory_repository.dart';
import 'package:solar_sales/features/invoices/data/invoice_api_service.dart';
import 'package:solar_sales/features/invoices/data/invoice_repository.dart';
import 'package:solar_sales/features/invoices/data/models/invoice_model.dart';
import 'package:solar_sales/features/items/data/item_api_service.dart';
import 'package:solar_sales/features/items/data/item_repository.dart';
import 'package:solar_sales/features/quotations/data/models/quotation_model.dart';
import 'package:solar_sales/features/quotations/data/quotation_api_service.dart';
import 'package:solar_sales/features/quotations/data/quotation_repository.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';

import '../helpers/recording_adapter.dart';

void main() {
  group('Quotation API workflow (web parity)', () {
    late ApiServicePair pair;
    late QuotationRepository repo;

    setUp(() {
      pair = createTestApi();
      repo = QuotationRepository(QuotationApiService(ApiService(pair.dio)));
    });

    test('create posts customerId + items like web form', () async {
      pair.adapter.on('POST', 'quotations', (req) {
        return {
          'id': 'q1',
          'quotation_number': 'QT-2026-00001',
          'customer_id': 'c1',
          'status': 'draft',
          'items': [],
        };
      });

      final created = await repo.create(
        customerId: 'c1',
        items: [
          const QuotationItemModel(
            itemId: 'i1',
            quantity: 2,
            unitPrice: 1000,
            gstPercent: 18,
            description: 'Panel',
          ),
        ],
        notes: 'Rush',
        validUntil: DateTime(2026, 12, 31),
      );

      expect(created.status, 'draft');
      final call = pair.adapter.of('POST', 'quotations').single;
      final body = call.data as Map;
      expect(body['customerId'], 'c1');
      expect(body['notes'], 'Rush');
      expect(body['validUntil'], '2026-12-31');
      expect(body['items'], isA<List>());
      expect((body['items'] as List).first['item_id'], 'i1');
      expect((body['items'] as List).first['quantity'], 2);
    });

    test('submit → pending_approval path', () async {
      pair.adapter.on('POST', 'submit', (req) {
        return {
          'id': 'q1',
          'quotation_number': 'QT-1',
          'customer_id': 'c1',
          'status': 'pending_approval',
          'items': [],
        };
      });

      final result = await repo.submit('q1');
      expect(result.status, 'pending_approval');
      expect(pair.adapter.of('POST', 'submit'), hasLength(1));
    });

    test('approve sets status sent (not approved)', () async {
      pair.adapter.on('POST', 'approve', (req) {
        return {
          'id': 'q1',
          'quotation_number': 'QT-1',
          'customer_id': 'c1',
          'status': DocumentWorkflow.quotationStatusAfterApprove,
          'items': [],
        };
      });

      final result = await repo.approve('q1');
      expect(result.status, 'sent');
      expect(DocumentWorkflow.isQuotationApproved(result.status), isTrue);
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: result.status,
          invoiceId: null,
        ),
        isTrue,
      );
    });

    test('reject posts reason body like web', () async {
      pair.adapter.on('POST', 'reject', (req) {
        expect(req.data, {'reason': 'Price too high'});
        return {
          'id': 'q1',
          'quotation_number': 'QT-1',
          'customer_id': 'c1',
          'status': 'rejected',
          'rejection_reason': 'Price too high',
          'items': [],
        };
      });

      final result = await repo.reject('q1', 'Price too high');
      expect(result.status, 'rejected');
      expect(result.rejectionReason, 'Price too high');
    });

    test('update sends quotationNumber and clears notes', () async {
      pair.adapter.on('PUT', 'quotations/', (req) {
        return {
          'id': 'q1',
          'quotation_number': 'QT-CUSTOM',
          'customer_id': 'c1',
          'status': 'draft',
          'notes': '',
          'items': [],
        };
      });

      await repo.update(
        id: 'q1',
        customerId: 'c1',
        items: [
          const QuotationItemModel(
            itemId: 'i1',
            quantity: 1,
            unitPrice: 100,
            gstPercent: 18,
          ),
        ],
        notes: '',
        quotationNumber: 'QT-CUSTOM',
      );

      final call = pair.adapter.of('PUT', 'quotations/').single;
      final body = call.data as Map;
      expect(body['quotationNumber'], 'QT-CUSTOM');
      expect(body.containsKey('quotation_number'), isFalse);
      expect(body['notes'], '');
      expect(body['customerId'], 'c1');
    });

    test('invoiceable endpoint used for create-invoice picker', () async {
      pair.adapter.on('GET', 'invoiceable', (req) {
        return [
          {
            'id': 'q2',
            'quotation_number': 'QT-2',
            'customer_id': 'c1',
            'status': 'sent',
            'items': [],
          },
        ];
      });

      final list = await repo.listInvoiceable();
      expect(list, hasLength(1));
      expect(list.first.status, 'sent');
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: list.first.status,
          invoiceId: list.first.invoiceId,
        ),
        isTrue,
      );
    });
  });

  group('Invoice API workflow (web parity)', () {
    late ApiServicePair pair;
    late InvoiceRepository repo;

    setUp(() {
      pair = createTestApi();
      repo = InvoiceRepository(InvoiceApiService(ApiService(pair.dio)));
    });

    test('create from quotation posts quotationId', () async {
      pair.adapter.on('POST', 'from-quotation', (req) {
        final body = Map<String, dynamic>.from(req.data as Map);
        expect(body['quotationId'], 'q1');
        expect(body['notes'], 'N1');
        expect(body['invoiceNumber'], 'INV-CUSTOM-1');
        expect(body['paymentMode'], 'UPI');
        expect(body['motorVehicleNo'], 'MH12AB1234');
        expect(body['ewayBillNo'], 'EWB1');
        expect(body['shipSameAsBill'], true);
        return {
          'id': 'inv1',
          'invoice_number': 'INV-CUSTOM-1',
          'quotation_id': 'q1',
          'customer_id': 'c1',
          'status': 'draft',
          'stock_deducted': false,
          'payment_mode': 'UPI',
          'motor_vehicle_no': 'MH12AB1234',
          'eway_bill_no': 'EWB1',
          'items': [],
        };
      });

      final inv = await repo.createFromQuotation(
        quotationId: 'q1',
        notes: 'N1',
        invoiceNumber: 'INV-CUSTOM-1',
        paymentMode: 'UPI',
        motorVehicleNo: 'MH12AB1234',
        ewayBillNo: 'EWB1',
      );
      expect(inv.status, 'draft');
      expect(inv.stockDeducted, isFalse);
      expect(inv.invoiceNumber, 'INV-CUSTOM-1');
      expect(inv.paymentMode, 'UPI');
    });

    test('create from quotation sends editable items payload', () async {
      pair.adapter.on('POST', 'from-quotation', (req) {
        final body = Map<String, dynamic>.from(req.data as Map);
        expect(body['quotationId'], 'q1');
        expect(body['items'], isA<List>());
        final item = (body['items'] as List).first as Map;
        expect(item['item_id'], 'i1');
        expect(item['quantity'], 2);
        expect(item['unit_price'], 500);
        expect(item['gst_percent'], 18);
        return {
          'id': 'inv2',
          'invoice_number': 'INV-2',
          'quotation_id': 'q1',
          'customer_id': 'c1',
          'status': 'draft',
          'stock_deducted': false,
          'items': [],
        };
      });

      final inv = await repo.createFromQuotation(
        quotationId: 'q1',
        items: [
          const InvoiceItemModel(
            itemId: 'i1',
            quantity: 2,
            unitPrice: 500,
            gstPercent: 18,
            description: 'Panel',
          ),
        ],
      );
      expect(inv.id, 'inv2');
    });

    test('update clears notes with empty string', () async {
      pair.adapter.on('PUT', 'invoices/', (req) {
        final body = Map<String, dynamic>.from(req.data as Map);
        expect(body['notes'], '');
        expect(body['items'], isA<List>());
        return {
          'id': 'inv1',
          'invoice_number': 'INV-1',
          'customer_id': 'c1',
          'status': 'draft',
          'stock_deducted': false,
          'notes': '',
          'items': [],
        };
      });

      await repo.update(
        id: 'inv1',
        items: [
          const InvoiceItemModel(
            itemId: 'i1',
            quantity: 1,
            unitPrice: 100,
            gstPercent: 18,
          ),
        ],
        notes: '',
      );
    });

    test('submit → pending_approval', () async {
      pair.adapter.on('POST', 'submit', (req) {
        return {
          'id': 'inv1',
          'invoice_number': 'INV-1',
          'customer_id': 'c1',
          'status': 'pending_approval',
          'stock_deducted': false,
          'items': [],
        };
      });

      final inv = await repo.submit('inv1');
      expect(inv.status, 'pending_approval');
    });

    test('approve requires warehouseId and sets sent + stock_deducted', () async {
      pair.adapter.on('POST', 'approve', (req) {
        expect(req.data, {'warehouseId': 'wh-1'});
        return {
          'id': 'inv1',
          'invoice_number': 'INV-1',
          'customer_id': 'c1',
          'status': DocumentWorkflow.invoiceStatusAfterApprove,
          'warehouse_id': 'wh-1',
          'stock_deducted': true,
          'items': [],
        };
      });

      final inv = await repo.approve('inv1', 'wh-1');
      expect(inv.status, 'sent');
      expect(inv.stockDeducted, isTrue);
      expect(inv.warehouseId, 'wh-1');
    });

    test('stock-check query includes warehouseId', () async {
      pair.adapter.on('GET', 'stock-check', (req) {
        expect(req.queryParameters['warehouseId'], 'wh-1');
        return {
          'ok': true,
          'lines': [
            {
              'item_id': 'i1',
              'item_name': 'Panel',
              'required': 2,
              'available': 5,
              'sufficient': true,
            },
          ],
        };
      });

      final check = await repo.stockCheck('inv1', 'wh-1');
      expect(check.ok, isTrue);
      expect(check.lines.first.ok, isTrue);
    });

    test('reject posts reason', () async {
      pair.adapter.on('POST', 'reject', (req) {
        expect(req.data, {'reason': 'No stock'});
        return {
          'id': 'inv1',
          'invoice_number': 'INV-1',
          'customer_id': 'c1',
          'status': 'rejected',
          'rejection_reason': 'No stock',
          'stock_deducted': false,
          'items': [],
        };
      });

      final inv = await repo.reject('inv1', 'No stock');
      expect(inv.status, 'rejected');
    });
  });

  group('Item approval API workflow (web parity)', () {
    late ApiServicePair pair;
    late ItemRepository repo;

    setUp(() {
      pair = createTestApi();
      repo = ItemRepository(ItemApiService(ApiService(pair.dio)));
    });

    test('approve pending → approved', () async {
      pair.adapter.on('POST', 'approve', (req) {
        return {
          'id': 'i1',
          'name': 'Panel',
          'sku': 'P-1',
          'status': 'approved',
          'unit': 'Nos',
          'gst_percent': 18,
          'selling_price': 1000,
          'min_stock_level': 5,
        };
      });

      final item = await repo.approve('i1');
      expect(item.status, 'approved');
      expect(DocumentWorkflow.isItemUsableInQuotations(item.status), isTrue);
    });

    test('reject posts reason → rejected', () async {
      pair.adapter.on('POST', 'reject', (req) {
        expect(req.data, {'reason': 'Duplicate SKU'});
        return {
          'id': 'i1',
          'name': 'Panel',
          'sku': 'P-1',
          'status': 'rejected',
          'rejection_reason': 'Duplicate SKU',
          'unit': 'Nos',
          'gst_percent': 18,
          'selling_price': 1000,
          'min_stock_level': 5,
        };
      });

      final item = await repo.reject('i1', 'Duplicate SKU');
      expect(item.status, 'rejected');
      expect(item.rejectionReason, 'Duplicate SKU');
    });
  });

  group('Inventory movement API workflow (web parity)', () {
    late ApiServicePair pair;
    late InventoryRepository repo;

    setUp(() {
      pair = createTestApi();
      repo = InventoryRepository(InventoryApiService(ApiService(pair.dio)));
    });

    test('stock-in posts camelCase body', () async {
      pair.adapter.on('POST', 'stock-in', (req) {
        expect(req.data, {
          'itemId': 'i1',
          'warehouseId': 'wh-1',
          'quantity': 10,
          'notes': 'recv',
        });
        return {'ok': true};
      });

      await repo.stockIn(
        itemId: 'i1',
        warehouseId: 'wh-1',
        quantity: 10,
        notes: 'recv',
      );
      expect(pair.adapter.of('POST', 'stock-in'), hasLength(1));
    });

    test('stock-out posts camelCase body', () async {
      pair.adapter.on('POST', 'stock-out', (req) {
        expect(req.data['quantity'], 4);
        return {'ok': true};
      });

      await repo.stockOut(itemId: 'i1', warehouseId: 'wh-1', quantity: 4);
    });

    test('stock-transfer posts from/to warehouse ids', () async {
      pair.adapter.on('POST', 'stock-transfer', (req) {
        expect(req.data, {
          'itemId': 'i1',
          'fromWarehouseId': 'wh-a',
          'toWarehouseId': 'wh-b',
          'quantity': 2,
        });
        return {'ok': true};
      });

      await repo.stockTransfer(
        itemId: 'i1',
        fromWarehouseId: 'wh-a',
        toWarehouseId: 'wh-b',
        quantity: 2,
      );
    });

    test('stock-adjustment posts absolute quantity', () async {
      pair.adapter.on('POST', 'stock-adjustment', (req) {
        expect(req.data['quantity'], 50);
        return {'ok': true};
      });

      await repo.stockAdjustment(
        itemId: 'i1',
        warehouseId: 'wh-1',
        quantity: 50,
      );
    });
  });
}

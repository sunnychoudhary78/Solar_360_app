import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';

void main() {
  group('InventoryPayloads — match web/backend camelCase bodies', () {
    test('stock-in body', () {
      expect(
        InventoryPayloads.stockIn(
          itemId: 'item-1',
          warehouseId: 'wh-1',
          quantity: 10,
          notes: 'recv',
          referenceNumber: 'PO-1',
        ),
        {
          'itemId': 'item-1',
          'warehouseId': 'wh-1',
          'quantity': 10,
          'notes': 'recv',
          'referenceNumber': 'PO-1',
        },
      );
    });

    test('stock-out body', () {
      expect(
        InventoryPayloads.stockOut(
          itemId: 'item-1',
          warehouseId: 'wh-1',
          quantity: 3,
        ),
        {
          'itemId': 'item-1',
          'warehouseId': 'wh-1',
          'quantity': 3,
        },
      );
    });

    test('stock-transfer body uses from/to warehouse ids', () {
      expect(
        InventoryPayloads.stockTransfer(
          itemId: 'item-1',
          fromWarehouseId: 'wh-a',
          toWarehouseId: 'wh-b',
          quantity: 5,
          notes: 'move',
        ),
        {
          'itemId': 'item-1',
          'fromWarehouseId': 'wh-a',
          'toWarehouseId': 'wh-b',
          'quantity': 5,
          'notes': 'move',
        },
      );
    });

    test('stock-adjustment quantity is absolute target', () {
      expect(
        InventoryPayloads.stockAdjustment(
          itemId: 'item-1',
          warehouseId: 'wh-1',
          quantity: 100,
        ),
        {
          'itemId': 'item-1',
          'warehouseId': 'wh-1',
          'quantity': 100,
        },
      );
    });

    test('ledger trans types match backend enum', () {
      expect(
        DocumentWorkflow.inventoryTransTypes,
        ['in', 'out', 'transfer', 'adjustment'],
      );
    });
  });
}

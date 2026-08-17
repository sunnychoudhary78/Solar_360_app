import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/invoices/data/models/invoice_model.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/quotations/data/models/quotation_model.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';

void main() {
  group('Model parsing — API snake_case like web/backend', () {
    test('QuotationModel parses approve→sent response', () {
      final q = QuotationModel.fromJson({
        'id': 'q1',
        'quotation_number': 'QT-2026-00001',
        'customer_id': 'c1',
        'status': 'sent',
        'subtotal': 1000,
        'gst_amount': 180,
        'total_amount': 1180,
        'customer': {
          'id': 'c1',
          'name': 'Acme',
          'email': 'a@acme.com',
          'phone': '9876543210',
        },
        'items': [
          {
            'id': 'li1',
            'item_id': 'i1',
            'quantity': 2,
            'unit_price': 500,
            'gst_percent': 18,
            'gst_amount': 180,
            'line_total': 1180,
            'description': 'Panel',
          },
        ],
      });

      expect(q.status, 'sent');
      expect(q.quotationNumber, 'QT-2026-00001');
      expect(q.items, hasLength(1));
      expect(q.items.first.itemId, 'i1');
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: q.status,
          invoiceId: q.invoiceId,
        ),
        isTrue,
      );
    });

    test('InvoiceModel parses stock_deducted after approve', () {
      final inv = InvoiceModel.fromJson({
        'id': 'inv1',
        'invoice_number': 'INV-2026-00001',
        'quotation_id': 'q1',
        'customer_id': 'c1',
        'status': 'sent',
        'warehouse_id': 'wh-1',
        'warehouse': {'id': 'wh-1', 'name': 'Main WH'},
        'stock_deducted': true,
        'subtotal': 1000,
        'gst_amount': 180,
        'total_amount': 1180,
        'items': [],
      });

      expect(inv.status, 'sent');
      expect(inv.stockDeducted, isTrue);
      expect(inv.warehouseId, 'wh-1');
      expect(inv.warehouseName, 'Main WH');
      expect(DocumentWorkflow.isInvoiceApproved(inv.status), isTrue);
    });

    test('ItemModel parses pending → approved', () {
      final pending = ItemModel.fromJson({
        'id': 'i1',
        'name': 'Panel',
        'sku': 'P-1',
        'status': 'pending',
        'unit': 'Nos',
        'gst_percent': 18,
        'selling_price': 1000,
        'min_stock_level': 5,
      });
      expect(DocumentWorkflow.canApproveOrRejectItem(pending.status), isTrue);

      final approved = ItemModel.fromJson({
        ...{
          'id': 'i1',
          'name': 'Panel',
          'sku': 'P-1',
          'unit': 'Nos',
          'gst_percent': 18,
          'selling_price': 1000,
          'min_stock_level': 5,
        },
        'status': 'approved',
      });
      expect(DocumentWorkflow.isItemUsableInQuotations(approved.status), isTrue);
      expect(DocumentWorkflow.canEditItem(approved.status), isFalse);
    });

    test('QuotationItemModel.toCreateJson matches web payload keys', () {
      const line = QuotationItemModel(
        itemId: 'i1',
        warehouseId: 'w1',
        quantity: 3,
        unitPrice: 200,
        gstPercent: 18,
        description: 'Cable',
      );
      expect(line.toCreateJson(), {
        'item_id': 'i1',
        'warehouse_id': 'w1',
        'quantity': 3,
        'unit_price': 200,
        'gst_percent': 18,
        'description': 'Cable',
      });
    });
  });
}

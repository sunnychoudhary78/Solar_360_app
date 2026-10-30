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
      expect(q.solarDesignId, isNull);
      expect(q.hasSolarDesign, isFalse);
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

    test('quotation and invoice parse marketing_template_id', () {
      final q = QuotationModel.fromJson({
        'id': 'q1',
        'marketing_template_id': 'tpl-q',
        'items': [],
      });
      final inv = InvoiceModel.fromJson({
        'id': 'inv1',
        'marketingTemplate': {'id': 'tpl-i', 'name': 'Invoice wrap'},
        'items': [],
      });
      expect(q.marketingTemplateId, 'tpl-q');
      expect(inv.marketingTemplateId, 'tpl-i');
      expect(inv.marketingTemplate?.name, 'Invoice wrap');
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

    test('quotation parses flattened solarDesign from quotation_design_links', () {
      final q = QuotationModel.fromJson({
        'id': 'q1',
        'quotation_number': 'QT-1',
        'customer_id': 'c1',
        'status': 'draft',
        'solar_design_id': 'd1',
        'solarDesign': {
          'id': 'd1',
          'name': 'Option A 5 kW',
          'capacity_kw': 5.0,
          'panel_count': 10,
          'share_code': 'AbCdEfGhIj',
          'share_enabled': true,
        },
        'items': [],
      });
      expect(q.solarDesignId, 'd1');
      expect(q.hasSolarDesign, isTrue);
      expect(q.solarDesign?.name, 'Option A 5 kW');
      expect(q.solarDesign?.panelCount, 10);
      expect(q.solarDesign?.previewUrl, contains('/p/AbCdEfGhIj'));
    });
  });
}

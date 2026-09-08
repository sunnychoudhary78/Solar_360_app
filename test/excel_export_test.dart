import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/dashboard/data/models/dashboard_model.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/items/data/models/item_model.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/reports/data/models/report_models.dart';
import 'package:solar_sales/shared/utils/excel_export.dart';
import 'package:solar_sales/shared/utils/excel_rows.dart';

LeadModel _lead(Map<String, dynamic> json) => LeadModel.fromJson(json);

void main() {
  group('excel file helpers', () {
    test('stamps filenames like the web helper', () {
      final date = DateTime(2026, 9, 8);
      expect(excelDateStamp(date), '2026-09-08');
      expect(excelFileName('Billbook_Stock', date), 'Billbook_Stock_2026-09-08.xlsx');
    });

    test('encodes a workbook from row maps', () {
      final bytes = encodeExcelWorkbook([
        ExcelSheetData(
          name: 'By Status',
          rows: const [
            {'Status': 'New Lead', 'Count': 2},
            {'Status': 'Converted', 'Count': 1},
          ],
        ),
      ]);
      expect(bytes, isNotEmpty);
    });

    test('refuses empty sheets', () {
      expect(
        () => encodeExcelWorkbook([
          const ExcelSheetData(name: 'Empty', rows: []),
        ]),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Billbook report Excel rows', () {
    test('sales, invoices, quotations and stock match web columns', () {
      final data = ReportsBundle(
        sales: [
          SalesPoint(
            month: DateTime(2026, 4, 1),
            invoiceCount: 2,
            totalSales: 1000,
          ),
        ],
        invoices: [
          ReportInvoiceRow(
            id: 'i1',
            invoiceNumber: 'INV-1',
            customerName: 'Acme',
            customerPhone: '999',
            customerEmail: 'a@x.com',
            customerCity: 'Pune',
            status: 'sent',
            subtotal: 100,
            gstAmount: 18,
            totalAmount: 118,
            paymentMode: 'UPI',
            stockDeducted: true,
            ewayBillNo: 'EW1',
            motorVehicleNo: 'MH12',
            notes: 'ok',
          ),
        ],
        quotations: [
          ReportQuotationRow(
            id: 'q1',
            quotationNumber: 'QT-1',
            customerName: 'Acme',
            status: 'approved',
            subtotal: 90,
            gstAmount: 16.2,
            totalAmount: 106.2,
            validUntil: '2026-09-30',
          ),
        ],
        stock: [
          StockModel(
            id: 's1',
            itemId: 'item-1',
            warehouseId: 'wh-1',
            currentQuantity: 4,
            totalQuantity: 4,
            isLowStock: true,
            item: const ItemModel(
              id: 'item-1',
              name: 'Panel',
              sku: 'PNL-1',
              category: 'Solar',
              minStockLevel: 10,
            ),
            warehouse: const WarehouseModel(id: 'wh-1', name: 'Main'),
          ),
        ],
      );

      final sales = billbookSalesRows(data);
      expect(sales.single['Invoice Count'], 2);
      expect(sales.single['Total Sales (₹)'], 1000);
      expect(sales.single['Share of Sales (%)'], 100);

      final invoices = billbookInvoiceRows(data);
      expect(invoices.single['Invoice Number'], 'INV-1');
      expect(invoices.single['Customer'], 'Acme');
      expect(invoices.single['Status'], 'Sent');
      expect(invoices.single['Stock Deducted'], 'Yes');

      final quotations = billbookQuotationRows(data);
      expect(quotations.single['Quotation Number'], 'QT-1');
      expect(quotations.single['Total (₹)'], 106.2);

      final stock = billbookStockRows(data.stock);
      expect(stock.single['Item'], 'Panel');
      expect(stock.single['SKU'], 'PNL-1');
      expect(stock.single['Status'], 'Low');
    });
  });

  group('Green Energy report Excel rows', () {
    test('counts by status, department and state', () {
      final leads = [
        _lead({
          'id': '1',
          'lead_code': 'L-1',
          'full_name': 'Asha',
          'status': 'New Lead',
          'current_department': 'Support',
          'state': 'Maharashtra',
          'mobile': '111',
        }),
        _lead({
          'id': '2',
          'lead_code': 'L-2',
          'full_name': 'Ravi',
          'status': 'Converted',
          'current_department': 'liaising',
          'state': 'Maharashtra',
          'mobile': '222',
        }),
      ];

      expect(LeadWorkflow.resolveDepartmentLabel('Support'), 'Documents');
      expect(LeadWorkflow.resolveDepartmentLabel('liaising'), 'Bank Process');

      final byStatus = greenEnergyStatusRows(leads);
      expect(byStatus.length, 2);
      expect(byStatus.first['Count'], 1);

      final byDept = greenEnergyDepartmentRows(leads);
      expect(
        byDept.map((r) => r['Department']).toSet(),
        containsAll(['Documents', 'Bank Process']),
      );

      final byState = greenEnergyStateRows(leads);
      expect(byState.single['State'], 'Maharashtra');
      expect(byState.single['Count'], 2);

      final allLeads = greenEnergyLeadRows(leads);
      expect(allLeads.first['Lead ID'], 'L-1');
      expect(allLeads.first['Department'], 'Documents');
    });
  });

  group('list Excel rows', () {
    test('leads export uses visible web columns', () {
      final rows = leadListExcelRows([
        _lead({
          'id': '1',
          'lead_code': 'L-9',
          'full_name': 'Neha',
          'mobile': '900',
          'status': 'New Lead',
          'current_department': 'Sales',
          'lead_stage': 'Open',
          'city': 'Jaipur',
          'assigned_to_name': 'Amit',
          'is_active': true,
        }),
      ]);
      expect(rows.single['Lead Code'], 'L-9');
      expect(rows.single['Assigned To'], 'Amit');
      expect(rows.single['Active'], 'Yes');
    });

    test('customers export uses default web columns', () {
      final rows = customerExcelRows([
        const CustomerModel(
          id: 'c1',
          name: 'Acme',
          email: 'a@x.com',
          phone: '999',
          city: 'Pune',
          state: 'MH',
          pincode: '411001',
          gstNumber: 'URP',
          createdByName: 'Admin',
          createdAt: '2026-09-01T10:00:00.000Z',
        ),
      ]);
      expect(rows.single['Name'], 'Acme');
      expect(rows.single['GST'], 'URP');
      expect(rows.single['Created By'], 'Admin');
      expect(rows.single['Created At'], isNotEmpty);
    });
  });
}

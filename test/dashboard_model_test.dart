import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/dashboard/data/models/dashboard_model.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

void main() {
  group('DashboardModel web overview fields', () {
    test('parses camelCase dashboard payload from solar-reports/dashboard', () {
      final model = DashboardModel.fromJson({
        'customersCount': 46,
        'itemsCount': 9,
        'approvedItemsCount': 9,
        'pendingItemsCount': 0,
        'quotationsCount': 12,
        'pendingQuotations': 0,
        'invoicesCount': 11,
        'pendingInvoices': 6,
        'lowStockCount': 3,
        'totalSales': 10651.18,
        'inventoryHealthPercent': 67,
        'gstCollected': 523.18,
        'quotationPipelineValue': 800000,
        'quotationStatus': {
          'draft': 2,
          'pending_approval': 0,
          'approved': 0,
          'rejected': 0,
          'sent': 10,
        },
        'invoiceStatus': {
          'draft': 1,
          'pending_approval': 6,
          'approved': 0,
          'rejected': 0,
          'sent': 4,
        },
        'thisMonthSales': 0,
        'lastMonthSales': 10651.18,
        'thisMonthInvoices': 0,
        'lastMonthInvoices': 4,
        'salesMomPercent': -100,
        'sentQuotations': 10,
        'invoicesFromQuotes': 4,
        'conversionPercent': 40,
        'avgInvoiceValue': 968.289,
        'topCustomers': [
          {
            'customer_id': 'c1',
            'name': 'Monika',
            'invoice_count': 2,
            'total_sales': 5300,
          },
        ],
        'lowStock': [
          {
            'id': 's1',
            'item_id': 'i1',
            'warehouse_id': 'w1',
            'current_quantity': 2,
            'item': {'id': 'i1', 'name': 'Battery', 'min_stock_level': 10},
          },
        ],
      });

      expect(model.customersCount, 46);
      expect(model.gstCollected, 523.18);
      expect(model.quotationPipelineValue, 800000);
      expect(model.quotationStatus.sent, 10);
      expect(model.invoiceStatus.pendingApproval, 6);
      expect(model.thisMonthSales, 0);
      expect(model.lastMonthInvoices, 4);
      expect(model.salesMomPercent, -100);
      expect(model.conversionPercent, 40);
      expect(model.avgInvoiceValue, closeTo(968.289, 0.001));
      expect(model.topCustomers, hasLength(1));
      expect(model.topCustomers.first.name, 'Monika');
      expect(model.docsSent, 14);
      expect(model.openDocs, 9);
      expect(model.completedDocs, 4);
      expect(model.healthyStock, 6);
      expect(model.pendingTotal, 6);
      expect(model.lowStock, hasLength(1));
      expect(model.lowStock.first.itemName, 'Battery');
    });

    test('copyWith keeps overview fields when attaching sales trend', () {
      final model =
          DashboardModel.fromJson({
            'gstCollected': 10,
            'conversionPercent': 40,
            'quotationStatus': {'sent': 3},
          }).copyWith(
            salesTrend: [
              SalesPoint(
                month: DateTime(2026, 8, 1),
                invoiceCount: 4,
                totalSales: 11000,
              ),
            ],
          );

      expect(model.gstCollected, 10);
      expect(model.conversionPercent, 40);
      expect(model.quotationStatus.sent, 3);
      expect(model.salesTrend, hasLength(1));
      expect(model.salesTrend.first.invoiceCount, 4);
    });
  });

  group('formatCompactInr', () {
    test('uses k / L / Cr suffixes like the web dashboard', () {
      expect(formatCompactInr(10651.18), '₹11k');
      expect(formatCompactInr(800000), '₹8.0 L');
      expect(formatCompactInr(523.18), '₹523.18');
      expect(formatCompactInr(1500), '₹1.5k');
    });
  });
}

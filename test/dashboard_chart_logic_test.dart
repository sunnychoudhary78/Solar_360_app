import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/dashboard/data/dashboard_chart_logic.dart';

void main() {
  group('Billbook chart calculations match web', () {
    test('Quotes vs invoices uses web status order', () {
      expect(quotesVsInvoiceStatusKeys, [
        'draft',
        'pending_approval',
        'approved',
        'sent',
        'rejected',
      ]);
    });

    test('invoice bars scale onto the sales axis independently', () {
      expect(
        scaleCountOntoSalesAxis(2, maxCount: 2, maxSales: 15750),
        15750,
      );
      expect(
        scaleCountOntoSalesAxis(1, maxCount: 2, maxSales: 15750),
        7875,
      );
      expect(scaleCountOntoSalesAxis(0, maxCount: 2, maxSales: 15750), 0);
      expect(scaleCountOntoSalesAxis(3, maxCount: 0, maxSales: 100), 0);
    });

    test('right-axis ticks convert sales scale back to invoice counts', () {
      expect(
        salesAxisToCount(15750, maxCount: 2, maxSales: 15750),
        2,
      );
      expect(
        salesAxisToCount(7875, maxCount: 2, maxSales: 15750),
        1,
      );
      expect(salesAxisToCount(0, maxCount: 2, maxSales: 15750), 0);
    });

    test('right-axis hides the padded tick so the top count is not drawn twice', () {
      expect(
        salesAxisCountLabel(15750, maxCount: 4, maxSales: 15750),
        '4',
      );
      expect(
        salesAxisCountLabel(15750 * 1.2, maxCount: 4, maxSales: 15750),
        '',
      );
      expect(
        salesAxisCountInterval(maxCount: 4, maxSales: 15750),
        15750 / 4,
      );
    });
  });
}

/// Chart math shared by Billbook overview graphs (web `BillbookDashboardOverview`).
const quotesVsInvoiceStatusKeys = [
  'draft',
  'pending_approval',
  'approved',
  'sent',
  'rejected',
];

/// Map an invoice-count series onto the sales/revenue Y axis (independent axes).
double scaleCountOntoSalesAxis(
  int count, {
  required int maxCount,
  required double maxSales,
}) {
  if (maxCount <= 0 || maxSales <= 0) return 0;
  return (count / maxCount) * maxSales;
}

/// Inverse of [scaleCountOntoSalesAxis] for right-axis tick labels.
int salesAxisToCount(
  double value, {
  required int maxCount,
  required double maxSales,
}) {
  if (maxCount <= 0 || maxSales <= 0) return 0;
  return ((value / maxSales) * maxCount).round().clamp(0, maxCount);
}

/// Hide padded ticks above max sales so the top invoice count is not drawn twice.
String salesAxisCountLabel(
  double value, {
  required int maxCount,
  required double maxSales,
}) {
  if (maxCount <= 0 || maxSales <= 0) return '';
  if (value < -0.01 || value > maxSales * 1.001) return '';
  return '${salesAxisToCount(value, maxCount: maxCount, maxSales: maxSales)}';
}

double? salesAxisCountInterval({
  required int maxCount,
  required double maxSales,
}) {
  if (maxCount <= 0 || maxSales <= 0) return null;
  return maxSales / maxCount;
}

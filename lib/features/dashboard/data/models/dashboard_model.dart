import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class SalesPoint {
  final DateTime? month;
  final int invoiceCount;
  final double totalSales;

  const SalesPoint({this.month, this.invoiceCount = 0, this.totalSales = 0});

  factory SalesPoint.fromJson(Map<String, dynamic> json) {
    return SalesPoint(
      month: parseDate(json['month']),
      invoiceCount: asInt(json['invoice_count'] ?? json['invoiceCount']),
      totalSales: asDouble(json['total_sales'] ?? json['totalSales']),
    );
  }
}

class DocumentStatusCounts {
  final int draft;
  final int pendingApproval;
  final int approved;
  final int rejected;
  final int sent;

  const DocumentStatusCounts({
    this.draft = 0,
    this.pendingApproval = 0,
    this.approved = 0,
    this.rejected = 0,
    this.sent = 0,
  });

  factory DocumentStatusCounts.fromJson(dynamic json) {
    if (json is! Map) return const DocumentStatusCounts();
    final map = Map<String, dynamic>.from(json);
    return DocumentStatusCounts(
      draft: asInt(map['draft']),
      pendingApproval: asInt(map['pending_approval'] ?? map['pendingApproval']),
      approved: asInt(map['approved']),
      rejected: asInt(map['rejected']),
      sent: asInt(map['sent']),
    );
  }

  int valueFor(String key) {
    switch (key) {
      case 'draft':
        return draft;
      case 'pending_approval':
        return pendingApproval;
      case 'approved':
        return approved;
      case 'rejected':
        return rejected;
      case 'sent':
        return sent;
      default:
        return 0;
    }
  }
}

class TopCustomer {
  final String customerId;
  final String name;
  final int invoiceCount;
  final double totalSales;

  const TopCustomer({
    this.customerId = '',
    this.name = '',
    this.invoiceCount = 0,
    this.totalSales = 0,
  });

  factory TopCustomer.fromJson(Map<String, dynamic> json) {
    return TopCustomer(
      customerId: asString(json['customer_id'] ?? json['customerId']),
      name: asString(json['name'], 'Unknown'),
      invoiceCount: asInt(json['invoice_count'] ?? json['invoiceCount']),
      totalSales: asDouble(json['total_sales'] ?? json['totalSales']),
    );
  }
}

class DashboardModel {
  final int customersCount;
  final int itemsCount;
  final int approvedItemsCount;
  final int pendingItemsCount;
  final int quotationsCount;
  final int pendingQuotations;
  final int invoicesCount;
  final int pendingInvoices;
  final int lowStockCount;
  final double totalSales;
  final int? inventoryHealthPercent;
  final List<StockModel> lowStock;
  final List<SalesPoint> salesTrend;
  final double gstCollected;
  final double quotationPipelineValue;
  final DocumentStatusCounts quotationStatus;
  final DocumentStatusCounts invoiceStatus;
  final double thisMonthSales;
  final double lastMonthSales;
  final int thisMonthInvoices;
  final int lastMonthInvoices;
  final int salesMomPercent;
  final int sentQuotations;
  final int invoicesFromQuotes;
  final int conversionPercent;
  final double avgInvoiceValue;
  final List<TopCustomer> topCustomers;

  const DashboardModel({
    this.customersCount = 0,
    this.itemsCount = 0,
    this.approvedItemsCount = 0,
    this.pendingItemsCount = 0,
    this.quotationsCount = 0,
    this.pendingQuotations = 0,
    this.invoicesCount = 0,
    this.pendingInvoices = 0,
    this.lowStockCount = 0,
    this.totalSales = 0,
    this.inventoryHealthPercent,
    this.lowStock = const [],
    this.salesTrend = const [],
    this.gstCollected = 0,
    this.quotationPipelineValue = 0,
    this.quotationStatus = const DocumentStatusCounts(),
    this.invoiceStatus = const DocumentStatusCounts(),
    this.thisMonthSales = 0,
    this.lastMonthSales = 0,
    this.thisMonthInvoices = 0,
    this.lastMonthInvoices = 0,
    this.salesMomPercent = 0,
    this.sentQuotations = 0,
    this.invoicesFromQuotes = 0,
    this.conversionPercent = 0,
    this.avgInvoiceValue = 0,
    this.topCustomers = const [],
  });

  int get pendingTotal =>
      pendingQuotations + pendingInvoices + pendingItemsCount;

  int get docsSent => invoiceStatus.sent + quotationStatus.sent;

  int get openDocs =>
      quotationStatus.draft +
      quotationStatus.pendingApproval +
      invoiceStatus.draft +
      invoiceStatus.pendingApproval;

  int get completedDocs => invoiceStatus.sent + invoiceStatus.approved;

  int get rejectedDocs => quotationStatus.rejected + invoiceStatus.rejected;

  int get healthyStock {
    final value = approvedItemsCount - lowStockCount;
    return value < 0 ? 0 : value;
  }

  int get completionPercent {
    if (quotationsCount <= 0) return 0;
    final base = sentQuotations > 0 ? sentQuotations : quotationsCount;
    if (base <= 0) return 0;
    return ((invoicesFromQuotes / base) * 100).round();
  }

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final lowRaw = json['lowStock'] ?? json['low_stock'] ?? [];
    final topRaw = json['topCustomers'] ?? json['top_customers'] ?? [];
    return DashboardModel(
      customersCount: asInt(json['customersCount'] ?? json['customers_count']),
      itemsCount: asInt(json['itemsCount'] ?? json['items_count']),
      approvedItemsCount: asInt(
        json['approvedItemsCount'] ?? json['approved_items_count'],
      ),
      pendingItemsCount: asInt(
        json['pendingItemsCount'] ?? json['pending_items_count'],
      ),
      quotationsCount: asInt(
        json['quotationsCount'] ?? json['quotations_count'],
      ),
      pendingQuotations: asInt(
        json['pendingQuotations'] ?? json['pending_quotations'],
      ),
      invoicesCount: asInt(json['invoicesCount'] ?? json['invoices_count']),
      pendingInvoices: asInt(
        json['pendingInvoices'] ?? json['pending_invoices'],
      ),
      lowStockCount: asInt(json['lowStockCount'] ?? json['low_stock_count']),
      totalSales: asDouble(json['totalSales'] ?? json['total_sales']),
      inventoryHealthPercent:
          json['inventoryHealthPercent'] == null &&
              json['inventory_health_percent'] == null
          ? null
          : asInt(
              json['inventoryHealthPercent'] ??
                  json['inventory_health_percent'],
            ),
      lowStock: lowRaw is List
          ? lowRaw
                .whereType<Map>()
                .map((e) => StockModel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      gstCollected: asDouble(json['gstCollected'] ?? json['gst_collected']),
      quotationPipelineValue: asDouble(
        json['quotationPipelineValue'] ?? json['quotation_pipeline_value'],
      ),
      quotationStatus: DocumentStatusCounts.fromJson(
        json['quotationStatus'] ?? json['quotation_status'],
      ),
      invoiceStatus: DocumentStatusCounts.fromJson(
        json['invoiceStatus'] ?? json['invoice_status'],
      ),
      thisMonthSales: asDouble(
        json['thisMonthSales'] ?? json['this_month_sales'],
      ),
      lastMonthSales: asDouble(
        json['lastMonthSales'] ?? json['last_month_sales'],
      ),
      thisMonthInvoices: asInt(
        json['thisMonthInvoices'] ?? json['this_month_invoices'],
      ),
      lastMonthInvoices: asInt(
        json['lastMonthInvoices'] ?? json['last_month_invoices'],
      ),
      salesMomPercent: asInt(
        json['salesMomPercent'] ?? json['sales_mom_percent'],
      ),
      sentQuotations: asInt(json['sentQuotations'] ?? json['sent_quotations']),
      invoicesFromQuotes: asInt(
        json['invoicesFromQuotes'] ?? json['invoices_from_quotes'],
      ),
      conversionPercent: asInt(
        json['conversionPercent'] ?? json['conversion_percent'],
      ),
      avgInvoiceValue: asDouble(
        json['avgInvoiceValue'] ?? json['avg_invoice_value'],
      ),
      topCustomers: topRaw is List
          ? topRaw
                .whereType<Map>()
                .map((e) => TopCustomer.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  DashboardModel copyWith({List<SalesPoint>? salesTrend}) {
    return DashboardModel(
      customersCount: customersCount,
      itemsCount: itemsCount,
      approvedItemsCount: approvedItemsCount,
      pendingItemsCount: pendingItemsCount,
      quotationsCount: quotationsCount,
      pendingQuotations: pendingQuotations,
      invoicesCount: invoicesCount,
      pendingInvoices: pendingInvoices,
      lowStockCount: lowStockCount,
      totalSales: totalSales,
      inventoryHealthPercent: inventoryHealthPercent,
      lowStock: lowStock,
      salesTrend: salesTrend ?? this.salesTrend,
      gstCollected: gstCollected,
      quotationPipelineValue: quotationPipelineValue,
      quotationStatus: quotationStatus,
      invoiceStatus: invoiceStatus,
      thisMonthSales: thisMonthSales,
      lastMonthSales: lastMonthSales,
      thisMonthInvoices: thisMonthInvoices,
      lastMonthInvoices: lastMonthInvoices,
      salesMomPercent: salesMomPercent,
      sentQuotations: sentQuotations,
      invoicesFromQuotes: invoicesFromQuotes,
      conversionPercent: conversionPercent,
      avgInvoiceValue: avgInvoiceValue,
      topCustomers: topCustomers,
    );
  }
}

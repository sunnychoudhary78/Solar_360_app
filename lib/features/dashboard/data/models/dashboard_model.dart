import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class SalesPoint {
  final DateTime? month;
  final int invoiceCount;
  final double totalSales;

  const SalesPoint({
    this.month,
    this.invoiceCount = 0,
    this.totalSales = 0,
  });

  factory SalesPoint.fromJson(Map<String, dynamic> json) {
    return SalesPoint(
      month: parseDate(json['month']),
      invoiceCount: asInt(json['invoice_count']),
      totalSales: asDouble(json['total_sales']),
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
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final lowRaw = json['lowStock'] ?? json['low_stock'] ?? [];
    return DashboardModel(
      customersCount: asInt(json['customersCount'] ?? json['customers_count']),
      itemsCount: asInt(json['itemsCount'] ?? json['items_count']),
      approvedItemsCount:
          asInt(json['approvedItemsCount'] ?? json['approved_items_count']),
      pendingItemsCount:
          asInt(json['pendingItemsCount'] ?? json['pending_items_count']),
      quotationsCount:
          asInt(json['quotationsCount'] ?? json['quotations_count']),
      pendingQuotations:
          asInt(json['pendingQuotations'] ?? json['pending_quotations']),
      invoicesCount: asInt(json['invoicesCount'] ?? json['invoices_count']),
      pendingInvoices:
          asInt(json['pendingInvoices'] ?? json['pending_invoices']),
      lowStockCount: asInt(json['lowStockCount'] ?? json['low_stock_count']),
      totalSales: asDouble(json['totalSales'] ?? json['total_sales']),
      inventoryHealthPercent: json['inventoryHealthPercent'] == null &&
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
    );
  }
}

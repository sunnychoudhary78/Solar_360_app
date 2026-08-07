import 'package:solar_sales/features/dashboard/data/models/dashboard_model.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class ReportQuotationRow {
  final String id;
  final String quotationNumber;
  final String? customerName;
  final double totalAmount;
  final String status;

  const ReportQuotationRow({
    required this.id,
    required this.quotationNumber,
    this.customerName,
    this.totalAmount = 0,
    this.status = '',
  });

  factory ReportQuotationRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return ReportQuotationRow(
      id: asString(json['id']),
      quotationNumber: asString(json['quotation_number']),
      customerName: customer is Map ? customer['name']?.toString() : null,
      totalAmount: asDouble(json['total_amount']),
      status: asString(json['status']),
    );
  }
}

class ReportInvoiceRow {
  final String id;
  final String invoiceNumber;
  final String? customerName;
  final double totalAmount;
  final String status;

  const ReportInvoiceRow({
    required this.id,
    required this.invoiceNumber,
    this.customerName,
    this.totalAmount = 0,
    this.status = '',
  });

  factory ReportInvoiceRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return ReportInvoiceRow(
      id: asString(json['id']),
      invoiceNumber: asString(json['invoice_number']),
      customerName: customer is Map ? customer['name']?.toString() : null,
      totalAmount: asDouble(json['total_amount']),
      status: asString(json['status']),
    );
  }
}

class ReportsBundle {
  final List<SalesPoint> sales;
  final List<StockModel> stock;
  final List<ReportQuotationRow> quotations;
  final List<ReportInvoiceRow> invoices;

  const ReportsBundle({
    this.sales = const [],
    this.stock = const [],
    this.quotations = const [],
    this.invoices = const [],
  });
}

List<T> _parseList<T>(
  dynamic res,
  T Function(Map<String, dynamic>) fromJson,
) {
  final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
  return list
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

ReportsBundle parseReportsBundle({
  required dynamic salesRes,
  required dynamic stockRes,
  required dynamic quotationsRes,
  required dynamic invoicesRes,
}) {
  return ReportsBundle(
    sales: _parseList(salesRes, SalesPoint.fromJson),
    stock: _parseList(stockRes, StockModel.fromJson),
    quotations: _parseList(quotationsRes, ReportQuotationRow.fromJson),
    invoices: _parseList(invoicesRes, ReportInvoiceRow.fromJson),
  );
}

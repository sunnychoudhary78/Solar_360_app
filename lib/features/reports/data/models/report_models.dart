import 'package:solar_sales/features/dashboard/data/models/dashboard_model.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class ReportQuotationRow {
  final String id;
  final String quotationNumber;
  final String? customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerCity;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String status;
  final String validUntil;
  final String notes;
  final String? approvedAt;
  final String? createdAt;
  final String? updatedAt;

  const ReportQuotationRow({
    required this.id,
    required this.quotationNumber,
    this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerCity = '',
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.status = '',
    this.validUntil = '',
    this.notes = '',
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportQuotationRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return ReportQuotationRow(
      id: asString(json['id']),
      quotationNumber: asString(json['quotation_number']),
      customerName: customer is Map ? customer['name']?.toString() : null,
      customerPhone: customer is Map ? asString(customer['phone']) : '',
      customerEmail: customer is Map ? asString(customer['email']) : '',
      customerCity: customer is Map ? asString(customer['city']) : '',
      subtotal: asDouble(json['subtotal']),
      gstAmount: asDouble(json['gst_amount']),
      totalAmount: asDouble(json['total_amount']),
      status: asString(json['status']),
      validUntil: asString(json['valid_until']),
      notes: asString(json['notes']),
      approvedAt: json['approved_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class ReportInvoiceRow {
  final String id;
  final String invoiceNumber;
  final String? customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerCity;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String status;
  final String paymentMode;
  final bool stockDeducted;
  final String ewayBillNo;
  final String motorVehicleNo;
  final String notes;
  final String? approvedAt;
  final String? createdAt;
  final String? updatedAt;

  const ReportInvoiceRow({
    required this.id,
    required this.invoiceNumber,
    this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerCity = '',
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.status = '',
    this.paymentMode = '',
    this.stockDeducted = false,
    this.ewayBillNo = '',
    this.motorVehicleNo = '',
    this.notes = '',
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportInvoiceRow.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return ReportInvoiceRow(
      id: asString(json['id']),
      invoiceNumber: asString(json['invoice_number']),
      customerName: customer is Map ? customer['name']?.toString() : null,
      customerPhone: customer is Map ? asString(customer['phone']) : '',
      customerEmail: customer is Map ? asString(customer['email']) : '',
      customerCity: customer is Map ? asString(customer['city']) : '',
      subtotal: asDouble(json['subtotal']),
      gstAmount: asDouble(json['gst_amount']),
      totalAmount: asDouble(json['total_amount']),
      status: asString(json['status']),
      paymentMode: asString(json['payment_mode']),
      stockDeducted: asBool(json['stock_deducted']),
      ewayBillNo: asString(json['eway_bill_no']),
      motorVehicleNo: asString(json['motor_vehicle_no']),
      notes: asString(json['notes']),
      approvedAt: json['approved_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
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

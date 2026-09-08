import 'package:intl/intl.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/inventory/data/models/inventory_models.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/reports/data/models/report_models.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

double excelMoney(num? value) {
  final v = (value ?? 0).toDouble();
  if (v.isNaN || v.isInfinite) return 0;
  return (v * 100).round() / 100;
}

String excelStatusLabel(String? status) {
  return AppStatusColors.labelFor(status ?? '');
}

String excelDateTimeText(dynamic value) {
  final parsed = value is DateTime ? value : parseDate(value);
  if (parsed == null) return '';
  return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
}

String excelMonthLabel(DateTime? month) {
  if (month == null) return '';
  return DateFormat.yMMMM().format(month.toLocal());
}

String leadExcelName(LeadModel lead) {
  final name = lead.fullName.trim();
  if (name.isNotEmpty) return name;
  return lead.leadCode.trim();
}

String leadExcelCapacity(LeadModel lead) {
  final raw = lead.loadSectionKw.trim();
  if (raw.isEmpty || raw == '-' || raw == '—') return '';
  return raw;
}

List<Map<String, Object?>> billbookSalesRows(ReportsBundle data) {
  final sales = data.sales;
  final salesTotal = sales.fold<double>(0, (sum, row) => sum + row.totalSales);
  final salesBase = salesTotal == 0 ? 1 : salesTotal;

  return sales.map((row) {
    final invoiceCount = row.invoiceCount;
    final totalSales = excelMoney(row.totalSales);
    return {
      'Month': excelMonthLabel(row.month),
      'Invoice Count': invoiceCount,
      'Total Sales (₹)': totalSales,
      'Avg Invoice (₹)': invoiceCount == 0
          ? 0
          : excelMoney(totalSales / invoiceCount),
      'Share of Sales (%)': excelMoney((totalSales / salesBase) * 100),
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> billbookInvoiceRows(ReportsBundle data) {
  return data.invoices.map((inv) {
    return {
      'Invoice Number': inv.invoiceNumber,
      'Customer': inv.customerName ?? '',
      'Phone': inv.customerPhone,
      'Email': inv.customerEmail,
      'City': inv.customerCity,
      'Status': excelStatusLabel(inv.status),
      'Subtotal (₹)': excelMoney(inv.subtotal),
      'GST (₹)': excelMoney(inv.gstAmount),
      'Total (₹)': excelMoney(inv.totalAmount),
      'Payment Mode': inv.paymentMode,
      'Stock Deducted': inv.stockDeducted ? 'Yes' : 'No',
      'E-Way Bill': inv.ewayBillNo,
      'Vehicle No': inv.motorVehicleNo,
      'Approved At': excelDateTimeText(inv.approvedAt),
      'Created At': excelDateTimeText(inv.createdAt),
      'Updated At': excelDateTimeText(inv.updatedAt),
      'Notes': inv.notes,
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> billbookQuotationRows(ReportsBundle data) {
  return data.quotations.map((q) {
    return {
      'Quotation Number': q.quotationNumber,
      'Customer': q.customerName ?? '',
      'Phone': q.customerPhone,
      'Email': q.customerEmail,
      'City': q.customerCity,
      'Status': excelStatusLabel(q.status),
      'Subtotal (₹)': excelMoney(q.subtotal),
      'GST (₹)': excelMoney(q.gstAmount),
      'Total (₹)': excelMoney(q.totalAmount),
      'Valid Until': q.validUntil,
      'Approved At': excelDateTimeText(q.approvedAt),
      'Created At': excelDateTimeText(q.createdAt),
      'Updated At': excelDateTimeText(q.updatedAt),
      'Notes': q.notes,
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> billbookStockRows(List<StockModel> stock) {
  return stock.map((s) {
    return {
      'Item': s.itemName,
      'SKU': s.item?.sku ?? '',
      'Category': s.item?.category ?? '',
      'Warehouse': s.warehouseName,
      'Quantity': s.currentQuantity,
      'Total Across Warehouses': s.totalQuantity == 0
          ? s.currentQuantity
          : s.totalQuantity,
      'Min Level': s.minStock,
      'Status': s.isLowStock ? 'Low' : 'OK',
      'Updated At': '',
    };
  }).toList(growable: false);
}

List<MapEntry<String, int>> countByLabel(Iterable<String> labels) {
  final map = <String, int>{};
  for (final raw in labels) {
    final key = raw.trim().isEmpty ? '—' : raw.trim();
    map[key] = (map[key] ?? 0) + 1;
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

List<Map<String, Object?>> greenEnergyStatusRows(List<LeadModel> leads) {
  return countByLabel(
    leads.map(
      (l) => LeadWorkflow.getStatusDisplayLabel(
        l.status.trim().isEmpty ? 'Unknown' : l.status,
      ),
    ),
  ).map((e) => {'Status': e.key, 'Count': e.value}).toList(growable: false);
}

List<Map<String, Object?>> greenEnergyDepartmentRows(List<LeadModel> leads) {
  return countByLabel(
    leads.map((l) {
      final label = LeadWorkflow.resolveDepartmentLabel(l.currentDepartment);
      return label.isEmpty ? 'Unassigned' : label;
    }),
  ).map((e) => {'Department': e.key, 'Count': e.value}).toList(growable: false);
}

List<Map<String, Object?>> greenEnergyStateRows(List<LeadModel> leads) {
  return countByLabel(
    leads.map((l) => l.state.trim().isEmpty ? 'Unknown' : l.state.trim()),
  ).map((e) => {'State': e.key, 'Count': e.value}).toList(growable: false);
}

List<Map<String, Object?>> greenEnergyLeadRows(List<LeadModel> leads) {
  return leads.map((lead) {
    return {
      'Lead ID': lead.leadCode.isNotEmpty ? lead.leadCode : lead.id,
      'Name': leadExcelName(lead),
      'Phone': lead.mobile,
      'Email': lead.email,
      'Status': LeadWorkflow.getStatusDisplayLabel(lead.status),
      'Department': LeadWorkflow.resolveDepartmentLabel(lead.currentDepartment),
      'Priority': lead.priority,
      'State': lead.state,
      'District': lead.district.isNotEmpty ? lead.district : lead.city,
      'Capacity': leadExcelCapacity(lead),
      'Source': lead.source,
      'Created By': lead.createdByName.isNotEmpty
          ? lead.createdByName
          : lead.createdBy,
      'Created At': excelDateTimeText(lead.createdAt),
      'Updated At': excelDateTimeText(lead.updatedAt),
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> leadListExcelRows(List<LeadModel> leads) {
  return leads.map((lead) {
    return {
      'Lead Code': lead.leadCode,
      'Name': leadExcelName(lead),
      'Mobile': lead.mobile,
      'Email': lead.email,
      'Status': LeadWorkflow.getStatusDisplayLabel(lead.status),
      'Department': LeadWorkflow.resolveDepartmentLabel(lead.currentDepartment),
      'Stage': lead.leadStage,
      'City': lead.city,
      'Assigned To': lead.assignedToName.isNotEmpty
          ? lead.assignedToName
          : lead.assignedTo,
      'Active': lead.isActive ? 'Yes' : 'No',
    };
  }).toList(growable: false);
}

List<Map<String, Object?>> customerExcelRows(List<CustomerModel> customers) {
  return customers.map((customer) {
    return {
      'Name': customer.name,
      'Email': customer.email ?? '',
      'Phone': customer.phone ?? '',
      'City': customer.city ?? '',
      'State': customer.state ?? '',
      'Pincode': customer.pincode ?? '',
      'GST': customer.gstNumber ?? '',
      'Aadhar': customer.aadharNumber ?? '',
      'Address': customer.address ?? '',
      'Created By': customer.createdByName,
      'Created At': excelDateTimeText(customer.createdAt),
      'Updated At': excelDateTimeText(customer.updatedAt),
    };
  }).toList(growable: false);
}

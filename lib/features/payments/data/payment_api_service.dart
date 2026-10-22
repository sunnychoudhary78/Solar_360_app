import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/payment_models.dart';

/// Collections API client — mirrors the web `paymentsApi`.
class PaymentApiService {
  final ApiService _api;

  PaymentApiService(this._api);

  Future<PaymentDashboardModel> dashboard() async {
    final res = await _api.get(ApiEndpoints.paymentsDashboard);
    return PaymentDashboardModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// Paginated milestone list (always invoices — `source_type` alone is ignored
  /// by the API unless `source_id` is present).
  Future<PaginatedResult<PaymentScheduleModel>> list({
    String? status,
    bool overdue = false,
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.paymentSchedules,
      queryParams: {
        'source_type': 'invoice',
        if (overdue) 'overdue': 'true',
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, PaymentScheduleModel.fromJson);
  }

  /// Milestones + roll-up for one invoice (no pagination, includes receipts).
  Future<InvoicePaymentBundle> forInvoice(String invoiceId) async {
    final res = await _api.get(
      ApiEndpoints.paymentSchedules,
      queryParams: {
        'source_type': 'invoice',
        'source_id': invoiceId,
      },
    );
    return InvoicePaymentBundle.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  Future<PaymentScheduleModel> getSchedule(String id) async {
    final res = await _api.get(ApiEndpoints.paymentSchedule(id));
    return PaymentScheduleModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// `POST /api/payments` — record a receipt against a milestone.
  Future<RecordReceiptResult> recordReceipt({
    required String scheduleId,
    required double amount,
    String? mode,
    String? referenceNo,
    DateTime? paidAt,
    String? notes,
  }) async {
    final res = await _api.post(ApiEndpoints.payments, {
      'scheduleId': scheduleId,
      'amount': amount,
      if (mode != null && mode.isNotEmpty) 'mode': mode,
      if (referenceNo != null && referenceNo.trim().isNotEmpty)
        'referenceNo': referenceNo.trim(),
      if (paidAt != null) 'paidAt': paidAt.toUtc().toIso8601String(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return RecordReceiptResult.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// `POST /api/payments/schedules` — extra milestone (invoice only here).
  Future<PaymentScheduleModel> addSchedule({
    required String sourceId,
    required String title,
    required double amount,
    String? dueDate,
    bool isCustomerDue = true,
    String sourceType = 'invoice',
  }) async {
    final res = await _api.post(ApiEndpoints.paymentSchedules, {
      'sourceType': sourceType,
      'sourceId': sourceId,
      'title': title.trim(),
      'amount': amount,
      if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
      'isCustomerDue': isCustomerDue,
    });
    return PaymentScheduleModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// `PUT /api/payments/schedules/:id` — due date / amount / title / notes.
  Future<PaymentScheduleModel> updateSchedule(
    String id, {
    String? dueDate,
    double? amount,
    String? title,
    String? notes,
  }) async {
    final res = await _api.put(ApiEndpoints.paymentSchedule(id), {
      if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
      'amount': ?amount,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'notes': notes?.trim(),
    });
    return PaymentScheduleModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// Staff in-app reminder — does not message the customer.
  Future<void> remind(String scheduleId) async {
    await _api.post(ApiEndpoints.paymentScheduleRemind(scheduleId));
  }

  /// `:id` is the **receipt** id, not the milestone.
  Future<void> voidReceipt(String receiptId) async {
    await _api.delete(ApiEndpoints.paymentReceipt(receiptId));
  }
}

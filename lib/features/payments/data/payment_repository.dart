import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/payment_models.dart';
import 'payment_api_service.dart';

class PaymentRepository {
  final PaymentApiService _api;

  PaymentRepository(this._api);

  Future<PaymentDashboardModel> dashboard() => _api.dashboard();

  Future<PaginatedResult<PaymentScheduleModel>> list({
    String? status,
    bool overdue = false,
    String? q,
    int page = 1,
    int limit = 20,
  }) =>
      _api.list(
        status: status,
        overdue: overdue,
        q: q,
        page: page,
        limit: limit,
      );

  Future<InvoicePaymentBundle> forInvoice(String invoiceId) =>
      _api.forInvoice(invoiceId);

  Future<PaymentScheduleModel> getSchedule(String id) => _api.getSchedule(id);

  Future<RecordReceiptResult> recordReceipt({
    required String scheduleId,
    required double amount,
    String? mode,
    String? referenceNo,
    DateTime? paidAt,
    String? notes,
  }) =>
      _api.recordReceipt(
        scheduleId: scheduleId,
        amount: amount,
        mode: mode,
        referenceNo: referenceNo,
        paidAt: paidAt,
        notes: notes,
      );

  Future<PaymentScheduleModel> addSchedule({
    required String sourceId,
    required String title,
    required double amount,
    String? dueDate,
    bool isCustomerDue = true,
  }) =>
      _api.addSchedule(
        sourceId: sourceId,
        title: title,
        amount: amount,
        dueDate: dueDate,
        isCustomerDue: isCustomerDue,
      );

  Future<PaymentScheduleModel> updateSchedule(
    String id, {
    String? dueDate,
    double? amount,
    String? title,
    String? notes,
  }) =>
      _api.updateSchedule(
        id,
        dueDate: dueDate,
        amount: amount,
        title: title,
        notes: notes,
      );

  Future<void> remind(String scheduleId) => _api.remind(scheduleId);

  Future<void> voidReceipt(String receiptId) => _api.voidReceipt(receiptId);
}

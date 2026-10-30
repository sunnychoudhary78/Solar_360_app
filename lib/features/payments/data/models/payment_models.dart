import 'package:solar_sales/shared/utils/formatters.dart';

/// Schedule statuses (a single milestone) — web parity.
class PaymentScheduleStatus {
  PaymentScheduleStatus._();

  static const pending = 'pending';
  static const partial = 'partial';
  static const paid = 'paid';
  static const overdue = 'overdue';
  static const waived = 'waived';
}

/// Invoice roll-up statuses returned in `summary.status` / `invoice.payment`.
class InvoicePaymentStatus {
  InvoicePaymentStatus._();

  static const unpaid = 'unpaid';
  static const partial = 'partial';
  static const paid = 'paid';
  static const overdue = 'overdue';
}

class PaymentCustomerInfo {
  final String id;
  final String name;
  final String? phone;
  final String? email;

  const PaymentCustomerInfo({
    this.id = '',
    this.name = '',
    this.phone,
    this.email,
  });

  factory PaymentCustomerInfo.fromJson(Map<String, dynamic> json) {
    return PaymentCustomerInfo(
      id: asString(json['id']),
      name: asString(json['name']),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class PaymentReceiptModel {
  final String id;
  final String? scheduleId;
  final String? invoiceId;
  final double amount;
  final DateTime? paidAt;
  final String? mode;
  final String? referenceNo;
  final String? notes;
  final String? partyName;
  final String? title;
  final String? sourceType;
  final String? sourceId;
  final String? invoiceNumber;

  const PaymentReceiptModel({
    required this.id,
    this.scheduleId,
    this.invoiceId,
    this.amount = 0,
    this.paidAt,
    this.mode,
    this.referenceNo,
    this.notes,
    this.partyName,
    this.title,
    this.sourceType,
    this.sourceId,
    this.invoiceNumber,
  });

  factory PaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptModel(
      id: asString(json['id']),
      scheduleId: json['schedule_id']?.toString(),
      invoiceId: json['invoice_id']?.toString(),
      amount: asDouble(json['amount']),
      paidAt: parseDate(json['paid_at'] ?? json['paidAt']),
      mode: json['mode']?.toString(),
      referenceNo: json['reference_no']?.toString(),
      notes: json['notes']?.toString(),
      partyName: json['party_name']?.toString(),
      title: json['title']?.toString(),
      sourceType: json['source_type']?.toString(),
      sourceId: json['source_id']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
    );
  }
}

class PaymentScheduleModel {
  final String id;
  final String? companyId;
  final String sourceType;
  final String sourceId;
  final String? quotationId;
  final String? customerId;
  final String title;
  final int sequence;
  final double percent;
  final double amount;
  final double paidAmount;
  final double balance;
  final String? dueDate;
  final String status;
  final bool isOverdue;
  final int daysOverdue;
  final bool isCustomerDue;
  final String? notes;
  final String? partyName;
  final String? invoiceNumber;
  final PaymentCustomerInfo? customer;
  final List<PaymentReceiptModel> receipts;
  final String? createdBy;
  final DateTime? createdAt;

  const PaymentScheduleModel({
    required this.id,
    this.companyId,
    this.sourceType = 'invoice',
    this.sourceId = '',
    this.quotationId,
    this.customerId,
    this.title = '',
    this.sequence = 1,
    this.percent = 0,
    this.amount = 0,
    this.paidAmount = 0,
    this.balance = 0,
    this.dueDate,
    this.status = PaymentScheduleStatus.pending,
    this.isOverdue = false,
    this.daysOverdue = 0,
    this.isCustomerDue = true,
    this.notes,
    this.partyName,
    this.invoiceNumber,
    this.customer,
    this.receipts = const [],
    this.createdBy,
    this.createdAt,
  });

  factory PaymentScheduleModel.fromJson(Map<String, dynamic> json) {
    final customerRaw = json['customer'];
    final receiptsRaw = json['receipts'];
    final amount = asDouble(json['amount']);

    final receipts = receiptsRaw is List
        ? receiptsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    PaymentReceiptModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : <PaymentReceiptModel>[];

    // Paid amount: accept alternate keys the API may use, and fall back to
    // the sum of attached receipts when the roll-up field is 0/missing.
    var paidAmount = 0.0;
    for (final key in const [
      'paid_amount',
      'paidAmount',
      'received_amount',
      'amount_paid',
      'total_paid',
    ]) {
      final v = asDouble(json[key]);
      if (v > paidAmount) paidAmount = v;
    }
    if (paidAmount <= 0 && receipts.isNotEmpty) {
      paidAmount = receipts.fold<double>(0, (s, r) => s + r.amount);
    }

    final rawBalance = json['balance'] == null
        ? (amount - paidAmount)
        : asDouble(json['balance']);
    // If the server balance wasn't reduced but money was received, trust the math.
    final balance = (paidAmount > 0 && rawBalance >= amount - 0.009)
        ? (amount - paidAmount).clamp(0, double.infinity).toDouble()
        : rawBalance;

    // Server can leave a part-paid milestone as "pending"/"overdue".
    var status = asString(json['status'], PaymentScheduleStatus.pending);
    if (paidAmount > 0.009 &&
        balance > 0.009 &&
        (status == PaymentScheduleStatus.pending ||
            status == PaymentScheduleStatus.overdue)) {
      status = PaymentScheduleStatus.partial;
    }

    return PaymentScheduleModel(
      id: asString(json['id']),
      companyId: json['company_id']?.toString(),
      sourceType: asString(json['source_type'], 'invoice'),
      sourceId: asString(json['source_id']),
      quotationId: json['quotation_id']?.toString(),
      customerId: json['customer_id']?.toString(),
      title: asString(json['title']),
      sequence: asInt(json['sequence'], 1),
      percent: asDouble(json['percent']),
      amount: amount,
      paidAmount: paidAmount,
      balance: balance,
      dueDate: json['due_date']?.toString(),
      status: status,
      isOverdue:
          asBool(json['is_overdue']) ||
          asString(json['status'], '') == PaymentScheduleStatus.overdue,
      daysOverdue: asInt(json['days_overdue']),
      isCustomerDue: json['is_customer_due'] == null
          ? true
          : asBool(json['is_customer_due']),
      notes: json['notes']?.toString(),
      partyName: json['party_name']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      customer: customerRaw is Map
          ? PaymentCustomerInfo.fromJson(Map<String, dynamic>.from(customerRaw))
          : null,
      receipts: receipts,
      createdBy: json['created_by']?.toString(),
      createdAt: parseDate(json['created_at']),
    );
  }

  /// Party/company label matching the web list.
  String get displayParty => partyName?.trim().isNotEmpty == true
      ? partyName!
      : (customer?.name.trim().isNotEmpty == true ? customer!.name : '—');

  String get displayTitle => title.trim().isNotEmpty
      ? title
      : (invoiceNumber?.trim().isNotEmpty == true
            ? 'Invoice $invoiceNumber'
            : 'Milestone');

  bool get isSettled =>
      status == PaymentScheduleStatus.paid ||
      status == PaymentScheduleStatus.waived;

  bool get canRecord => !isSettled && balance > 0.009;

  double get overdueAmount => isOverdue ? balance : 0;

  static List<PaymentScheduleModel> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PaymentScheduleModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  PaymentScheduleModel copyWith({
    double? amount,
    double? paidAmount,
    double? balance,
    String? status,
    bool? isOverdue,
    int? daysOverdue,
    List<PaymentReceiptModel>? receipts,
  }) {
    return PaymentScheduleModel(
      id: id,
      companyId: companyId,
      sourceType: sourceType,
      sourceId: sourceId,
      quotationId: quotationId,
      customerId: customerId,
      title: title,
      sequence: sequence,
      percent: percent,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      balance: balance ?? this.balance,
      dueDate: dueDate,
      status: status ?? this.status,
      isOverdue: isOverdue ?? this.isOverdue,
      daysOverdue: daysOverdue ?? this.daysOverdue,
      isCustomerDue: isCustomerDue,
      notes: notes,
      partyName: partyName,
      invoiceNumber: invoiceNumber,
      customer: customer,
      receipts: receipts ?? this.receipts,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  // PaymentScheduleModel copyWith({
  //   double? paidAmount,
  //   double? balance,
  //   String? status,
  // }) {
  //   return PaymentScheduleModel(
  //     id: id,
  //     companyId: companyId,
  //     sourceType: sourceType,
  //     sourceId: sourceId,
  //     quotationId: quotationId,
  //     customerId: customerId,
  //     title: title,
  //     sequence: sequence,
  //     percent: percent,
  //     amount: amount,
  //     paidAmount: paidAmount ?? this.paidAmount,
  //     balance: balance ?? this.balance,
  //     dueDate: dueDate,
  //     status: status ?? this.status,
  //     isOverdue: isOverdue,
  //     daysOverdue: daysOverdue,
  //     isCustomerDue: isCustomerDue,
  //     notes: notes,
  //     partyName: partyName,
  //     invoiceNumber: invoiceNumber,
  //     customer: customer,
  //     receipts: receipts,
  //     createdBy: createdBy,
  //     createdAt: createdAt,
  //   );
  // }
}

/// Invoice roll-up (`summary` on the schedules-for-invoice call, `payment` on
/// invoice detail / list rows).
class InvoicePaymentSummaryModel {
  final String status;
  final double amount;
  final double paidAmount;
  final double balance;
  final String? dueDate;
  final int overdueCount;
  final List<PaymentScheduleModel> schedules;

  const InvoicePaymentSummaryModel({
    this.status = InvoicePaymentStatus.unpaid,
    this.amount = 0,
    this.paidAmount = 0,
    this.balance = 0,
    this.dueDate,
    this.overdueCount = 0,
    this.schedules = const [],
  });

  factory InvoicePaymentSummaryModel.fromJson(Map<String, dynamic> json) {
    final schedulesRaw = json['schedules'];
    final amount = asDouble(json['amount']);
    final paidAmount = asDouble(json['paid_amount']);
    return InvoicePaymentSummaryModel(
      status: asString(json['status'], InvoicePaymentStatus.unpaid),
      amount: amount,
      paidAmount: paidAmount,
      balance: json['balance'] == null
          ? (amount - paidAmount)
          : asDouble(json['balance']),
      dueDate: json['due_date']?.toString(),
      overdueCount: asInt(json['overdue_count']),
      schedules: schedulesRaw is List
          ? schedulesRaw
                .whereType<Map>()
                .map(
                  (e) => PaymentScheduleModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
    );
  }

  double get progress => amount <= 0 ? 0 : (paidAmount / amount).clamp(0, 1);

  bool get isOverdue => status == InvoicePaymentStatus.overdue;
}

/// Result of `GET /api/payments/schedules?source_id=…` (milestones + summary).
class InvoicePaymentBundle {
  final List<PaymentScheduleModel> schedules;
  final InvoicePaymentSummaryModel? summary;

  const InvoicePaymentBundle({this.schedules = const [], this.summary});

  factory InvoicePaymentBundle.fromJson(Map<String, dynamic> json) {
    return InvoicePaymentBundle(
      schedules: PaymentScheduleModel.listFromJson(json['data']),
      summary: json['summary'] is Map
          ? InvoicePaymentSummaryModel.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map),
            )
          : null,
    );
  }

  /// Roll-up derived locally when the API omits `summary` (e.g. no milestones).
  InvoicePaymentSummaryModel get effectiveSummary {
    if (summary != null) return summary!;
    final total = schedules.fold<double>(0, (sum, s) => sum + s.amount);
    final paid = schedules.fold<double>(0, (sum, s) => sum + s.paidAmount);
    final overdueCount = schedules.where((s) => s.isOverdue).length;
    final status = total <= 0
        ? InvoicePaymentStatus.unpaid
        : paid >= total - 0.009
        ? InvoicePaymentStatus.paid
        : paid > 0
        ? InvoicePaymentStatus.partial
        : InvoicePaymentStatus.unpaid;
    return InvoicePaymentSummaryModel(
      status: overdueCount > 0 ? InvoicePaymentStatus.overdue : status,
      amount: total,
      paidAmount: paid,
      balance: total - paid,
      dueDate: schedules.isEmpty ? null : schedules.first.dueDate,
      overdueCount: overdueCount,
      schedules: schedules,
    );
  }
}

class PaymentAgingModel {
  final double d0_15;
  final double d16_30;
  final double d31_60;
  final double d60plus;

  const PaymentAgingModel({
    this.d0_15 = 0,
    this.d16_30 = 0,
    this.d31_60 = 0,
    this.d60plus = 0,
  });

  factory PaymentAgingModel.fromJson(Map<String, dynamic> json) {
    return PaymentAgingModel(
      d0_15: asDouble(json['d0_15']),
      d16_30: asDouble(json['d16_30']),
      d31_60: asDouble(json['d31_60']),
      d60plus: asDouble(json['d60plus']),
    );
  }

  double get total => d0_15 + d16_30 + d31_60 + d60plus;

  List<PaymentAgingBucket> get buckets => [
    PaymentAgingBucket('0–15d', d0_15),
    PaymentAgingBucket('16–30d', d16_30),
    PaymentAgingBucket('31–60d', d31_60),
    PaymentAgingBucket('60d+', d60plus),
  ];
}

class PaymentAgingBucket {
  final String label;
  final double amount;

  const PaymentAgingBucket(this.label, this.amount);
}

class PaymentDashboardModel {
  final double collectedThisMonth;
  final double outstanding;
  final double overdueAmount;
  final int overdueCount;
  final double dueThisWeekAmount;
  final int dueThisWeekCount;
  final int paidCount;
  final int partialCount;
  final int pendingCount;
  final PaymentAgingModel aging;
  final List<PaymentScheduleModel> topOverdue;
  final List<PaymentScheduleModel> dueThisWeek;
  final List<PaymentReceiptModel> recentPayments;

  const PaymentDashboardModel({
    this.collectedThisMonth = 0,
    this.outstanding = 0,
    this.overdueAmount = 0,
    this.overdueCount = 0,
    this.dueThisWeekAmount = 0,
    this.dueThisWeekCount = 0,
    this.paidCount = 0,
    this.partialCount = 0,
    this.pendingCount = 0,
    this.aging = const PaymentAgingModel(),
    this.topOverdue = const [],
    this.dueThisWeek = const [],
    this.recentPayments = const [],
  });

  factory PaymentDashboardModel.fromJson(Map<String, dynamic> json) {
    final agingRaw = json['aging'];
    return PaymentDashboardModel(
      collectedThisMonth: asDouble(json['collectedThisMonth']),
      outstanding: asDouble(json['outstanding']),
      overdueAmount: asDouble(json['overdueAmount']),
      overdueCount: asInt(json['overdueCount']),
      dueThisWeekAmount: asDouble(json['dueThisWeekAmount']),
      dueThisWeekCount: asInt(json['dueThisWeekCount']),
      paidCount: asInt(json['paidCount']),
      partialCount: asInt(json['partialCount']),
      pendingCount: asInt(json['pendingCount']),
      aging: agingRaw is Map
          ? PaymentAgingModel.fromJson(Map<String, dynamic>.from(agingRaw))
          : const PaymentAgingModel(),
      topOverdue: PaymentScheduleModel.listFromJson(json['topOverdue']),
      dueThisWeek: PaymentScheduleModel.listFromJson(json['dueThisWeek']),
      recentPayments: (json['recentPayments'] is List)
          ? (json['recentPayments'] as List)
                .whereType<Map>()
                .map(
                  (e) => PaymentReceiptModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

/// `POST /api/payments` response.
class RecordReceiptResult {
  final PaymentReceiptModel? receipt;
  final PaymentScheduleModel? schedule;

  const RecordReceiptResult({this.receipt, this.schedule});

  factory RecordReceiptResult.fromJson(Map<String, dynamic> json) {
    return RecordReceiptResult(
      receipt: json['receipt'] is Map
          ? PaymentReceiptModel.fromJson(
              Map<String, dynamic>.from(json['receipt'] as Map),
            )
          : null,
      schedule: json['schedule'] is Map
          ? PaymentScheduleModel.fromJson(
              Map<String, dynamic>.from(json['schedule'] as Map),
            )
          : null,
    );
  }
}

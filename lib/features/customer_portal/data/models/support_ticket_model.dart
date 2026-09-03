import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

class SupportTicketParty {
  final String id;
  final String name;
  final String? email;
  final String? phone;

  const SupportTicketParty({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  factory SupportTicketParty.fromJson(dynamic json) {
    if (json is! Map) {
      return const SupportTicketParty(id: '', name: '');
    }
    final map = Map<String, dynamic>.from(json);
    return SupportTicketParty(
      id: asString(map['id']),
      name: asString(map['name']),
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
    );
  }
}

class SupportTicketMessage {
  final String id;
  final String message;
  final String senderType;
  final String senderId;
  final String senderName;
  final bool isInternal;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const SupportTicketMessage({
    required this.id,
    required this.message,
    this.senderType = 'customer',
    this.senderId = '',
    this.senderName = '',
    this.isInternal = false,
    this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  bool get isCustomer => senderType.toLowerCase() == 'customer';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json['sender'] is Map
        ? Map<String, dynamic>.from(json['sender'] as Map)
        : null;
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : null;
    var senderType = asString(
      json['sender_type'] ?? json['senderType'] ?? json['role'],
    ).toLowerCase();
    final hasStaffSender =
        user != null ||
        asString(json['user_id'] ?? json['userId']).isNotEmpty;
    if (senderType.isEmpty) {
      senderType = hasStaffSender ? 'admin' : 'customer';
    }
    final isCustomer = senderType == 'customer';
    final senderId = asString(
      json['user_id'] ??
          json['userId'] ??
          json['customer_id'] ??
          json['customerId'] ??
          user?['id'] ??
          customer?['id'],
    );
    final senderName = asString(
      json['sender_name'] ??
          json['senderName'] ??
          json['user_name'] ??
          json['userName'] ??
          (isCustomer ? customer : user)?['name'] ??
          user?['name'] ??
          customer?['name'],
    );
    return SupportTicketMessage(
      id: asString(json['id'] ?? json['message_id'] ?? json['messageId']),
      message: asString(
        json['message'] ?? json['body'] ?? json['text'] ?? json['content'],
      ),
      senderType: senderType,
      senderId: senderId,
      senderName: senderName,
      isInternal: _asFlag(json['is_internal'] ?? json['isInternal']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      deliveredAt: parseDate(
        json['delivered_at'] ??
            json['deliveredAt'] ??
            json['delivery_at'] ??
            json['deliveryAt'],
      ),
      readAt: parseDate(
        json['read_at'] ?? json['readAt'] ?? json['seen_at'] ?? json['seenAt'],
      ),
    );
  }

  static bool _asFlag(dynamic value) {
    if (value == true || value == 1) return true;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}

class SupportTicketHistoryItem {
  final String id;
  final String action;
  final String note;
  final DateTime? createdAt;

  const SupportTicketHistoryItem({
    required this.id,
    required this.action,
    required this.note,
    this.createdAt,
  });

  factory SupportTicketHistoryItem.fromJson(Map<String, dynamic> json) {
    return SupportTicketHistoryItem(
      id: asString(json['id']),
      action: asString(
        json['action'] ??
            json['event'] ??
            json['new_status'] ??
            json['newStatus'] ??
            json['status'],
      ),
      note: asString(
        json['note'] ??
            json['remarks'] ??
            json['message'] ??
            json['description'] ??
            json['status_note'],
      ),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  String get title {
    if (action.trim().isEmpty) return 'Update';
    return SupportTicketConstants.statusLabel(action);
  }
}

class SupportTicketModel {
  final String id;
  final String ticketNumber;
  final String subject;
  final String description;
  final String requestType;
  final String category;
  final String subCategory;
  final String priority;
  final String status;
  final String source;
  final String? phone;
  final String? email;
  final String? resolutionSummary;
  final bool customerVerified;
  final String customerId;
  final SupportTicketParty? customer;
  final SupportTicketParty? assignee;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SupportTicketMessage> messages;
  final List<SupportTicketHistoryItem> history;
  final int unreadCountHint;

  const SupportTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    this.description = '',
    this.requestType = '',
    this.category = '',
    this.subCategory = '',
    this.priority = 'medium',
    this.status = '',
    this.source = '',
    this.phone,
    this.email,
    this.resolutionSummary,
    this.customerVerified = false,
    this.customerId = '',
    this.customer,
    this.assignee,
    this.createdAt,
    this.updatedAt,
    this.messages = const [],
    this.history = const [],
    this.unreadCountHint = 0,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map
        ? SupportTicketParty.fromJson(json['customer'])
        : null;
    final assignee = json['assignee'] is Map
        ? SupportTicketParty.fromJson(json['assignee'])
        : null;
    final messagesRaw =
        json['messages'] ??
        json['conversation'] ??
        json['ticket_messages'] ??
        json['TicketMessages'] ??
        json['ticketMessages'];
    final historyRaw = json['history'];
    final unreadRaw =
        json['unread_count'] ??
        json['unread_messages'] ??
        json['unreadMessageCount'];
    final resolved = _resolveRequestType(json);
    return SupportTicketModel(
      id: asString(json['id']),
      ticketNumber: asString(json['ticket_number'] ?? json['ticketNumber']),
      subject: asString(json['subject']),
      description: asString(json['description']),
      requestType: resolved.$1,
      category: asString(json['category']),
      subCategory: resolved.$2,
      priority: asString(json['priority']).isEmpty
          ? 'medium'
          : asString(json['priority']),
      status: asString(json['status']),
      source: asString(json['source']),
      phone: (json['phone'] ?? customer?.phone)?.toString(),
      email: (json['email'] ?? customer?.email)?.toString(),
      resolutionSummary:
          json['resolution_summary']?.toString() ??
          json['resolutionSummary']?.toString(),
      customerVerified:
          json['customer_verified'] == true || json['customerVerified'] == true,
      customerId: asString(
        json['customer_id'] ?? json['customerId'] ?? customer?.id,
      ),
      customer: customer,
      assignee: assignee,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      messages: _parseMessages(messagesRaw),
      history: _parseHistory(historyRaw),
      unreadCountHint: unreadRaw is num ? unreadRaw.toInt() : 0,
    );
  }

  static (String requestType, String subCategory) _resolveRequestType(
    Map<String, dynamic> json,
  ) {
    final apiRequestType = asString(
      json['request_type'] ?? json['requestType'],
    ).trim();
    final rawSub = asString(json['sub_category'] ?? json['subCategory']);
    final decoded = SupportTicketConstants.decodeRequestTypeFromSubCategory(
      rawSub,
    );
    if (apiRequestType.isNotEmpty) {
      return (
        apiRequestType,
        decoded.requestType.isNotEmpty ? decoded.subCategory : rawSub,
      );
    }
    return (decoded.requestType, decoded.subCategory);
  }

  SupportTicketModel copyWith({
    String? id,
    String? ticketNumber,
    String? subject,
    String? description,
    String? requestType,
    String? category,
    String? subCategory,
    String? priority,
    String? status,
    String? source,
    String? phone,
    String? email,
    String? resolutionSummary,
    bool? customerVerified,
    String? customerId,
    SupportTicketParty? customer,
    SupportTicketParty? assignee,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<SupportTicketMessage>? messages,
    List<SupportTicketHistoryItem>? history,
    int? unreadCountHint,
  }) {
    return SupportTicketModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      requestType: requestType ?? this.requestType,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      source: source ?? this.source,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      resolutionSummary: resolutionSummary ?? this.resolutionSummary,
      customerVerified: customerVerified ?? this.customerVerified,
      customerId: customerId ?? this.customerId,
      customer: customer ?? this.customer,
      assignee: assignee ?? this.assignee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      history: history ?? this.history,
      unreadCountHint: unreadCountHint ?? this.unreadCountHint,
    );
  }

  static List<SupportTicketMessage> _parseMessages(dynamic raw) {
    dynamic source = raw;
    if (source is Map) {
      source =
          source['rows'] ??
          source['data'] ??
          source['messages'] ??
          source['items'];
    }
    if (source is! List) return const [];
    final parsed = source
        .whereType<Map>()
        .map((e) => SupportTicketMessage.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.message.trim().isNotEmpty)
        .toList();
    parsed.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return parsed;
  }

  static List<SupportTicketHistoryItem> _parseHistory(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) =>
              SupportTicketHistoryItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  String get customerName => customer?.name ?? '';

  String get statusLabel => SupportTicketConstants.statusLabel(status);

  String get priorityLabel => SupportTicketConstants.priorityLabel(priority);

  String get categoryLabel => SupportTicketConstants.categoryLabel(category);

  String get requestTypeLabel =>
      SupportTicketConstants.requestTypeLabel(requestType);

  bool get isNew =>
      status == 'complaint_raised' || status == 'open' || status.isEmpty;

  bool get isClosed => status == 'closed' || status == 'cancelled';

  bool get isResolved => status == 'resolved';

  bool get isNewTag => status == 'complaint_raised' || status == 'open';

  int unreadIncomingCount({required bool isCustomerView}) {
    if (messages.isEmpty) return unreadCountHint;
    return messages.where((message) {
      if (message.isInternal) return false;
      final incoming = isCustomerView
          ? !message.isCustomer
          : message.isCustomer;
      return incoming && message.readAt == null;
    }).length;
  }
}

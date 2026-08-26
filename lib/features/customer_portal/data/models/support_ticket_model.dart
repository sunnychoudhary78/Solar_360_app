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
  final DateTime? readAt;

  const SupportTicketMessage({
    required this.id,
    required this.message,
    this.senderType = 'customer',
    this.senderId = '',
    this.senderName = '',
    this.isInternal = false,
    this.createdAt,
    this.readAt,
  });

  bool get isCustomer => senderType.toLowerCase() == 'customer';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : null;
    final senderType = asString(json['sender_type'] ?? json['senderType']);
    final isCustomer = senderType.toLowerCase() == 'customer';
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
          (isCustomer ? customer : user)?['name'] ??
          user?['name'] ??
          customer?['name'],
    );
    return SupportTicketMessage(
      id: asString(json['id']),
      message: asString(json['message'] ?? json['body'] ?? json['text']),
      senderType: senderType.isEmpty ? 'customer' : senderType,
      senderId: senderId,
      senderName: senderName,
      isInternal: json['is_internal'] == true || json['isInternal'] == true,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      readAt: parseDate(json['read_at'] ?? json['readAt'] ?? json['seen_at']),
    );
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
    return action
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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
  final String customerId;
  final SupportTicketParty? customer;
  final SupportTicketParty? assignee;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SupportTicketMessage> messages;
  final List<SupportTicketHistoryItem> history;

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
    this.customerId = '',
    this.customer,
    this.assignee,
    this.createdAt,
    this.updatedAt,
    this.messages = const [],
    this.history = const [],
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map
        ? SupportTicketParty.fromJson(json['customer'])
        : null;
    final assignee = json['assignee'] is Map
        ? SupportTicketParty.fromJson(json['assignee'])
        : null;
    final messagesRaw = json['messages'] ?? json['conversation'];
    final historyRaw = json['history'];
    return SupportTicketModel(
      id: asString(json['id']),
      ticketNumber: asString(json['ticket_number'] ?? json['ticketNumber']),
      subject: asString(json['subject']),
      description: asString(json['description']),
      requestType: asString(json['request_type'] ?? json['requestType']),
      category: asString(json['category']),
      subCategory: asString(json['sub_category'] ?? json['subCategory']),
      priority: asString(json['priority']).isEmpty
          ? 'medium'
          : asString(json['priority']),
      status: asString(json['status']),
      source: asString(json['source']),
      phone: (json['phone'] ?? customer?.phone)?.toString(),
      email: (json['email'] ?? customer?.email)?.toString(),
      resolutionSummary: json['resolution_summary']?.toString() ??
          json['resolutionSummary']?.toString(),
      customerId: asString(json['customer_id'] ?? json['customerId'] ?? customer?.id),
      customer: customer,
      assignee: assignee,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      messages: _parseMessages(messagesRaw),
      history: _parseHistory(historyRaw),
    );
  }

  static List<SupportTicketMessage> _parseMessages(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => SupportTicketMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<SupportTicketHistoryItem> _parseHistory(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => SupportTicketHistoryItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  String get customerName => customer?.name ?? '';

  String get statusLabel => _titleCase(status.isEmpty ? 'open' : status);

  String get priorityLabel => _titleCase(priority);

  String get categoryLabel =>
      category.trim().isEmpty ? '—' : _titleCase(category);

  bool get isNew =>
      status == 'complaint_raised' || status == 'open' || status.isEmpty;

  bool get isClosed =>
      status == 'closed' || status == 'resolved' || status == 'cancelled';

  bool get isNewTag => status == 'complaint_raised' || status == 'open';

  static String _titleCase(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

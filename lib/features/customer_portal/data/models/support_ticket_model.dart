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
  final String? phone;
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.phone,
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id']?.toString() ?? '',
      ticketNumber: (json['ticket_number'] ?? json['ticketNumber'] ?? '')
          .toString(),
      subject: json['subject']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      requestType:
          (json['request_type'] ?? json['requestType'] ?? '').toString(),
      category: json['category']?.toString() ?? '',
      subCategory:
          (json['sub_category'] ?? json['subCategory'] ?? '').toString(),
      priority: json['priority']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
      updatedAt: DateTime.tryParse(
        (json['updated_at'] ?? json['updatedAt'] ?? '').toString(),
      ),
    );
  }

  String get statusLabel {
    if (status.trim().isEmpty) return 'Open';
    return status
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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
      id: json['id']?.toString() ?? '',
      action: (json['action'] ?? json['event'] ?? json['status'] ?? '')
          .toString(),
      note: (json['note'] ?? json['remarks'] ?? json['message'] ?? json['description'] ?? '')
          .toString(),
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }
}

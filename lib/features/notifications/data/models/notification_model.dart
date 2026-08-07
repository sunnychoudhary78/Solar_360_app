class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? leadId;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.leadId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      leadId: (json['lead_id'] ?? json['leadId'])?.toString(),
      isRead: json['is_read'] == true ||
          json['isRead'] == true ||
          json['read'] == true,
      createdAt: json['created_at']?.toString() ??
          json['createdAt']?.toString() ??
          '',
    );
  }
}

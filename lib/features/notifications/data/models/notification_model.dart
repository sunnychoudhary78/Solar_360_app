class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? leadId;
  final String? redirectUrl;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.leadId,
    this.redirectUrl,
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
      redirectUrl: (json['redirect_url'] ?? json['redirectUrl'])?.toString(),
      isRead: json['is_read'] == true ||
          json['isRead'] == true ||
          json['read'] == true,
      createdAt: json['created_at']?.toString() ??
          json['createdAt']?.toString() ??
          '',
    );
  }

  bool get hasNavigationTarget {
    final redirect = redirectUrl?.trim();
    if (redirect != null && redirect.isNotEmpty) return true;
    return leadId != null && leadId!.isNotEmpty;
  }
}

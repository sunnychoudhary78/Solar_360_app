class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? leadId;
  final String? redirectUrl;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.leadId,
    this.redirectUrl,
    this.metadata = const {},
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['metadata'];
    final metadata = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : const <String, dynamic>{};

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      leadId: (json['lead_id'] ?? json['leadId'])?.toString(),
      redirectUrl: (json['redirect_url'] ?? json['redirectUrl'])?.toString(),
      metadata: metadata,
      isRead: json['is_read'] == true ||
          json['isRead'] == true ||
          json['read'] == true,
      createdAt: json['created_at']?.toString() ??
          json['createdAt']?.toString() ??
          '',
    );
  }

  String? metadataString(String key) {
    final value = metadata[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool get hasNavigationTarget {
    final redirect = redirectUrl?.trim();
    if (redirect != null && redirect.isNotEmpty) return true;
    if (metadataString('task_id') != null) return true;
    if (title.trim().toLowerCase() == 'task assigned to you') return true;
    return leadId != null && leadId!.isNotEmpty;
  }
}

import 'package:solar_sales/shared/utils/formatters.dart';

const whatsappMessageMaxLength = 2000;

const whatsappGreen = 0xFF25D366;

/// Same client check as the web share dialog.
bool isValidWhatsAppNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && digits.length <= 15;
}

String whatsappTemplateLabel(String key) {
  switch (key) {
    case 'quotation_share':
      return 'Quotation shared';
    case 'invoice_share':
      return 'Invoice shared';
    case 'invoice_payment_reminder':
      return 'Payment reminder';
    case 'lead_welcome':
      return 'Welcome message';
    case 'lead_follow_up':
      return 'Follow-up';
    default:
      return key;
  }
}

/// Matches the web history phone display (Indian numbers as +91 XXXXX XXXXX).
String formatWhatsAppPhone(String digits) {
  final d = digits.trim();
  if (d.length == 12 && d.startsWith('91')) {
    return '+91 ${d.substring(2, 7)} ${d.substring(7)}';
  }
  return d.isEmpty ? '' : '+$d';
}

class WhatsappTemplate {
  final String key;
  final String label;

  const WhatsappTemplate({required this.key, required this.label});

  factory WhatsappTemplate.fromJson(Map<String, dynamic> json) {
    return WhatsappTemplate(
      key: asString(json['key']),
      label: asString(json['label']),
    );
  }
}

class WhatsappComposeResult {
  final String entityType;
  final String entityId;
  final String templateKey;
  final List<WhatsappTemplate> templates;
  final String recipientName;
  final String phone;
  final String message;

  const WhatsappComposeResult({
    required this.entityType,
    required this.entityId,
    required this.templateKey,
    required this.templates,
    required this.recipientName,
    required this.phone,
    required this.message,
  });

  factory WhatsappComposeResult.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['templates'];
    final templates = rawTemplates is List
        ? rawTemplates
            .whereType<Map>()
            .map(
              (e) => WhatsappTemplate.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : const <WhatsappTemplate>[];
    return WhatsappComposeResult(
      entityType: asString(json['entityType']),
      entityId: asString(json['entityId']),
      templateKey: asString(json['templateKey']),
      templates: templates,
      recipientName: asString(json['recipientName']),
      phone: asString(json['phone']),
      message: asString(json['message']),
    );
  }
}

class WhatsappShareResult {
  final String url;

  const WhatsappShareResult({required this.url});

  factory WhatsappShareResult.fromJson(Map<String, dynamic> json) {
    return WhatsappShareResult(url: asString(json['url']));
  }
}

class WhatsappMessageModel {
  final String id;
  final String templateKey;
  final String phone;
  final String message;
  final DateTime? createdAt;
  final String? creatorName;
  final String? creatorEmail;

  const WhatsappMessageModel({
    required this.id,
    required this.templateKey,
    required this.phone,
    required this.message,
    this.createdAt,
    this.creatorName,
    this.creatorEmail,
  });

  String get senderLabel {
    final name = creatorName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = creatorEmail?.trim() ?? '';
    if (email.isNotEmpty) return email;
    return 'Unknown';
  }

  factory WhatsappMessageModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    String? creatorName;
    String? creatorEmail;
    if (creator is Map) {
      creatorName = creator['name']?.toString();
      creatorEmail = creator['email']?.toString();
    }
    return WhatsappMessageModel(
      id: asString(json['id']),
      templateKey: asString(json['template_key'] ?? json['templateKey']),
      phone: asString(json['phone']),
      message: asString(json['message']),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      creatorName: creatorName,
      creatorEmail: creatorEmail,
    );
  }
}

class WhatsappEntityKey {
  final String entityType;
  final String entityId;

  const WhatsappEntityKey({
    required this.entityType,
    required this.entityId,
  });

  @override
  bool operator ==(Object other) {
    return other is WhatsappEntityKey &&
        other.entityType == entityType &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(entityType, entityId);
}

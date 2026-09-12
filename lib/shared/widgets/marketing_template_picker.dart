import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/core/utils/upload_url.dart';

class MarketingTemplate {
  final String id;
  final String name;
  final String description;
  final String filePath;
  final String fileUrl;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final String appliesTo;
  final bool isActive;

  const MarketingTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.filePath = '',
    this.fileUrl = '',
    this.originalName = '',
    this.mimeType = '',
    this.fileSize = 0,
    this.appliesTo = 'both',
    this.isActive = true,
  });

  factory MarketingTemplate.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic value, {bool fallback = true}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      return fallback;
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return MarketingTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['original_name'] ?? 'Template').toString(),
      description: (json['description'] ?? '').toString(),
      filePath: (json['file_path'] ?? json['filePath'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? json['fileUrl'] ?? '').toString(),
      originalName:
          (json['original_name'] ?? json['originalName'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'] ?? '').toString(),
      fileSize: asInt(json['file_size'] ?? json['fileSize']),
      appliesTo: (json['applies_to'] ?? json['appliesTo'] ?? 'both').toString(),
      isActive: asBool(json['is_active'] ?? json['isActive']),
    );
  }

  bool get isPdf => mimeType.toLowerCase().contains('pdf') ||
      originalName.toLowerCase().endsWith('.pdf') ||
      filePath.toLowerCase().endsWith('.pdf');

  String get appliesLabel {
    if (appliesTo == 'quotation') return 'Quotations';
    if (appliesTo == 'invoice') return 'Invoices';
    return 'Both';
  }

  String get previewUrl {
    if (fileUrl.trim().isNotEmpty) {
      return resolveStoredUploadUrl(fileUrl);
    }
    return resolveStoredUploadUrl(filePath);
  }

  String get formattedSize {
    if (fileSize <= 0) return '—';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MarketingTemplateApi {
  final ApiService _api;

  MarketingTemplateApi(this._api);

  Future<List<MarketingTemplate>> list({
    String? appliesTo,
    bool activeOnly = false,
  }) async {
    final query = <String, dynamic>{};
    if (appliesTo != null && appliesTo.isNotEmpty) {
      query['appliesTo'] = appliesTo;
    }
    if (activeOnly) query['activeOnly'] = 'true';

    final res = await _api.get(
      ApiEndpoints.marketingTemplates,
      queryParams: query.isEmpty ? null : query,
    );
    return _parseList(res);
  }

  Future<MarketingTemplate> create({
    required String name,
    String description = '',
    required String appliesTo,
    required String filePath,
  }) async {
    final filename = fileDisplayName(filePath);
    final form = FormData.fromMap({
      'name': name,
      'applies_to': appliesTo,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _contentTypeFor(filename),
      ),
    });
    final res = await _api.postFormData(ApiEndpoints.marketingTemplates, form);
    if (res is Map) {
      return MarketingTemplate.fromJson(Map<String, dynamic>.from(res));
    }
    throw const ApiException('Failed to upload template');
  }

  Future<void> updateActive({
    required String id,
    required bool isActive,
  }) {
    return _api.patch(
      ApiEndpoints.marketingTemplate(id),
      {'is_active': isActive},
    );
  }

  Future<void> remove(String id) {
    return _api.delete(ApiEndpoints.marketingTemplate(id));
  }

  Future<Uint8List> download(String id) {
    return _api.getBytes(ApiEndpoints.marketingTemplateDownload(id));
  }

  MediaType _contentTypeFor(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('application', 'octet-stream');
  }

  List<MarketingTemplate> _parseList(dynamic res) {
    final raw = res is List
        ? res
        : (res is Map ? (res['data'] ?? res['rows'] ?? []) : []);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => MarketingTemplate.fromJson(Map<String, dynamic>.from(e)))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }
}

final marketingTemplateApiProvider = Provider<MarketingTemplateApi>((ref) {
  return MarketingTemplateApi(ref.watch(apiServiceProvider));
});

final marketingTemplatesProvider = FutureProvider.autoDispose
    .family<List<MarketingTemplate>, String>((ref, appliesTo) async {
  return ref.watch(marketingTemplateApiProvider).list(
        appliesTo: appliesTo,
        activeOnly: true,
      );
});

final marketingTemplatesAdminProvider =
    FutureProvider.autoDispose<List<MarketingTemplate>>((ref) {
  return ref.watch(marketingTemplateApiProvider).list();
});

/// Body field name the backend reads (`req.body.marketingTemplateId`), same as web.
Object? marketingTemplateIdBody(String? id) {
  final trimmed = (id ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

MarketingTemplate? marketingTemplateFromDocJson(Map<String, dynamic> json) {
  final nested = json['marketingTemplate'] ?? json['marketing_template'];
  if (nested is! Map) return null;
  final tpl = MarketingTemplate.fromJson(Map<String, dynamic>.from(nested));
  return tpl.id.isEmpty ? null : tpl;
}

String? marketingTemplateIdFromJson(Map<String, dynamic> json) {
  final nested = marketingTemplateFromDocJson(json);
  final id = json['marketing_template_id'] ??
      json['marketingTemplateId'] ??
      nested?.id;
  final value = id?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

class MarketingTemplatePicker extends ConsumerWidget {
  final String appliesTo;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const MarketingTemplatePicker({
    super.key,
    required this.appliesTo,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketingTemplatesProvider(appliesTo));
    final templates = async.asData?.value ?? const <MarketingTemplate>[];
    final selected =
        templates.any((t) => t.id == value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Marketing template',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None'),
            ),
            ...templates.map(
              (t) => DropdownMenuItem<String?>(
                value: t.id,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: enabled && !async.isLoading ? onChanged : null,
        ),
        const SizedBox(height: 4),
        Text(
          'Attached when you email or download; manage in Settings → Templates.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

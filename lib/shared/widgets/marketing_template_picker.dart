import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/providers/network_providers.dart';

class MarketingTemplate {
  final String id;
  final String name;

  const MarketingTemplate({required this.id, required this.name});

  factory MarketingTemplate.fromJson(Map<String, dynamic> json) {
    return MarketingTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['original_name'] ?? 'Template').toString(),
    );
  }
}

class MarketingTemplateApi {
  final ApiService _api;

  MarketingTemplateApi(this._api);

  Future<List<MarketingTemplate>> list({
    required String appliesTo,
    bool activeOnly = true,
  }) async {
    final res = await _api.get(
      ApiEndpoints.marketingTemplates,
      queryParams: {
        'appliesTo': appliesTo,
        'activeOnly': activeOnly,
      },
    );
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
  return ref
      .watch(marketingTemplateApiProvider)
      .list(appliesTo: appliesTo);
});

String? marketingTemplateIdFromJson(Map<String, dynamic> json) {
  final nested = json['marketingTemplate'] ?? json['marketing_template'];
  final id = json['marketing_template_id'] ??
      json['marketingTemplateId'] ??
      (nested is Map ? nested['id'] : null);
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

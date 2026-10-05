import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/whatsapp_models.dart';

class WhatsappApiService {
  final ApiService _api;

  WhatsappApiService(this._api);

  Future<WhatsappComposeResult> compose({
    required String entityType,
    required String entityId,
    String? templateKey,
  }) async {
    final res = await _api.post(ApiEndpoints.whatsappCompose, {
      'entityType': entityType,
      'entityId': entityId,
      if (templateKey != null && templateKey.isNotEmpty)
        'templateKey': templateKey,
    });
    return WhatsappComposeResult.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  Future<WhatsappShareResult> share({
    required String entityType,
    required String entityId,
    required String templateKey,
    required String phone,
    required String message,
  }) async {
    final res = await _api.post(ApiEndpoints.whatsappShare, {
      'entityType': entityType,
      'entityId': entityId,
      'templateKey': templateKey,
      'phone': phone,
      'message': message,
    });
    return WhatsappShareResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<WhatsappMessageModel>> messages({
    required String entityType,
    required String entityId,
  }) async {
    final res = await _api.get(
      ApiEndpoints.whatsappMessages,
      queryParams: {
        'entityType': entityType,
        'entityId': entityId,
      },
    );
    if (res is! List) {
      throw const ApiException('Could not load WhatsApp history');
    }
    return res
        .whereType<Map>()
        .map(
          (e) => WhatsappMessageModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }
}

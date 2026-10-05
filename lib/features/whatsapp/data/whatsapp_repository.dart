import 'models/whatsapp_models.dart';
import 'whatsapp_api_service.dart';

class WhatsappRepository {
  final WhatsappApiService _api;

  WhatsappRepository(this._api);

  Future<WhatsappComposeResult> compose({
    required String entityType,
    required String entityId,
    String? templateKey,
  }) =>
      _api.compose(
        entityType: entityType,
        entityId: entityId,
        templateKey: templateKey,
      );

  Future<WhatsappShareResult> share({
    required String entityType,
    required String entityId,
    required String templateKey,
    required String phone,
    required String message,
  }) =>
      _api.share(
        entityType: entityType,
        entityId: entityId,
        templateKey: templateKey,
        phone: phone,
        message: message,
      );

  Future<List<WhatsappMessageModel>> messages({
    required String entityType,
    required String entityId,
  }) =>
      _api.messages(entityType: entityType, entityId: entityId);
}

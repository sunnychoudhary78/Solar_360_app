import 'notification_api_service.dart';
import 'models/notification_model.dart';

class NotificationRepository {
  final NotificationApiService _api;

  NotificationRepository(this._api);

  Future<List<NotificationModel>> getMyNotifications({String? module}) =>
      _api.getMyNotifications(module: module);

  Future<int> getUnreadCount({String? module}) =>
      _api.getUnreadCount(module: module);

  Future<void> markRead(String id) => _api.markRead(id);

  Future<void> markAllRead({String? module}) =>
      _api.markAllRead(module: module);
}

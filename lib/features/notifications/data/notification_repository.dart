import 'notification_api_service.dart';
import 'models/notification_model.dart';

class NotificationRepository {
  final NotificationApiService _api;

  NotificationRepository(this._api);

  Future<List<NotificationModel>> getMyNotifications() =>
      _api.getMyNotifications();

  Future<int> getUnreadCount() => _api.getUnreadCount();

  Future<void> markRead(String id) => _api.markRead(id);

  Future<void> markAllRead() => _api.markAllRead();
}

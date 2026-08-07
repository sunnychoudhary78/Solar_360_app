import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/notification_model.dart';

class NotificationApiService {
  final ApiService _api;

  NotificationApiService(this._api);

  Future<List<NotificationModel>> getMyNotifications() async {
    final res = await _api.get(ApiEndpoints.myNotifications);
    final list = _extractList(res);
    return list
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final res = await _api.get(ApiEndpoints.unreadNotificationCount);
    if (res is Map) {
      final count = res['unread_count'] ?? res['count'] ?? res['data'];
      if (count is num) return count.toInt();
    }
    if (res is num) return res.toInt();
    return 0;
  }

  Future<void> markRead(String id) async {
    await _api.put(ApiEndpoints.markNotificationRead(id), {});
  }

  Future<void> markAllRead() async {
    await _api.put(ApiEndpoints.markAllNotificationsRead, {});
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/network_providers.dart';

import 'package:solar_sales/features/notifications/data/notification_api_service.dart';
import 'package:solar_sales/features/notifications/data/notification_repository.dart';
import 'package:solar_sales/features/notifications/data/models/notification_model.dart';

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService(ref.watch(apiServiceProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(notificationApiServiceProvider));
});

final myNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  return ref.watch(notificationRepositoryProvider).getMyNotifications();
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/utils/profile_url.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/features/auth/data/auth_api_service.dart';
import 'package:solar_sales/features/notifications/data/notification_api_service.dart';

import 'helpers/recording_adapter.dart';

void main() {
  group('Solar360 backend alignment', () {
    test('notification endpoints match backend routes', () {
      expect(
        ApiEndpoints.markNotificationRead('notification-id'),
        'notifications/mark-as-read/notification-id',
      );
      expect(
        ApiEndpoints.markAllNotificationsRead,
        'notifications/mark-all-as-read',
      );
    });

    test('production API points at the Billbook host', () {
      expect(ApiConstants.baseUrl, 'https://imt-billbook.immortalgroup.in/api');
    });

    test('lead upload URLs use the backend /api/uploads mount', () {
      expect(
        resolveUploadUrl('leads/example.jpg'),
        'https://imt-billbook.immortalgroup.in/api/uploads/leads/example.jpg',
      );
      expect(
        resolveUploadUrl('https://example.com/api/uploads/leads/example.jpg'),
        'https://example.com/api/uploads/leads/example.jpg',
      );
    });

    test('profile URLs use the backend /api/uploads mount', () {
      expect(resolveProfilePictureUrls('users/avatar.jpg'), [
        'https://imt-billbook.immortalgroup.in/api/uploads/users/avatar.jpg',
      ]);
    });

    test('change password sends backend-required confirmation', () async {
      final pair = createTestApi();
      pair.adapter.on('POST', 'auth/change-password', (request) {
        final body = Map<String, dynamic>.from(request.data as Map);
        expect(body['currentPassword'], 'old-password');
        expect(body['newPassword'], 'new-password');
        expect(body['confirmPassword'], 'new-password');
        return {'success': true};
      });

      await AuthApiService(ApiService(pair.dio)).changePassword(
        currentPassword: 'old-password',
        newPassword: 'new-password',
        confirmPassword: 'new-password',
      );
    });

    test('notification count and mark-read contracts match backend', () async {
      final pair = createTestApi();
      pair.adapter.on('GET', 'notifications/unread-count', (_) {
        return {'success': true, 'unread_count': 3};
      });
      pair.adapter.on('PUT', 'notifications/mark-as-read/notification-id', (_) {
        return {'success': true};
      });
      pair.adapter.on('PUT', 'notifications/mark-all-as-read', (_) {
        return {'success': true};
      });

      final service = NotificationApiService(ApiService(pair.dio));
      expect(await service.getUnreadCount(), 3);
      await service.markRead('notification-id');
      await service.markAllRead();

      expect(
        pair.adapter.of('PUT', 'mark-as-read/notification-id'),
        hasLength(1),
      );
      expect(pair.adapter.of('PUT', 'mark-all-as-read'), hasLength(1));
    });
  });
}

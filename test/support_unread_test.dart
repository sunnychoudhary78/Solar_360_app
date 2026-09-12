import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';

void main() {
  group('Support ticket unread indicators', () {
    test('parses unread_count from a string like the API COUNT result', () {
      final ticket = SupportTicketModel.fromJson({
        'id': '1',
        'ticket_number': 'TKT-2026-00041',
        'subject': 'hauaua',
        'unread_count': '1',
        'has_unread_messages': true,
        'last_message': {
          'message': 'hi',
          'sender_type': 'admin',
          'read_at': null,
        },
      });

      expect(ticket.unreadCountHint, 1);
      expect(
        ticket.unreadIncomingCount(isCustomerView: true),
        1,
      );
      expect(
        ticket.unreadIncomingCount(isCustomerView: false),
        1,
      );
    });

    test('clears the unread badge after the thread is opened', () {
      final ticket = SupportTicketModel.fromJson({
        'id': '1',
        'subject': 'Issue',
        'unread_count': 2,
        'has_unread_messages': true,
      }).clearedUnread();

      expect(ticket.unreadCountHint, 0);
      expect(ticket.hasUnreadMessages, isFalse);
      expect(ticket.unreadIncomingCount(isCustomerView: true), 0);
    });

    test('staff view counts unread customer messages from last_message', () {
      final ticket = SupportTicketModel.fromJson({
        'id': '2',
        'subject': 'Need help',
        'last_message': {
          'message': 'please check',
          'sender_type': 'customer',
        },
      });

      expect(ticket.unreadIncomingCount(isCustomerView: false), 1);
      expect(ticket.unreadIncomingCount(isCustomerView: true), 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/workflow/lead_workflow.dart';

void main() {
  group('LeadWorkflow next statuses', () {
    test('sales can reject, follow up, or convert a new lead', () {
      final next = LeadWorkflow.getAllowedNextStatuses('New Lead', 'Sales');
      expect(next, ['Rejected', 'Follow Up', 'Converted']);
    });

    test('sales can still act after follow up', () {
      final next = LeadWorkflow.getAllowedNextStatuses('Follow Up', 'Sales');
      expect(next, ['Rejected', 'Converted']);
      expect(next, isNot(contains('Follow Up')));
    });

    test('super admin gets sequential next regardless of role status list', () {
      final next = LeadWorkflow.getAllowedNextStatuses(
        'New Lead',
        'SuperAdmin',
      );
      expect(next, ['Rejected', 'Follow Up', 'Converted']);
    });

    test('final statuses have no next', () {
      expect(
        LeadWorkflow.getAllowedNextStatuses('Final Complete', 'Admin'),
        isEmpty,
      );
      expect(LeadWorkflow.getAllowedNextStatuses('Rejected', 'Sales'), isEmpty);
    });

    test('finance can mark amount received after finance verification', () {
      final next = LeadWorkflow.getAllowedNextStatuses(
        'Finance Verification Started',
        'Finance User',
      );
      expect(next, ['Amount Received']);
    });

    test('electrical engineer completes an installation', () {
      final next = LeadWorkflow.getAllowedNextStatuses(
        'Installation Started',
        'Electrical Engineer',
      );
      expect(next, ['Installation Completed']);
    });
  });

  group('LeadWorkflow role + pipeline helpers', () {
    test('resolveRoleKey maps liaison aliases', () {
      expect(LeadWorkflow.resolveRoleKey('liaison'), 'Bank Process');
      expect(LeadWorkflow.resolveRoleKey('Liaison Officer'), 'Bank Process');
      expect(LeadWorkflow.resolveRoleKey('leasing'), 'Bank Process');
    });

    test('resolveRoleKey maps installation aliases', () {
      expect(
        LeadWorkflow.resolveRoleKey('installation'),
        'Installation Manager',
      );
      expect(
        LeadWorkflow.resolveRoleKey('Installation Team'),
        'Installation Manager',
      );
    });

    test('isAdminRole detects admin and super', () {
      expect(LeadWorkflow.isAdminRole('Admin'), isTrue);
      expect(LeadWorkflow.isAdminRole('SuperAdmin'), isTrue);
      expect(LeadWorkflow.isAdminRole('Sales'), isFalse);
      expect(LeadWorkflow.isAdminRole('Document Administrator'), isFalse);
    });

    test('isFinalStatus and canSalesCompleteDetails', () {
      expect(LeadWorkflow.isFinalStatus('Final Complete'), isTrue);
      expect(LeadWorkflow.canSalesCompleteDetails('Converted'), isTrue);
      expect(LeadWorkflow.canSalesCompleteDetails('New Lead'), isFalse);
    });

    test('pipelineIndexForStatus follows known map', () {
      expect(LeadWorkflow.pipelineIndexForStatus('New Lead'), 0);
      expect(LeadWorkflow.pipelineIndexForStatus('Banking Process Start'), 4);
      expect(LeadWorkflow.pipelineIndexForStatus('Final Complete'), 9);
    });

    test('nextActionLabel returns domain labels', () {
      expect(
        LeadWorkflow.nextActionLabel('New Lead'),
        'Reject, follow up, or convert',
      );
      expect(
        LeadWorkflow.nextActionLabel('Amount Received'),
        'Assign engineers',
      );
    });

    test('visible statuses include handoff steps for exact role desks', () {
      expect(
        LeadWorkflow.getVisibleStatusesForRole('Finance Manager'),
        containsAll([
          'Approved By Sales Manager',
          'Assigned To Document Administrator',
        ]),
      );
      expect(
        LeadWorkflow.getVisibleStatusesForRole('Material Engineer'),
        containsAll([
          'Assigned To Material Engineer',
          'Material Verification Started',
          'Material Completed',
        ]),
      );
      expect(
        LeadWorkflow.getVisibleStatusesForRole('Document Administrator'),
        isNot(contains('Documents Submitted')),
      );
    });
  });
}

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

    test('pipelineIndexForStatus follows web 12-stage map', () {
      expect(LeadWorkflow.pipelineIndexForStatus('New Lead'), 0);
      expect(LeadWorkflow.pipelineIndexForStatus('Banking Process Start'), 4);
      expect(LeadWorkflow.pipelineIndexForStatus('Material Completed'), 7);
      expect(LeadWorkflow.pipelineIndexForStatus('Installation Completed'), 8);
      expect(LeadWorkflow.pipelineIndexForStatus('Installation Done'), 9);
      expect(LeadWorkflow.pipelineIndexForStatus('Discom Status'), 10);
      expect(LeadWorkflow.pipelineIndexForStatus('Final Complete'), 11);
      expect(LeadWorkflow.pipelineSteps, hasLength(12));
      expect(LeadWorkflow.pipelineSteps.last, 'Final Complete');
    });

    test('status labels and next-actor hints match web', () {
      expect(
        LeadWorkflow.getStatusDisplayLabel('Approved By Sales Manager'),
        'Approved',
      );
      expect(
        LeadWorkflow.nextActorHint('Converted'),
        'Waiting for KYC collection',
      );
      expect(LeadWorkflow.isConvertedPipelineStatus('KYC Collected'), isTrue);
      expect(LeadWorkflow.isConvertedPipelineStatus('New Lead'), isFalse);
      expect(
        LeadWorkflow.isCompletedStatus('Lead Closed'),
        isTrue,
      );
      expect(LeadWorkflow.requiresStatusRemarks('Rejected By Sales Manager'), isTrue);
    });

    test('converted vs completed list filters match web', () {
      expect(LeadWorkflow.isConvertedPipelineStatus('Converted'), isTrue);
      expect(LeadWorkflow.isConvertedPipelineStatus('Installation Done'), isTrue);
      expect(LeadWorkflow.isConvertedPipelineStatus('Final Complete'), isFalse);
      expect(LeadWorkflow.isConvertedPipelineStatus('Lead Closed'), isFalse);
      expect(LeadWorkflow.isCompletedStatus('Final Complete'), isTrue);
      expect(LeadWorkflow.isCompletedStatus('Lead Completed'), isTrue);
      expect(LeadWorkflow.isCompletedStatus('Lead Closed'), isTrue);
      expect(
        LeadWorkflow.isCompletedStatus(
          'KYC Collected',
          department: 'Completed',
        ),
        isTrue,
      );
      expect(LeadWorkflow.isCompletedStatus('Converted'), isFalse);
    });

    test('rejected leads are visible only to sales and admin roles', () {
      expect(LeadWorkflow.canViewRejectedLeads('Sales'), isTrue);
      expect(LeadWorkflow.canViewRejectedLeads('Sales Manager'), isTrue);
      expect(LeadWorkflow.canViewRejectedLeads('Company Admin'), isTrue);
      expect(LeadWorkflow.canViewRejectedLeads('SuperAdmin'), isTrue);
      expect(LeadWorkflow.canViewRejectedLeads('Finance User'), isFalse);
      expect(
        LeadWorkflow.canViewRejectedLeads('Document Administrator'),
        isFalse,
      );
    });

    test('KYC gate requires text fields, titled docs, and cheque', () {
      expect(LeadWorkflow.getMissingKycDetails(null), isNotEmpty);
      expect(
        LeadWorkflow.hasFilledKycDetails({
          'full_name': 'Ravi',
          'mobile': '9876543210',
          'ca_number': 'CA1',
          'discom': 'BSES',
          'load_section_kw': '5',
          'address': '12 St',
          'city': 'Delhi',
          'state': 'DL',
          'pincode': '110001',
          'bank_account_name': 'Ravi',
          'bank_name': 'SBI',
          'account_number': '123',
          'account_type': 'Saving',
          'ifsc_code': 'SBIN0001234',
          'cheque_passbook_copy': 'leads/cheque.pdf',
          'additional_documents': [
            {'title': 'Aadhaar Front', 'file': 'leads/a1.jpg'},
            {'title': 'Aadhaar Back', 'file': 'leads/a2.jpg'},
            {'title': 'PAN Card', 'file': 'leads/pan.pdf'},
            {'title': 'Electricity Bill', 'file': 'leads/bill.pdf'},
          ],
        }),
        isTrue,
      );
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

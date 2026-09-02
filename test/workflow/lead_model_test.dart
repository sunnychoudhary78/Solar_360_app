import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/leads/data/lead_files.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

void main() {
  group('LeadModel parsing', () {
    test('parses snake_case lead payload', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-1',
        'lead_code': 'LD-001',
        'full_name': 'Ravi Kumar',
        'mobile': '9876543210',
        'email': 'ravi@example.com',
        'address': '12 Solar Street',
        'city': 'Delhi',
        'state': 'DL',
        'pincode': '110001',
        'load_section_kw': '5',
        'ca_number': 'CA123',
        'k_number': 'K99',
        'reference_number': 'REF-1',
        'discom': 'BSES',
        'geo_location': 'Delhi',
        'latitude': '28.6',
        'longitude': '77.2',
        'bank_account_name': 'Ravi Kumar',
        'account_type': 'Saving',
        'bank_name': 'SBI',
        'account_number': '1234567890',
        'ifsc_code': 'SBIN0001234',
        'project_type': 'Residential',
        'source': 'Referral',
        'status': 'New Lead',
        'current_department': 'Sales',
        'workflow_step': 'Lead Created (Basic)',
        'lead_stage': 'open',
        'assigned_to': 'u2',
        'assigned_by': 'u1',
        'created_by': 'u1',
        'updated_by': 'u1',
        'priority': 'medium',
        'notes': 'site visit pending',
        'roof_photo_status': 'pending',
        'available_shadow_free_area': '400',
        'quotation_amount': '250000',
        'visited_employee_name': 'Amit',
        'visited_employee_contact': '9999999999',
        'follow_up_date': '2026-08-10',
        'last_contacted_at': '2026-08-01',
        'roof_load_bearing_capacity': true,
        'shadow_free_roof': true,
        'vendor_visited_site': false,
        'is_active': true,
        'payment_type': 'Subsidy',
        'subsidy_percentage': '40',
        'payment_amount': '120000',
        'final_amount_received': true,
        'subsidy_apply_status': 'Processing',
        'assigned_to_document_admin': 'doc-1',
        'assigned_to_document_admin_name': 'Doc User',
        'assigned_to_finance_user': 'fin-1',
        'assignedFinanceUser': {'name': 'Finance User'},
        'assigned_to_material_engineer': 'me-1',
        'assignedMaterialEngineer': {'name': 'Material Engineer'},
        'assigned_to_electrical_engineer': 'ee-1',
        'assignedElectricalEngineer': {'name': 'Electrical Engineer'},
        'registration_images': ['leads/reg-1.png', 'leads/reg-2.png'],
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-01T11:00:00.000Z',
        'installation_details': {'panel_brand': 'Waaree', 'panel_count': 10},
      });

      expect(lead.id, 'lead-1');
      expect(lead.leadCode, 'LD-001');
      expect(lead.fullName, 'Ravi Kumar');
      expect(lead.status, 'New Lead');
      expect(lead.currentDepartment, 'Sales');
      expect(lead.discom, 'BSES');
      expect(lead.roofLoadBearingCapacity, isTrue);
      expect(lead.paymentType, 'Subsidy');
      expect(lead.subsidyPercentage, '40');
      expect(lead.paymentAmount, '120000');
      expect(lead.finalAmountReceived, isTrue);
      expect(lead.assignedToDocumentAdminName, 'Doc User');
      expect(lead.assignedToFinanceUserName, 'Finance User');
      expect(lead.assignedToMaterialEngineerName, 'Material Engineer');
      expect(lead.assignedToElectricalEngineerName, 'Electrical Engineer');
      expect(lead.registrationImages, hasLength(2));
      expect(lead.accountType, 'Saving');
      expect(lead.resolvedBankAccountType, 'Saving');
      expect(lead.installationDetails?['panel_brand'], 'Waaree');
    });

    test('defaults isActive to true when omitted', () {
      final lead = LeadModel.fromJson({'id': 'lead-4'});
      expect(lead.isActive, isTrue);
    });

    test('keeps explicit isActive false', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-5',
        'is_active': false,
      });
      expect(lead.isActive, isFalse);
    });

    test('extracts upload paths from nested file objects', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-7',
        'roof_photo': {'file': 'leads/roof-1.jpg'},
        'cheque_passbook_copy':
            '{"path":"leads/cheque.png","title":"Cheque"}',
        'quotation_document': {
          'url': 'https://example.com/api/uploads/leads/quote.pdf',
        },
      });

      expect(lead.roofPhoto, 'leads/roof-1.jpg');
      expect(lead.chequePassbookCopy, 'leads/cheque.png');
      expect(lead.quotationDocument, contains('leads/quote.pdf'));
    });

    test('retains customer source, urgent priority, and titled documents', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-6',
        'source': 'Customer Portal',
        'priority': 'Urgent',
        'additional_documents': [
          {'title': 'Aadhaar Front', 'file': 'leads/aadhaar-front.pdf'},
          {'title': 'PAN Card', 'path': 'leads/pan.pdf'},
        ],
      });

      expect(lead.source, 'Customer Portal');
      expect(lead.priority, 'Urgent');
      expect(lead.additionalDocuments, contains('Aadhaar Front'));
      expect(lead.additionalDocuments, contains('leads/aadhaar-front.pdf'));
      expect(lead.additionalDocuments, contains('PAN Card'));
    });

    test('parses camelCase aliases', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-2',
        'leadCode': 'LD-002',
        'fullName': 'Anita',
        'mobile': '9000000000',
        'status': 'Converted',
        'currentDepartment': 'Sales',
        'loadSectionKw': '3',
      });

      expect(lead.leadCode, 'LD-002');
      expect(lead.fullName, 'Anita');
      expect(lead.loadSectionKw, '3');
      expect(lead.status, 'Converted');
    });

    test('resolves account type from bank_account_name fallback', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-3',
        'bank_account_name': 'Current',
      });

      expect(lead.accountType, isEmpty);
      expect(lead.resolvedBankAccountType, 'Current');
    });

    test('collectLeadFiles includes single slots and titled KYC docs', () {
      final lead = LeadModel.fromJson({
        'id': 'lead-8',
        'roof_photo': 'leads/roof.jpg',
        'cheque_passbook_copy': {'file': 'leads/cheque.png'},
        'additional_documents': [
          {'title': 'Aadhaar Front', 'file': 'leads/aadhaar-front.pdf'},
          {'title': 'PAN Card', 'existingPath': 'leads/pan.pdf'},
        ],
        'additional_images': [
          {'title': 'Geo Tag Photo', 'path': 'leads/geo.jpg'},
        ],
      });

      final files = collectLeadFiles(lead);
      final labels = files.map((item) => item.label).toList();
      expect(labels, contains('Roof Photo'));
      expect(labels, contains('Cheque / Passbook'));
      expect(labels, contains('Aadhaar Front'));
      expect(labels, contains('PAN Card'));
      expect(labels, contains('Geo Tag Photo'));
      expect(files.every((item) => item.url.contains('/api/uploads/')), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';

LeadModel _lead({
  String id = '1',
  String status = 'New Lead',
  String address = '',
  String caNumber = '',
  String discom = '',
  String kw = '',
}) {
  return LeadModel.fromJson({
    'id': id,
    'status': status,
    'full_name': 'Test',
    'mobile': '9876543210',
    'address': address,
    'ca_number': caNumber,
    'discom': discom,
    'load_section_kw': kw,
  });
}

void main() {
  group('customer lead rules', () {
    test('customer can edit New Lead / Follow Up / Rejected only', () {
      expect(canCustomerEditLead(_lead()), isTrue);
      expect(canCustomerEditLead(_lead(status: 'Follow Up')), isTrue);
      expect(canCustomerEditLead(_lead(status: 'Rejected')), isTrue);
      expect(canCustomerEditLead(_lead(status: 'Converted')), isFalse);
      expect(canCustomerEditLead(_lead(status: 'KYC Collected')), isFalse);
    });

    test('incomplete lead is detected from missing full-form fields', () {
      expect(isCustomerLeadIncomplete(_lead()), isTrue);
      expect(
        isCustomerLeadIncomplete(
          _lead(
            address: '12 Street',
            caNumber: 'CA1',
            discom: 'BSES Rajdhani',
            kw: '5',
          ),
        ),
        isFalse,
      );
    });

    test('create is allowed only when there is no editable draft', () {
      expect(canCustomerCreateLead(const []), isTrue);
      expect(canCustomerCreateLead([_lead()]), isFalse);
      expect(
        canCustomerCreateLead([_lead(status: 'Converted')]),
        isFalse,
      );
    });

    test('existing editable lead is preferred over create', () {
      final draft = _lead(id: 'draft');
      final converted = _lead(id: 'done', status: 'Converted');
      expect(existingEditableCustomerLead([converted, draft])?.id, 'draft');
      expect(existingEditableCustomerLead([converted]), isNull);
      expect(canCustomerFillOrComplete([converted, draft]), isFalse);
      expect(canCustomerFillOrComplete([draft]), isTrue);
    });

    test('inactive leftovers are reused instead of creating another lead', () {
      final inactive = LeadModel.fromJson({
        'id': 'ghost',
        'status': 'New Lead',
        'is_active': false,
        'full_name': 'Ghost',
        'mobile': '9876543210',
      });
      final draft = _lead(id: 'draft');
      expect(existingEditableCustomerLead([inactive, draft])?.id, 'draft');
      expect(existingEditableCustomerLead([inactive])?.id, 'ghost');
      expect(canCustomerCreateLead([inactive]), isFalse);
    });

    test('duplicate drafts collapse to the oldest complete lead', () {
      final older = LeadModel.fromJson({
        'id': 'old',
        'status': 'New Lead',
        'created_at': '2026-09-01T10:00:00.000Z',
        'address': '12 Street',
        'ca_number': 'CA1',
        'discom': 'BSES Rajdhani',
        'load_section_kw': '5',
      });
      final newer = LeadModel.fromJson({
        'id': 'new',
        'status': 'New Lead',
        'created_at': '2026-09-02T10:00:00.000Z',
        'address': '12 Street',
        'ca_number': 'CA1',
        'discom': 'BSES Rajdhani',
        'load_section_kw': '5',
      });
      expect(existingEditableCustomerLead([newer, older])?.id, 'old');
    });

    test('all pre-convert drafts are listed, not only the ranked first', () {
      final first = _lead(id: 'a');
      final second = _lead(id: 'b', status: 'Follow Up');
      expect(
        customerDraftLeads([first, second]).map((lead) => lead.id),
        ['a', 'b'],
      );
    });

    test('inactive leftovers stay hidden but are reused instead of a new POST', () {
      final inactive = LeadModel.fromJson({
        'id': 'ghost',
        'status': 'New Lead',
        'is_active': false,
        'full_name': 'Ghost',
        'mobile': '9876543210',
      });
      expect(customerDraftLeads([inactive]), isEmpty);
      expect(canCustomerCreateLead([inactive]), isFalse);
      expect(
        reusableCustomerLeadId(
          existingLeadId: null,
          existingLeads: [inactive],
        ),
        'ghost',
      );
    });

    test('edit save reuses the open lead id even when another draft exists', () {
      final first = _lead(id: 'keep');
      final extra = _lead(id: 'extra');
      expect(
        reusableCustomerLeadId(
          existingLeadId: 'keep',
          existingLeads: [first, extra],
        ),
        'keep',
      );
      expect(
        reusableCustomerLeadId(
          existingLeadId: null,
          existingLeads: [first],
        ),
        'keep',
      );
    });

    test('fill/complete action continues an incomplete draft', () {
      final basic = _lead(id: 'draft');
      final complete = _lead(
        id: 'full',
        address: '12 Street',
        caNumber: 'CA1',
        discom: 'BSES Rajdhani',
        kw: '5',
      );
      expect(customerLeadNeedingCompletion([basic])?.id, 'draft');
      expect(canCustomerFillOrComplete([basic]), isTrue);
      expect(customerLeadNeedingCompletion([complete]), isNull);
      expect(canCustomerFillOrComplete([complete]), isTrue);
      expect(canCustomerFillOrComplete([_lead(status: 'Converted')]), isFalse);
    });
  });
}

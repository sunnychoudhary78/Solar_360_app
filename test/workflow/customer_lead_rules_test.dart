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
      expect(canCustomerFillOrComplete([complete]), isFalse);
    });
  });
}

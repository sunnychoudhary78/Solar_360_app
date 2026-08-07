import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/leads/data/lead_api_service.dart';
import 'package:solar_sales/features/leads/data/lead_repository.dart';

import '../helpers/recording_adapter.dart';

Map<String, dynamic> _leadJson({
  String id = 'lead-1',
  String status = 'New Lead',
}) {
  return {
    'id': id,
    'lead_code': 'LD-$id',
    'full_name': 'Test Lead',
    'mobile': '9876543210',
    'email': 'lead@example.com',
    'status': status,
    'current_department': 'Sales',
    'project_type': 'Residential',
    'is_active': true,
  };
}

void main() {
  group('Lead API workflow', () {
    late ApiServicePair pair;
    late LeadRepository repo;

    setUp(() {
      pair = createTestApi();
      repo = LeadRepository(LeadApiService(ApiService(pair.dio), pair.dio));
    });

    test('getAllLeads parses list payload', () async {
      pair.adapter.on('GET', 'leads', (_) {
        return {
          'data': [
            _leadJson(id: 'a', status: 'New Lead'),
            _leadJson(id: 'b', status: 'Converted'),
          ],
        };
      });

      final leads = await repo.getAllLeads();
      expect(leads, hasLength(2));
      expect(leads.first.id, 'a');
      expect(leads.last.status, 'Converted');
    });

    test('getLeadById parses the backend data wrapper', () async {
      pair.adapter.on('GET', 'leads/lead-1', (_) {
        return {'data': _leadJson()};
      });

      final lead = await repo.getLeadById('lead-1');
      expect(lead.fullName, 'Test Lead');
    });

    test('updateLeadStatus patches status + remarks', () async {
      pair.adapter.on('PATCH', 'leads/lead-1/status', (req) {
        final body = req.data;
        expect(body, isA<Map>());
        final map = Map<String, dynamic>.from(body as Map);
        expect(map['status'], 'Converted');
        expect(map['remarks'], 'docs ok');
        return {
          'data': {'id': 'lead-1', 'new_status': 'Converted'},
        };
      });

      final result = await repo.updateLeadStatus(
        leadId: 'lead-1',
        status: 'Converted',
        remarks: 'docs ok',
      );
      expect(result['new_status'], 'Converted');
      expect(pair.adapter.of('PATCH', 'status'), hasLength(1));
    });

    test('assignLead patches workflow assignees', () async {
      pair.adapter.on('PATCH', 'leads/lead-1/assign', (req) {
        final body = Map<String, dynamic>.from(req.data as Map);
        expect(body['assigned_to_document_admin'], 'doc-1');
        expect(body['assigned_to_finance_user'], 'fin-1');
        return {
          'data': {
            ..._leadJson(id: 'lead-1', status: 'Approved By Sales Manager'),
            'assigned_to_document_admin': 'doc-1',
            'assigned_to_finance_user': 'fin-1',
          },
        };
      });

      final lead = await repo.assignLead('lead-1', {
        'assigned_to_document_admin': 'doc-1',
        'assigned_to_finance_user': 'fin-1',
      });

      expect(lead.assignedToDocumentAdmin, 'doc-1');
      expect(lead.assignedToFinanceUser, 'fin-1');
    });

    test('getUsersByRole returns workflow user list', () async {
      pair.adapter.on(
        'GET',
        'users/by-role?roles=Document+Administrator%2CBank+Process',
        (_) {
          return {
            'data': [
              {'id': 'u1', 'name': 'Doc Admin'},
              {'id': 'u2', 'name': 'Bank User'},
            ],
          };
        },
      );

      final users = await repo.getUsersByRole([
        'Document Administrator',
        'Bank Process',
      ]);

      expect(users, hasLength(2));
      expect(users.first['name'], 'Doc Admin');
    });

    test('createLead posts multipart-compatible form fields', () async {
      pair.adapter.on('POST', 'leads', (req) {
        // Multipart or map — ensure request was sent.
        expect(req.method, 'POST');
        return {'id': 'lead-new', 'status': 'New Lead'};
      });

      await repo.createLead({
        'full_name': 'New Customer',
        'mobile': '9123456780',
        'project_type': 'Residential',
      });

      expect(pair.adapter.of('POST', 'leads'), hasLength(1));
    });

    test('getLeadHistory parses history list', () async {
      pair.adapter.on('GET', 'leads/lead-1/history', (_) {
        return {
          'data': [
            {'status': 'New Lead', 'remarks': 'created'},
            {'status': 'Converted', 'remarks': 'ok'},
          ],
        };
      });

      final history = await repo.getLeadHistory('lead-1');
      expect(history, hasLength(2));
      expect(history.last['status'], 'Converted');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';

LeadModel _lead({
  String id = '1',
  String state = 'Uttar Pradesh',
  String district = '',
  String status = 'New Lead',
  String assignedTo = '',
  String createdBy = 'u1',
  String priority = 'Medium',
  bool isActive = true,
  Map<String, dynamic>? installation,
}) {
  return LeadModel.fromJson({
    'id': id,
    'lead_code': 'LEAD-$id',
    'full_name': 'Lead $id',
    'state': state,
    'district': district,
    'status': status,
    'assigned_to': assignedTo,
    'created_by': createdBy,
    'priority': priority,
    'is_active': isActive,
    'created_at': DateTime.now().toIso8601String(),
    if (installation != null) 'installation_details': installation,
  });
}

TerritoryUser _user({
  String id = 'u1',
  String name = 'Demo',
  String state = 'Uttar Pradesh',
  String district = 'Lucknow',
  List<String> roles = const ['Sales'],
}) {
  return TerritoryUser(
    id: id,
    name: name,
    state: state,
    district: district,
    roles: roles,
  );
}

void main() {
  group('India state names', () {
    test('normalizes aliases used by the web dashboard', () {
      expect(normalizeStateName('UP'), 'Uttar Pradesh');
      expect(normalizeStateName('uk'), 'Uttarakhand');
      expect(normalizeStateName('Jammu & Kashmir'), 'Jammu and Kashmir');
      expect(normalizeStateName('orissa'), 'Odisha');
    });
  });

  group('Green Energy dashboard logic', () {
    test('counts pipeline KPIs using the same status rules as web', () {
      final kpis = buildDashboardKpis(
        [
          _lead(id: '1', status: 'New Lead', priority: 'Urgent'),
          _lead(id: '2', status: 'Converted'),
          _lead(id: '3', status: 'Final Complete'),
          _lead(id: '4', status: 'Rejected'),
        ],
        canSeeRejected: true,
      );

      expect(kpis.total, 4);
      expect(kpis.open, 2);
      expect(kpis.converted, 1);
      expect(kpis.completed, 1);
      expect(kpis.rejected, 1);
      expect(kpis.inPipeline, 2);
      expect(kpis.urgent, 1);
      expect(kpis.installPending, 2);
    });

    test('hides rejected counts when the role cannot see them', () {
      final kpis = buildDashboardKpis(
        [
          _lead(id: '1', status: 'New Lead'),
          _lead(id: '2', status: 'Rejected'),
        ],
        canSeeRejected: false,
      );
      expect(kpis.total, 1);
      expect(kpis.rejected, 0);
    });

    test('district filter depends on selected state users and leads', () {
      final snapshot = buildDashboardSnapshot(
        allLeads: [
          _lead(id: '1', state: 'Uttar Pradesh', district: 'Lucknow', createdBy: 'u1'),
          _lead(id: '2', state: 'Karnataka', district: 'Bengaluru', createdBy: 'u2'),
        ],
        users: [
          _user(id: 'u1', state: 'Uttar Pradesh', district: 'Lucknow'),
          _user(id: 'u2', state: 'Karnataka', district: 'Mysuru', roles: const ['Sales Manager']),
        ],
        filters: const TerritoryFilters(state: 'Uttar Pradesh'),
        canSeeRejected: true,
      );

      expect(snapshot.availableDistricts, ['Lucknow']);
      expect(snapshot.leads, hasLength(1));
      expect(snapshot.availableUsers.map((u) => u.id), ['u1']);
    });

    test('user filter keeps leads created by that user', () {
      final filtered = applyTerritoryFilters(
        leads: [
          _lead(id: '1', createdBy: 'u1'),
          _lead(id: '2', createdBy: 'u2'),
        ],
        users: [_user(id: 'u1'), _user(id: 'u2', name: 'Other')],
        filters: const TerritoryFilters(userId: 'u1'),
      );
      expect(filtered.map((l) => l.id), ['1']);
    });

    test('state analytics still include zero-lead states', () {
      final analytics = buildStateAnalytics(
        leads: [_lead(id: '1', state: 'Uttar Pradesh')],
        users: const [],
        canSeeRejected: true,
      );
      expect(analytics['Delhi']?.leads, 0);
      expect(analytics['Uttar Pradesh']?.leads, 1);
    });
  });

  test('users endpoint matches the existing web API', () {
    expect(ApiEndpoints.users, 'users');
    expect(ApiEndpoints.usersByRole, 'users/by-role');
  });
}

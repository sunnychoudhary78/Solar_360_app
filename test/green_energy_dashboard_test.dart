import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';

LeadModel _lead({
  required String id,
  String state = 'Uttar Pradesh',
  String district = '',
  String status = 'New Lead',
  String department = 'Sales',
  String createdBy = 'u1',
  String assignedTo = '',
  String priority = 'Medium',
  bool isActive = true,
  Map<String, dynamic>? installation,
}) {
  return LeadModel.fromJson({
    'id': id,
    'state': state,
    'district': district,
    'status': status,
    'current_department': department,
    'created_by': createdBy,
    'assigned_to': assignedTo,
    'priority': priority,
    'is_active': isActive,
    'created_at': DateTime.now().toIso8601String(),
    'installation_details': ?installation,
  });
}

void main() {
  test('users endpoint matches the existing web dashboard contract', () {
    expect(ApiEndpoints.users, 'users');
    expect(ApiEndpoints.usersByRole, 'users/by-role');
  });

  test('normalizes India state aliases used by the web map', () {
    expect(normalizeStateName('UP'), 'Uttar Pradesh');
    expect(normalizeStateName('orissa'), 'Odisha');
    expect(normalizeStateName('Jammu & Kashmir'), 'Jammu and Kashmir');
  });

  test('district options depend on the selected state', () {
    final users = [
      const TerritoryUser(
        id: '1',
        name: 'A',
        state: 'Uttar Pradesh',
        district: 'Lucknow',
        roles: ['Sales'],
      ),
      const TerritoryUser(
        id: '2',
        name: 'B',
        state: 'Karnataka',
        district: 'Bengaluru',
        roles: ['Sales'],
      ),
    ];
    final snapshot = buildDashboardSnapshot(
      allLeads: const [],
      users: users,
      filters: const TerritoryFilters(state: 'Uttar Pradesh'),
      canSeeRejected: true,
    );
    expect(snapshot.availableDistricts, ['Lucknow']);
  });

  test('user list updates with role and state filters', () {
    final users = [
      const TerritoryUser(
        id: '1',
        name: 'Sales One',
        state: 'Uttar Pradesh',
        roles: ['Sales'],
      ),
      const TerritoryUser(
        id: '2',
        name: 'Engineer',
        state: 'Uttar Pradesh',
        roles: ['Electrical Engineer'],
      ),
      const TerritoryUser(
        id: '3',
        name: 'Other State',
        state: 'Karnataka',
        roles: ['Sales'],
      ),
    ];
    final snapshot = buildDashboardSnapshot(
      allLeads: const [],
      users: users,
      filters: const TerritoryFilters(state: 'Uttar Pradesh', role: 'Sales'),
      canSeeRejected: true,
    );
    expect(snapshot.availableUsers.map((u) => u.id), ['1']);
  });

  test('KPIs and lead mix follow the same filtered leads', () {
    final users = [
      const TerritoryUser(
        id: 'u1',
        name: 'Demo',
        state: 'Uttar Pradesh',
        roles: ['Sales'],
      ),
    ];
    final leads = [
      _lead(id: '1', status: 'New Lead', createdBy: 'u1'),
      _lead(id: '2', status: 'Converted', createdBy: 'u1'),
      _lead(id: '3', status: 'Final Complete', department: 'Completed', createdBy: 'u1'),
      _lead(id: '4', status: 'Rejected', createdBy: 'u1'),
      _lead(id: '5', state: 'Karnataka', status: 'New Lead', createdBy: 'u2'),
    ];

    final snapshot = buildDashboardSnapshot(
      allLeads: leads,
      users: users,
      filters: const TerritoryFilters(state: 'Uttar Pradesh'),
      canSeeRejected: true,
    );

    expect(snapshot.kpis.total, 4);
    expect(snapshot.kpis.open, 2);
    expect(snapshot.kpis.converted, 1);
    expect(snapshot.kpis.completed, 1);
    expect(snapshot.kpis.rejected, 1);
    expect(snapshot.kpis.inPipeline, snapshot.kpis.open);
    expect(snapshot.selectedState?.leads, 4);
    expect(snapshot.selectedState?.name, 'Uttar Pradesh');
  });

  test('clear filters restores the full dashboard snapshot', () {
    final leads = [
      _lead(id: '1'),
      _lead(id: '2', state: 'Karnataka'),
    ];
    final filtered = buildDashboardSnapshot(
      allLeads: leads,
      users: const [],
      filters: const TerritoryFilters(state: 'Karnataka'),
      canSeeRejected: true,
    );
    final cleared = buildDashboardSnapshot(
      allLeads: leads,
      users: const [],
      filters: const TerritoryFilters(),
      canSeeRejected: true,
    );
    expect(filtered.kpis.total, 1);
    expect(cleared.kpis.total, 2);
  });

  test('states with zero leads still exist in analytics', () {
    final snapshot = buildDashboardSnapshot(
      allLeads: [_lead(id: '1')],
      users: const [],
      filters: const TerritoryFilters(),
      canSeeRejected: true,
    );
    expect(snapshot.stateAnalytics['Goa']?.leads, 0);
    expect(snapshot.stateAnalytics['Uttar Pradesh']?.leads, 1);
  });
}

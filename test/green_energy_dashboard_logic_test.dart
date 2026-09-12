import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/features/leads/data/green_energy_dashboard_logic.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/models/territory_user_model.dart';
import 'package:solar_sales/features/leads/presentation/widgets/india_heat_map.dart';

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

    test('uses short state codes on the heat map to avoid overlap', () {
      expect(indiaMapShortName('Jammu and Kashmir'), 'J&K');
      expect(indiaMapShortName('Andaman and Nicobar Islands'), 'AN');
      expect(indiaMapShortName('Dadra and Nagar Haveli and Daman and Diu'), 'DD');
      expect(indiaMapShortName('Uttar Pradesh'), 'UP');
      expect(indiaMapShortName('Himachal Pradesh'), 'HP');
      expect(indiaMapShortName('Punjab'), 'PB');
      expect(indiaMapShortName('Nagaland'), 'NL');
      expect(indiaMapShortName('Meghalaya'), 'ML');
      expect(indiaMapShortName('Mizoram'), 'MZ');
      expect(indiaMapLabelLines('UP'), ['UP']);
      expect(indiaMapLabelLines('Goa'), ['Goa']);
    });

    test('covers every canonical state with a short map code', () {
      for (final name in indiaStateNames) {
        final code = indiaMapShortName(name);
        expect(code, isNot(name), reason: '$name should not stay as a full map label');
        expect(code.length, lessThanOrEqualTo(3), reason: '$name map code is too long: $code');
      }
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
      expect(kpis.active, 2);
      expect(kpis.urgent, 1);
      expect(kpis.installPending, 2);
      expect(kpis.mixPipeline, 1);
      expect(kpis.mixConverted, 1);
      expect(kpis.leadMixTotal, 4);
    });

    test('Active Leads excludes completed and rejected even if is_active is true', () {
      final kpis = buildDashboardKpis(
        [
          _lead(id: '1', status: 'New Lead', isActive: true),
          _lead(id: '2', status: 'Converted', isActive: false),
          _lead(id: '3', status: 'Final Complete', isActive: true),
          _lead(id: '4', status: 'Lead Closed', isActive: true),
          _lead(id: '5', status: 'Rejected', isActive: true),
        ],
        canSeeRejected: true,
      );

      expect(kpis.completed, 2);
      expect(kpis.rejected, 1);
      expect(kpis.active, 1);
      expect(kpis.open, 2);
    });

    test('Lead mix does not double-count a converted lead', () {
      final kpis = buildDashboardKpis(
        [_lead(id: '1', status: 'Converted')],
        canSeeRejected: true,
      );

      expect(kpis.total, 1);
      expect(kpis.inPipeline, 1);
      expect(kpis.converted, 1);
      expect(kpis.mixPipeline, 0);
      expect(kpis.mixConverted, 1);
      expect(kpis.leadMixTotal, 1);
    });

    test('counts open-lead priority mix the same way as web', () {
      final kpis = buildDashboardKpis(
        [
          _lead(id: '1', status: 'New Lead', priority: 'Urgent'),
          _lead(id: '2', status: 'New Lead', priority: 'High'),
          _lead(id: '3', status: 'New Lead', priority: 'Medium'),
          _lead(id: '4', status: 'New Lead', priority: 'Low'),
          _lead(id: '5', status: 'Final Complete', priority: 'Urgent'),
        ],
        canSeeRejected: true,
      );

      expect(kpis.open, 4);
      expect(kpis.urgent, 1);
      expect(kpis.high, 1);
      expect(kpis.medium, 1);
      expect(kpis.low, 1);
      expect(kpis.priorityMixTotal, kpis.open);
    });

    test('Priority mix counts blank priority as Medium so open leads match', () {
      final kpis = buildDashboardKpis(
        [
          _lead(id: '1', status: 'New Lead', priority: ''),
          _lead(id: '2', status: 'Converted', priority: 'Normal'),
          _lead(id: '3', status: 'Final Complete', priority: 'Urgent'),
        ],
        canSeeRejected: true,
      );

      expect(kpis.open, 2);
      expect(kpis.urgent, 0);
      expect(kpis.medium, 2);
      expect(kpis.priorityMixTotal, 2);
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

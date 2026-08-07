import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/auth/data/models/auth_models.dart';

void main() {
  group('AuthUser / LoginResult', () {
    test('parses login user with companyModules and roles', () {
      final result = LoginResult.fromJson({
        'token': 'jwt-token',
        'user': {
          'id': 'u1',
          'name': 'Priya',
          'email': 'priya@imt.com',
          'roleId': 'r1',
          'activeRole': 'SalesExecutive',
          'roles': ['SalesExecutive', 'Sales'],
          'companyId': 'c1',
          'companyName': 'IMT Solar',
          'companyModules': {'billbook': true, 'solar': true},
          'role': {
            'id': 'r1',
            'name': 'SalesExecutive',
            'hierarchy_level': 400,
          },
        },
      });

      expect(result.token, 'jwt-token');
      expect(result.user.name, 'Priya');
      expect(result.user.activeRole, 'SalesExecutive');
      expect(result.user.roles, ['SalesExecutive', 'Sales']);
      expect(result.user.companyId, 'c1');
      expect(result.user.companyModules.billbook, isTrue);
      expect(result.user.companyModules.solar, isTrue);
      expect(result.user.effectiveRoleName, 'SalesExecutive');
    });
  });

  group('UserProfile', () {
    test('parses /me style payload with nested company flags', () {
      final profile = UserProfile.fromJson({
        'user': {
          'id': 'u2',
          'name': 'Admin User',
          'email': 'admin@imt.com',
          'activeRole': 'Admin',
          'roles': ['Admin', 'Sales'],
          'Role': {
            'name': 'Admin',
            'hierarchy_level': 200,
          },
          'employee_detail': {
            'company_id': 'c9',
            'company': {
              'id': 'c9',
              'name': 'Green Co',
              'billbook_enabled': true,
              'solar_enabled': false,
            },
          },
        },
      });

      expect(profile.isCompanyAdmin, isTrue);
      expect(profile.companyName, 'Green Co');
      expect(profile.companyModules.billbook, isTrue);
      expect(profile.companyModules.solar, isFalse);
      expect(profile.effectiveRoleName, 'Admin');
    });

    test('platform super admin detection', () {
      final profile = UserProfile.fromJson({
        'id': 'sa',
        'name': 'Platform',
        'email': 'sa@imt.com',
        'Role': {'name': 'SuperAdmin', 'hierarchy_level': 10},
      });
      expect(profile.isPlatformSuperAdmin, isTrue);
    });
  });

  group('SwitchRoleResult', () {
    test('parses switch-role response with permission names', () {
      final result = SwitchRoleResult.fromJson({
        'token': 'new-jwt',
        'user': {
          'id': 'u1',
          'name': 'Priya',
          'email': 'priya@imt.com',
          'activeRole': 'FinanceHead',
          'roles': ['SalesExecutive', 'FinanceHead'],
          'role': {'name': 'FinanceHead', 'hierarchy_level': 300},
        },
        'permissions': ['invoice.read', 'invoice.approve', 'quotation.read'],
      });

      expect(result.token, 'new-jwt');
      expect(result.user.activeRole, 'FinanceHead');
      expect(result.permissions, contains('invoice.approve'));
    });
  });

  group('CompanyModules', () {
    test('defaults allow both when missing', () {
      final mods = CompanyModules.fromJson(null);
      expect(mods.billbook, isTrue);
      expect(mods.solar, isTrue);
    });

    test('false flags disable modules', () {
      final mods = CompanyModules.fromJson({
        'billbook': false,
        'solar': true,
      });
      expect(mods.billbook, isFalse);
      expect(mods.solar, isTrue);
    });
  });
}

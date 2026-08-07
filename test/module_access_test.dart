import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/shared/module/module_access.dart';

void main() {
  group('resolvePreferredModule', () {
    test('prefers stored solar when allowed', () {
      final result = resolvePreferredModule(
        permissions: ['lead.read'],
        role: 'Sales',
        stored: AppModules.solar,
        companyBillbook: true,
        companySolar: true,
      );
      expect(result, AppModules.solar);
    });

    test('falls back to billbook when solar company flag off', () {
      final result = resolvePreferredModule(
        permissions: ['lead.read', 'customer.read'],
        role: 'Sales',
        stored: AppModules.solar,
        companyBillbook: true,
        companySolar: false,
      );
      expect(result, AppModules.billbook);
    });

    test('falls back to solar when billbook company flag off', () {
      final result = resolvePreferredModule(
        permissions: ['lead.read', 'customer.read'],
        role: 'SalesExecutive',
        stored: AppModules.billbook,
        companyBillbook: false,
        companySolar: true,
      );
      expect(result, AppModules.solar);
    });

    test('company admin can use module without resource perms', () {
      final result = resolvePreferredModule(
        permissions: const [],
        role: 'Admin',
        stored: AppModules.billbook,
        companyBillbook: true,
        companySolar: true,
        companyAdmin: true,
      );
      expect(result, AppModules.billbook);
    });

    test('solar role prefers solar when both modules allowed', () {
      final result = resolvePreferredModule(
        permissions: ['lead.read', 'customer.read'],
        role: 'Installation Team',
        stored: null,
        companyBillbook: true,
        companySolar: true,
      );
      expect(result, AppModules.solar);
    });

    test('billbook-only permissions land on billbook', () {
      final result = resolvePreferredModule(
        permissions: ['customer.read', 'quotation.read'],
        role: 'SalesExecutive',
        stored: null,
        companyBillbook: true,
        companySolar: true,
      );
      expect(result, AppModules.billbook);
    });

    test('platform admin can prefer billbook without resource perms', () {
      final result = resolvePreferredModule(
        permissions: const [],
        role: 'SuperAdmin',
        stored: AppModules.billbook,
        companyBillbook: true,
        companySolar: true,
        platformAdmin: true,
      );
      expect(result, AppModules.billbook);
    });
  });

  group('filterRolesForModule', () {
    test('hides solar roles in billbook module', () {
      final roles = filterRolesForModule(
        ['SalesExecutive', 'Sales', 'FinanceHead'],
        AppModules.billbook,
      );
      expect(roles, contains('SalesExecutive'));
      expect(roles, contains('FinanceHead'));
      expect(roles, isNot(contains('Sales')));
    });

    test('hides billbook roles in solar module', () {
      final roles = filterRolesForModule(
        ['SalesExecutive', 'Installation Team', 'Sales'],
        AppModules.solar,
      );
      expect(roles, contains('Installation Team'));
      expect(roles, contains('Sales'));
      expect(roles, isNot(contains('SalesExecutive')));
    });

    test('excludes SuperAdmin from switcher lists', () {
      final roles = filterRolesForModule(
        ['SuperAdmin', 'SalesExecutive'],
        AppModules.billbook,
      );
      expect(roles, isNot(contains('SuperAdmin')));
      expect(roles, contains('SalesExecutive'));
    });
  });

  group('module helpers', () {
    test('labels and home routes', () {
      expect(ModuleLabels.of(AppModules.billbook), 'Billbook');
      expect(ModuleLabels.of(AppModules.solar), 'Green Energy');
      expect(moduleHomeRoute(AppModules.billbook), '/');
      expect(moduleHomeRoute(AppModules.solar), '/solar');
    });

    test('normalizeProductModule aliases', () {
      expect(normalizeProductModule('green_energy'), AppModules.solar);
      expect(normalizeProductModule('erp'), AppModules.billbook);
      expect(normalizeProductModule('nope'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/core/utils/role_utils.dart';

void main() {
  group('RoleUtils.normalizeAppRole', () {
    test('maps solar desk roles', () {
      expect(RoleUtils.normalizeAppRole('Sales'), 'sales');
      expect(RoleUtils.normalizeAppRole('Sales Manager'), 'sales');
      expect(RoleUtils.normalizeAppRole('Document Administrator'), 'support');
      expect(RoleUtils.normalizeAppRole('Finance User'), 'finance');
      expect(RoleUtils.normalizeAppRole('Installation Team'), 'installation');
      expect(RoleUtils.normalizeAppRole('liaison'), 'liaison');
      expect(RoleUtils.normalizeAppRole('Liaison Officer'), 'liaison');
    });

    test('maps admin roles', () {
      expect(RoleUtils.normalizeAppRole('Admin'), 'admin');
      expect(RoleUtils.normalizeAppRole('SuperAdmin'), 'admin');
    });

    test('defaults empty to sales', () {
      expect(RoleUtils.normalizeAppRole(null), 'sales');
      expect(RoleUtils.normalizeAppRole(''), 'sales');
    });
  });

  group('RoleUtils.displayTitle', () {
    test('returns desk titles', () {
      expect(RoleUtils.displayTitle('admin'), 'Solar Admin');
      expect(RoleUtils.displayTitle('support'), 'Document Administration');
      expect(RoleUtils.displayTitle('liaison'), 'Bank Process');
      expect(RoleUtils.displayTitle('finance'), 'Finance Team');
      expect(RoleUtils.displayTitle('installation'), 'Installation Team');
      expect(RoleUtils.displayTitle('sales'), 'Solar Sales');
    });
  });

  group('RoleUtils.displayTitleForRole', () {
    test('preserves distinct solar workflow roles', () {
      expect(RoleUtils.displayTitleForRole('Sales Manager'), 'Sales Manager');
      expect(
        RoleUtils.displayTitleForRole('Finance Manager'),
        'Finance Manager',
      );
      expect(RoleUtils.displayTitleForRole('Finance User'), 'Finance User');
      expect(
        RoleUtils.displayTitleForRole('Material Engineer'),
        'Material Engineer',
      );
      expect(
        RoleUtils.displayTitleForRole('Electrical Engineer'),
        'Electrical Engineer',
      );
    });
  });
}

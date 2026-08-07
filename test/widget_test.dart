import 'package:flutter_test/flutter_test.dart';

import 'package:solar_sales/shared/module/module_access.dart';

void main() {
  test('module home routes', () {
    expect(moduleHomeRoute(AppModules.billbook), '/');
    expect(moduleHomeRoute(AppModules.solar), '/solar');
  });

  test('module labels', () {
    expect(ModuleLabels.of(AppModules.billbook), 'Billbook');
    expect(ModuleLabels.of(AppModules.solar), 'Green Energy');
  });
}

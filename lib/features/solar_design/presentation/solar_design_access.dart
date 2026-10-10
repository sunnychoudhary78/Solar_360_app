import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';

class SolarDesignAccess {
  static const read = 'solar_design.read';
  static const create = 'solar_design.create';
  static const update = 'solar_design.update';

  static bool canRead(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(read) || auth.isCompanyAdmin;
  }

  static bool canCreate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(create) || auth.isCompanyAdmin;
  }

  static bool canUpdate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(update) || auth.isCompanyAdmin;
  }
}

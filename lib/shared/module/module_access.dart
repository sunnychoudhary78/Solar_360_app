/// Product module helpers — keep in sync with web ModuleContext + roleModules.
///
/// Solar lead permissions intentionally have two levels:
/// - `lead.read` grants API and workflow access.
/// - `leads.read` grants the Leads list/menu (CompanyAdmin + SolarSales).
library;

class AppModules {
  static const billbook = 'billbook';
  static const solar = 'solar';
}

class ModuleLabels {
  static const billbook = 'Billbook';
  static const solar = 'Green Energy';

  static String of(String moduleId) {
    if (moduleId == AppModules.solar) return solar;
    return billbook;
  }
}

const storageModuleKey = 'imt_active_module';

const billbookPerms = [
  'module.billbook.access',
  'customer.read',
  'item.read',
  'inventory.read',
  'quotation.read',
  'invoice.read',
  'report.read',
];

const solarPerms = [
  'module.solar.access',
  'lead.read',
  'leads.read',
  'installation.read',
  'closedlead.read',
];

const billbookRoleNames = [
  'SalesExecutive',
  'SalesHead',
  'FinanceExecutive',
  'FinanceHead',
  'ProcurementExecutive',
  'ProcurementHOD',
];

const solarRoleNames = [
  'Sales',
  'SolarSales',
  'Sales Manager',
  'Finance Manager',
  'Document Administrator',
  'Bank Process',
  'Finance User',
  'Installation Manager',
  'Installation Team',
  'Material Engineer',
  'Electrical Engineer',
];

final _billbookRoleSet = billbookRoleNames.map((n) => n.toLowerCase()).toSet();
final _solarRoleSet = solarRoleNames.map((n) => n.toLowerCase()).toSet();

final _solarRoleKeys = {
  'sales',
  'solarsales',
  'sales manager',
  'finance manager',
  'finance user',
  'document administrator',
  'bank process',
  'installation manager',
  'installation team',
  'material engineer',
  'electrical engineer',
};

bool hasAnyPerm(List<String> permissions, List<String> required) {
  if (required.isEmpty) return true;
  return required.any(permissions.contains);
}

String? normalizeProductModule(String? module) {
  final m = (module ?? '').trim().toLowerCase();
  if (m == 'solar' || m == 'green' || m == 'green_energy' || m == 'crm') {
    return AppModules.solar;
  }
  if (m == 'billbook' || m == 'erp' || m == 'inventory') {
    return AppModules.billbook;
  }
  return null;
}

/// Filter role names for the active product module.
List<String> filterRolesForModule(List<String> roles, String? module) {
  final mod = normalizeProductModule(module);
  if (mod == null) return List<String>.from(roles);

  return roles.where((role) {
    final key = role.trim().toLowerCase();
    if (key.isEmpty) return false;
    if (key == 'superadmin' || key == 'super admin') return false;
    if (mod == AppModules.billbook) return !_solarRoleSet.contains(key);
    if (mod == AppModules.solar) return !_billbookRoleSet.contains(key);
    return true;
  }).toList();
}

String resolvePreferredModule({
  required List<String> permissions,
  String role = '',
  String? stored,
  bool companyBillbook = true,
  bool companySolar = true,
  bool companyAdmin = false,
  bool platformAdmin = false,
}) {
  final canBillbook =
      (platformAdmin || companyBillbook) &&
      (companyAdmin || platformAdmin || hasAnyPerm(permissions, billbookPerms));
  final canSolar =
      companySolar && (companyAdmin || hasAnyPerm(permissions, solarPerms));

  final roleKey = role.trim().toLowerCase();
  final solarRole = _solarRoleKeys.contains(roleKey);

  if (stored == AppModules.solar && canSolar) return AppModules.solar;
  if (stored == AppModules.billbook && canBillbook) return AppModules.billbook;

  if (solarRole && canSolar && !canBillbook) return AppModules.solar;
  if (canBillbook && !canSolar) return AppModules.billbook;
  if (canSolar && !canBillbook) return AppModules.solar;
  if (solarRole && canSolar) return AppModules.solar;
  if (canBillbook) return AppModules.billbook;
  if (canSolar) return AppModules.solar;
  return AppModules.billbook;
}

String moduleHomeRoute(String moduleId) {
  return moduleId == AppModules.solar ? '/solar' : '/';
}

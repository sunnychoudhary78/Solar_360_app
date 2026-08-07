/// Role-specific dashboard welcome copy (web Dashboard.jsx parity).
class RoleTaglines {
  RoleTaglines._();

  static const map = {
    'SuperAdmin': 'Full system access — manage users, settings, and operations.',
    'Admin': 'Oversee sales, inventory, and team workflows.',
    'SalesHead': 'Lead your sales team — customers, quotations, and approvals.',
    'SalesExecutive': 'Create customers and quotations, track your pipeline.',
    'FinanceHead': 'Approve invoices, manage billing, and review reports.',
    'FinanceExecutive': 'Create and submit invoices for approval.',
    'ProcurementHOD': 'Approve items and manage inventory operations.',
    'ProcurementExecutive': 'Create items, manage stock in/out and warehouses.',
  };

  static String forRole(String? roleName) {
    if (roleName == null || roleName.isEmpty) {
      return 'Your workspace for quotations, inventory & billing.';
    }
    return map[roleName] ??
        'Your workspace for quotations, inventory & billing.';
  }
}

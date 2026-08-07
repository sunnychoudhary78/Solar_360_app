import 'package:solar_sales/core/workflow/lead_workflow.dart';

class RoleUtils {
  RoleUtils._();

  static String normalizeAppRole(String? roleName) {
    final key = LeadWorkflow.resolveRoleKey(roleName);
    final lower = key.toLowerCase();

    if (lower == 'sales' || lower == 'sales manager') return 'sales';
    if (lower == 'document administrator') return 'support';
    if (lower == 'bank process') {
      return 'liaison';
    }
    if (lower == 'finance manager' || lower == 'finance user') {
      return 'finance';
    }
    if (lower == 'installation manager' ||
        lower == 'material engineer' ||
        lower == 'electrical engineer') {
      return 'installation';
    }
    if (LeadWorkflow.isAdminRole(key)) return 'admin';

    return lower.isEmpty ? 'sales' : lower;
  }

  static String displayTitle(String appRole) {
    switch (appRole) {
      case 'admin':
        return 'Solar Admin';
      case 'support':
        return 'Document Administration';
      case 'liaison':
        return 'Bank Process';
      case 'finance':
        return 'Finance Team';
      case 'installation':
        return 'Installation Team';
      case 'sales':
      default:
        return 'Solar Sales';
    }
  }

  static String displayTitleForRole(String? roleName) {
    final roleKey = LeadWorkflow.resolveRoleKey(roleName);
    if (LeadWorkflow.isAdminRole(roleKey)) return 'Solar Admin';

    switch (roleKey) {
      case 'Sales':
        return 'Solar Sales';
      case 'Sales Manager':
        return 'Sales Manager';
      case 'Finance Manager':
        return 'Finance Manager';
      case 'Document Administrator':
        return 'Document Administration';
      case 'Bank Process':
        return 'Bank Process';
      case 'Finance User':
        return 'Finance User';
      case 'Installation Manager':
        return 'Installation Manager';
      case 'Material Engineer':
        return 'Material Engineer';
      case 'Electrical Engineer':
        return 'Electrical Engineer';
      default:
        return displayTitle(normalizeAppRole(roleName));
    }
  }
}

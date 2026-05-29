import '../workflow/lead_workflow.dart';

/// Maps backend role names to app navigation keys.
class RoleUtils {
  RoleUtils._();

  static String normalizeAppRole(String? roleName) {
    final key = LeadWorkflow.resolveRoleKey(roleName);
    final lower = key.toLowerCase();

    if (LeadWorkflow.isAdminRole(key)) return 'admin';
    if (lower == 'sales') return 'sales';
    if (lower == 'support') return 'support';
    if (lower == 'liaison officer' || lower == 'liaising') return 'liaison';
    if (lower == 'finance') return 'finance';
    if (lower == 'installation team' || lower == 'installation') {
      return 'installation';
    }
    return lower.isEmpty ? 'sales' : lower;
  }

  static String displayTitle(String appRole) {
    switch (appRole) {
      case 'admin':
        return 'CSPL Solar Admin';
      case 'support':
        return 'Support Team';
      case 'liaison':
        return 'Liaison Officer';
      case 'finance':
        return 'Finance Team';
      case 'installation':
        return 'Installation Team';
      case 'sales':
      default:
        return 'Solar Sales';
    }
  }
}

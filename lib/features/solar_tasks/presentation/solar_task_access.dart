import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';

/// Permission gates for Task Management — keep in sync with web
/// `TaskManagement.jsx` + `RequirePermission permission="task.read"`.
///
/// Web does **not** grant Company Admin a bypass; access is only via
/// `task.read` / `task.create` / `task.update` / `task.delete`.
class SolarTaskAccess {
  SolarTaskAccess._();

  static const read = 'task.read';
  static const create = 'task.create';
  static const update = 'task.update';
  static const delete = 'task.delete';

  /// Page / drawer / quick-action visibility.
  static bool canRead(AuthState auth) {
    if (auth.isCustomerSession) return false;
    // Companions on web: create/update/delete imply read in Roles UI.
    // Still accept any of the four so a partial grant can open the board.
    return auth.hasAny(const [read, create, update, delete]);
  }

  static bool canCreate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(create);
  }

  static bool canUpdate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(update);
  }

  /// Soft-delete API + Team / company-wide scope (backend `canOverseeTasks`).
  static bool canOversee(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(delete) || auth.isPlatformSuperAdmin;
  }

  static bool canOpenLeads(AuthState auth) {
    return auth.hasAny(const ['leads.read', 'lead.read']);
  }
}

import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';

/// Permission gates for AMC Visits — keep in sync with web `AmcVisits.jsx`.
class AmcAccess {
  AmcAccess._();

  static const read = 'amc.read';
  static const create = 'amc.create';
  static const update = 'amc.update';
  static const delete = 'amc.delete';

  /// Page / drawer / quick-action visibility (web route: `amc.read`).
  static bool canRead(AuthState auth) {
    if (auth.isCustomerSession) return false;
    // Companions: create/update/delete imply read in Roles UI.
    return auth.hasAny(const [read, create, update, delete]);
  }

  /// Start AMC, extra visit, renew (web uses `amc.create` only).
  static bool canCreate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(create);
  }

  /// Complete visit, checklist, photos, assignee (web: `amc.update`).
  static bool canUpdate(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(update);
  }

  /// Soft-delete an uncompleted visit (web: `amc.delete`).
  static bool canDelete(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(delete);
  }

  static bool canOpenLead(AuthState auth) {
    return auth.hasAny(const ['leads.read', 'lead.read']);
  }
}

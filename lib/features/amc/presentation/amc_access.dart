import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';

/// Permission gates for AMC Visits — keep in sync with web `/solar/amc`.
class AmcAccess {
  AmcAccess._();

  static const read = 'amc.read';
  static const create = 'amc.create';
  static const update = 'amc.update';
  static const delete = 'amc.delete';

  /// Page / drawer / quick-action visibility.
  static bool canRead(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasAny(const [read, create, update, delete]);
  }

  /// Start AMC, extra visit, renew, edit contract.
  static bool canManageContract(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasAny(const [create, update]);
  }

  /// Complete visit, checklist, photos, assignee.
  static bool canUpdateVisit(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(update);
  }

  /// Soft-delete an uncompleted visit.
  static bool canDeleteVisit(AuthState auth) {
    if (auth.isCustomerSession) return false;
    return auth.hasPermission(delete);
  }

  static bool canOpenLead(AuthState auth) {
    return auth.hasAny(const ['leads.read', 'lead.read']);
  }
}

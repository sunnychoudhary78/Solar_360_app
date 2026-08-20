import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:solar_sales/features/invoices/presentation/providers/invoice_providers.dart';
import 'package:solar_sales/features/items/presentation/providers/item_providers.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/quotations/presentation/providers/quotation_providers.dart';
import 'package:solar_sales/features/reports/presentation/providers/reports_providers.dart';

/// Clears role-scoped caches after a role switch.
///
/// Must not invalidate providers that [ref.watch(authProvider)] while still
/// inside [AuthNotifier] — that causes CircularDependencyError (seen with
/// dashboardProvider). Call via [scheduleRoleScopedInvalidation] instead.
void invalidateRoleScopedData(Ref ref) {
  // Intentionally skip dashboardProvider: it already watches authProvider and
  // refreshes when permissions change. Invalidating it from auth caused:
  // CircularDependencyError: FutureProvider<DashboardModel>

  ref.invalidate(reportsProvider);
  ref.invalidate(allLeadsProvider);
  ref.invalidate(leadListProvider(false));
  ref.invalidate(leadListProvider(true));
  ref.invalidate(unreadNotificationCountProvider);
  ref.invalidate(myNotificationsProvider);
  ref.invalidate(pendingQuotationsProvider);
  ref.invalidate(pendingInvoicesProvider);
  ref.invalidate(invoiceableQuotationsProvider);
  ref.invalidate(warehousesProvider);
  ref.invalidate(managedWarehousesProvider);
  ref.invalidate(lowStockProvider);
  ref.invalidate(customerListProvider);
  ref.invalidate(quotationListProvider);
  ref.invalidate(invoiceListProvider);
  ref.invalidate(itemListProvider);
}

/// Runs cache invalidation after navigation/overlays have settled so Riverpod
/// and InheritedWidget dependents are not torn down mid-update.
void scheduleRoleScopedInvalidation(Ref ref) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      try {
        invalidateRoleScopedData(ref);
      } catch (_) {
        // Best-effort cache clear — never crash the UI after a successful switch.
      }
    });
  });
}

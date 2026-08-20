import 'package:flutter/material.dart';

import 'package:solar_sales/features/customers/presentation/screens/customers_screen.dart';
import 'package:solar_sales/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/inventory_hub_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/all_leads_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/solar_home_screen.dart';
import 'package:solar_sales/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:solar_sales/features/quotations/presentation/screens/quotations_screen.dart';
import 'package:solar_sales/shared/module/module_access.dart';

/// Where a destination lives in the navigation chrome.
enum NavSection {
  main,
  catalog,
  approvals,
  solarCrm,
  app,
}

/// Whether the destination is an IndexedStack tab or a pushed named route.
enum NavKind { shellTab, route }

/// Single declarative destination shared by drawer, shell tabs, and home
/// quick-action grids so the three surfaces can never drift.
class AppDestination {
  const AppDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.section,
    required this.kind,
    this.permission = '',
    this.route,
    this.screen,
    this.quickAction = false,
    this.quickActionSubtitle,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final NavSection section;
  final NavKind kind;

  /// Empty string = always visible (subject to module).
  final String permission;

  /// Named route for [NavKind.route] destinations.
  final String? route;

  /// Widget for [NavKind.shellTab] destinations.
  final Widget? screen;

  /// Show as a quick-action tile on the module home.
  final bool quickAction;
  final String? quickActionSubtitle;

  IconData get effectiveSelectedIcon => selectedIcon ?? icon;
}

class NavDestinations {
  NavDestinations._();

  /// Green Energy Customers — shown in the drawer for Sales User only
  /// (injected above Switch Role; not part of the default section list).
  static const AppDestination solarCustomers = AppDestination(
    id: 'ge_customers',
    label: 'Customers',
    icon: Icons.people_outline,
    selectedIcon: Icons.people_rounded,
    section: NavSection.main,
    kind: NavKind.route,
    route: '/customers',
  );

  // ── Billbook ────────────────────────────────────────────────────────────

  static const List<AppDestination> billbook = [
    AppDestination(
      id: 'bb_home',
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      screen: DashboardScreen(),
    ),
    AppDestination(
      id: 'bb_customers',
      label: 'Customers',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      permission: 'customer.read',
      screen: CustomersScreen(),
      quickAction: true,
      quickActionSubtitle: 'Manage parties',
    ),
    AppDestination(
      id: 'bb_quotes',
      label: 'Quotes',
      icon: Icons.request_quote_outlined,
      selectedIcon: Icons.request_quote_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      permission: 'quotation.read',
      screen: QuotationsScreen(),
      quickAction: true,
      quickActionSubtitle: 'Create & track quotes',
    ),
    AppDestination(
      id: 'bb_stock',
      label: 'Stock',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      permission: 'inventory.read',
      screen: InventoryHubScreen(),
      quickAction: true,
      quickActionSubtitle: 'Inventory hub',
    ),
    AppDestination(
      id: 'bb_invoices',
      label: 'Invoices',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      permission: 'invoice.read',
      screen: InvoicesScreen(),
      quickAction: true,
      quickActionSubtitle: 'Billing & dispatch',
    ),
    AppDestination(
      id: 'bb_notifications',
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      screen: NotificationsScreen(),
    ),
    AppDestination(
      id: 'bb_items',
      label: 'Items',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      section: NavSection.catalog,
      kind: NavKind.route,
      permission: 'item.read',
      route: '/items',
      quickAction: true,
      quickActionSubtitle: 'Product catalog',
    ),
    AppDestination(
      id: 'bb_warehouses',
      label: 'Warehouses',
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
      section: NavSection.catalog,
      kind: NavKind.route,
      permission: 'inventory.read',
      route: '/inventory/warehouses',
      quickAction: true,
      quickActionSubtitle: 'Add & manage sites',
    ),
    AppDestination(
      id: 'bb_item_approvals',
      label: 'Item Approvals',
      icon: Icons.fact_check_outlined,
      section: NavSection.approvals,
      kind: NavKind.route,
      permission: 'item.approve',
      route: '/items/approvals',
    ),
    AppDestination(
      id: 'bb_quote_approvals',
      label: 'Quotation Approvals',
      icon: Icons.approval_outlined,
      section: NavSection.approvals,
      kind: NavKind.route,
      permission: 'quotation.approve',
      route: '/quotations/approvals',
    ),
    AppDestination(
      id: 'bb_invoice_approvals',
      label: 'Invoice Approvals',
      icon: Icons.verified_outlined,
      section: NavSection.approvals,
      kind: NavKind.route,
      permission: 'invoice.approve',
      route: '/invoices/approvals',
    ),
    AppDestination(
      id: 'bb_reports',
      label: 'Reports',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      section: NavSection.app,
      kind: NavKind.route,
      permission: 'report.read',
      route: '/reports',
      quickAction: true,
      quickActionSubtitle: 'KPIs & analytics',
    ),
    AppDestination(
      id: 'bb_settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      section: NavSection.app,
      kind: NavKind.route,
      route: '/settings',
    ),
  ];

  // ── Green Energy ────────────────────────────────────────────────────────

  static const List<AppDestination> solar = [
    AppDestination(
      id: 'ge_home',
      label: 'Green Energy',
      icon: Icons.solar_power_outlined,
      selectedIcon: Icons.solar_power_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      screen: SolarHomeScreen(),
    ),
    AppDestination(
      id: 'ge_leads',
      label: 'Leads',
      icon: Icons.handshake_outlined,
      selectedIcon: Icons.handshake_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      permission: 'lead.read',
      screen: AllLeadsScreen(),
      quickAction: true,
      quickActionSubtitle: 'Pipeline overview',
    ),
    AppDestination(
      id: 'ge_alerts',
      label: 'Alerts',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      section: NavSection.main,
      kind: NavKind.shellTab,
      screen: NotificationsScreen(),
      quickAction: true,
      quickActionSubtitle: 'Notifications',
    ),
    AppDestination(
      id: 'ge_completed',
      label: 'Completed Leads',
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt_rounded,
      section: NavSection.solarCrm,
      kind: NavKind.route,
      permission: 'lead.read',
      route: '/solar/completed-leads',
    ),
    AppDestination(
      id: 'ge_create',
      label: 'Create Lead',
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle_rounded,
      section: NavSection.solarCrm,
      kind: NavKind.route,
      permission: 'lead.create',
      route: '/solar/leads/form',
      quickAction: true,
      quickActionSubtitle: 'Add a new lead',
    ),
    AppDestination(
      id: 'ge_settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      section: NavSection.app,
      kind: NavKind.route,
      route: '/settings',
    ),
  ];

  static List<AppDestination> forModule(String moduleId) {
    return moduleId == AppModules.solar ? solar : billbook;
  }

  /// Shell IndexedStack tabs, filtered by permission.
  static List<AppDestination> shellTabs(
    String moduleId,
    bool Function(String permission) hasPermission,
  ) {
    return forModule(moduleId).where((d) {
      if (d.kind != NavKind.shellTab) return false;
      if (d.permission.isEmpty) return true;
      return hasPermission(d.permission);
    }).toList();
  }

  /// Drawer items for a section, filtered by permission.
  static List<AppDestination> forSection(
    String moduleId,
    NavSection section,
    bool Function(String permission) hasPermission,
  ) {
    return forModule(moduleId).where((d) {
      if (d.section != section) return false;
      if (d.permission.isEmpty) return true;
      return hasPermission(d.permission);
    }).toList();
  }

  /// Home quick-action tiles (excludes the home tab itself).
  static List<AppDestination> quickActions(
    String moduleId,
    bool Function(String permission) hasPermission,
  ) {
    return forModule(moduleId).where((d) {
      if (!d.quickAction) return false;
      if (d.permission.isEmpty) return true;
      return hasPermission(d.permission);
    }).toList();
  }

  static String sectionLabel(NavSection section) {
    switch (section) {
      case NavSection.main:
        return 'Main';
      case NavSection.catalog:
        return 'Catalog';
      case NavSection.approvals:
        return 'Approvals';
      case NavSection.solarCrm:
        return 'Solar CRM';
      case NavSection.app:
        return 'App';
    }
  }
}

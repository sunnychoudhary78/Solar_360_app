import 'package:flutter/material.dart';

import 'package:solar_sales/app/app_root.dart';
import 'package:solar_sales/features/auth/presentation/screens/login_screen.dart'
    show LoginScreen, ChangePasswordScreen;
import 'package:solar_sales/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:solar_sales/features/customers/presentation/screens/customers_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_support_detail_screen.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_support_form_screen.dart';
import 'package:solar_sales/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/inventory_hub_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/low_stock_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/stock_ledger_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/stock_screen.dart';
import 'package:solar_sales/features/inventory/presentation/screens/warehouses_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoice_approvals_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoice_create_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoice_detail_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoice_direct_form_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoice_form_screen.dart';
import 'package:solar_sales/features/invoices/presentation/screens/invoices_screen.dart';
import 'package:solar_sales/features/items/presentation/screens/item_approvals_screen.dart';
import 'package:solar_sales/features/items/presentation/screens/item_categories_screen.dart';
import 'package:solar_sales/features/items/presentation/screens/item_detail_screen.dart';
import 'package:solar_sales/features/items/presentation/screens/item_form_screen.dart';
import 'package:solar_sales/features/items/presentation/screens/items_screen.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/screens/all_leads_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_detail_by_id_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_form_screen.dart';
import 'package:solar_sales/features/leads/presentation/screens/solar_home_screen.dart';
import 'package:solar_sales/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:solar_sales/features/quotations/presentation/screens/quotation_approvals_screen.dart';
import 'package:solar_sales/features/quotations/presentation/screens/quotation_detail_screen.dart';
import 'package:solar_sales/features/quotations/presentation/screens/quotation_form_screen.dart';
import 'package:solar_sales/features/quotations/presentation/screens/quotations_screen.dart';
import 'package:solar_sales/features/reports/presentation/screens/reports_screen.dart';
import 'package:solar_sales/features/settings/presentation/screens/settings_screen.dart';
import 'package:solar_sales/features/shell/presentation/screens/app_shell.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
    '/': (_) => const AppRoot(),
    '/login': (_) => const LoginScreen(),
    '/solar': (_) => const AppShell(),
    '/solar/leads': (_) => const AllLeadsScreen(),
    '/solar/completed-leads': (_) => const AllLeadsScreen(completedOnly: true),
    '/solar/leads/detail': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return LeadDetailByIdScreen(leadId: id);
    },
    '/solar/leads/form': (_) => const LeadFormScreen(),
    '/solar/home': (_) => const SolarHomeScreen(),
    '/solar/notifications': (_) => const NotificationsScreen(),
    '/dashboard': (_) => const DashboardScreen(),
    '/settings': (_) => const SettingsScreen(),
    '/change-password': (_) => const ChangePasswordScreen(),
    '/customer/lead-form': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return LeadFormScreen(
        mode: LeadFormMode.completeDetails,
        existingLead: args is LeadModel ? args : null,
        customerPortal: true,
      );
    },
    '/customer/support/new': (_) => const CustomerSupportFormScreen(),
    '/customer/support/detail': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return CustomerSupportDetailScreen(ticketId: id);
    },
    '/customers': (_) => const CustomersScreen(),
    '/customers/form': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = args is String ? args : null;
      return CustomerFormScreen(customerId: id);
    },
    '/items': (_) => const ItemsScreen(),
    '/items/categories': (_) => const ItemCategoriesScreen(),
    '/items/form': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = args is String ? args : null;
      return ItemFormScreen(itemId: id);
    },
    '/items/detail': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return ItemDetailScreen(itemId: id);
    },
    '/items/approvals': (_) => const ItemApprovalsScreen(),
    '/quotations': (_) => const QuotationsScreen(),
    '/quotations/form': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final id = args is String ? args : null;
      return QuotationFormScreen(quotationId: id);
    },
    '/quotations/detail': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return QuotationDetailScreen(quotationId: id);
    },
    '/quotations/approvals': (_) => const QuotationApprovalsScreen(),
    '/invoices': (_) => const InvoicesScreen(),
    '/invoices/create': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      String? quotationId;
      if (args is String) {
        quotationId = args;
      } else if (args is Map) {
        quotationId = args['quotationId']?.toString();
      }
      return InvoiceCreateScreen(quotationId: quotationId);
    },
    '/invoices/new': (_) => const InvoiceDirectFormScreen(),
    '/invoices/form': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return InvoiceFormScreen(invoiceId: id);
    },
    '/invoices/detail': (context) {
      final id = ModalRoute.of(context)!.settings.arguments as String;
      return InvoiceDetailScreen(invoiceId: id);
    },
    '/invoices/approvals': (_) => const InvoiceApprovalsScreen(),
    '/reports': (_) => const ReportsScreen(),
    '/inventory': (_) => const InventoryHubScreen(),
    '/inventory/stock': (_) => const StockScreen(),
    '/inventory/ledger': (_) => const StockLedgerScreen(),
    '/inventory/low-stock': (_) => const LowStockScreen(),
    '/inventory/warehouses': (_) => const WarehousesScreen(),
  };
}

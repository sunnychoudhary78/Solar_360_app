class ApiEndpoints {
  // Auth
  static const login = 'auth/login';
  static const me = 'auth/me';
  static const permissions = 'auth/permissions';
  static const changePassword = 'auth/change-password';
  static const switchRole = 'auth/switch-role';

  // Branding / reports
  static const solarBranding = 'company-settings/solar-branding';
  static const itemCategories = 'company-settings/item-categories';
  static String itemCategory(String id) =>
      'company-settings/item-categories/$id';
  static const dashboard = 'solar-reports/dashboard';
  static const salesReport = 'solar-reports/sales';
  static const stockReport = 'solar-reports/stock';
  static const quotationsReport = 'solar-reports/quotations';
  static const invoicesReport = 'solar-reports/invoices';

  // Customers (staff CRUD)
  static const customers = 'customers';
  static String customer(String id) => 'customers/$id';
  static String customerResetPassword(String id) =>
      'customers/$id/reset-default-password';

  // Customer portal auth
  static const customerLogin = 'customers/login';
  static const customerMe = 'customers/me';
  static const customerChangePassword = 'customers/change-password';
  static const customerLogout = 'customers/logout';

  // Customer portal leads
  static const customerLeads = 'customers/leads';
  static String customerLead(String id) => 'customers/leads/$id';

  // Customer portal support
  static const supportTickets = 'support-tickets';
  static const supportTicketsDashboard = 'support-tickets/dashboard';
  static String supportTicket(String id) => 'support-tickets/$id';
  static String supportTicketHistory(String id) =>
      'support-tickets/$id/history';
  static String supportTicketMessages(String id) =>
      'support-tickets/$id/messages';
  static String supportTicketMessagesRead(String id) =>
      'support-tickets/$id/messages/read';
  static String supportTicketVerify(String id) => 'support-tickets/$id/verify';

  // Staff / Company Admin support (Billbook)
  static const adminSupportTickets = 'support-tickets/admin/list';
  static String adminSupportTicket(String id) => 'support-tickets/admin/$id';
  static String adminSupportTicketMessages(String id) =>
      'support-tickets/admin/$id/messages';
  static String adminSupportTicketMessagesRead(String id) =>
      'support-tickets/admin/$id/messages/read';
  static String adminSupportTicketHistory(String id) =>
      'support-tickets/admin/$id/history';

  // Items
  static const items = 'items';
  static const itemsApproved = 'items/approved';
  static const itemsStockable = 'items/stockable';
  static const itemsPending = 'items/pending-approvals';
  static String item(String id) => 'items/$id';
  static String itemDeactivate(String id) => 'items/$id/deactivate';
  static String itemApprove(String id) => 'items/$id/approve';
  static String itemReject(String id) => 'items/$id/reject';

  // Warehouses
  static const warehouses = 'warehouses';
  static String warehouse(String id) => 'warehouses/$id';
  static String warehouseDeactivate(String id) => 'warehouses/$id/deactivate';
  static String warehouseActivate(String id) => 'warehouses/$id/activate';

  // Inventory
  static const stock = 'inventory/stock';
  static const ledger = 'inventory/ledger';
  static const lowStock = 'inventory/low-stock';
  static const stockIn = 'inventory/stock-in';
  static const stockOut = 'inventory/stock-out';
  static const stockTransfer = 'inventory/stock-transfer';
  static const stockAdjustment = 'inventory/stock-adjustment';

  // Quotations
  static const quotations = 'quotations';
  static const quotationsInvoiceable = 'quotations/invoiceable';
  static const quotationsPending = 'quotations/pending-approvals';
  static String quotation(String id) => 'quotations/$id';
  static String quotationSubmit(String id) => 'quotations/$id/submit';
  static String quotationApprove(String id) => 'quotations/$id/approve';
  static String quotationReject(String id) => 'quotations/$id/reject';
  static String quotationPdf(String id) => 'quotations/$id/pdf';
  static String quotationEmail(String id) => 'quotations/$id/send-email';

  // Invoices
  static const invoices = 'invoices';
  static const invoicesPending = 'invoices/pending-approvals';
  static const invoiceFromQuotation = 'invoices/from-quotation';
  static String invoice(String id) => 'invoices/$id';
  static String invoiceSubmit(String id) => 'invoices/$id/submit';
  static String invoiceApprove(String id) => 'invoices/$id/approve';
  static String invoiceReject(String id) => 'invoices/$id/reject';
  static String invoiceStockCheck(String id) => 'invoices/$id/stock-check';
  static String invoicePdf(String id) => 'invoices/$id/pdf';
  static String invoiceEmail(String id) => 'invoices/$id/send-email';

  // Solar CRM — leads
  static const leads = 'leads';
  static String lead(String id) => 'leads/$id';
  static String leadAssign(String id) => 'leads/$id/assign';
  static String leadStatus(String id) => 'leads/$id/status';
  static String leadHistory(String id) => 'leads/$id/history';
  static const leadsWorkflowMeta = 'leads/workflow/meta';
  static const leadsTextAll = 'leads/text/all';
  static const usersByRole = 'users/by-role';

  // Solar CRM — installations
  static String installationByLead(String leadId) =>
      'installations/lead/$leadId';
  static String installation(String id) => 'installations/$id';
  static const installations = 'installations';

  // Solar CRM — notifications
  static const myNotifications = 'notifications/my-notifications';
  static const unreadNotificationCount = 'notifications/unread-count';
  static String markNotificationRead(String id) =>
      'notifications/mark-as-read/$id';
  static const markAllNotificationsRead = 'notifications/mark-all-as-read';

  // Profile photo
  static const employeePhoto = 'employee-photo';
  static const employeePhotoUpload = 'employee-photo/photo';
}

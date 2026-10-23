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

  // Staff / Company Admin support (Green Energy)
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

  // Costing
  static const costings = 'costings';
  static String costing(String id) => 'costings/$id';
  static String customerCosting(String customerId) =>
      'costings/customer/$customerId';
  static String customerCostingLines(String customerId) =>
      'costings/customer/$customerId/lines';
  static String leadCosting(String leadId) => 'costings/lead/$leadId';
  static String leadCostingLines(String leadId) =>
      'costings/lead/$leadId/lines';
  static const vendors = 'vendors';
  static String vendor(String id) => 'vendors/$id';
  static String costingVendor(String costingId) =>
      'costings/$costingId/vendor';
  static String costingLine(String costingId, String lineId) =>
      'costings/$costingId/lines/$lineId';
  static String costingClear(String costingId) => 'costings/$costingId/clear';
  static String costingPdf(String costingId) => 'costings/$costingId/pdf';
  static String customerCostingSave(String customerId) =>
      'costings/customer/$customerId/save';
  static String leadCostingSave(String leadId) => 'costings/lead/$leadId/save';

  // BOM (bill of materials) — Billbook only, no prices
  static const boms = 'boms';
  static String bom(String id) => 'boms/$id';
  static String bomSave(String id) => 'boms/$id/save';
  static String bomsByCustomer(String customerId) => 'boms/customer/$customerId';
  static String customerBomSave(String customerId) => 'boms/customer/$customerId/save';
  static String customerBomLines(String customerId) =>
      'boms/customer/$customerId/lines';
  static String bomLine(String bomId, String lineId) =>
      'boms/$bomId/lines/$lineId';
  static String bomClear(String bomId) => 'boms/$bomId/clear';
  static String bomPdf(String bomId) => 'boms/$bomId/pdf';

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

  // Payments / collections (accounts receivable on invoices)
  static const payments = 'payments';
  static const paymentsDashboard = 'payments/dashboard';
  static const paymentSchedules = 'payments/schedules';
  static String paymentSchedule(String id) => 'payments/schedules/$id';
  static String paymentScheduleRemind(String id) =>
      'payments/schedules/$id/remind';
  static String paymentReceipt(String id) => 'payments/$id';

  // WhatsApp share (same routes as the web app)
  static const whatsappCompose = 'whatsapp/compose';
  static const whatsappShare = 'whatsapp/share';
  static const whatsappMessages = 'whatsapp/messages';

  // Solar CRM — leads
  static const leads = 'leads';
  static String lead(String id) => 'leads/$id';
  static String leadAssign(String id) => 'leads/$id/assign';
  static String leadStatus(String id) => 'leads/$id/status';
  static String leadHistory(String id) => 'leads/$id/history';
  static const leadsWorkflowMeta = 'leads/workflow/meta';
  static const leadsTextAll = 'leads/text/all';
  static const users = 'users';
  static const usersByRole = 'users/by-role';

  // Solar CRM — installations
  static String installationByLead(String leadId) =>
      'installations/lead/$leadId';
  static String installationForm(String leadId) =>
      'installations/form/$leadId';
  static String installation(String id) => 'installations/$id';
  static const installations = 'installations';

  // Solar CRM — notifications
  static const myNotifications = 'notifications/my-notifications';
  static const unreadNotificationCount = 'notifications/unread-count';
  static String markNotificationRead(String id) =>
      'notifications/mark-as-read/$id';
  static const markAllNotificationsRead = 'notifications/mark-all-as-read';

  static const marketingTemplates = 'marketing-templates';
  static String marketingTemplate(String id) => 'marketing-templates/$id';
  static String marketingTemplateDownload(String id) =>
      'marketing-templates/$id/download';
  static const employeePhoto = 'employee-photo';
  static const employeePhotoUpload = 'employee-photo/photo';

  // Site survey templates and filled surveys
  static const surveyTemplates = 'survey-templates';
  static String surveyTemplate(String id) => 'survey-templates/$id';
  static String surveyTemplatePublish(String id) => 'survey-templates/$id/publish';
  static String surveyTemplateSetDefault(String id) =>
      'survey-templates/$id/set-default';
  static String surveyTemplateDuplicate(String id) =>
      'survey-templates/$id/duplicate';
  static String surveyTemplateDeactivate(String id) =>
      'survey-templates/$id/deactivate';
  static const surveyTemplateStarter = 'survey-templates/starter';

  static String siteSurveyByLead(String leadId) => 'site-surveys/lead/$leadId';
  static String siteSurvey(String id) => 'site-surveys/$id';
  static String siteSurveyDiscard(String id) => 'site-surveys/$id/discard';
  static String siteSurveyFiles(String id) => 'site-surveys/$id/files';
  static String siteSurveyFile(String id, String fileId) =>
      'site-surveys/$id/files/$fileId';
  static String siteSurveyPdf(String id) => 'site-surveys/$id/pdf';

  // Solar panel catalog (used by 3D solar design module selection)
  static const solarPanels = 'solar-panels';
  static const solarPanelsEnabled = 'solar-panels/enabled';
  static String solarPanel(String id) => 'solar-panels/$id';

  // Solar CRM — task management
  static const solarTasks = 'solar-tasks';
  static const solarTasksMeta = 'solar-tasks/meta';
  static const solarTasksProjects = 'solar-tasks/projects';
  static const solarTasksAssignees = 'solar-tasks/assignees';
  static const solarTasksChecklist = 'solar-tasks/checklist';
  static String solarTask(String id) => 'solar-tasks/$id';
  static String solarTaskStatus(String id) => 'solar-tasks/$id/status';

  // 3D Solar Design (staff + public preview helpers)
  static String solarDesignsForLead(String leadId) =>
      'solar-designs/lead/$leadId';
  static String solarDesignsForCustomer(String customerId) =>
      'solar-designs/customer/$customerId';
  static String solarDesign(String id) => 'solar-designs/$id';
  static String solarDesignShare(String id) => 'solar-designs/$id/share';
  static String solarDesignReport(String id) => 'solar-designs/$id/report';
  static String solarDesignDeactivate(String id) =>
      'solar-designs/$id/deactivate';
  static const solarDesignGeocode = 'solar-designs/geocode';
  static const solarDesignGeocodeSuggest = 'solar-designs/geocode/suggest';
  static const solarDesignGeocodePlace = 'solar-designs/geocode/place';
  static const solarDesignEnergyEstimate = 'solar-designs/energy-estimate';
  static String solarDesignSurroundings(String id) =>
      'solar-designs/$id/surroundings';
  static String publicSolarDesign(String code) =>
      'public/solar-designs/$code';
}

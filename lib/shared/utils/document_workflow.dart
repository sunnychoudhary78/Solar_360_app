/// Business rules aligned with Imt-Billbook web + backend workflows.
/// HR admin (employees, roles, company settings) remains web-only.
class DocumentWorkflow {
  DocumentWorkflow._();

  /// Quotation / invoice list filters used by the React app.
  static const documentStatusFilters = <String>[
    'draft',
    'pending_approval',
    'sent',
    'rejected',
  ];

  /// Item master statuses (procurement approvals).
  static const itemStatusFilters = <String>[
    'pending',
    'approved',
    'rejected',
  ];

  static const inventoryTransTypes = <String>[
    'in',
    'out',
    'transfer',
    'adjustment',
  ];

  /// Draft/rejected: `quotation.create`. Pending: `quotation.approve` only.
  static bool canEditQuotation(
    String status, {
    required bool canCreate,
    required bool canApprove,
  }) {
    if (status == 'draft' || status == 'rejected') return canCreate;
    if (status == 'pending_approval') return canApprove;
    return false;
  }

  static bool canSubmitQuotation(String status) =>
      status == 'draft' || status == 'rejected';

  static bool canApproveOrRejectQuotation(String status) =>
      status == 'pending_approval';

  /// Backend [approveQuotation] sets status to `sent` (not `approved`).
  static bool isQuotationApproved(String status) => status == 'sent';

  /// Web: create invoice only when quotation is `sent` and has no invoice.
  static bool canCreateInvoiceFromQuotation({
    required String status,
    String? invoiceId,
  }) {
    return status == 'sent' && (invoiceId == null || invoiceId.isEmpty);
  }

  static bool canEmailQuotation(String status) => status == 'sent';

  /// PDF available only after approval (`sent`).
  static bool canDownloadQuotation(String status) => status == 'sent';

  /// Draft/rejected: `invoice.create`. Pending: `invoice.approve` only.
  static bool canEditInvoice(
    String status, {
    required bool canCreate,
    required bool canApprove,
    bool stockDeducted = false,
  }) {
    if (stockDeducted) return false;
    if (status == 'draft' || status == 'rejected') return canCreate;
    if (status == 'pending_approval') return canApprove;
    return false;
  }

  static bool canSubmitInvoice(String status) =>
      status == 'draft' || status == 'rejected';

  static bool canApproveOrRejectInvoice(String status) =>
      status == 'pending_approval';

  /// Backend [approveInvoice] sets status to `sent` and deducts stock.
  static bool isInvoiceApproved(String status) => status == 'sent';

  static bool canEmailInvoice(String status) => status == 'sent';

  /// PDF available only after approval (`sent`).
  static bool canDownloadInvoice(String status) => status == 'sent';

  /// Expected status after quotation approve (web/backend parity).
  static const quotationStatusAfterApprove = 'sent';

  /// Expected status after invoice approve (web/backend parity).
  static const invoiceStatusAfterApprove = 'sent';

  static bool canEditItem(String status) => status != 'approved';

  static bool canApproveOrRejectItem(String status) => status == 'pending';

  static bool isItemUsableInQuotations(String status) => status == 'approved';
}

class InventoryPayloads {
  InventoryPayloads._();

  static Map<String, dynamic> stockIn({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
    String? referenceNumber,
  }) =>
      {
        'itemId': itemId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
        if (referenceNumber != null) 'referenceNumber': referenceNumber,
      };

  static Map<String, dynamic> stockOut({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
    String? referenceNumber,
  }) =>
      {
        'itemId': itemId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
        if (referenceNumber != null) 'referenceNumber': referenceNumber,
      };

  static Map<String, dynamic> stockTransfer({
    required String itemId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required int quantity,
    String? notes,
  }) =>
      {
        'itemId': itemId,
        'fromWarehouseId': fromWarehouseId,
        'toWarehouseId': toWarehouseId,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
      };

  /// [quantity] is the absolute target quantity (not a delta).
  static Map<String, dynamic> stockAdjustment({
    required String itemId,
    required String warehouseId,
    required int quantity,
    String? notes,
  }) =>
      {
        'itemId': itemId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
      };
}

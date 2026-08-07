import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/shared/utils/document_workflow.dart';

void main() {
  group('DocumentWorkflow — web parity status filters', () {
    test('quotation/invoice filters match React (no approved chip)', () {
      expect(
        DocumentWorkflow.documentStatusFilters,
        ['draft', 'pending_approval', 'sent', 'rejected'],
      );
      expect(DocumentWorkflow.documentStatusFilters.contains('approved'), isFalse);
    });

    test('item filters match React', () {
      expect(
        DocumentWorkflow.itemStatusFilters,
        ['pending', 'approved', 'rejected'],
      );
    });
  });

  group('Quotation workflow (web)', () {
    test('draft/rejected can edit with create; pending with approve', () {
      expect(
        DocumentWorkflow.canEditQuotation(
          'draft',
          canCreate: true,
          canApprove: false,
        ),
        isTrue,
      );
      expect(DocumentWorkflow.canSubmitQuotation('draft'), isTrue);
      expect(
        DocumentWorkflow.canEditQuotation(
          'rejected',
          canCreate: true,
          canApprove: false,
        ),
        isTrue,
      );
      expect(DocumentWorkflow.canSubmitQuotation('rejected'), isTrue);
      expect(
        DocumentWorkflow.canEditQuotation(
          'pending_approval',
          canCreate: true,
          canApprove: false,
        ),
        isFalse,
      );
      expect(
        DocumentWorkflow.canEditQuotation(
          'pending_approval',
          canCreate: false,
          canApprove: true,
        ),
        isTrue,
      );
      expect(DocumentWorkflow.canSubmitQuotation('sent'), isFalse);
      expect(
        DocumentWorkflow.canEditQuotation(
          'sent',
          canCreate: true,
          canApprove: true,
        ),
        isFalse,
      );
    });

    test('only pending_approval can approve/reject', () {
      expect(DocumentWorkflow.canApproveOrRejectQuotation('pending_approval'), isTrue);
      expect(DocumentWorkflow.canApproveOrRejectQuotation('draft'), isFalse);
      expect(DocumentWorkflow.canApproveOrRejectQuotation('sent'), isFalse);
    });

    test('approve result status is sent (backend parity)', () {
      expect(DocumentWorkflow.quotationStatusAfterApprove, 'sent');
      expect(DocumentWorkflow.isQuotationApproved('sent'), isTrue);
      expect(DocumentWorkflow.isQuotationApproved('approved'), isFalse);
    });

    test('create invoice only when sent and no invoice linked', () {
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: 'sent',
          invoiceId: null,
        ),
        isTrue,
      );
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: 'sent',
          invoiceId: '',
        ),
        isTrue,
      );
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: 'approved',
          invoiceId: null,
        ),
        isFalse,
      );
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: 'sent',
          invoiceId: 'inv-1',
        ),
        isFalse,
      );
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: 'pending_approval',
          invoiceId: null,
        ),
        isFalse,
      );
    });

    test('email and PDF only when sent', () {
      expect(DocumentWorkflow.canEmailQuotation('sent'), isTrue);
      expect(DocumentWorkflow.canEmailQuotation('draft'), isFalse);
      expect(DocumentWorkflow.canDownloadQuotation('sent'), isTrue);
      expect(DocumentWorkflow.canDownloadQuotation('pending_approval'), isFalse);
      expect(DocumentWorkflow.canDownloadQuotation('draft'), isFalse);
    });
  });

  group('Invoice workflow (web)', () {
    test('draft/rejected can submit; pending edit for approvers', () {
      expect(DocumentWorkflow.canSubmitInvoice('draft'), isTrue);
      expect(DocumentWorkflow.canSubmitInvoice('rejected'), isTrue);
      expect(DocumentWorkflow.canSubmitInvoice('pending_approval'), isFalse);
      expect(
        DocumentWorkflow.canEditInvoice(
          'pending_approval',
          canCreate: false,
          canApprove: true,
        ),
        isTrue,
      );
      expect(
        DocumentWorkflow.canEditInvoice(
          'pending_approval',
          canCreate: true,
          canApprove: false,
        ),
        isFalse,
      );
      expect(
        DocumentWorkflow.canEditInvoice(
          'draft',
          canCreate: true,
          canApprove: false,
          stockDeducted: true,
        ),
        isFalse,
      );
    });

    test('only pending_approval can approve/reject', () {
      expect(DocumentWorkflow.canApproveOrRejectInvoice('pending_approval'), isTrue);
      expect(DocumentWorkflow.canApproveOrRejectInvoice('sent'), isFalse);
    });

    test('approve result status is sent and stock deducted', () {
      expect(DocumentWorkflow.invoiceStatusAfterApprove, 'sent');
      expect(DocumentWorkflow.isInvoiceApproved('sent'), isTrue);
      expect(DocumentWorkflow.isInvoiceApproved('approved'), isFalse);
    });

    test('email and PDF only when sent', () {
      expect(DocumentWorkflow.canEmailInvoice('sent'), isTrue);
      expect(DocumentWorkflow.canEmailInvoice('draft'), isFalse);
      expect(DocumentWorkflow.canDownloadInvoice('sent'), isTrue);
      expect(DocumentWorkflow.canDownloadInvoice('pending_approval'), isFalse);
    });
  });

  group('Item approval workflow (web)', () {
    test('pending can approve/reject; approved cannot edit', () {
      expect(DocumentWorkflow.canApproveOrRejectItem('pending'), isTrue);
      expect(DocumentWorkflow.canEditItem('pending'), isTrue);
      expect(DocumentWorkflow.canEditItem('approved'), isFalse);
      expect(DocumentWorkflow.isItemUsableInQuotations('approved'), isTrue);
      expect(DocumentWorkflow.isItemUsableInQuotations('pending'), isFalse);
    });
  });

  group('End-to-end status chain (web)', () {
    test('quotation: draft → pending_approval → sent → invoiceable', () {
      var status = 'draft';
      expect(DocumentWorkflow.canSubmitQuotation(status), isTrue);

      status = 'pending_approval';
      expect(DocumentWorkflow.canApproveOrRejectQuotation(status), isTrue);

      status = DocumentWorkflow.quotationStatusAfterApprove;
      expect(status, 'sent');
      expect(
        DocumentWorkflow.canCreateInvoiceFromQuotation(
          status: status,
          invoiceId: null,
        ),
        isTrue,
      );
    });

    test('invoice: draft → pending_approval → sent (stock deducted)', () {
      var status = 'draft';
      expect(DocumentWorkflow.canSubmitInvoice(status), isTrue);

      status = 'pending_approval';
      expect(DocumentWorkflow.canApproveOrRejectInvoice(status), isTrue);

      status = DocumentWorkflow.invoiceStatusAfterApprove;
      expect(status, 'sent');
      expect(DocumentWorkflow.canEmailInvoice(status), isTrue);
    });
  });
}

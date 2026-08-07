/// Common payment modes for invoices (web [PAYMENT_MODES] parity).
class PaymentModes {
  PaymentModes._();

  static const values = [
    'Cash',
    'Cheque',
    'UPI',
    'NEFT/RTGS',
    'Card',
    'Credit',
    'Bank Transfer',
    'Other',
  ];
}

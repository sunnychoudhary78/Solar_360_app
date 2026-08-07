// Split combined GST into CGST + SGST for intra-state display (web gstBreakdown.js parity).

class GstBreakdown {
  final double cgstAmount;
  final double sgstAmount;
  final double cgstRate;
  final double sgstRate;
  final double gstAmount;
  final double gstRate;

  const GstBreakdown({
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.cgstRate = 0,
    this.sgstRate = 0,
    this.gstAmount = 0,
    this.gstRate = 0,
  });
}

GstBreakdown splitCgstSgst(num gstAmount, num subtotal) {
  final gst = gstAmount.toDouble();
  final sub = subtotal.toDouble();
  final totalRate =
      sub > 0 ? ((gst / sub) * 10000).roundToDouble() / 100 : 0.0;
  final halfRate =
      totalRate > 0 ? ((totalRate / 2) * 100).roundToDouble() / 100 : 0.0;

  double cgstAmount = 0;
  double sgstAmount = 0;

  if (sub > 0 && halfRate > 0) {
    cgstAmount = ((sub * halfRate / 100) * 100).roundToDouble() / 100;
    sgstAmount = cgstAmount;
  } else if (gst > 0) {
    cgstAmount = ((gst / 2) * 100).roundToDouble() / 100;
    sgstAmount = cgstAmount;
  }

  return GstBreakdown(
    cgstAmount: cgstAmount,
    sgstAmount: sgstAmount,
    cgstRate: halfRate,
    sgstRate: halfRate,
    gstAmount: gst,
    gstRate: totalRate,
  );
}

double getLineGstAmount({
  double? gstAmount,
  required int quantity,
  required double unitPrice,
  required double gstPercent,
}) {
  if (gstAmount != null) return gstAmount;
  // Backend calcLine: half-rate CGST + SGST, then sum (avoids 1-paisa drift).
  final subtotal = quantity * unitPrice;
  final halfRate = gstPercent / 2;
  final halfTax =
      ((subtotal * halfRate / 100) * 100).roundToDouble() / 100;
  return ((halfTax * 2) * 100).roundToDouble() / 100;
}

double getLineGstPercent({
  double? gstPercent,
  required int quantity,
  required double unitPrice,
  double? gstAmount,
}) {
  if (gstPercent != null) return gstPercent;
  final subtotal = quantity * unitPrice;
  if (subtotal <= 0) return 0;
  final gst = getLineGstAmount(
    gstAmount: gstAmount,
    quantity: quantity,
    unitPrice: unitPrice,
    gstPercent: 0,
  );
  return ((gst / subtotal) * 10000).roundToDouble() / 100;
}

GstBreakdown splitLineCgstSgst({
  required int quantity,
  required double unitPrice,
  double? gstPercent,
  double? gstAmount,
}) {
  final subtotal = ((quantity * unitPrice) * 100).roundToDouble() / 100;
  final pct = getLineGstPercent(
    gstPercent: gstPercent,
    quantity: quantity,
    unitPrice: unitPrice,
    gstAmount: gstAmount,
  );
  final halfRate = pct > 0 ? ((pct / 2) * 100).roundToDouble() / 100 : 0.0;
  final result = splitCgstSgst(
    getLineGstAmount(
      gstAmount: gstAmount,
      quantity: quantity,
      unitPrice: unitPrice,
      gstPercent: pct,
    ),
    subtotal,
  );
  return GstBreakdown(
    cgstAmount: result.cgstAmount,
    sgstAmount: result.sgstAmount,
    cgstRate: halfRate > 0 ? halfRate : result.cgstRate,
    sgstRate: halfRate > 0 ? halfRate : result.sgstRate,
    gstAmount: result.gstAmount,
    gstRate: pct > 0 ? pct : result.gstRate,
  );
}

/// Document-level totals from line items.
class DocumentTotals {
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final GstBreakdown breakdown;

  const DocumentTotals({
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.breakdown,
  });
}

DocumentTotals calcDocumentTotals(List<LineTotalsInput> lines) {
  var subtotal = 0.0;
  var gstAmount = 0.0;
  for (final line in lines) {
    if (line.quantity <= 0 || line.unitPrice < 0) continue;
    final lineSub = line.quantity * line.unitPrice;
    final lineGst = getLineGstAmount(
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      gstPercent: line.gstPercent,
    );
    subtotal += lineSub;
    gstAmount += lineGst;
  }
  subtotal = (subtotal * 100).roundToDouble() / 100;
  gstAmount = (gstAmount * 100).roundToDouble() / 100;
  final totalAmount = ((subtotal + gstAmount) * 100).roundToDouble() / 100;
  return DocumentTotals(
    subtotal: subtotal,
    gstAmount: gstAmount,
    totalAmount: totalAmount,
    breakdown: splitCgstSgst(gstAmount, subtotal),
  );
}

class LineTotalsInput {
  final int quantity;
  final double unitPrice;
  final double gstPercent;

  const LineTotalsInput({
    required this.quantity,
    required this.unitPrice,
    required this.gstPercent,
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/finance/data/emi_calculator.dart';

void main() {
  final start = DateTime(2026, 10, 1);

  test('Example A — EMI ₹1L / 6 months / 7.99%', () {
    final result = buildSchedule(
      principal: 100000,
      annualPercent: 7.99,
      months: 6,
      scheme: EmiScheme.emi,
      startDate: start,
    );

    expect(result.emi, 17057.22);
    expect(result.totalInterest, 2343.30);
    expect(result.totalPayment, 102343.30);
    expect(result.rows, hasLength(6));

    expect(result.rows[0].principal, 16391.39);
    expect(result.rows[0].interest, 665.83);
    expect(result.rows[0].payment, 17057.22);
    expect(result.rows[0].balance, 83608.61);
    expect(result.rows[0].label, 'Oct 2026');

    expect(result.rows[5].principal, 16944.38);
    expect(result.rows[5].interest, 112.82);
    expect(result.rows[5].payment, 17057.20);
    expect(result.rows[5].balance, 0.00);

    // Exact schedule: principals sum to loan; interest sum = totalInterest;
    // each row principal + interest = payment.
    final principalSum = round2(
      result.rows.fold<double>(0, (s, r) => s + r.principal),
    );
    final interestSum = round2(
      result.rows.fold<double>(0, (s, r) => s + r.interest),
    );
    final paymentSum = round2(
      result.rows.fold<double>(0, (s, r) => s + r.payment),
    );
    expect(principalSum, result.principal);
    expect(interestSum, result.totalInterest);
    expect(paymentSum, result.totalPayment);
    for (final row in result.rows) {
      expect(round2(row.principal + row.interest), row.payment);
    }
    // Whole-rupee display: 17,057×6 = 1,02,342 ≠ total repayment 1,02,343.
    final wholeRupeePrincipals = result.rows
        .map((r) => r.principal.round())
        .fold<int>(0, (s, v) => s + v);
    final wholeRupeeInterest = result.rows
        .map((r) => r.interest.round())
        .fold<int>(0, (s, v) => s + v);
    final wholeRupeePayments = result.rows
        .map((r) => r.payment.round())
        .fold<int>(0, (s, v) => s + v);
    expect(wholeRupeePrincipals, isNot(result.principal.round()));
    expect(wholeRupeeInterest, isNot(result.totalInterest.round()));
    expect(wholeRupeePayments, isNot(result.totalPayment.round()));

    expect(formatEmiScheduleInr(result.emi), '₹17,057.22');
    expect(formatEmiScheduleInr(result.totalPayment), '₹1,02,343.30');
  });

  test('Example B — EMI ₹1L / 12 months / 7.99%', () {
    final result = buildSchedule(
      principal: 100000,
      annualPercent: 7.99,
      months: 12,
      scheme: EmiScheme.emi,
      startDate: start,
    );

    expect(result.emi, 8698.38);
    expect(result.totalInterest, 4380.55);
    expect(result.totalPayment, 104380.55);
    expect(result.rows.first.principal, 8032.55);
    expect(result.rows.first.interest, 665.83);
    expect(result.rows.first.payment, 8698.38);
    expect(result.rows.first.balance, 91967.45);
    expect(result.rows.last.principal, 8640.84);
    expect(result.rows.last.interest, 57.53);
    expect(result.rows.last.payment, 8698.37);
    expect(result.rows.last.balance, 0.00);
  });

  test('Example C — Advance EMI ₹1L / 6 months (0%)', () {
    final result = buildSchedule(
      principal: 100000,
      annualPercent: 0,
      months: 6,
      scheme: EmiScheme.advanceEmi,
      startDate: start,
    );

    expect(result.emi, 16666.67);
    expect(result.totalInterest, 0);
    expect(result.totalPayment, 100000);
    expect(result.rows.last.payment, 16666.65);
  });

  test('Example D — Advance EMI ₹1L / 12 months / 7.99% after teaser', () {
    final result = buildSchedule(
      principal: 100000,
      annualPercent: 7.99,
      months: 12,
      scheme: EmiScheme.advanceEmi,
      startDate: start,
    );

    expect(result.emi, 8333.33);
    expect(result.rows[0].payment, 8333.33);
    expect(result.rows[0].interest, 0);
    expect(result.rows[5].balance, 50000.02);
    expect(result.rows[6].payment, 8528.61);
    expect(result.totalInterest, 1171.66);
    expect(result.totalPayment, 101171.66);
  });
}

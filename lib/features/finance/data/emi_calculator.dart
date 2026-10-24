import 'package:intl/intl.dart';

/// Reducing-balance EMI and Advance EMI (0% teaser for first 6 months).
/// Port of `Imt_Billbook_frontend/src/lib/emi.js` — keep math identical.

const double kEmiMinAmount = 50000;
const double kEmiMaxAmount = 10000000;
const int kEmiMinMonths = 6;
const int kEmiMaxMonths = 60;
const double kDefaultInterestRate = 7.99;
const int kAdvanceZeroMonths = 6;

const List<({String label, double value})> kAmountPresets = [
  (label: '50K', value: 50000),
  (label: '1L', value: 100000),
  (label: '10L', value: 1000000),
  (label: '25L', value: 2500000),
  (label: '50L', value: 5000000),
  (label: '75L', value: 7500000),
  (label: '1Cr', value: 10000000),
];

const List<({String label, int value})> kTenurePresets = [
  (label: '6M', value: 6),
  (label: '1Y', value: 12),
  (label: '2Y', value: 24),
  (label: '3Y', value: 36),
  (label: '4Y', value: 48),
  (label: '5Y', value: 60),
];

const List<String> kFinanceSegments = [
  'Residential',
  'Commercial',
  'Housing Society',
];

enum EmiScheme { emi, advanceEmi }

extension EmiSchemeX on EmiScheme {
  String get apiValue => this == EmiScheme.advanceEmi ? 'advance_emi' : 'emi';

  String get caption =>
      this == EmiScheme.advanceEmi ? 'Advance EMI' : 'Reducing-balance EMI';
}

double clampNum(num n, num min, num max) {
  final v = n.toDouble();
  if (v.isNaN || v.isInfinite) return min.toDouble();
  if (v < min) return min.toDouble();
  if (v > max) return max.toDouble();
  return v;
}

/// Matches JS: `Math.round((n + Number.EPSILON) * 100) / 100`
double round2(num n) {
  const epsilon = 2.220446049250313e-16;
  return (((n.toDouble() + epsilon) * 100).round()) / 100;
}

double monthlyRate(num annualPercent) {
  final rate = annualPercent.toDouble();
  if (rate.isNaN || rate.isInfinite || rate <= 0) return 0;
  return rate / 12 / 100;
}

double reducingEmi(num principal, num annualPercent, int months) {
  final p = principal.toDouble();
  final n = months < 1 ? 1 : months;
  if (p.isNaN || p.isInfinite || p <= 0) return 0;
  final r = monthlyRate(annualPercent);
  if (r == 0) return p / n;
  final pow = _pow(1 + r, n);
  return (p * r * pow) / (pow - 1);
}

double _pow(double base, int exp) {
  var result = 1.0;
  for (var i = 0; i < exp; i++) {
    result *= base;
  }
  return result;
}

class EmiScheduleRow {
  const EmiScheduleRow({
    required this.month,
    required this.date,
    required this.label,
    required this.year,
    required this.yearKey,
    required this.principal,
    required this.interest,
    required this.payment,
    required this.balance,
  });

  final int month;
  final DateTime date;
  final String label;
  final int year;
  final String yearKey;
  final double principal;
  final double interest;
  final double payment;
  final double balance;
}

class EmiYearGroup {
  EmiYearGroup({
    required this.key,
    required this.year,
    this.principal = 0,
    this.interest = 0,
    this.payment = 0,
    List<EmiScheduleRow>? months,
  }) : months = months ?? <EmiScheduleRow>[];

  final String key;
  final int year;
  double principal;
  double interest;
  double payment;
  final List<EmiScheduleRow> months;
}

class EmiScheduleResult {
  const EmiScheduleResult({
    required this.principal,
    required this.months,
    required this.annualPercent,
    required this.scheme,
    required this.emi,
    required this.totalInterest,
    required this.totalPayment,
    required this.rows,
    required this.years,
  });

  final double principal;
  final int months;
  final double annualPercent;
  final EmiScheme scheme;
  final double emi;
  final double totalInterest;
  final double totalPayment;
  final List<EmiScheduleRow> rows;
  final List<EmiYearGroup> years;
}

EmiScheduleResult buildSchedule({
  required num principal,
  required num annualPercent,
  required int months,
  EmiScheme scheme = EmiScheme.emi,
  DateTime? startDate,
}) {
  final p = round2(clampNum(principal, 0, kEmiMaxAmount));
  final n = clampNum(months, 1, kEmiMaxMonths).round();
  final start = startDate ?? DateTime.now();
  final rows = <EmiScheduleRow>[];
  var balance = p;

  if (scheme == EmiScheme.advanceEmi) {
    final zeroMonths = n < kAdvanceZeroMonths ? n : kAdvanceZeroMonths;
    final advanceInstalment = zeroMonths > 0 ? round2(p / n) : 0.0;

    for (var i = 1; i <= zeroMonths; i++) {
      final principalPart = (i == zeroMonths && n == zeroMonths)
          ? round2(balance)
          : (advanceInstalment < round2(balance)
              ? round2(advanceInstalment)
              : round2(balance));
      const interest = 0.0;
      final payment = round2(principalPart + interest);
      balance = round2(balance - principalPart < 0 ? 0 : balance - principalPart);
      rows.add(_makeRow(i, start, principalPart, interest, payment, balance));
    }

    final remainingMonths = n - zeroMonths;
    if (remainingMonths > 0 && balance > 0) {
      final emi = reducingEmi(balance, annualPercent, remainingMonths);
      _appendReducingRows(
        rows: rows,
        startIndex: zeroMonths + 1,
        months: remainingMonths,
        annualPercent: annualPercent,
        emi: emi,
        start: start,
        getBalance: () => balance,
        setBalance: (next) => balance = next,
      );
    }
  } else {
    final emi = reducingEmi(p, annualPercent, n);
    _appendReducingRows(
      rows: rows,
      startIndex: 1,
      months: n,
      annualPercent: annualPercent,
      emi: emi,
      start: start,
      getBalance: () => balance,
      setBalance: (next) => balance = next,
    );
  }

  final totalInterest = round2(rows.fold<double>(0, (s, r) => s + r.interest));
  final totalPayment = round2(rows.fold<double>(0, (s, r) => s + r.payment));
  final emiAmount = rows.isEmpty ? 0.0 : rows.first.payment;

  return EmiScheduleResult(
    principal: p,
    months: n,
    annualPercent: annualPercent.toDouble().isNaN ? 0 : annualPercent.toDouble(),
    scheme: scheme,
    emi: round2(emiAmount),
    totalInterest: totalInterest,
    totalPayment: totalPayment,
    rows: rows,
    years: _groupByYear(rows),
  );
}

void _appendReducingRows({
  required List<EmiScheduleRow> rows,
  required int startIndex,
  required int months,
  required num annualPercent,
  required double emi,
  required DateTime start,
  required double Function() getBalance,
  required void Function(double) setBalance,
}) {
  final r = monthlyRate(annualPercent);
  for (var i = 0; i < months; i++) {
    final monthNo = startIndex + i;
    var balance = getBalance();
    final interest = round2(balance * r);
    var principalPart = round2(emi - interest);
    if (i == months - 1 || principalPart > balance) {
      principalPart = round2(balance);
    }
    final payment = round2(principalPart + interest);
    balance = round2(balance - principalPart < 0 ? 0 : balance - principalPart);
    setBalance(balance);
    rows.add(_makeRow(monthNo, start, principalPart, interest, payment, balance));
  }
}

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthLabel(DateTime date) =>
    '${_monthShort[date.month - 1]} ${date.year}';

EmiScheduleRow _makeRow(
  int monthNo,
  DateTime start,
  double principal,
  double interest,
  double payment,
  double balance,
) {
  final date = DateTime(start.year, start.month + (monthNo - 1), 1);
  return EmiScheduleRow(
    month: monthNo,
    date: date,
    label: _monthLabel(date),
    year: date.year,
    yearKey: 'Year ${(monthNo / 12).ceil()}',
    principal: round2(principal),
    interest: round2(interest),
    payment: round2(payment),
    balance: round2(balance),
  );
}

List<EmiYearGroup> _groupByYear(List<EmiScheduleRow> rows) {
  final map = <String, EmiYearGroup>{};
  for (final row in rows) {
    final prev = map.putIfAbsent(
      row.yearKey,
      () => EmiYearGroup(key: row.yearKey, year: row.year),
    );
    prev.principal = round2(prev.principal + row.principal);
    prev.interest = round2(prev.interest + row.interest);
    prev.payment = round2(prev.payment + row.payment);
    prev.months.add(row);
  }
  return map.values.toList();
}

String formatEmiInr(num? value, {int decimals = 0}) {
  final n = value?.toDouble() ?? 0;
  final fmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals,
  );
  return fmt.format(n);
}

String formatTenure(int months) {
  if (months < 12) return '$months month${months == 1 ? '' : 's'}';
  final years = months / 12;
  final whole = years == years.roundToDouble()
      ? years.round()
      : double.parse(years.toStringAsFixed(1));
  return '$whole year${whole == 1 ? '' : 's'}';
}

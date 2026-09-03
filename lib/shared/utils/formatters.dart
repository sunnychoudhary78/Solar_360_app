import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

String formatInr(num? value) => _inr.format(value ?? 0);

String formatDate(DateTime? value) {
  if (value == null) return '—';
  return _date.format(value.toLocal());
}

String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return _dateTime.format(value.toLocal());
}

/// Compact datetime for conversation bubbles (local device timezone).
String formatDateTimeShort(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('dd MMM, hh:mm a').format(value.toLocal());
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is num) {
    final n = value.toInt();
    // Heuristic: 10-digit values are seconds; larger are milliseconds.
    final ms = n > 9999999999 ? n : n * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  var text = value.toString().trim();
  if (text.isEmpty) return null;

  // MySQL / Sequelize often emit "yyyy-MM-dd HH:mm:ss(.SSS)" without a `T`.
  if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}').hasMatch(text)) {
    text = text.replaceFirst(' ', 'T');
  }

  final parsed = DateTime.tryParse(text);
  // UTC (…Z / offset) → device local; already-local values stay unchanged.
  return parsed?.toLocal();
}

String cleanError(Object e) {
  return e.toString().replaceFirst('Exception: ', '').trim();
}

num? asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

int asInt(dynamic value, [int fallback = 0]) {
  return asNum(value)?.toInt() ?? fallback;
}

double asDouble(dynamic value, [double fallback = 0]) {
  return asNum(value)?.toDouble() ?? fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString().toLowerCase() == 'true';
}

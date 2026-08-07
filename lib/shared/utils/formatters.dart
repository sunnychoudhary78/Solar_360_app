import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _date = DateFormat('dd MMM yyyy');
final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

String formatInr(num? value) => _inr.format(value ?? 0);

String formatDate(DateTime? value) {
  if (value == null) return '—';
  return _date.format(value);
}

String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  return _dateTime.format(value);
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
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

import 'package:solar_sales/shared/utils/formatters.dart';

/// `due_date` is a plain `YYYY-MM-DD` string (no timezone) — never parse it as
/// UTC, otherwise the local calendar day can shift.

DateTime? parseDueDate(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (match == null) return parseDate(raw);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String formatDueDateYmd(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

String dueDateLabel(String? value) => formatDate(parseDueDate(value));

/// Today in the device calendar — the API already sets `is_overdue`/`status`,
/// this is only for display (parity with web IST comparison).
DateTime todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String paymentModeLabel(String? mode) {
  final value = mode?.trim() ?? '';
  return value.isEmpty ? '—' : value;
}

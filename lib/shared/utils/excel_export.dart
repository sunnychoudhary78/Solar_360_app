import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'package:solar_sales/core/utils/file_download.dart';

class ExcelSheetData {
  const ExcelSheetData({
    required this.name,
    required this.rows,
  });

  final String name;
  final List<Map<String, Object?>> rows;
}

String excelDateStamp([DateTime? date]) {
  final d = date ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String excelFileName(String prefix, [DateTime? date]) {
  final base = prefix.endsWith('.xlsx')
      ? prefix.substring(0, prefix.length - 5)
      : prefix;
  return '${base}_${excelDateStamp(date)}.xlsx';
}

String _safeSheetName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/?*\[\]]'), ' ').trim();
  if (cleaned.isEmpty) return 'Sheet';
  return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
}

CellValue _cellFor(Object? value) {
  if (value == null) return TextCellValue('');
  if (value is bool) return BoolCellValue(value);
  if (value is int) return IntCellValue(value);
  if (value is double) {
    if (value.isNaN || value.isInfinite) return TextCellValue('');
    return DoubleCellValue(value);
  }
  if (value is num) return DoubleCellValue(value.toDouble());
  if (value is DateTime) {
    return DateTimeCellValue(
      year: value.year,
      month: value.month,
      day: value.day,
      hour: value.hour,
      minute: value.minute,
      second: value.second,
    );
  }
  return TextCellValue(value.toString());
}

Uint8List encodeExcelWorkbook(List<ExcelSheetData> sheets) {
  final usable = sheets
      .where((sheet) => sheet.rows.isNotEmpty)
      .toList(growable: false);
  if (usable.isEmpty) {
    throw Exception('No data to download for this section');
  }

  final excel = Excel.createExcel();
  final defaultName = excel.getDefaultSheet() ?? 'Sheet1';

  for (var i = 0; i < usable.length; i++) {
    final spec = usable[i];
    final name = _safeSheetName(spec.name);
    if (i == 0 && name != defaultName) {
      excel.rename(defaultName, name);
    }
    final sheet = excel[name];
    final headers = spec.rows.first.keys.toList(growable: false);
    sheet.appendRow(headers.map(_cellFor).toList(growable: false));
    for (final row in spec.rows) {
      sheet.appendRow(
        headers.map((key) => _cellFor(row[key])).toList(growable: false),
      );
    }
    for (var c = 0; c < headers.length; c++) {
      final header = headers[c].toString();
      final width = (header.length + 4).clamp(12, 36).toDouble();
      sheet.setColumnWidth(c, width);
    }
  }

  if (excel.sheets.containsKey(defaultName) &&
      usable.every((s) => _safeSheetName(s.name) != defaultName)) {
    excel.delete(defaultName);
  }

  final bytes = excel.encode();
  if (bytes == null || bytes.isEmpty) {
    throw Exception('Failed to generate Excel');
  }
  return Uint8List.fromList(bytes);
}

Future<String> downloadExcelWorkbook({
  required List<ExcelSheetData> sheets,
  required String filename,
  bool openAfterSave = true,
}) async {
  final bytes = encodeExcelWorkbook(sheets);
  return saveBytesAsDownload(
    bytes: bytes,
    fileName: filename.endsWith('.xlsx') ? filename : '$filename.xlsx',
    openAfterSave: openAfterSave,
  );
}

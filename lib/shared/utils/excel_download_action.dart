import 'package:flutter/material.dart';

import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/excel_export.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

Future<void> runExcelDownload({
  required BuildContext context,
  required List<ExcelSheetData> sheets,
  required String filePrefix,
}) async {
  try {
    await downloadExcelWorkbook(
      sheets: sheets,
      filename: excelFileName(filePrefix),
    );
    if (!context.mounted) return;
    showAppSnackBar(context, 'Excel downloaded');
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(context, cleanError(e), isError: true);
  }
}

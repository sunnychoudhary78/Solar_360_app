import 'package:flutter/material.dart';

import 'package:solar_sales/app/navigator.dart';

/// Shows a floating snackbar using the root navigator context when possible.
/// Never throws — avoids red-screen crashes after successful actions that
/// already popped the current route.
void showAppMessage(
  BuildContext? context,
  String message, {
  bool isError = false,
}) {
  void present(BuildContext ctx) {
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.paddingOf(ctx).top + 12,
          left: 16,
          right: 16,
        ),
        backgroundColor:
            isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  try {
    final rootContext = navigatorKey.currentContext;
    if (rootContext != null && rootContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!rootContext.mounted) return;
        try {
          present(rootContext);
        } catch (_) {}
      });
      return;
    }

    if (context != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        try {
          present(context);
        } catch (_) {}
      });
    }
  } catch (_) {
    // Swallow — caller already completed the real action successfully.
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/validators.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showReasonSheet(
  BuildContext context, {
  required String title,
  String hint = 'Enter reason',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ReasonSheetBody(title: title, hint: hint),
  );
}

class _ReasonSheetBody extends StatefulWidget {
  final String title;
  final String hint;

  const _ReasonSheetBody({required this.title, required this.hint});

  @override
  State<_ReasonSheetBody> createState() => _ReasonSheetBodyState();
}

class _ReasonSheetBodyState extends State<_ReasonSheetBody> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.sm,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please provide a clear reason for this action.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  labelText: 'Reason',
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                validator: (v) => AppValidators.maxLength(
                  v,
                  max: 500,
                  min: 5,
                  field: 'Reason',
                  required: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  Navigator.pop(context, _controller.text.trim());
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blocking dialog when no active warehouses exist for approve / stock moves.
/// Returns `true` if user chose "Open Warehouses".
Future<bool> showWarehouseUnavailableDialog(
  BuildContext context, {
  String message =
      'No active warehouses are available. Create or activate a warehouse before continuing.',
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('No warehouse available'),
      content: Text(
        message,
        style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('OK'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Open Warehouses'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    await Navigator.pushNamed(context, '/inventory/warehouses');
  }
  return result == true;
}

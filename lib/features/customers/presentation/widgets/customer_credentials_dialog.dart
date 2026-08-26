import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';

Future<void> showCustomerCredentialsDialog(
  BuildContext context, {
  required LoginCredentials credentials,
  String title = 'Customer login created',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CustomerCredentialsDialog(
      credentials: credentials,
      title: title,
    ),
  );
}

class CustomerCredentialsDialog extends StatefulWidget {
  final LoginCredentials credentials;
  final String title;

  const CustomerCredentialsDialog({
    super.key,
    required this.credentials,
    this.title = 'Customer login created',
  });

  @override
  State<CustomerCredentialsDialog> createState() =>
      _CustomerCredentialsDialogState();
}

class _CustomerCredentialsDialogState extends State<CustomerCredentialsDialog> {
  bool _showPassword = false;
  String _copied = '';

  Future<void> _copy(String value, String key) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copied = key);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _copied == key) setState(() => _copied = '');
    });
  }

  Future<void> _share() async {
    final email = widget.credentials.email;
    final password = widget.credentials.password;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Solar 360 customer login\nEmail: $email\nTemporary password: $password',
        subject: 'Solar 360 login credentials',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final credentials = widget.credentials;

    return AlertDialog(
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.key_rounded, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.title, textAlign: TextAlign.center),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save these credentials and share them securely with the customer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CredentialRow(
            label: 'Login email',
            value: credentials.email,
            copied: _copied == 'email',
            onCopy: () => _copy(credentials.email, 'email'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CredentialRow(
            label: 'Temporary password',
            value: _showPassword ? credentials.password : '••••••••••••',
            copied: _copied == 'password',
            onCopy: () => _copy(credentials.password, 'password'),
            trailing: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'This is a temporary password. Ask the customer to change it after the first login.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: _share,
          child: const Text('Share'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copied;
  final VoidCallback onCopy;
  final Widget? trailing;

  const _CredentialRow({
    required this.label,
    required this.value,
    required this.copied,
    required this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            ?trailing,
            IconButton(
              tooltip: copied ? 'Copied' : 'Copy',
              onPressed: onCopy,
              icon: Icon(
                copied ? Icons.check_rounded : Icons.copy_outlined,
                color: copied ? scheme.primary : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

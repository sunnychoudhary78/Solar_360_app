import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import '../../data/models/whatsapp_models.dart';
import '../providers/whatsapp_providers.dart';

/// Same flow as the web share dialog: compose on the server, log via share,
/// then open the returned wa.me link so the user presses Send in WhatsApp.
Future<void> showWhatsAppShareDialog(
  BuildContext context, {
  required String entityType,
  required String entityId,
  String title = 'Send on WhatsApp',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => WhatsAppShareDialog(
      entityType: entityType,
      entityId: entityId,
      title: title,
    ),
  );
}

class WhatsAppShareDialog extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  final String title;

  const WhatsAppShareDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.title,
  });

  @override
  ConsumerState<WhatsAppShareDialog> createState() =>
      _WhatsAppShareDialogState();
}

class _WhatsAppShareDialogState extends ConsumerState<WhatsAppShareDialog> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  List<WhatsappTemplate> _templates = const [];
  String _templateKey = '';
  String _recipientName = '';
  bool _loading = true;
  bool _sending = false;
  String? _phoneError;
  String? _messageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load({String? templateKey, bool keepPhone = false}) async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(whatsappRepositoryProvider).compose(
            entityType: widget.entityType,
            entityId: widget.entityId,
            templateKey: templateKey,
          );
      if (!mounted) return;
      setState(() {
        _templates = result.templates;
        _templateKey = result.templateKey;
        _recipientName = result.recipientName;
        _messageController.text = result.message;
        if (!keepPhone) _phoneController.text = result.phone;
        _phoneError = null;
        _messageError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _send() async {
    final phone = _phoneController.text;
    final message = _messageController.text;
    String? phoneError;
    String? messageError;
    if (!isValidWhatsAppNumber(phone)) {
      phoneError = 'Enter a valid mobile number (10 digits or with country code)';
    }
    if (message.trim().isEmpty) {
      messageError = 'Message is required';
    } else if (message.length > whatsappMessageMaxLength) {
      messageError =
          'Message is too long (max $whatsappMessageMaxLength characters)';
    }
    setState(() {
      _phoneError = phoneError;
      _messageError = messageError;
    });
    if (phoneError != null || messageError != null) return;

    setState(() => _sending = true);
    late final String url;
    try {
      final result = await ref.read(whatsappRepositoryProvider).share(
            entityType: widget.entityType,
            entityId: widget.entityId,
            templateKey: _templateKey,
            phone: phone,
            message: message,
          );
      url = result.url;
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(context, cleanError(e), isError: true);
      return;
    }

    if (!mounted) return;
    ref.invalidate(
      whatsappMessagesProvider(
        WhatsappEntityKey(
          entityType: widget.entityType,
          entityId: widget.entityId,
        ),
      ),
    );

    var opened = false;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'WhatsApp opened — press Send in WhatsApp to deliver the message'
              : 'Could not open WhatsApp',
        ),
        backgroundColor: opened ? null : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final greeting = _recipientName.trim().isEmpty
        ? ''
        : 'To $_recipientName. ';

    return PopScope(
      canPop: !_sending,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.chat_rounded,
                          color: Color(whatsappGreen),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${greeting}WhatsApp will open with this message ready — review it there and press Send.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('Preparing message…')),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_templates.length > 1) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final template in _templates)
                                      ChoiceChip(
                                        label: Text(template.label),
                                        selected: template.key == _templateKey,
                                        onSelected: _sending
                                            ? null
                                            : (selected) {
                                                if (!selected ||
                                                    template.key ==
                                                        _templateKey) {
                                                  return;
                                                }
                                                _load(
                                                  templateKey: template.key,
                                                  keepPhone: true,
                                                );
                                              },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enabled: !_sending,
                                decoration: InputDecoration(
                                  labelText: 'WhatsApp number',
                                  hintText: '98765 43210',
                                  errorText: _phoneError,
                                  helperText:
                                      '10-digit numbers are sent as India (+91).',
                                ),
                                onChanged: (_) {
                                  if (_phoneError != null) {
                                    setState(() => _phoneError = null);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _messageController,
                                enabled: !_sending,
                                minLines: 6,
                                maxLines: 10,
                                decoration: InputDecoration(
                                  labelText: 'Message',
                                  alignLabelWithHint: true,
                                  errorText: _messageError,
                                ),
                                onChanged: (_) => setState(() {
                                  if (_messageError != null) {
                                    _messageError = null;
                                  }
                                }),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${_messageController.text.length}/$whatsappMessageMaxLength',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _loading || _sending ? null : _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(whatsappGreen),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(_sending ? 'Opening…' : 'Open WhatsApp'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

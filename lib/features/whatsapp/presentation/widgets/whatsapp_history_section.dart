import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

import '../../data/models/whatsapp_models.dart';
import '../providers/whatsapp_providers.dart';

/// Message log for a quotation, invoice, lead, or customer.
class WhatsAppHistorySection extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;
  final String title;
  final EdgeInsetsGeometry padding;

  const WhatsAppHistorySection({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title = 'WhatsApp messages',
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      0,
    ),
  });

  @override
  ConsumerState<WhatsAppHistorySection> createState() =>
      _WhatsAppHistorySectionState();
}

class _WhatsAppHistorySectionState
    extends ConsumerState<WhatsAppHistorySection> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = WhatsappEntityKey(
      entityType: widget.entityType,
      entityId: widget.entityId,
    );
    final async = ref.watch(whatsappMessagesProvider(key));

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_rounded,
                size: 18,
                color: Color(whatsappGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              async.maybeWhen(
                data: (rows) => rows.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        '(${rows.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => Text(
              'Loading…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            error: (error, _) => Text(
              cleanError(error),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'No WhatsApp messages sent yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    _MessageTile(
                      row: row,
                      expanded: _expandedId == row.id,
                      onToggle: () {
                        setState(() {
                          _expandedId = _expandedId == row.id ? null : row.id;
                        });
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final WhatsappMessageModel row;
  final bool expanded;
  final VoidCallback onToggle;

  const _MessageTile({
    required this.row,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = row.createdAt == null
        ? ''
        : ' on ${formatDateTime(row.createdAt)}';

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  whatsappTemplateLabel(row.templateKey),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatWhatsAppPhone(row.phone),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sent by ${row.senderLabel}$when',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(expanded ? 'Hide message' : 'Show message'),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(row.message),
            ),
        ],
      ),
    );
  }
}

/// Customer row action on the web: history of messages sent for this customer.
Future<void> showWhatsAppCustomerHistory(
  BuildContext context, {
  required String customerId,
  required String customerName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        customerName.trim().isEmpty ? 'Customer' : customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'WhatsApp messages sent to this customer for quotations, invoices and leads.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: WhatsAppHistorySection(
                    entityType: 'customer',
                    entityId: customerId,
                    title: 'Message history',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

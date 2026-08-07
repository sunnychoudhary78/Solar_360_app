import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/providers/connectivity_provider.dart';
import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/invoices/presentation/providers/invoice_providers.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/quotations/presentation/providers/quotation_providers.dart';

/// Slim offline strip with Retry — not full offline sync.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  Future<void> _retry(WidgetRef ref) async {
    ref.invalidate(connectivityRecheckProvider);
    await ref.read(connectivityRecheckProvider.future);

    ref.invalidate(allLeadsProvider);
    ref.invalidate(leadListProvider(false));
    ref.invalidate(leadListProvider(true));
    ref.invalidate(unreadNotificationCountProvider);

    try {
      await ref.read(customerListProvider.notifier).refresh();
    } catch (_) {}
    try {
      await ref.read(invoiceListProvider.notifier).refresh();
    } catch (_) {}
    try {
      await ref.read(quotationListProvider.notifier).refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(isOnlineProvider);
    final isOnline = onlineAsync.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );
    if (isOnline) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You’re offline',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _retry(ref),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_shell.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/dialogs.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(authProvider).customer;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Account'),
      body: ListView(
        primary: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initials(customer?.name),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.name ?? 'Customer',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          CustomerInfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: customer?.phone ?? '—',
          ),
          const SizedBox(height: 10),
          CustomerInfoTile(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: [
              customer?.city,
              customer?.state,
            ].where((v) => v != null && v.trim().isNotEmpty).join(', '),
          ),
          if ((customer?.companyName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            CustomerInfoTile(
              icon: Icons.apartment_outlined,
              label: 'Company',
              value: customer!.companyName!,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: () => Navigator.pushNamed(context, '/change-password'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: const Row(
              children: [
                Icon(Icons.lock_reset_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => _logout(context, ref),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Text(
                  'Sign out',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out',
      message: 'Sign out of your customer account?',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(authProvider.notifier).logout();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/customer_portal/presentation/screens/customer_shell.dart';
import 'package:solar_sales/features/customer_portal/presentation/widgets/customer_lead_progress.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

class CustomerHomeScreen extends ConsumerWidget {
  final VoidCallback onOpenLeads;
  final VoidCallback onOpenSupport;

  const CustomerHomeScreen({
    super.key,
    required this.onOpenLeads,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(authProvider).customer;
    final leadsAsync = ref.watch(customerLeadsProvider);
    final scheme = Theme.of(context).colorScheme;
    final today = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: 'Home'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerLeadsProvider);
          await ref.read(customerLeadsProvider.future);
        },
        child: ListView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              AppCard(
                variant: AppCardVariant.gradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerGreeting(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back, ${customer?.firstName ?? 'there'}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is your customer dashboard.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: const Text('Customer'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: scheme.primary.withValues(alpha: 0.12),
                          side: BorderSide.none,
                        ),
                        Text(
                          today,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'My account',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              CustomerInfoTile(
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: customer?.name ?? '—',
              ),
              const SizedBox(height: 10),
              CustomerInfoTile(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: customer?.email ?? '—',
                tint: Colors.lightBlue,
              ),
              const SizedBox(height: 10),
              CustomerInfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: customer?.phone ?? '—',
                tint: Colors.amber.shade800,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'My workspace',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _WorkspaceTile(
                      icon: Icons.assignment_outlined,
                      title: 'My Leads',
                      subtitle: 'See which stage your lead is in.',
                      color: Colors.lightBlue,
                      onTap: onOpenLeads,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WorkspaceTile(
                      icon: Icons.headset_mic_outlined,
                      title: 'Support',
                      subtitle: 'Raise a request or contact the team.',
                      color: scheme.primary,
                      onTap: onOpenSupport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              leadsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(customerLeadsProvider),
                ),
                data: (leads) => CustomerLeadProgress(
                  leads: leads,
                  onFillDetails: hasConvertedCustomerLead(leads)
                      ? null
                      : () => _openLeadForm(context, ref, null),
                  onEditDetails: (lead) => _openLeadForm(context, ref, lead),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _openLeadForm(
    BuildContext context,
    WidgetRef ref,
    LeadModel? lead,
  ) async {
    final result = await Navigator.pushNamed(
      context,
      '/customer/lead-form',
      arguments: lead,
    );
    if (result == true) {
      ref.invalidate(customerLeadsProvider);
    }
  }
}

class _WorkspaceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _WorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

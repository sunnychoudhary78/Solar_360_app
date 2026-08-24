import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/features/leads/presentation/screens/lead_form_screen.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/features/workflow/presentation/screens/workflow_team_screen.dart';
import 'package:solar_sales/shared/module/module_access.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/home/shared_home_layout.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/premium_ui.dart';
import 'package:solar_sales/shared/widgets/unread_badge.dart';

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class SolarHomeScreen extends ConsumerWidget {
  const SolarHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Workflow Desk / Admin Pipeline is Company Admin only — other roles
    // use the shared home (Leads, Create Lead, Explore), not a role desk.
    return _SalesAdminHome(auth: auth);
  }
}

class _SalesAdminHome extends ConsumerStatefulWidget {
  final AuthState auth;

  const _SalesAdminHome({required this.auth});

  @override
  ConsumerState<_SalesAdminHome> createState() => _SalesAdminHomeState();
}

class _SalesAdminHomeState extends ConsumerState<_SalesAdminHome> {
  bool _isRefreshing = false;

  String get _deskLabel {
    switch (widget.auth.workflowRoleKey) {
      case 'Sales':
      case 'Sales Manager':
        return 'Sales Desk';
      case 'Company Admin':
      case 'Admin':
        return 'Admin Desk';
      default:
        return 'Dashboard';
    }
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.refresh(allLeadsProvider.future),
        ref.refresh(unreadNotificationCountProvider.future),
      ]);
    } catch (_) {
      // Keep previous UI; pull / button can be retried.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final scheme = Theme.of(context).colorScheme;
    final firstName = auth.profile?.name.split(' ').first ?? 'there';

    final header = HomeHeaderData(
      title: firstName,
      subtitle: auth.roleName.isNotEmpty
          ? auth.roleName
          : 'Lead pipeline & workflow',
      badge: StatusPill(label: _deskLabel, color: scheme.primary),
      heroImage: 'assets/images/solar_header.png',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer.withValues(alpha: 0.55),
          scheme.secondaryContainer.withValues(alpha: 0.35),
          scheme.surfaceContainerLowest,
        ],
      ),
      accentColor: scheme.primary,
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Green Energy',
        subtitle: '${_timeGreeting()}, $firstName',
        largeTitle: true,
        actions: [
          UnreadBadge(
            child: IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, '/solar/notifications'),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _refreshDashboard,
            icon: _isRefreshing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SharedHomeLayout(
        header: header,
        greeting: _timeGreeting(),
        onRefresh: _refreshDashboard,
        child: _SolarHomeContent(auth: auth),
      ),
    );
  }
}

class _SolarHomeContent extends ConsumerWidget {
  const _SolarHomeContent({required this.auth});

  final AuthState auth;

  bool get _canReadLeads => auth.hasPermission('lead.read');
  bool get _canCreateLead => auth.hasPermission('lead.create');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(allLeadsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final tabs = NavDestinations.shellTabs(
      AppModules.solar,
      auth.hasPermission,
    );
    final quickDests = NavDestinations.quickActions(
      AppModules.solar,
      auth.hasPermission,
    );

    final leadCount = leadsAsync.asData?.value.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canReadLeads) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Total leads',
                    value: '$leadCount',
                    icon: Icons.groups_rounded,
                    onTap: () =>
                        Navigator.pushNamed(context, '/solar/leads'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Your role',
                    value: auth.roleName.isNotEmpty ? auth.roleName : '—',
                    icon: Icons.badge_outlined,
                  ),
                ),
              ],
            ),
          ).appFadeSlide(index: 0),
          const SizedBox(height: AppSpacing.lg),
        ] else
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppCard(
              variant: AppCardVariant.flat,
              child: Text(
                'Your account does not have lead permissions yet. Ask an admin to assign lead.read / lead.create.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),

        if (_canCreateLead || _canReadLeads) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PremiumSectionTitle(title: 'Lead actions'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_canCreateLead)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: AppCard(
                variant: AppCardVariant.flat,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeadFormScreen(),
                    ),
                  );
                  ref.invalidate(allLeadsProvider);
                },
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Lead',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Add basic details — Support will review first',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ).appFadeSlide(index: 1),
          if (auth.isCompanyAdmin && _canReadLeads)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: AppCard(
                variant: AppCardVariant.flat,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkflowTeamScreen(
                        titleOverride: 'Admin Pipeline',
                      ),
                    ),
                  );
                },
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.account_tree_rounded,
                        color: scheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Workflow Desk',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Cross-team pipeline view',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: scheme.tertiary,
                    ),
                  ],
                ),
              ),
            ).appFadeSlide(index: 2),
        ],

        const SizedBox(height: AppSpacing.lg),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PremiumSectionTitle(
            title: 'Explore',
            subtitle: 'Jump to a feature',
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        QuickActionGrid(
          destinations: quickDests,
          onDestination: (dest) => navigateDestination(context, dest, tabs),
        ).appFadeSlide(index: 3),

        if (leadsAsync.isLoading && !leadsAsync.hasValue)
          const Padding(
            padding: EdgeInsets.all(24),
            child: SkeletonList(count: 2),
          ),
      ],
    );
  }
}

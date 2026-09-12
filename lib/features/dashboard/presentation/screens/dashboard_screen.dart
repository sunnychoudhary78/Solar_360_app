
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_state.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:solar_sales/shared/constants/role_taglines.dart';
import 'package:solar_sales/shared/utils/formatters.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/async_states.dart';
import 'package:solar_sales/shared/widgets/home/shared_home_layout.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:solar_sales/shared/widgets/unread_badge.dart';

import '../../data/models/dashboard_model.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/billbook_overview_section.dart';

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isRefreshing = false;

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.refresh(dashboardProvider.future),
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
    final async = ref.watch(dashboardProvider);
    final auth = ref.watch(authProvider);
    final scheme = Theme.of(context).colorScheme;
    final firstName = auth.profile?.name.split(' ').first ?? 'there';
    final roleSubtitle = RoleTaglines.forRole(auth.profile?.roleName);

    const green = Color(0xFF0E9F6E);

    final header = HomeHeaderData(
      title: firstName,
      subtitle: roleSubtitle.isEmpty
          ? "Here's what's happening with your business today."
          : roleSubtitle,
      badge: const StatusPill(
        label: 'Billbook',
        color: green,
        icon: Icons.auto_graph_rounded,
      ),
      // DO NOT CHANGE: existing Billbook header image.
      heroImage: 'assets/images/billbook_header.png',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: scheme.brightness == Brightness.dark
            ? [
                scheme.surfaceContainerLowest,
                scheme.surfaceContainerLow,
                scheme.surfaceContainer,
              ]
            : const [
                Color(0xFFF3FBF7),
                Color(0xFFE8F7F0),
                Color(0xFFF8FCFA),
              ],
      ),
      accentColor: green,
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(
        title: 'Billbook',
        subtitle: '${_timeGreeting()}, $firstName',
        largeTitle: true,
        actions: [
          if (auth.hasPermission('companySettings.read'))
            IconButton(
              tooltip: 'Templates',
              icon: const Icon(Icons.layers_outlined),
              onPressed: () =>
                  Navigator.pushNamed(context, '/settings/templates'),
            ),
          UnreadBadge(
            child: IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                ref.invalidate(unreadNotificationCountProvider);
              },
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
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: cleanError(e),
          onRetry: _refreshDashboard,
        ),
        data: (data) => SharedHomeLayout(
          header: header,
          greeting: _timeGreeting(),
          onRefresh: _refreshDashboard,
          child: _BillBookContent(
            data: data,
            auth: auth,
            accentColor: green,
          ),
        ),
      ),
    );
  }
}

class _BillBookContent extends StatelessWidget {
  const _BillBookContent({
    required this.data,
    required this.auth,
    required this.accentColor,
  });

  final DashboardModel data;
  final AuthState auth;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: BillbookOverviewSection(
        data: data,
        accentColor: accentColor,
        canOpenReports: auth.hasPermission('report.read'),
        onOpen: (route) => Navigator.pushNamed(context, route),
      ),
    );
  }
}

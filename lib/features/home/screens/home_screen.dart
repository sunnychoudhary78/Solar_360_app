import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/role_utils.dart';
import '../../../core/widgets/profile_photo_box.dart';
import '../../auth/auth_session.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/screens/all_leads_screen.dart';
import '../../leads/screens/lead_form_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../workflow/screens/finance_team_screen.dart';
import '../../workflow/screens/workflow_team_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const bgColor = Color(0xFFF7F8FC);
  static const drawerBgColor = Color(0xFFF9F7FF);
  static const cardColor = Colors.white;

  static const primaryColor = Color(0xFF4E5FAE);
  static const teamAccent = Color(0xFF22B8A8);

  static const textColor = Color(0xFF1F2028);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final appRole = auth.appRole;

    if (appRole == 'support' ||
        appRole == 'liaison' ||
        appRole == 'installation') {
      return WorkflowTeamScreen(
        titleOverride: RoleUtils.displayTitle(appRole),
      );
    }

    if (appRole == 'finance') {
      return const FinanceTeamScreen();
    }

    return _SalesAdminShell(auth: auth);
  }
}

class _SalesAdminShell extends ConsumerStatefulWidget {
  final AuthState auth;

  const _SalesAdminShell({required this.auth});

  @override
  ConsumerState<_SalesAdminShell> createState() => _SalesAdminShellState();
}

class _SalesAdminShellState extends ConsumerState<_SalesAdminShell> {
  int selectedPage = 0;

  AuthState get auth => widget.auth;

  bool get _canReadLeads => auth.hasPermission('lead.read');
  bool get _canCreateLead => auth.hasPermission('lead.create');

  String get _title => RoleUtils.displayTitle(auth.appRole);

  IconData get _roleIcon {
    switch (auth.appRole) {
      case 'sales':
        return Icons.solar_power_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }

  String get _deskLabel {
    switch (auth.appRole) {
      case 'sales':
        return 'Sales Desk';
      case 'admin':
        return 'Admin Desk';
      default:
        return 'Dashboard';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(allLeadsProvider);

    final leadCount = leadsAsync.maybeWhen(
      data: (leads) => leads.length,
      orElse: () => 0,
    );

    return WillPopScope(
      onWillPop: () async {
        if (selectedPage != 0) {
          setState(() => selectedPage = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: HomeScreen.bgColor,
        drawer: _drawer(context),
        appBar: AppBar(
          backgroundColor: HomeScreen.bgColor,
          elevation: 0,
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              splashColor: HomeScreen.primaryColor.withOpacity(0.14),
              highlightColor: Colors.transparent,
              icon: const Icon(
                Icons.menu_rounded,
                size: 34,
                color: HomeScreen.primaryColor,
              ),
              onPressed: () {
                ref.read(authProvider.notifier).refreshProfile();
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: Text(
            selectedPage == 1 ? 'Notifications' : _title,
            style: const TextStyle(
              color: HomeScreen.textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              splashColor: HomeScreen.primaryColor.withOpacity(0.14),
              highlightColor: Colors.transparent,
              onPressed: _refreshLeads,
              icon: const Icon(
                Icons.refresh,
                color: HomeScreen.primaryColor,
              ),
            ),
            IconButton(
              splashColor: HomeScreen.primaryColor.withOpacity(0.14),
              highlightColor: Colors.transparent,
              onPressed: () => setState(() => selectedPage = 1),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: HomeScreen.primaryColor,
              ),
            ),
          ],
        ),
        body: selectedPage == 1
            ? const NotificationsScreen()
            : _dashboard(leadCount: leadCount),
      ),
    );
  }

  void _refreshLeads() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        ref.invalidate(allLeadsProvider);
      } catch (err, st) {
        debugPrint('invalidate failed: $err\n$st');
      }
    });
  }

  Widget _dashboard({required int leadCount}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _salesHeroCard(),
          const SizedBox(height: 20),
          if (_canReadLeads)
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Leads',
                    leadCount.toString(),
                    Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _statCard(
                    'Role',
                    auth.user?.roleName ?? '—',
                    Icons.badge_outlined,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (!_canReadLeads)
            const Text(
              'Your account does not have lead permissions yet. Ask an admin to assign lead.read / lead.create.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          if (_canCreateLead) ...[
            const Text(
              'Lead Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: HomeScreen.textColor,
              ),
            ),
            const SizedBox(height: 14),
            _action(
              title: 'Create New Lead',
              subtitle: 'Add basic details — Support will review first',
              icon: Icons.add_circle_outline_rounded,
              onTap: _openCreateLead,
            ),
          ],
          if (_canReadLeads) ...[
            const SizedBox(height: 14),
            _action(
              title: 'All Leads',
              subtitle: 'View pipeline and update status',
              icon: Icons.list_alt_rounded,
              onTap: _openAllLeads,
            ),
          ],
          if (auth.appRole == 'admin' && _canReadLeads) ...[
            const SizedBox(height: 14),
            _action(
              title: 'Workflow Desk',
              subtitle: 'Cross-team pipeline view',
              icon: Icons.account_tree_rounded,
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
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCreateLead() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeadFormScreen()),
    );

    if (!mounted) return;
    _refreshLeads();
  }

  void _openAllLeads() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllLeadsScreen()),
    );
  }

  Widget _salesHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HomeScreen.primaryColor,
            HomeScreen.teamAccent,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: HomeScreen.primaryColor.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: Container(
              height: 112,
              width: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -46,
            child: Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _roleIcon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _deskLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                auth.user?.roleName ?? _title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomeScreen.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: HomeScreen.primaryColor, size: 32),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: HomeScreen.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        splashColor: HomeScreen.primaryColor.withOpacity(0.12),
        highlightColor: HomeScreen.primaryColor.withOpacity(0.04),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HomeScreen.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: HomeScreen.primaryColor.withOpacity(0.12),
                child: Icon(icon, color: HomeScreen.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HomeScreen.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: HomeScreen.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawer(BuildContext context) {
    final userName = auth.user?.name?.trim().isNotEmpty == true
        ? auth.user!.name!.trim()
        : 'User';

    final roleName = auth.user?.roleName?.trim().isNotEmpty == true
        ? auth.user!.roleName!.trim()
        : _title;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: HomeScreen.drawerBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _drawerHeader(
              userName: userName,
              roleName: roleName,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerSectionTitle('MAIN'),
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    selected: selectedPage == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => selectedPage = 0);
                    },
                  ),
                  _drawerSectionTitle('WORK'),
                  _drawerItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    selected: selectedPage == 1,
                    trailing: Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => selectedPage = 1);
                    },
                  ),
                  if (_canCreateLead)
                    _drawerItem(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'Create Lead',
                      onTap: () {
                        Navigator.pop(context);
                        _openCreateLead();
                      },
                    ),
                  if (_canReadLeads)
                    _drawerItem(
                      icon: Icons.list_alt_rounded,
                      title: 'All Leads',
                      onTap: () {
                        Navigator.pop(context);
                        _openAllLeads();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: _drawerItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                isLogout: true,
                onTap: () async {
                  Navigator.pop(context);
                  await AuthSession.logout(context, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerHeader({
    required String userName,
    required String roleName,
  }) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HomeScreen.primaryColor,
            HomeScreen.teamAccent,
          ],
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            splashColor: HomeScreen.primaryColor.withOpacity(0.12),
            highlightColor: Colors.white24,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) {
                ref.read(authProvider.notifier).refreshProfile();
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 62,
              width: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ProfilePhotoBox(
                rawProfilePicture: auth.user?.profilePicture,
                initial: initial,
                textColor: HomeScreen.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            roleName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.black.withOpacity(0.55),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool isLogout = false,
    Widget? trailing,
  }) {
    final color = isLogout
        ? const Color(0xFFD32F2F)
        : selected
            ? HomeScreen.primaryColor
            : HomeScreen.textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? HomeScreen.primaryColor.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          splashColor: HomeScreen.primaryColor.withOpacity(0.12),
          highlightColor: HomeScreen.primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: selected || isLogout
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

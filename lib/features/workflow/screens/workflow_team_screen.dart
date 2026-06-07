import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/role_utils.dart';
import '../../../core/widgets/profile_photo_box.dart';
import '../../../core/workflow/lead_workflow.dart';
import '../../../screens/theme/theme_settings_screen.dart';
import '../../auth/auth_session.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/widgets/leads_table.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';

class WorkflowTeamScreen extends ConsumerStatefulWidget {
  final String? titleOverride;

  const WorkflowTeamScreen({super.key, this.titleOverride});

  @override
  ConsumerState<WorkflowTeamScreen> createState() => _WorkflowTeamScreenState();
}

class _WorkflowTeamScreenState extends ConsumerState<WorkflowTeamScreen> {
  static const teamAccent = Color(0xFF18A999);

  int selectedPage = 0; // 0 Dashboard, 1 Profile, 2 Notifications

  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;

  Color get _drawerBgColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F7FF);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  String get _title {
    final auth = ref.read(authProvider);
    return widget.titleOverride ?? RoleUtils.displayTitle(auth.appRole);
  }

  String get _pageTitle {
    if (selectedPage == 2) return 'Notifications';
    return _title;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final leadsAsync = ref.watch(allLeadsProvider);

    return WillPopScope(
      onWillPop: () async {
        if (selectedPage != 0) {
          setState(() => selectedPage = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        drawer: selectedPage == 1 ? null : _drawer(),
        appBar: selectedPage == 1
            ? null
            : AppBar(
                backgroundColor: _bgColor,
                foregroundColor: _textColor,
                elevation: 0,
                centerTitle: true,
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      size: 34,
                      color: _primaryColor,
                    ),
                    onPressed: () {
                      ref.read(authProvider.notifier).refreshProfile();
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ),
                title: Text(
                  _pageTitle,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _refreshLeads,
                    icon: Icon(Icons.refresh, color: _primaryColor),
                  ),
                  IconButton(
                    onPressed: () => setState(() => selectedPage = 2),
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
        body: selectedPage == 1
            ? const ProfileScreen()
            : selectedPage == 2
                ? const NotificationsScreen()
                : leadsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          e.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    data: (leads) {
                      final roleName = auth.user?.roleName ?? '';
                      final filteredLeads =
                          _filterLeadsForRole(leads, roleName);
                      return _dashboard(filteredLeads, roleName);
                    },
                  ),
      ),
    );
  }

  void _refreshLeads() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(allLeadsProvider);
    });
  }

  List<LeadModel> _filterLeadsForRole(List<LeadModel> leads, String roleName) {
    if (LeadWorkflow.isAdminRole(roleName)) return leads;

    final roleKey = LeadWorkflow.resolveRoleKey(roleName);
    final department = _departmentForRole(roleKey);

    if (department == null) return [];

    return leads.where((lead) {
      final leadDepartment = lead.currentDepartment.trim().toLowerCase();
      return leadDepartment == department.toLowerCase();
    }).toList();
  }

  String? _departmentForRole(String roleKey) {
    switch (roleKey) {
      case 'Sales':
        return 'Sales';
      case 'Support':
        return 'Support';
      case 'Liaising':
        return 'Liaising';
      case 'Finance':
        return 'Finance';
      case 'Installation':
        return 'Installation';
      default:
        return null;
    }
  }

  IconData _roleIcon(String roleKey) {
    switch (roleKey) {
      case 'Sales':
        return Icons.solar_power_rounded;
      case 'Support':
        return Icons.support_agent_rounded;
      case 'Liaising':
        return Icons.account_tree_rounded;
      case 'Installation':
        return Icons.electrical_services_rounded;
      case 'Finance':
        return Icons.account_balance_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }

  String _roleDeskLabel(String roleKey) {
    switch (roleKey) {
      case 'Sales':
        return 'Sales Desk';
      case 'Support':
        return 'Support Desk';
      case 'Liaising':
        return 'Liaison Desk';
      case 'Installation':
        return 'Installation Desk';
      case 'Finance':
        return 'Finance Desk';
      default:
        return 'Dashboard';
    }
  }

  Widget _dashboard(List<LeadModel> leads, String roleName) {
    final active = leads.where((l) => l.isActive).length;

    final completed = leads.where((l) {
      return l.status == 'Lead Completed' || l.status == 'Lead Closed';
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              _heroCard(
                active: active,
                completed: completed,
                roleName: roleName,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      label: 'Active',
                      value: '$active',
                      icon: Icons.groups_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      label: 'Completed',
                      value: '$completed',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pipeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
        ),
        Expanded(
          child: LeadsTable(
            leads: leads,
            emptyMessage: 'No leads in your queue',
          ),
        ),
      ],
    );
  }

  Widget _heroCard({
    required int active,
    required int completed,
    required String roleName,
  }) {
    final resolvedRole = LeadWorkflow.resolveRoleKey(roleName);
    final roleIcon = _roleIcon(resolvedRole);
    final deskLabel = _roleDeskLabel(resolvedRole);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, teamAccent],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -18, top: -24, child: _bgCircle(112)),
          Positioned(right: 40, bottom: -46, child: _bgCircle(96)),
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
                    child: Icon(roleIcon, color: Colors.white, size: 32),
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
                      deskLabel,
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
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$active active leads, $completed completed',
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

  Widget _bgCircle(double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.07),
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: _primaryColor),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: _textColor.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawer() {
    final auth = ref.watch(authProvider);

    final userName = auth.user?.name.trim().isNotEmpty == true
        ? auth.user!.name.trim()
        : 'User';

    final roleName = auth.user?.roleName.trim().isNotEmpty == true
        ? auth.user!.roleName.trim()
        : _title;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: _drawerBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _drawerHeader(userName: userName, roleName: roleName),
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
                  _drawerItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Profile',
                    selected: selectedPage == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => selectedPage = 1);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThemeSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _drawerSectionTitle('WORK'),
                  _drawerItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    selected: selectedPage == 2,
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
                      setState(() => selectedPage = 2);
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, teamAccent],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: ProfilePhotoBox(
              rawProfilePicture: ref.watch(authProvider).user?.profilePicture,
              initial: initial,
              textColor: _primaryColor,
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
          color: _textColor.withOpacity(0.55),
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
            ? _primaryColor
            : _textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? _primaryColor.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          splashColor: _primaryColor.withOpacity(0.12),
          highlightColor: _primaryColor.withOpacity(0.04),
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
                      fontWeight:
                          selected || isLogout ? FontWeight.bold : FontWeight.w500,
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
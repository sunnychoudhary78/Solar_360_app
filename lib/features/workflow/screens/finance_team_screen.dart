import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/profile_photo_box.dart';
import '../../../screens/theme/theme_settings_screen.dart';
import '../../auth/auth_session.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/widgets/leads_table.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';

class FinanceTeamScreen extends ConsumerStatefulWidget {
  const FinanceTeamScreen({super.key});

  @override
  ConsumerState<FinanceTeamScreen> createState() => _FinanceTeamScreenState();
}

class _FinanceTeamScreenState extends ConsumerState<FinanceTeamScreen> {
  static const accentColor = Color(0xFF18A999);

  int selectedPage = 0;
  bool actionLoading = false;

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

  @override
  Widget build(BuildContext context) {
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
                  builder: (context) {
                    return IconButton(
                      icon: Icon(
                        Icons.menu_rounded,
                        size: 34,
                        color: _primaryColor,
                      ),
                      onPressed: () {
                        ref.read(authProvider.notifier).refreshProfile();
                        Scaffold.of(context).openDrawer();
                      },
                    );
                  },
                ),
                title: Text(
                  _pageTitle(),
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _refreshLeads,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: _primaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => selectedPage = 3),
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
        body: selectedPage == 1
            ? const ProfileScreen()
            : leadsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                data: (allLeads) {
                  final leads = _financeLeads(allLeads);
                  final liaisonLeads = _liaisonTeamLeads(allLeads);

                  return IndexedStack(
                    index: selectedPage == 3 ? 2 : selectedPage == 2 ? 1 : 0,
                    children: [
                      _dashboard(leads),
                      LeadsTable(
                        leads: liaisonLeads,
                        emptyMessage: 'No leads received from Liaison Team yet',
                      ),
                      const NotificationsScreen(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  String _pageTitle() {
    switch (selectedPage) {
      case 2:
        return 'Liaison Team';
      case 3:
        return 'Notifications';
      default:
        return 'Finance Team';
    }
  }

  void _refreshLeads() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(allLeadsProvider);
    });
  }

  List<LeadModel> _financeLeads(List<LeadModel> leads) {
    return leads.where((lead) {
      final dept = lead.currentDepartment.trim().toLowerCase();
      final status = lead.status.trim().toLowerCase();

      return dept == 'finance' ||
          status == 'liaison completed' ||
          status == 'finance verification started' ||
          status == 'loan approved';
    }).toList();
  }

  List<LeadModel> _liaisonTeamLeads(List<LeadModel> leads) {
    return _financeLeads(leads).where((lead) {
      final status = lead.status.trim().toLowerCase();
      return status == 'liaison completed' ||
          status == 'finance verification started';
    }).toList();
  }

  Future<void> _changeStatus(LeadModel lead, String status) async {
    try {
      setState(() => actionLoading = true);

      await ref.read(leadRepositoryProvider).updateLeadStatus(
            leadId: lead.id,
            status: status,
          );

      ref.invalidate(allLeadsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated: $status')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => actionLoading = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Liaison Completed':
        return Colors.orange;
      case 'Finance Verification Started':
        return Colors.blue;
      case 'Loan Approved':
        return Colors.green;
      default:
        return _primaryColor;
    }
  }

  Widget _drawer() {
    final auth = ref.watch(authProvider);

    final userName = auth.user?.name?.trim().isNotEmpty == true
        ? auth.user!.name!.trim()
        : 'Finance User';

    final roleName = auth.user?.roleName?.trim().isNotEmpty == true
        ? auth.user!.roleName!.trim()
        : 'Finance Team';

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
                    icon: Icons.account_tree_rounded,
                    title: 'Liaison Team',
                    selected: selectedPage == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => selectedPage = 2);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    selected: selectedPage == 3,
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
                      setState(() => selectedPage = 3);
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
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'F';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, accentColor],
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(26)),
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

  Widget _dashboard(List<LeadModel> leads) {
    final fromLiaison = leads.where((lead) {
      final status = lead.status.toLowerCase();
      return status == 'liaison completed' ||
          status == 'finance verification started';
    }).length;

    final approvedCount =
        leads.where((lead) => lead.status == 'Loan Approved').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              _financeHeroCard(
                total: leads.length,
                fromLiaison: fromLiaison,
                approved: approvedCount,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      'Pipeline',
                      leads.length.toString(),
                      Icons.groups_rounded,
                      _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metricCard(
                      'Approved',
                      approvedCount.toString(),
                      Icons.check_circle_rounded,
                      accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LeadsTable(
            leads: leads,
            emptyMessage: 'No finance leads in queue',
          ),
        ),
      ],
    );
  }

  Widget _financeHeroCard({
    required int total,
    required int fromLiaison,
    required int approved,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, accentColor],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -18, top: -24, child: _circle(112)),
          Positioned(right: 40, bottom: -46, child: _circle(96)),
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
                    child: const Icon(
                      Icons.account_balance_rounded,
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
                    child: const Text(
                      'Finance Desk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Finance Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$total active leads, $fromLiaison from Liaison Team, $approved approved',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.07),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _textColor.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              color: _textColor.withOpacity(0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(LeadModel lead) {
    if (actionLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: CircularProgressIndicator(),
      );
    }

    if (lead.status == 'Liaison Completed') {
      return _mainButton(
        title: 'Start Finance Verification',
        icon: Icons.verified_user_rounded,
        color: Colors.orange,
        onTap: () => _changeStatus(lead, 'Finance Verification Started'),
      );
    }

    if (lead.status == 'Finance Verification Started') {
      return _mainButton(
        title: 'Approve Loan & Send To Installation',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        onTap: () => _changeStatus(lead, 'Loan Approved'),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _mainButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: actionLoading ? null : onTap,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
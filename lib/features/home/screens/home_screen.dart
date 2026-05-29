import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/role_utils.dart';
import '../../auth/auth_session.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/screens/all_leads_screen.dart';
import '../../leads/screens/lead_form_screen.dart';
import '../../workflow/screens/finance_team_screen.dart';
import '../../workflow/screens/workflow_team_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
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

class _SalesAdminShell extends ConsumerWidget {
  final AuthState auth;

  const _SalesAdminShell({required this.auth});

  bool get _canReadLeads => auth.hasPermission('lead.read');
  bool get _canCreateLead => auth.hasPermission('lead.create');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(allLeadsProvider);
    final title = RoleUtils.displayTitle(auth.appRole);
    final leadCount = leadsAsync.maybeWhen(
      data: (leads) => leads.length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: HomeScreen.bgColor,
      drawer: _drawer(context, ref, title),
      appBar: AppBar(
        backgroundColor: HomeScreen.bgColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: HomeScreen.textColor,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: HomeScreen.textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _welcomeCard(auth, title),
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
                context,
                title: 'Create New Lead',
                subtitle: 'Add customer, KYC and site details',
                icon: Icons.add_circle_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeadFormScreen()),
                ),
              ),
            ],
            if (_canReadLeads) ...[
              const SizedBox(height: 14),
              _action(
                context,
                title: 'All Leads',
                subtitle: 'View pipeline and update status',
                icon: Icons.list_alt_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllLeadsScreen()),
                ),
              ),
            ],
            if (auth.appRole == 'admin' && _canReadLeads) ...[
              const SizedBox(height: 14),
              _action(
                context,
                title: 'Workflow Desk',
                subtitle: 'Cross-team pipeline view',
                icon: Icons.account_tree_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkflowTeamScreen(
                      titleOverride: 'Admin Pipeline',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard(AuthState auth, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5663A0), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.solar_power_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Welcome, ${auth.user?.name ?? 'User'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
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
          Text(title, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
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
                    style: const TextStyle(color: Colors.black45, fontSize: 14),
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
    );
  }

  Widget _drawer(BuildContext context, WidgetRef ref, String title) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.solar_power_rounded,
                size: 72, color: HomeScreen.primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              auth.user?.email ?? '',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),
            if (_canCreateLead)
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: HomeScreen.primaryColor),
                title: const Text('Create Lead',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeadFormScreen(),
                    ),
                  );
                },
              ),
            if (_canReadLeads)
              ListTile(
                leading: const Icon(Icons.list_alt_outlined,
                    color: HomeScreen.primaryColor),
                title: const Text('All Leads',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllLeadsScreen(),
                    ),
                  );
                },
              ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: HomeScreen.primaryColor),
              title: const Text('Logout',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => AuthSession.logout(context, ref),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_session.dart';
import '../../leads/models/lead_model.dart';
import '../../leads/screens/all_leads_screen.dart';
import '../../leads/screens/lead_form_screen.dart';
import '../../notifications/screens/notifications_screen.dart';

import '../../workflow/screens/support_team_screen.dart';
import '../../workflow/screens/liaison_process_screen.dart';
import '../../workflow/screens/finance_team_screen.dart';
import '../../workflow/screens/installation_team_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const _leadsKey = 'savedLeads';
  static final List<LeadModel> leads = [];

  static Future<void> loadLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLeads = prefs.getString(_leadsKey);

    if (rawLeads == null || rawLeads.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(rawLeads);

      if (decoded is! List) return;

      leads
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map(
                (lead) => LeadModel.fromJson(
                  Map<String, dynamic>.from(lead),
                ),
              )
              .toList(),
        );
    } catch (_) {
      await prefs.remove(_leadsKey);
    }
  }

  static Future<void> saveLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      leads.map((lead) => lead.toJson()).toList(),
    );

    await prefs.setString(_leadsKey, encoded);
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  String userRole = 'sales';
  bool isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndLeads();
  }

  Future<void> _loadUserRoleAndLeads() async {
    final prefs = await SharedPreferences.getInstance();

    await HomeScreen.loadLeads();

    if (!mounted) return;

    setState(() {
      userRole = _normalizedRole(prefs.getString('userRole'));
      isLoadingRole = false;
    });
  }

  String _normalizedRole(String? savedRole) {
    if (savedRole == 'leasing') return 'liaison';
    return savedRole ?? 'sales';
  }

  String get appTitle {
    switch (userRole) {
      case 'support':
        return 'Support Team';
      case 'liaison':
        return 'Liaison Officer';
      case 'finance':
        return 'Finance Team';
      case 'installation':
        return 'Installation Team';
      default:
        return 'Solar Sales';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideParentChrome = isLoadingRole || userRole == 'support';

    return Scaffold(
      backgroundColor: bgColor,
      drawer: hideParentChrome ? null : _drawer(),
      appBar: hideParentChrome
          ? null
          : AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              centerTitle: true,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: textColor,
                      size: 34,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
              title: Text(
                appTitle,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _pushNotifications,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    size: 31,
                    color: textColor,
                  ),
                ),
              ],
            ),
      body: isLoadingRole
          ? const Center(child: CircularProgressIndicator())
          : _getRoleBasedBody(),
    );
  }

  Widget _getRoleBasedBody() {
    if (userRole == 'sales') {
      return _newLeadTab();
    }

    if (userRole == 'support') {
      return const SupportTeamScreen();
    }

    if (userRole == 'liaison') {
      return const LiaisonProcessScreen();
    }

    if (userRole == 'finance') {
      return const FinanceTeamScreen();
    }

    if (userRole == 'installation') {
      return const InstallationTeamScreen();
    }

    return const Center(
      child: Text(
        'Invalid user role',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _newLeadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Total Leads',
                  value: HomeScreen.leads.length.toString(),
                  icon: Icons.groups_rounded,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _statCard(
                  title: 'New Leads',
                  value: HomeScreen.leads.length.toString(),
                  icon: Icons.fiber_new_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Lead Actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          _actionButton(
            title: 'Create New Lead',
            subtitle: 'Add customer details, KYC, roof details and documents',
            icon: Icons.add_circle_outline_rounded,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeadFormScreen(),
                ),
              );

              await HomeScreen.loadLeads();

              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _actionButton(
            title: 'All Leads',
            subtitle: 'View all saved leads and workflow progress',
            icon: Icons.list_alt_rounded,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllLeadsScreen(),
                ),
              );

              await HomeScreen.loadLeads();

              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5663A0),
            Color(0xFF6C63FF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.solar_power_rounded,
            size: 70,
            color: Colors.white,
          ),
          SizedBox(height: 18),
          Text(
            'Welcome Back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Manage your solar leads easily',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
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
          Icon(
            icon,
            color: primaryColor,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
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
          color: cardColor,
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
              radius: 28,
              backgroundColor: primaryColor.withOpacity(0.12),
              child: Icon(
                icon,
                color: primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
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
              size: 18,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 34),
            const Icon(
              Icons.solar_power_rounded,
              size: 76,
              color: primaryColor,
            ),
            const SizedBox(height: 18),
            Text(
              appTitle,
              style: const TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 36),
            _drawerItem(
              Icons.dashboard_outlined,
              'Dashboard',
              () {
                Navigator.pop(context);
              },
            ),
            if (userRole == 'sales')
              _drawerItem(
                Icons.add_circle_outline_rounded,
                'Create Lead',
                () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeadFormScreen(),
                    ),
                  );

                  await HomeScreen.loadLeads();

                  if (mounted) setState(() {});
                },
              ),
            if (userRole == 'sales')
              _drawerItem(
                Icons.list_alt_outlined,
                'All Leads',
                () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllLeadsScreen(),
                    ),
                  );

                  await HomeScreen.loadLeads();

                  if (mounted) setState(() {});
                },
              ),
            _drawerItem(
              Icons.notifications_none_rounded,
              'Notifications',
              () {
                Navigator.pop(context);
                _pushNotifications();
              },
            ),
            const Spacer(),
            _drawerItem(
              Icons.logout_rounded,
              'Logout',
              () async {
                if (!mounted) return;
                await AuthSession.logout(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _pushNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(showAppBar: true),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          icon,
          color: primaryColor,
          size: 33,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

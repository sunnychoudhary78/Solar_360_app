import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/role_utils.dart';
import '../../../core/workflow/lead_workflow.dart';
import '../../auth/auth_session.dart';
import '../../auth/models/auth_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/widgets/leads_table.dart';
import '../../notifications/screens/notifications_screen.dart';

/// Dynamic workflow desk — loads leads from API (scoped by backend role).
class WorkflowTeamScreen extends ConsumerStatefulWidget {
  final String? titleOverride;

  const WorkflowTeamScreen({super.key, this.titleOverride});

  @override
  ConsumerState<WorkflowTeamScreen> createState() =>
      _WorkflowTeamScreenState();
}

class _WorkflowTeamScreenState extends ConsumerState<WorkflowTeamScreen> {
  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  int selectedPage = 0;

  String get _title {
    if (widget.titleOverride != null) return widget.titleOverride!;
    final auth = ref.read(authProvider);
    return RoleUtils.displayTitle(auth.appRole);
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
        backgroundColor: bgColor,
        drawer: _drawer(auth),
        appBar: AppBar(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded, size: 34),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            selectedPage == 1 ? 'Notifications' : _title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(allLeadsProvider),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: () => setState(() => selectedPage = 1),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        body: selectedPage == 1
            ? const NotificationsScreen()
            : leadsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
                data: (leads) => _dashboard(leads, auth.user?.roleName ?? ''),
              ),
      ),
    );
  }

  Widget _dashboard(List<LeadModel> leads, String roleName) {
    final active = leads.where((l) => l.isActive).length;
    final completed = leads
        .where((l) =>
            l.status == 'Lead Completed' || l.status == 'Lead Closed')
        .length;

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
                    child: _metric('Active', '$active', Icons.groups_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      'Completed',
                      '$completed',
                      Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pipeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5663A0), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$active active · $completed completed',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Role: ${LeadWorkflow.resolveRoleKey(roleName)}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
          Icon(icon, color: primaryColor),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _drawer(AuthState auth) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            const Icon(Icons.solar_power_rounded,
                size: 72, color: primaryColor),
            const SizedBox(height: 12),
            Text(
              auth.user?.name ?? _title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              auth.user?.roleName ?? '',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined, color: primaryColor),
              title: const Text('Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedPage = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none, color: primaryColor),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedPage = 1);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: primaryColor),
              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                await AuthSession.logout(context, ref);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

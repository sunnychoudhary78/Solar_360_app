import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/profile_photo_box.dart';
import '../../auth/auth_session.dart';
import '../../auth/providers/auth_provider.dart';
import '../../leads/models/lead_model.dart';
import '../../leads/providers/lead_provider.dart';
import '../../leads/widgets/leads_table.dart';
import '../../notifications/screens/notifications_screen.dart';

class FinanceTeamScreen extends ConsumerStatefulWidget {
  const FinanceTeamScreen({super.key});

  @override
  ConsumerState<FinanceTeamScreen> createState() => _FinanceTeamScreenState();
}

class _FinanceTeamScreenState extends ConsumerState<FinanceTeamScreen> {
  static const bgColor = Color(0xfff4f7fb);
  static const drawerBgColor = Color(0xFFF9F7FF);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const accentColor = Color(0xFF18A999);
  static const textColor = Color(0xFF1F2028);

  int selectedPage = 0;
  bool actionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  List<LeadModel> _financeLeads(List<LeadModel> leads) {
    return leads.where((lead) {
      final dept = lead.currentDepartment.toLowerCase();
      final status = lead.status.toLowerCase();

      return dept == 'finance' ||
          status == 'liaison completed' ||
          status == 'finance verification started' ||
          status == 'loan approved';
    }).toList();
  }

  List<LeadModel> _liaisonTeamLeads(List<LeadModel> leads) {
    return _financeLeads(leads).where((lead) {
      final status = lead.status.toLowerCase();
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Liaison Completed':
        return Colors.orange;
      case 'Finance Verification Started':
        return Colors.blue;
      case 'Loan Approved':
        return Colors.green;
      default:
        return primaryColor;
    }
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
        backgroundColor: bgColor,
        drawer: _drawer(),
        appBar: AppBar(
          backgroundColor: bgColor,
          foregroundColor: textColor,
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
                onPressed: () {
                  ref.read(authProvider.notifier).refreshProfile();
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
          title: Text(
            _pageTitle(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _refreshLeads,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: () => setState(() => selectedPage = 2),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: leadsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
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
              index: selectedPage,
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
      case 1:
        return 'Liaison Team';
      case 2:
        return 'Notifications';
      default:
        return 'Finance Team';
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
      backgroundColor: drawerBgColor,
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
                    icon: Icons.account_tree_rounded,
                    title: 'Liaison Team',
                    selected: selectedPage == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => selectedPage = 1);
                    },
                  ),
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
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'F';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            Color(0xFFBFC6FF),
          ],
        ),
        borderRadius: BorderRadius.only(
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
              textColor: primaryColor,
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
            ? primaryColor
            : textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? primaryColor.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
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
                      primaryColor,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, accentColor],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.24),
            blurRadius: 24,
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

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAF2)),
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
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCard(double quotationTotal) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAF2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.green.withOpacity(0.12),
            child: const Icon(
              Icons.currency_rupee_rounded,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quotation Value',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rs ${quotationTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAF2)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: primaryColor.withOpacity(0.10),
            child: const Icon(
              Icons.inbox_rounded,
              color: primaryColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _leadCard(LeadModel lead) {
    final color = _statusColor(lead.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE7EAF2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: primaryColor.withOpacity(0.12),
                child: const Icon(Icons.person, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lead.fullName.isEmpty ? 'Customer Lead' : lead.fullName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lead.status.isEmpty ? 'No Status' : lead.status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _shortInfo(Icons.confirmation_number, 'Lead Code: ${lead.leadCode}'),
          _shortInfo(Icons.phone, 'Mobile: ${lead.mobile}'),
          _shortInfo(Icons.email_outlined, 'Email: ${lead.email}'),
          _shortInfo(Icons.confirmation_number, 'CA: ${lead.caNumber}'),
          _shortInfo(Icons.numbers, 'K No: ${lead.kNumber}'),
          _shortInfo(Icons.business, 'Discom: ${lead.discom}'),
          _shortInfo(
            Icons.currency_rupee,
            'Quotation: ${lead.quotationAmount}',
          ),
          _shortInfo(Icons.account_balance, 'Bank: ${lead.bankName}'),
          _shortInfo(Icons.flag, 'Stage: ${lead.leadStage}'),
          _shortInfo(Icons.business_center, 'Dept: ${lead.currentDepartment}'),
          if (lead.notes.trim().isNotEmpty)
            _shortInfo(Icons.edit_note_rounded, 'Notes: ${lead.notes}'),
          const SizedBox(height: 14),
          _actionButton(lead),
        ],
      ),
    );
  }

  Widget _shortInfo(IconData icon, String value) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty ||
        cleanValue.endsWith(':') ||
        cleanValue.endsWith(': ')) {
      return const SizedBox.shrink();
    }

    final parts = cleanValue.split(':');
    if (parts.length > 1 && parts.sublist(1).join(':').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cleanValue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
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

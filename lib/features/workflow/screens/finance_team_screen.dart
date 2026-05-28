import 'package:flutter/material.dart';

import '../../auth/auth_session.dart';
import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';
import '../../notifications/screens/notifications_screen.dart';

class FinanceTeamScreen extends StatefulWidget {
  const FinanceTeamScreen({super.key});

  @override
  State<FinanceTeamScreen> createState() => _FinanceTeamScreenState();
}

class _FinanceTeamScreenState extends State<FinanceTeamScreen> {
  static const bgColor = Color(0xfff4f7fb);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const accentColor = Color(0xFF18A999);
  static const textColor = Color(0xFF1F2028);

  int selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _loadLatestLeads();
  }

  Future<void> _loadLatestLeads() async {
    await HomeScreen.loadLeads();
    if (mounted) setState(() {});
  }

  List<LeadModel> get financeLeads {
    return HomeScreen.leads.where((lead) {
      return lead.status == 'Liaison Completed' ||
          lead.status == 'Finance Verification Started' ||
          lead.status == 'Loan Approved';
    }).toList();
  }

  List<LeadModel> get liaisonTeamLeads {
    return financeLeads.where((lead) {
      return lead.status == 'Liaison Completed' ||
          lead.status == 'Finance Verification Started';
    }).toList();
  }

  Future<void> _updateLead(LeadModel oldLead, LeadModel updatedLead) async {
    final index = HomeScreen.leads.indexOf(oldLead);
    if (index == -1) return;

    setState(() {
      HomeScreen.leads[index] = updatedLead;
    });

    await HomeScreen.saveLeads();
  }

  Future<void> _changeStatus(LeadModel lead, String status) async {
    await _updateLead(
      lead,
      lead.copyWith(status: status),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated: $status')),
    );
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = financeLeads;
    final liaisonLeads = liaisonTeamLeads;

    return WillPopScope(
      onWillPop: () async {
        if (selectedPage != 0) {
          setState(() => selectedPage = 0);
        }
        return false;
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
                onPressed: () => Scaffold.of(context).openDrawer(),
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
              onPressed: () => setState(() => selectedPage = 2),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: selectedPage,
          children: [
            _dashboard(leads),
            liaisonLeads.isEmpty
                ? _emptyState(
                    'No leads received from Liaison Team',
                    'Completed liaison leads will appear here for finance verification.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: liaisonLeads.map(_leadCard).toList(),
                  ),
            const NotificationsScreen(),
          ],
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
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.solar_power_rounded,
                size: 80,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Finance Team',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 38),
              _drawerItem(Icons.dashboard_rounded, 'Dashboard', 0),
              _drawerItem(Icons.account_tree_rounded, 'Liaison Team', 1),
              _drawerItem(Icons.notifications_none_rounded, 'Notifications', 2),
              const Spacer(),
              ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  await AuthSession.logout(context);
                },
                leading: const Icon(
                  Icons.logout_rounded,
                  color: primaryColor,
                  size: 30,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int page) {
    final selected = selectedPage == page;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? primaryColor.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          setState(() => selectedPage = page);
        },
        leading: Icon(icon, color: primaryColor, size: 30),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _dashboard(List<LeadModel> leads) {
    final fromLiaison = liaisonTeamLeads.length;
    final verificationCount = leads
        .where((lead) => lead.status == 'Finance Verification Started')
        .length;
    final approvedCount =
        leads.where((lead) => lead.status == 'Loan Approved').length;
    final quotationTotal = leads.fold<double>(
      0,
      (value, lead) =>
          value + (double.tryParse(lead.quotationAmount.trim()) ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _loadLatestLeads,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _financeHeroCard(
            total: leads.length,
            fromLiaison: fromLiaison,
            approved: approvedCount,
          ),
          const SizedBox(height: 16),
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
                  'Liaison',
                  fromLiaison.toString(),
                  Icons.account_tree_rounded,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Verification',
                  verificationCount.toString(),
                  Icons.verified_user_rounded,
                  Colors.blue,
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
          const SizedBox(height: 14),
          _valueCard(quotationTotal),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Finance Leads',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedPage = 1),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (leads.isEmpty)
            _emptyState(
              'No leads received from Liaison Team',
              'Finance-ready leads will show up here automatically.',
            )
          else
            ...leads.take(4).map(_leadCard),
        ],
      ),
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
          colors: [
            Color(0xFF5663A0),
            Color(0xFF18A999),
          ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Finance desk',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Finance Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
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
    );
  }

  Widget _metricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
            style: const TextStyle(
              color: Colors.black54,
              height: 1.4,
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: primaryColor.withOpacity(0.12),
                child: const Icon(
                  Icons.person,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lead.name.isEmpty ? 'Customer Lead' : lead.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lead.status,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          _shortInfo(Icons.phone, lead.mobile),
          _shortInfo(Icons.email_outlined, lead.email),
          _shortInfo(Icons.confirmation_number, 'CA: ${lead.caNo}'),
          _shortInfo(Icons.numbers, 'K No: ${lead.kNo}'),
          _shortInfo(Icons.business, 'Discom: ${lead.discom}'),
          _shortInfo(Icons.currency_rupee, 'Quotation: ${lead.quotationAmount}'),
          _shortInfo(Icons.account_balance, 'Bank: ${lead.bankDetails}'),

          if (lead.liaisonNote.trim().isNotEmpty)
            _shortInfo(
              Icons.edit_note_rounded,
              'Liaison Note: ${lead.liaisonNote}',
            ),

          const SizedBox(height: 14),

          _actionButton(lead),
        ],
      ),
    );
  }

  Widget _shortInfo(IconData icon, String value) {
    if (value.trim().isEmpty ||
        value.trim() == 'CA:' ||
        value.trim() == 'K No:' ||
        value.trim() == 'Discom:' ||
        value.trim() == 'Quotation:' ||
        value.trim() == 'Bank:') {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(LeadModel lead) {
    if (lead.status == 'Liaison Completed') {
      return _mainButton(
        title: 'Start Finance Verification',
        icon: Icons.verified_user_rounded,
        color: Colors.orange,
        onTap: () => _changeStatus(
          lead,
          'Finance Verification Started',
        ),
      );
    }

    if (lead.status == 'Finance Verification Started') {
      return _mainButton(
        title: 'Approve Loan & Send To Installation',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        onTap: () => _changeStatus(
          lead,
          'Loan Approved',
        ),
      );
    }

    return const SizedBox();
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
        onPressed: onTap,
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

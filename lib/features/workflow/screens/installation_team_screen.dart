import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../auth/auth_session.dart';
import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';
import '../../notifications/screens/notifications_screen.dart';

class InstallationTeamScreen extends StatefulWidget {
  const InstallationTeamScreen({super.key});

  @override
  State<InstallationTeamScreen> createState() => _InstallationTeamScreenState();
}

class _InstallationTeamScreenState extends State<InstallationTeamScreen> {
  static const bgColor = Color(0xfff4f7fb);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const accentColor = Color(0xFF16A34A);
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

  List<LeadModel> get installationLeads {
    return HomeScreen.leads.where((lead) {
      return lead.status == 'Loan Approved' ||
          lead.status == 'Installation In Progress' ||
          lead.status == 'Installation Done';
    }).toList();
  }

  List<LeadModel> get financeTeamLeads {
    return installationLeads.where((lead) {
      return lead.status == 'Loan Approved' ||
          lead.status == 'Installation In Progress';
    }).toList();
  }

  bool _hasFile(String? path) => path != null && path.trim().isNotEmpty;

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
  }

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  List<String> _docsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split('|||').where((e) => e.trim().isNotEmpty).toList();
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
    await _updateLead(lead, lead.copyWith(status: status));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated: $status')),
    );
  }

  Future<List<String>> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null) return [];

    return result.paths
        .where((path) => path != null && path.trim().isNotEmpty)
        .map((path) => path!)
        .toList();
  }

  Future<void> _openCompleteInstallationForm(LeadModel lead) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteInstallationFormScreen(
          lead: lead,
          pickFiles: _pickFiles,
          isPdf: _isPdf,
        ),
      ),
    );

    if (result == null) return;

    final selectedFiles = result['files'] as List<String>;
    final note = result['note'] as String;

    final oldDocs = _docsFromString(lead.installationDocumentPath);
    final allDocs = [...oldDocs, ...selectedFiles].join('|||');

    await _updateLead(
      lead,
      lead.copyWith(
        installationNote: note,
        installationDocumentPath: allDocs,
        status: 'Installation Done',
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Installation completed. Lead sent to Support Team.'),
      ),
    );
  }

  int _totalDocs(LeadModel lead) {
    return [
          lead.aadhaarFrontPath,
          lead.aadhaarBackPath,
          lead.panFrontPath,
          lead.panBackPath,
          lead.electricityBillPath,
          lead.bankImagePath,
          lead.roofImagePath,
        ].where(_hasFile).length +
        _docsFromString(lead.customerDocuments).length +
        _docsFromString(lead.supportDocumentPath).length +
        _docsFromString(lead.liaisonDocumentPath).length +
        _docsFromString(lead.installationDocumentPath).length;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Loan Approved':
        return Colors.orange;
      case 'Installation In Progress':
        return Colors.blue;
      case 'Installation Done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = installationLeads;
    final financeLeads = financeTeamLeads;

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
                icon: const Icon(Icons.menu_rounded, size: 34),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          title: Text(
            _pageTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
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
            financeLeads.isEmpty
                ? _emptyState(
                    'No leads received from Finance Team',
                    'Approved finance leads will appear here for installation.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: financeLeads.map(_leadCard).toList(),
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
        return 'Finance Team';
      case 2:
        return 'Notifications';
      default:
        return 'Installation Team';
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
              const Icon(Icons.solar_power_rounded, size: 80, color: primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Installation Team',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 38),
              _drawerItem(Icons.dashboard_rounded, 'Dashboard', 0),
              _drawerItem(Icons.account_balance_rounded, 'Finance Team', 1),
              _drawerItem(Icons.notifications_none_rounded, 'Notifications', 2),
              const Spacer(),
              ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  await AuthSession.logout(context);
                },
                leading: const Icon(Icons.logout_rounded, color: primaryColor, size: 30),
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
    final fromFinance = financeTeamLeads.length;
    final inProgress =
        leads.where((lead) => lead.status == 'Installation In Progress').length;
    final completed =
        leads.where((lead) => lead.status == 'Installation Done').length;
    final docsCount = leads.fold<int>(0, (value, lead) => value + _totalDocs(lead));

    return RefreshIndicator(
      onRefresh: _loadLatestLeads,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _installationHeroCard(
            total: leads.length,
            fromFinance: fromFinance,
            completed: completed,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Ready',
                  fromFinance.toString(),
                  Icons.account_balance_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Progress',
                  inProgress.toString(),
                  Icons.engineering_rounded,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Done',
                  completed.toString(),
                  Icons.check_circle_rounded,
                  accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Docs',
                  docsCount.toString(),
                  Icons.folder_copy_rounded,
                  primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Installation Leads',
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
              'No leads received from Finance Team',
              'Finance-approved leads will show up here automatically.',
            )
          else
            ...leads.take(4).map(_leadCard),
        ],
      ),
    );
  }

  Widget _installationHeroCard({
    required int total,
    required int fromFinance,
    required int completed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5663A0), Color(0xFF16A34A)],
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
                  Icons.engineering_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Field workflow',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Installation Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$total active leads, $fromFinance from Finance Team, $completed completed',
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
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
            style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
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
            child: const Icon(Icons.inbox_rounded, color: primaryColor, size: 34),
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
                child: const Icon(Icons.person, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lead.name.isEmpty ? 'Customer Lead' : lead.name,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
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
          if (lead.liaisonNote.trim().isNotEmpty)
            _shortInfo(Icons.edit_note_rounded, 'Liaison: ${lead.liaisonNote}'),
          if (lead.installationNote.trim().isNotEmpty)
            _shortInfo(Icons.engineering_rounded, 'Installation completed'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDocumentsSheet(lead),
              icon: const Icon(Icons.folder_copy_rounded),
              label: Text('View Docs (${_totalDocs(lead)})'),
            ),
          ),
          const SizedBox(height: 12),
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
        value.trim() == 'Quotation:') {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(LeadModel lead) {
    if (lead.status == 'Loan Approved') {
      return _mainButton(
        title: 'Start Installation',
        icon: Icons.play_arrow_rounded,
        color: Colors.orange,
        onTap: () => _changeStatus(lead, 'Installation In Progress'),
      );
    }

    if (lead.status == 'Installation In Progress') {
      return _mainButton(
        title: 'Complete Installation',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        onTap: () => _openCompleteInstallationForm(lead),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  void _showDocumentsSheet(LeadModel lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Documents',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                _sectionTitle('Customer Documents'),
                _fileTile('Aadhaar Front', lead.aadhaarFrontPath),
                _fileTile('Aadhaar Back', lead.aadhaarBackPath),
                _fileTile('PAN Front', lead.panFrontPath),
                _fileTile('PAN Back', lead.panBackPath),
                _fileTile('Electricity Bill', lead.electricityBillPath),
                _fileTile('Bank Document', lead.bankImagePath),
                _fileTile('Roof Document', lead.roofImagePath),
                ..._docsFromString(lead.customerDocuments).asMap().entries.map(
                      (e) => _fileTile('Checklist Doc ${e.key + 1}', e.value),
                    ),
                const SizedBox(height: 10),
                _sectionTitle('Support Team Documents'),
                ..._docsFromString(lead.supportDocumentPath).asMap().entries.map(
                      (e) => _fileTile('Support Doc ${e.key + 1}', e.value),
                    ),
                const SizedBox(height: 10),
                _sectionTitle('Liaison Documents'),
                ..._docsFromString(lead.liaisonDocumentPath).asMap().entries.map(
                      (e) => _fileTile('Liaison Doc ${e.key + 1}', e.value),
                    ),
                const SizedBox(height: 10),
                _sectionTitle('Installation Documents'),
                ..._docsFromString(lead.installationDocumentPath).asMap().entries.map(
                      (e) => _fileTile('Installation Doc ${e.key + 1}', e.value),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _fileTile(String title, String? path) {
    if (!_hasFile(path)) return const SizedBox();

    final filePath = path!;
    final isPdf = _isPdf(filePath);
    final isImage = _isImage(filePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: () {
          if (isImage) {
            _openImage(filePath);
          } else {
            OpenFilex.open(filePath);
          }
        },
        leading: Icon(
          isPdf ? Icons.picture_as_pdf : Icons.image,
          color: isPdf ? Colors.red : primaryColor,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          filePath.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new, color: primaryColor),
      ),
    );
  }

  void _openImage(String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          height: 260,
                          alignment: Alignment.center,
                          color: Colors.white,
                          child: const Text('Image not found'),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CompleteInstallationFormScreen extends StatefulWidget {
  final LeadModel lead;
  final Future<List<String>> Function() pickFiles;
  final bool Function(String path) isPdf;

  const CompleteInstallationFormScreen({
    super.key,
    required this.lead,
    required this.pickFiles,
    required this.isPdf,
  });

  @override
  State<CompleteInstallationFormScreen> createState() =>
      _CompleteInstallationFormScreenState();
}

class _CompleteInstallationFormScreenState
    extends State<CompleteInstallationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final fileNo = TextEditingController();
  final clientName = TextEditingController();
  final capacity = TextEditingController();
  final date = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();

  final registrationId = TextEditingController();
  final registrationDateTime = TextEditingController();
  final paymentMode = TextEditingController();
  final bankNameBranch = TextEditingController();

  final state = TextEditingController();
  final district = TextEditingController();
  final blockVillage = TextEditingController();
  final address = TextEditingController();
  final pinCode = TextEditingController();
  final discomAgency = TextEditingController();
  final sanctionLoad = TextEditingController();

  final bankName = TextEditingController();
  final bankIfsc = TextEditingController();
  final bankBranch = TextEditingController();

  final sp1 = TextEditingController();
  final sp2 = TextEditingController();
  final sp3 = TextEditingController();
  final sp4 = TextEditingController();
  final sp5 = TextEditingController();
  final panelBrand = TextEditingController();
  final solarPanelCount = TextEditingController();
  final netMeterDate = TextEditingController();
  final discomInspectDate = TextEditingController();

  final quotationAmount = TextEditingController();
  final quotationRef = TextEditingController();
  final receiptFirst = TextEditingController();
  final totalAmount = TextEditingController();

  final transportDate = TextEditingController();
  final invoiceNo = TextEditingController();
  final ewayBillNo = TextEditingController();

  final agreementMadeDate = TextEditingController();
  final agreementSignDate = TextEditingController();
  final agreementUploadDate = TextEditingController();
  final delayReason = TextEditingController();

  final remarks = TextEditingController();

  final selectedFiles = <String>[];

  @override
  void initState() {
    super.initState();

    clientName.text = widget.lead.name;
    email.text = widget.lead.email;
    mobile.text = widget.lead.mobile;
    quotationAmount.text = widget.lead.quotationAmount;
    discomAgency.text = widget.lead.discom;
    bankNameBranch.text = widget.lead.bankDetails;
  }

  @override
  void dispose() {
    for (final c in [
      fileNo,
      clientName,
      capacity,
      date,
      email,
      mobile,
      registrationId,
      registrationDateTime,
      paymentMode,
      bankNameBranch,
      state,
      district,
      blockVillage,
      address,
      pinCode,
      discomAgency,
      sanctionLoad,
      bankName,
      bankIfsc,
      bankBranch,
      sp1,
      sp2,
      sp3,
      sp4,
      sp5,
      panelBrand,
      solarPanelCount,
      netMeterDate,
      discomInspectDate,
      quotationAmount,
      quotationRef,
      receiptFirst,
      totalAmount,
      transportDate,
      invoiceNo,
      ewayBillNo,
      agreementMadeDate,
      agreementSignDate,
      agreementUploadDate,
      delayReason,
      remarks,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label required';
    return null;
  }

  String? _mobileValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
      return 'Enter valid 10 digit mobile number';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v)) {
      return 'Enter valid email';
    }
    return null;
  }

  String? _pinCodeValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Enter valid 6 digit pin code';
    }
    return null;
  }

  String? _ifscValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.toUpperCase())) {
      return 'Enter valid IFSC code';
    }
    return null;
  }

  String? _numberValidator(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null) return '$label must be number';
    if (n < 0) return '$label cannot be negative';
    return null;
  }

  Future<void> _addFiles() async {
    final files = await widget.pickFiles();
    setState(() => selectedFiles.addAll(files));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload installation documents')),
      );
      return;
    }

    final note = '''
INSTALLATION COMPLETED

File No: ${fileNo.text}
Client Name: ${clientName.text}
Capacity: ${capacity.text}
Date: ${date.text}
Email: ${email.text}
Mobile: ${mobile.text}

REGISTRATION
Registration ID: ${registrationId.text}
Registration Date & Time: ${registrationDateTime.text}
Payment Mode: ${paymentMode.text}
Bank Name & Branch: ${bankNameBranch.text}

CLIENT DETAILS
State: ${state.text}
District: ${district.text}
Block/Village: ${blockVillage.text}
Address: ${address.text}
Pin Code: ${pinCode.text}
Discom Agency: ${discomAgency.text}
Sanction Load KW: ${sanctionLoad.text}

BANK DETAILS
Bank Name: ${bankName.text}
IFSC: ${bankIfsc.text}
Branch: ${bankBranch.text}

INSTALLATION DETAILS
S.P No.1: ${sp1.text}
S.P No.2: ${sp2.text}
S.P No.3: ${sp3.text}
S.P No.4: ${sp4.text}
S.P No.5: ${sp5.text}
Solar Panel Brand: ${panelBrand.text}
No. of Solar Panel: ${solarPanelCount.text}
Install Net Meter Date: ${netMeterDate.text}
Inspect of Discom Date: ${discomInspectDate.text}

PAYMENT
Quotation Amount: ${quotationAmount.text}
Quotation Ref No: ${quotationRef.text}
Receipt First: ${receiptFirst.text}
Total Amount: ${totalAmount.text}

TRANSPORTATION
Date: ${transportDate.text}
Invoice No: ${invoiceNo.text}
E-Way Bill No: ${ewayBillNo.text}

AGREEMENT
Agreement Made Date: ${agreementMadeDate.text}
Agreement Sign Date: ${agreementSignDate.text}
Agreement Upload Date: ${agreementUploadDate.text}
Reason of Delay: ${delayReason.text}

Remarks: ${remarks.text}
''';

    Navigator.pop(context, {
      'note': note.trim(),
      'files': selectedFiles,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        backgroundColor: const Color(0xfff4f7fb),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2028),
        title: const Text(
          'Complete Installation Form',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Basic Details'),
            _field(fileNo, 'File No.'),
            _field(clientName, 'Client Name', required: true),
            _field(
              capacity,
              'Capacity KW',
              required: true,
              keyboardType: TextInputType.number,
            ),
            _field(date, 'Date'),
            _field(email, 'Email ID', keyboardType: TextInputType.emailAddress),
            _field(mobile, 'Mobile', required: true, keyboardType: TextInputType.phone),
            _section('Registration'),
            _field(registrationId, 'Registration ID'),
            _field(registrationDateTime, 'Registration Date & Time'),
            _field(paymentMode, 'Payment Mode', required: true),
            _field(bankNameBranch, 'Bank Name & Branch'),
            _section('Client Details'),
            _field(state, 'State', required: true),
            _field(district, 'District', required: true),
            _field(blockVillage, 'Block / Village'),
            _field(address, 'Address', maxLines: 2, required: true),
            _field(pinCode, 'Pin Code', keyboardType: TextInputType.number),
            _field(discomAgency, 'Discom Agency', required: true),
            _field(sanctionLoad, 'Sanction Load KW', keyboardType: TextInputType.number),
            _section('Bank Details'),
            _field(bankName, 'Bank Name'),
            _field(bankIfsc, 'Bank IFSC Code'),
            _field(bankBranch, 'Bank Branch'),
            _section('Installation Details'),
            _field(sp1, 'S.P No. 1'),
            _field(sp2, 'S.P No. 2'),
            _field(sp3, 'S.P No. 3'),
            _field(sp4, 'S.P No. 4'),
            _field(sp5, 'S.P No. 5'),
            _field(panelBrand, 'Solar Panel Brand', required: true),
            _field(
              solarPanelCount,
              'No. of Solar Panel',
              required: true,
              keyboardType: TextInputType.number,
            ),
            _field(netMeterDate, 'Install Net Meter Date'),
            _field(discomInspectDate, 'Inspect of Discom Date'),
            _section('Payment Received'),
            _field(
              quotationAmount,
              'Total Quotation Amount',
              keyboardType: TextInputType.number,
            ),
            _field(quotationRef, 'Quotation Reference No.'),
            _field(receiptFirst, 'Receipt No. First'),
            _field(totalAmount, 'Total Amount', keyboardType: TextInputType.number),
            _section('Transportation'),
            _field(transportDate, 'Date of Transportation'),
            _field(invoiceNo, 'Invoice No.'),
            _field(ewayBillNo, 'E-Way Bill No.'),
            _section('Agreement'),
            _field(agreementMadeDate, 'Agreement Made Date'),
            _field(agreementSignDate, 'Agreement Sign Date'),
            _field(agreementUploadDate, 'Agreement Upload Date'),
            _field(delayReason, 'Reason of Delay', maxLines: 2),
            _section('Final Remarks'),
            _field(
              remarks,
              'Installation report / panel setup / inverter details',
              maxLines: 4,
              required: true,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('Add Photos / PDF Reports'),
            ),
            const SizedBox(height: 8),
            ...selectedFiles.map(
              (path) => Card(
                child: ListTile(
                  leading: Icon(widget.isPdf(path) ? Icons.picture_as_pdf : Icons.image),
                  title: Text(
                    path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => selectedFiles.remove(path)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle),
              label: const Text('Submit & Complete Installation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2028),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (required) {
            final requiredError = _requiredValidator(value, label);
            if (requiredError != null) return requiredError;
          }

          final lower = label.toLowerCase();

          if (lower.contains('mobile')) return _mobileValidator(value);
          if (lower.contains('email')) return _emailValidator(value);
          if (lower.contains('pin code')) return _pinCodeValidator(value);
          if (lower.contains('ifsc')) return _ifscValidator(value);

          if (lower.contains('amount') ||
              lower.contains('capacity') ||
              lower.contains('solar panel') ||
              lower.contains('sanction load')) {
            return _numberValidator(value, label);
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
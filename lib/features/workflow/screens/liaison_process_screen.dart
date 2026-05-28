import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../auth/auth_session.dart';
import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';
import '../../notifications/screens/notifications_screen.dart';

class LiaisonProcessScreen extends StatefulWidget {
  const LiaisonProcessScreen({super.key});

  @override
  State<LiaisonProcessScreen> createState() => _LiaisonProcessScreenState();
}

class _LiaisonProcessScreenState extends State<LiaisonProcessScreen> {
  static const bgColor = Color(0xfff4f7fb);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const accentColor = Color(0xFF20B486);
  static const textColor = Color(0xFF1F2028);

  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadLatestLeads();
  }

  Future<void> _loadLatestLeads() async {
    await HomeScreen.loadLeads();
    if (mounted) setState(() {});
  }

  List<LeadModel> get liaisonLeads {
    return HomeScreen.leads.where((lead) {
      return lead.status == 'Documents Submitted' ||
          lead.status == 'Liaison Process Started' ||
          lead.status == 'Bank Coordination In Progress' ||
          lead.status == 'Sent For Final Liaison' ||
          lead.status == 'Meter Process Started';
    }).toList();
  }

  List<String> _docsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split('|||').where((e) => e.trim().isNotEmpty).toList();
  }

  bool _hasFile(String? path) => path != null && path.trim().isNotEmpty;

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
  }

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

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

  Future<void> _openNoteAndFilesDialog(LeadModel lead) async {
    final noteController = TextEditingController(text: lead.liaisonNote);
    final selectedFiles = <String>[];

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Add Liaison Note',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: noteController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Bank / authority coordination note...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final files = await _pickFiles();
                            dialogSetState(() {
                              selectedFiles.addAll(files);
                            });
                          },
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add PDF / Images'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...selectedFiles.map(
                        (path) => ListTile(
                          dense: true,
                          leading: Icon(
                            _isPdf(path)
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            color: _isPdf(path) ? Colors.red : primaryColor,
                          ),
                          title: Text(
                            path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              dialogSetState(() {
                                selectedFiles.remove(path);
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (noteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter note')),
                      );
                      return;
                    }

                    final oldDocs = _docsFromString(lead.liaisonDocumentPath);
                    final allDocs = [...oldDocs, ...selectedFiles].join('|||');

                    await _updateLead(
                      lead,
                      lead.copyWith(
                        liaisonNote: noteController.text.trim(),
                        liaisonDocumentPath: allDocs,
                        status: 'Liaison Completed',
                      ),
                    );

                    if (!mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lead sent to Finance Team'),
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
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
        _docsFromString(lead.liaisonDocumentPath).length;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Documents Submitted':
        return Colors.orange;
      case 'Liaison Process Started':
        return Colors.blue;
      case 'Bank Coordination In Progress':
        return Colors.indigo;
      case 'Liaison Completed':
        return Colors.green;
      case 'Sent For Final Liaison':
        return Colors.deepPurple;
      case 'Meter Process Started':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = liaisonLeads;
    final supportLeads = leads
        .where(
          (lead) => _docsFromString(lead.supportDocumentPath).isNotEmpty,
        )
        .toList();

    return WillPopScope(
      onWillPop: () async {
        if (selectedTab != 0) {
          setState(() => selectedTab = 0);
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
          title: Text(
            _pageTitle(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() => selectedTab = 2),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        body: IndexedStack(
          index: selectedTab,
          children: [
            _dashboard(leads),
            supportLeads.isEmpty
                ? _emptyState(
                    'No support documents received',
                    'Documents shared by the Support Team will appear here.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: supportLeads.map(_leadCard).toList(),
                  ),
            const NotificationsScreen(),
          ],
        ),
      ),
    );
  }

  String _pageTitle() {
    switch (selectedTab) {
      case 1:
        return 'From Support Team';
      case 2:
        return 'Notifications';
      default:
        return 'Liaison Officer';
    }
  }

  Widget _dashboard(List<LeadModel> leads) {
    final bankCount = leads
        .where((lead) => lead.status == 'Bank Coordination In Progress')
        .length;
    final meterCount =
        leads.where((lead) => lead.status == 'Meter Process Started').length;
    final docsCount = leads.fold<int>(
      0,
      (value, lead) => value + _totalDocs(lead),
    );

    return RefreshIndicator(
      onRefresh: _loadLatestLeads,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _heroDashboardCard(leads.length, bankCount, meterCount),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Leads',
                  leads.length.toString(),
                  Icons.groups_rounded,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Documents',
                  docsCount.toString(),
                  Icons.folder_copy_rounded,
                  accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Bank',
                  bankCount.toString(),
                  Icons.account_balance_rounded,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Meter',
                  meterCount.toString(),
                  Icons.electric_meter_rounded,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Liaison Leads',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => selectedTab = 1),
                child: const Text('View docs'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (leads.isEmpty)
            _emptyState(
              'No leads received from Support Team',
              'New verified leads will show up here automatically.',
            )
          else
            ...leads.take(4).map(_leadCard),
        ],
      ),
    );
  }

  Widget _heroDashboardCard(int total, int bank, int meter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5663A0),
            Color(0xFF20B486),
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
                  Icons.solar_power_rounded,
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
                  'Live workflow',
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
            'Liaison Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$total active leads, $bank in bank coordination, $meter in meter process',
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

  Widget _drawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.solar_power_rounded,
                size: 80,
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Liaison Officer',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              _drawerItem(Icons.dashboard_rounded, 'Dashboard', 0),
              _drawerItem(Icons.support_agent_rounded, 'From Support Team', 1),
              _drawerItem(Icons.notifications_none_rounded, 'Notifications', 2),
              const Spacer(),
              ListTile(
                onTap: () async {
                  Navigator.pop(context);
                  await AuthSession.logout(context);
                },
                leading: const Icon(Icons.logout_rounded, color: primaryColor),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int tab) {
    final selected = selectedTab == tab;

    return ListTile(
      onTap: () {
        Navigator.pop(context);
        setState(() => selectedTab = tab);
      },
      leading: Icon(icon, color: primaryColor),
      selected: selected,
      selectedTileColor: primaryColor.withOpacity(0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
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
          _shortInfo(Icons.note_alt_outlined, 'Support: ${lead.supportNotes}'),
          if (lead.liaisonNote.trim().isNotEmpty)
            _shortInfo(Icons.edit_note_rounded, 'Liaison: ${lead.liaisonNote}'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDocumentsSheet(lead),
                  icon: const Icon(Icons.folder_copy_rounded),
                  label: Text('View Docs (${_totalDocs(lead)})'),
                ),
              ),
            ],
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
        value.trim() == 'Support:') {
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
              maxLines: 1,
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
    if (lead.status == 'Documents Submitted') {
      return _mainButton(
        title: 'Start Liaison Process',
        icon: Icons.play_arrow_rounded,
        color: Colors.orange,
        onTap: () => _changeStatus(
          lead,
          'Liaison Process Started',
        ),
      );
    }

    if (lead.status == 'Liaison Process Started') {
      return _mainButton(
        title: 'Start Bank Coordination',
        icon: Icons.account_balance_rounded,
        color: Colors.blue,
        onTap: () => _changeStatus(
          lead,
          'Bank Coordination In Progress',
        ),
      );
    }

    if (lead.status == 'Bank Coordination In Progress') {
      return _mainButton(
        title: 'Add Note & Submit To Finance',
        icon: Icons.note_add_rounded,
        color: Colors.green,
        onTap: () => _openNoteAndFilesDialog(lead),
      );
    }

    if (lead.status == 'Sent For Final Liaison') {
      return _mainButton(
        title: 'Start Meter Process',
        icon: Icons.electric_meter_rounded,
        color: Colors.deepPurple,
        onTap: () => _changeStatus(
          lead,
          'Meter Process Started',
        ),
      );
    }

    if (lead.status == 'Meter Process Started') {
      return _mainButton(
        title: 'Complete Government Approval',
        icon: Icons.verified_rounded,
        color: Colors.teal,
        onTap: () => _changeStatus(
          lead,
          'Government Approval Completed',
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

  void _showDocumentsSheet(LeadModel lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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

                ..._docsFromString(lead.customerDocuments)
                    .asMap()
                    .entries
                    .map(
                      (e) => _fileTile(
                        'Checklist Doc ${e.key + 1}',
                        e.value,
                      ),
                    ),

                const SizedBox(height: 10),
                _sectionTitle('Support Team Documents'),

                ..._docsFromString(lead.supportDocumentPath)
                    .asMap()
                    .entries
                    .map(
                      (e) => _fileTile(
                        'Support Doc ${e.key + 1}',
                        e.value,
                      ),
                    ),

                const SizedBox(height: 10),
                _sectionTitle('Liaison Uploaded Documents'),

                ..._docsFromString(lead.liaisonDocumentPath)
                    .asMap()
                    .entries
                    .map(
                      (e) => _fileTile(
                        'Liaison Doc ${e.key + 1}',
                        e.value,
                      ),
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
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 10,
      ),
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
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          filePath.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.open_in_new,
          color: primaryColor,
        ),
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_session.dart';
import '../../home/screens/home_screen.dart';
import '../../leads/models/lead_model.dart';
import '../../notifications/screens/notifications_screen.dart';

class SupportTeamScreen extends StatefulWidget {
  const SupportTeamScreen({super.key});

  static final ValueNotifier<bool> openNewLeads = ValueNotifier(false);

  @override
  State<SupportTeamScreen> createState() => _SupportTeamScreenState();
}

class _SupportTeamScreenState extends State<SupportTeamScreen> {
  static const bgColor = Color(0xFFF7F8FC);
  static const cardColor = Colors.white;
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);
  static const _selectedPageKey = 'supportSelectedPage';

  int _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedPage();
    SupportTeamScreen.openNewLeads.addListener(_openNewLeadsFromDrawer);
  }

  @override
  void dispose() {
    SupportTeamScreen.openNewLeads.removeListener(_openNewLeadsFromDrawer);
    super.dispose();
  }

  void _openNewLeadsFromDrawer() {
    if (SupportTeamScreen.openNewLeads.value) {
      if (mounted) _setSelectedPage(1);
      SupportTeamScreen.openNewLeads.value = false;
    }
  }

  Future<void> _loadSelectedPage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt(_selectedPageKey) ?? 0;

    if (!mounted || savedPage < 0 || savedPage > 5) return;

    setState(() => _selectedPage = savedPage);
  }

  Future<void> _saveSelectedPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedPageKey, page);
  }

  void _setSelectedPage(int page) {
    setState(() => _selectedPage = page);
    _saveSelectedPage(page);
  }

  bool _hasFile(String? path) => path != null && path.trim().isNotEmpty;

  bool _isPdfFile(String path) => path.toLowerCase().endsWith('.pdf');

  bool _isImageFile(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
  }

  List<String> _docsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw
        .split('|||')
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList();
  }

  String _docsToString(List<String> docs) => docs.join('|||');

  List<String> _supportDocsFromLead(LeadModel lead) {
    return _docsFromString(lead.supportDocumentPath);
  }

  List<String> _customerDocsFromLead(LeadModel lead) {
    return _docsFromString(lead.customerDocuments);
  }

  List<String> _installationDocsFromLead(LeadModel lead) {
    return _docsFromString(lead.installationDocumentPath);
  }

  List<String> _downloadableDocs(LeadModel lead) {
    final docs = <String>[];

    void addIfPdf(String? path) {
      if (_hasFile(path) && _isPdfFile(path!)) docs.add(path);
    }

    addIfPdf(lead.aadhaarFrontPath);
    addIfPdf(lead.aadhaarBackPath);
    addIfPdf(lead.panFrontPath);
    addIfPdf(lead.panBackPath);
    addIfPdf(lead.electricityBillPath);
    addIfPdf(lead.bankImagePath);
    addIfPdf(lead.roofImagePath);

    docs.addAll(_customerDocsFromLead(lead).where((path) => !_isImageFile(path)));
    docs.addAll(_supportDocsFromLead(lead).where((path) => !_isImageFile(path)));
    docs.addAll(_installationDocsFromLead(lead).where((path) => !_isImageFile(path)));

    return docs;
  }

  int _allDocsCount(LeadModel lead) {
    return _supportDocsFromLead(lead).length +
        _customerDocsFromLead(lead).length +
        _installationDocsFromLead(lead).length +
        (_hasFile(lead.aadhaarFrontPath) ? 1 : 0) +
        (_hasFile(lead.aadhaarBackPath) ? 1 : 0) +
        (_hasFile(lead.panFrontPath) ? 1 : 0) +
        (_hasFile(lead.panBackPath) ? 1 : 0) +
        (_hasFile(lead.electricityBillPath) ? 1 : 0) +
        (_hasFile(lead.bankImagePath) ? 1 : 0) +
        (_hasFile(lead.roofImagePath) ? 1 : 0);
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
      case 'Loan Approved':
        return Colors.teal;
      case 'Installation In Progress':
        return Colors.deepOrange;
      case 'Installation Done':
        return Colors.green;
      case 'Sent To Liaison After Installation':
        return Colors.deepPurple;
      default:
        return primaryColor;
    }
  }

  Future<void> _sendInstallationLeadToLiaison(int index) async {
    final lead = HomeScreen.leads[index];

    HomeScreen.leads[index] = lead.copyWith(
      status: 'Sent To Liaison After Installation',
    );

    await HomeScreen.saveLeads();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lead sent to Liaison Team after installation.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = HomeScreen.leads;

    final docsCount = leads.fold<int>(
      0,
      (value, lead) => value + _allDocsCount(lead),
    );

    final notedCount =
        leads.where((lead) => lead.supportNotes.trim().isNotEmpty).length;

    final pendingCount = leads.length - notedCount;

    return WillPopScope(
      onWillPop: () async {
        if (_selectedPage != 0) {
          _setSelectedPage(0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        drawer: _drawer(),
        appBar: AppBar(
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
            _pageTitle(),
            style: const TextStyle(
              color: textColor,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: textColor,
                size: 31,
              ),
              onPressed: () => _setSelectedPage(5),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: _selectedPage,
          children: [
            _dashboard(leads.length, docsCount, notedCount, pendingCount),
            leads.isEmpty
                ? _emptyState('No new leads available')
                : _leadsList(leads),
            _documentsScreen(leads),
            _notesScreen(leads),
            _pendingScreen(leads),
            const NotificationsScreen(),
          ],
        ),
      ),
    );
  }

  String _pageTitle() {
    switch (_selectedPage) {
      case 1:
        return 'New Leads';
      case 2:
        return 'Documents';
      case 3:
        return 'Notes';
      case 4:
        return 'Pending';
      case 5:
        return 'Notifications';
      default:
        return 'Support Team';
    }
  }

  Widget _drawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 34),
            const Icon(Icons.solar_power_rounded, color: primaryColor, size: 76),
            const SizedBox(height: 18),
            const Text(
              'Support Team',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 36),
            _drawerItem(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              pageIndex: 0,
            ),
            _drawerItem(
              icon: Icons.people_alt_outlined,
              title: 'New Leads',
              pageIndex: 1,
            ),
            _drawerItem(
              icon: Icons.file_copy_outlined,
              title: 'Documents',
              pageIndex: 2,
            ),
            _drawerItem(
              icon: Icons.edit_note_rounded,
              title: 'Notes Added',
              pageIndex: 3,
            ),
            _drawerItem(
              icon: Icons.pending_actions_outlined,
              title: 'Pending',
              pageIndex: 4,
            ),
            _drawerItem(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              pageIndex: 5,
            ),
            const Spacer(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 28),
              leading: const Icon(
                Icons.logout_rounded,
                color: primaryColor,
                size: 33,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              onTap: () async {
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

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required int pageIndex,
  }) {
    final selected = _selectedPage == pageIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? primaryColor.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(icon, color: primaryColor, size: 33),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          _setSelectedPage(pageIndex);
        },
      ),
    );
  }

  Widget _dashboard(int total, int docs, int notes, int pending) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5663A0), Color(0xFF6C63FF)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.support_agent_rounded, color: Colors.white, size: 54),
                SizedBox(height: 22),
                Text(
                  'Support Lead Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Track customer leads, installation details and documents.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statCard(
                'New Leads',
                '$total',
                Icons.person_add_alt_1_rounded,
                pageIndex: 1,
              ),
              const SizedBox(width: 14),
              _statCard(
                'Documents',
                '$docs',
                Icons.file_copy_rounded,
                pageIndex: 2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCard(
                'Notes Added',
                '$notes',
                Icons.edit_note_rounded,
                pageIndex: 3,
              ),
              const SizedBox(width: 14),
              _statCard(
                'Pending',
                '$pending',
                Icons.pending_actions,
                pageIndex: 4,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _setSelectedPage(1),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open New Leads'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon, {
    required int pageIndex,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => _setSelectedPage(pageIndex),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE4E1EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: primaryColor, size: 36),
              const SizedBox(height: 24),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _leadsList(List<LeadModel> leads) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        return _leadCard(index, leads[index]);
      },
    );
  }

  Widget _documentsScreen(List<LeadModel> leads) {
    final filtered = leads.where((lead) => _allDocsCount(lead) > 0).toList();

    if (filtered.isEmpty) return _emptyState('No documents found');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final originalIndex = HomeScreen.leads.indexOf(filtered[index]);
        return _leadCard(originalIndex, filtered[index]);
      },
    );
  }

  Widget _notesScreen(List<LeadModel> leads) {
    final filtered =
        leads.where((lead) => lead.supportNotes.trim().isNotEmpty).toList();

    if (filtered.isEmpty) return _emptyState('No notes added');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final originalIndex = HomeScreen.leads.indexOf(filtered[index]);
        return _leadCard(originalIndex, filtered[index]);
      },
    );
  }

  Widget _pendingScreen(List<LeadModel> leads) {
    final filtered =
        leads.where((lead) => lead.supportNotes.trim().isEmpty).toList();

    if (filtered.isEmpty) return _emptyState('No pending leads');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final originalIndex = HomeScreen.leads.indexOf(filtered[index]);
        return _leadCard(originalIndex, filtered[index]);
      },
    );
  }

  Widget _leadCard(int index, LeadModel lead) {
    final allDocCount = _allDocsCount(lead);
    final downloadableCount = _downloadableDocs(lead).length;
    final statusColor = _statusColor(lead.status);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _openLeadDetails(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: const Color(0xFFE8E5EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryColor.withOpacity(0.12),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    lead.name.isEmpty ? 'Unknown Customer' : lead.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    lead.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _quickInfo(Icons.call_rounded, 'Mobile', lead.mobile),
            _quickInfo(Icons.confirmation_number_outlined, 'CA No', lead.caNo),
            _quickInfo(Icons.numbers_outlined, 'K No', lead.kNo),
            _quickInfo(Icons.business_outlined, 'Discom', lead.discom),
            if (lead.supportNotes.trim().isNotEmpty)
              _quickInfo(Icons.note_alt_outlined, 'Notes', lead.supportNotes),
            if (lead.installationNote.trim().isNotEmpty)
              _quickInfo(
                Icons.engineering_rounded,
                'Installation',
                'Installation form submitted',
              ),
            if (allDocCount > 0)
              _quickInfo(
                Icons.attach_file_rounded,
                'Documents',
                '$allDocCount files available',
              ),
            if (downloadableCount > 0)
              _quickInfo(
                Icons.download_rounded,
                'Separate Docs',
                '$downloadableCount PDF files need separate open',
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLeadDetails(index),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createPdf(lead),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDownloadableDocs(lead),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Docs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          downloadableCount > 0 ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickInfo(IconData icon, String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          Text(
            '$title: ',
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _openLeadDetails(int index) {
    LeadModel currentLead = HomeScreen.leads[index];
    final notesController =
        TextEditingController(text: currentLead.supportNotes);
    List<String> selectedSupportDocs = _supportDocsFromLead(currentLead);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            currentLead = HomeScreen.leads[index];
            final customerDocs = _customerDocsFromLead(currentLead);
            final installationDocs = _installationDocsFromLead(currentLead);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.92,
                maxChildSize: 0.98,
                minChildSize: 0.55,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetHandle(),
                        const SizedBox(height: 20),
                        _detailHeader(currentLead),
                        const SizedBox(height: 18),
                        _section(
                          title: 'Customer Details',
                          children: [
                            _row('Name', currentLead.name),
                            _row('Mobile', currentLead.mobile),
                            _row('Email', currentLead.email),
                            _row('CA No', currentLead.caNo),
                            _row('K No', currentLead.kNo),
                            _row('Ref No', currentLead.refNo),
                            _row('Discom', currentLead.discom),
                            _row('Status', currentLead.status),
                          ],
                        ),
                        _section(
                          title: 'Customer Documents',
                          children: [
                            _fileBox(
                                'Aadhaar Front', currentLead.aadhaarFrontPath),
                            _fileBox(
                                'Aadhaar Back', currentLead.aadhaarBackPath),
                            _fileBox('PAN Front', currentLead.panFrontPath),
                            _fileBox('PAN Back', currentLead.panBackPath),
                            _fileBox('Electricity Bill',
                                currentLead.electricityBillPath),
                            if (!_hasFile(currentLead.aadhaarFrontPath) &&
                                !_hasFile(currentLead.aadhaarBackPath) &&
                                !_hasFile(currentLead.panFrontPath) &&
                                !_hasFile(currentLead.panBackPath) &&
                                !_hasFile(currentLead.electricityBillPath))
                              const Text(
                                'No customer documents uploaded',
                                style: TextStyle(color: Colors.black45),
                              ),
                          ],
                        ),
                        _section(
                          title: 'Multiple Checklist Documents',
                          children: [
                            if (customerDocs.isEmpty)
                              const Text(
                                'No checklist documents uploaded',
                                style: TextStyle(color: Colors.black45),
                              ),
                            ...customerDocs.asMap().entries.map(
                                  (entry) => _fileBox(
                                    'Checklist Doc ${entry.key + 1}',
                                    entry.value,
                                  ),
                                ),
                          ],
                        ),
                        _section(
                          title: 'Location Details',
                          children: [
                            _row('Geo Location', currentLead.geoLocation),
                            _row('Longitude', currentLead.longitude),
                            _row('Latitude', currentLead.latitude),
                          ],
                        ),
                        _section(
                          title: 'Bank & Roof Details',
                          children: [
                            _row('Bank Details', currentLead.bankDetails),
                            _fileBox(
                                'Bank Document', currentLead.bankImagePath),
                            _row('Roof Area', currentLead.roofArea),
                            _fileBox(
                                'Roof Document', currentLead.roofImagePath),
                            _row('Quotation', currentLead.quotationAmount),
                            _row('Employee', currentLead.employeeName),
                            _row('Staff Contact', currentLead.staffContact),
                          ],
                        ),
                        _section(
                          title: 'Installation Form Details',
                          children: [
                            if (currentLead.installationNote.trim().isEmpty)
                              const Text(
                                'No installation form details found',
                                style: TextStyle(color: Colors.black45),
                              )
                            else
                              _enhancedInstallationDetails(
                                currentLead.installationNote,
                              ),
                          ],
                        ),
                        _section(
                          title: 'Installation Photos / PDF Reports',
                          children: [
                            if (installationDocs.isEmpty)
                              const Text(
                                'No installation documents uploaded',
                                style: TextStyle(color: Colors.black45),
                              ),
                            ...installationDocs.asMap().entries.map(
                                  (entry) => _fileBox(
                                    'Installation Doc ${entry.key + 1}',
                                    entry.value,
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Support Notes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: notesController,
                          maxLines: 5,
                          scrollPadding: const EdgeInsets.only(bottom: 220),
                          decoration: InputDecoration(
                            hintText: 'Write support notes here...',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Support Uploaded Documents',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _documentsList(selectedSupportDocs, setModalState),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final paths = await _pickMultipleDocuments();
                            if (paths.isEmpty) return;

                            selectedSupportDocs.addAll(paths);

                            HomeScreen.leads[index] = currentLead.copyWith(
                              supportNotes: notesController.text.trim(),
                              supportDocumentPath:
                                  _docsToString(selectedSupportDocs),
                              status: currentLead.status == 'Installation Done'
                                  ? 'Installation Done'
                                  : 'Documents Submitted',
                            );

                            await HomeScreen.saveLeads();

                            setState(() {});
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload Multiple Support Docs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: const BorderSide(color: primaryColor),
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            HomeScreen.leads[index] = currentLead.copyWith(
                              supportNotes: notesController.text.trim(),
                              supportDocumentPath:
                                  _docsToString(selectedSupportDocs),
                              status: currentLead.status == 'Installation Done'
                                  ? 'Installation Done'
                                  : 'Documents Submitted',
                            );

                            await HomeScreen.saveLeads();

                            setState(() {});
                            if (!mounted) return;
                            Navigator.pop(context);

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  currentLead.status == 'Installation Done'
                                      ? 'Saved successfully.'
                                      : 'Saved successfully. Lead sent to Liaison Officer.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            currentLead.status == 'Installation Done'
                                ? 'Save Support Notes'
                                : 'Save & Send To Liaison',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _createPdf(HomeScreen.leads[index]),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Download Lead PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showDownloadableDocs(HomeScreen.leads[index]),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download Separate Docs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (HomeScreen.leads[index].status ==
                            'Installation Done')
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _sendInstallationLeadToLiaison(index);

                              if (!mounted) return;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Send To Liaison Team'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _enhancedInstallationDetails(String details) {
    final lines = details
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final widgets = <Widget>[];

    Widget statusBanner(String value) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.green.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionTitle(String title) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: primaryColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    Widget detailCard({
      required String label,
      required String value,
      required IconData icon,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryColor.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryColor, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      color: textColor,
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

    IconData iconForLabel(String label) {
      final lower = label.toLowerCase();

      if (lower.contains('file')) return Icons.folder_open_outlined;
      if (lower.contains('client name')) return Icons.person_outline_rounded;
      if (lower.contains('capacity')) return Icons.solar_power_outlined;
      if (lower.contains('date')) return Icons.calendar_month_outlined;
      if (lower.contains('email')) return Icons.email_outlined;
      if (lower.contains('mobile')) return Icons.call_outlined;
      if (lower.contains('registration')) return Icons.app_registration_outlined;
      if (lower.contains('payment')) return Icons.payments_outlined;
      if (lower.contains('bank')) return Icons.account_balance_outlined;
      if (lower.contains('aadhaar')) return Icons.badge_outlined;
      if (lower.contains('pan')) return Icons.credit_card_outlined;
      if (lower.contains('bill')) return Icons.receipt_long_outlined;
      if (lower.contains('cheque')) return Icons.account_balance_wallet_outlined;
      if (lower.contains('state')) return Icons.map_outlined;
      if (lower.contains('district')) return Icons.location_city_outlined;
      if (lower.contains('village') || lower.contains('block')) {
        return Icons.home_work_outlined;
      }
      if (lower.contains('address')) return Icons.location_on_outlined;
      if (lower.contains('pin')) return Icons.pin_drop_outlined;
      if (lower.contains('approval')) return Icons.verified_outlined;
      if (lower.contains('reference')) return Icons.confirmation_number_outlined;

      return Icons.info_outline_rounded;
    }

    for (final line in lines) {
      final upper = line.toUpperCase();

      if (!line.contains(':')) {
        if (upper.contains('INSTALLATION COMPLETED')) {
          widgets.add(statusBanner(line));
        } else {
          widgets.add(sectionTitle(line));
        }
        continue;
      }

      final parts = line.split(':');
      final label = parts.first.trim();
      final value = parts.sublist(1).join(':').trim();

      widgets.add(
        detailCard(
          label: label,
          value: value,
          icon: iconForLabel(label),
        ),
      );
    }

    if (widgets.isEmpty) {
      return Text(
        details,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 15,
          height: 1.4,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _documentsList(
    List<String> docs,
    void Function(void Function()) setModalState,
  ) {
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange.withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No support document uploaded yet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: docs.map((path) {
        final isPdf = _isPdfFile(path);
        final isImage = _isImageFile(path);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryColor.withOpacity(0.28)),
          ),
          child: ListTile(
            onTap: () {
              if (isImage) {
                _openImagePopup(path);
              } else {
                OpenFilex.open(path);
              }
            },
            leading: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : isImage
                      ? Icons.image_rounded
                      : Icons.insert_drive_file_rounded,
              color: isPdf ? Colors.red : primaryColor,
            ),
            title: Text(
              path.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isImage
                  ? 'Image available separately'
                  : 'This file opens/downloads separately',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: () {
                setModalState(() {
                  docs.remove(path);
                });
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<List<String>> _pickMultipleDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null) return [];

    return result.files
        .where((file) => file.path != null)
        .map((file) => file.path!)
        .toList();
  }

  void _showDownloadableDocs(LeadModel lead) {
    final docs = _downloadableDocs(lead);

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No separate downloadable documents found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 18),
                const Text(
                  'Download / Open Separate Documents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final path = docs[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4E1EA)),
                        ),
                        child: ListTile(
                          onTap: () => OpenFilex.open(path),
                          leading: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.red,
                            size: 34,
                          ),
                          title: Text(
                            path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text('Tap to open / download'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              color: primaryColor,
                            ),
                            onPressed: () => OpenFilex.open(path),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailHeader(LeadModel lead) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5663A0), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              lead.name.isEmpty ? 'Customer Lead' : lead.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPdf(LeadModel lead) async {
    try {
      final customerDocs = _customerDocsFromLead(lead);
      final supportDocs = _supportDocsFromLead(lead);
      final installationDocs = _installationDocsFromLead(lead);

      final pdf = pw.Document();

      pw.Widget sectionTitle(String title) {
        return pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
      }

      pw.Widget fileNameRow(String title, String? path) {
        if (!_hasFile(path)) return pw.SizedBox();
        return _pdfRow(title, path!.split('/').last);
      }

      List<pw.Widget> installationDetailsWidgets(String text) {
        if (text.trim().isEmpty) {
          return [
            pw.Text(
              'No installation form details found',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ];
        }

        final lines = text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        return lines.map((line) {
          if (!line.contains(':')) {
            return pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 8, bottom: 5),
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }

          final parts = line.split(':');
          final label = parts.first.trim();
          final value = parts.sublist(1).join(':').trim();

          return _pdfRow(label, value);
        }).toList();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          maxPages: 100,
          build: (context) => [
            pw.Text(
              'Solar Lead Details',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 14),
            sectionTitle('Customer Details'),
            _pdfRow('Name', lead.name),
            _pdfRow('Mobile', lead.mobile),
            _pdfRow('Email', lead.email),
            _pdfRow('CA No', lead.caNo),
            _pdfRow('K No', lead.kNo),
            _pdfRow('Ref No', lead.refNo),
            _pdfRow('Discom', lead.discom),
            _pdfRow('Status', lead.status),
            sectionTitle('Location Details'),
            _pdfRow('Geo Location', lead.geoLocation),
            _pdfRow('Longitude', lead.longitude),
            _pdfRow('Latitude', lead.latitude),
            sectionTitle('Bank & Roof Details'),
            _pdfRow('Bank Details', lead.bankDetails),
            _pdfRow('Roof Area', lead.roofArea),
            _pdfRow('Quotation Amount', lead.quotationAmount),
            _pdfRow('Employee Name', lead.employeeName),
            _pdfRow('Staff Contact', lead.staffContact),
            sectionTitle('Support Notes'),
            _pdfRow('Notes', lead.supportNotes),
            sectionTitle('Installation Form Details'),
            ...installationDetailsWidgets(lead.installationNote),
            sectionTitle('Main Uploaded Documents'),
            fileNameRow('Aadhaar Front', lead.aadhaarFrontPath),
            fileNameRow('Aadhaar Back', lead.aadhaarBackPath),
            fileNameRow('PAN Front', lead.panFrontPath),
            fileNameRow('PAN Back', lead.panBackPath),
            fileNameRow('Electricity Bill', lead.electricityBillPath),
            fileNameRow('Bank Document', lead.bankImagePath),
            fileNameRow('Roof Document', lead.roofImagePath),
            sectionTitle('Multiple Checklist Documents'),
            if (customerDocs.isEmpty) pw.Text('No checklist documents uploaded'),
            ...customerDocs.asMap().entries.map(
                  (entry) => _pdfRow(
                    'Checklist Doc ${entry.key + 1}',
                    entry.value.split('/').last,
                  ),
                ),
            sectionTitle('Support Uploaded Documents'),
            if (supportDocs.isEmpty) pw.Text('No support documents uploaded'),
            ...supportDocs.asMap().entries.map(
                  (entry) => _pdfRow(
                    'Support Doc ${entry.key + 1}',
                    entry.value.split('/').last,
                  ),
                ),
            sectionTitle('Installation Photos / PDF Reports'),
            if (installationDocs.isEmpty)
              pw.Text('No installation documents uploaded'),
            ...installationDocs.asMap().entries.map(
                  (entry) => _pdfRow(
                    'Installation Doc ${entry.key + 1}',
                    entry.value.split('/').last,
                  ),
                ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Note: Images and PDF documents are listed here. Open/download original files from Docs button.',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();

      final safeName = lead.name.trim().isEmpty
          ? 'lead'
          : lead.name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

      final file = File('${dir.path}/${safeName}_details.pdf');

      await file.writeAsBytes(await pdf.save());

      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: ${file.path}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('PDF ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generation failed: $e'),
        ),
      );
    }
  }

  pw.Widget _pdfRow(String title, String value) {
    if (value.trim().isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 130,
            child: pw.Text(
              '$title:',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileBox(String title, String? path) {
    if (!_hasFile(path)) return const SizedBox.shrink();

    if (_isPdfFile(path!)) return _pdfBox(title, path);

    return _imageBox(title, path);
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Widget _imageBox(String title, String path) {
    return InkWell(
      onTap: () => _openImagePopup(path),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E1EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(path),
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: const Text('Image not found'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfBox(String title, String path) {
    return InkWell(
      onTap: () => OpenFilex.open(path),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4E1EA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            const Icon(Icons.open_in_new, color: primaryColor),
          ],
        ),
      ),
    );
  }

  void _openImagePopup(String imagePath) {
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
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 260,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Image not found',
                            style: TextStyle(color: Colors.black54),
                          ),
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

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 55,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
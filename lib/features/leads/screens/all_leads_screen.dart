import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../home/screens/home_screen.dart';
import '../models/lead_model.dart';

class AllLeadsScreen extends StatefulWidget {
  const AllLeadsScreen({super.key});

  @override
  State<AllLeadsScreen> createState() => _AllLeadsScreenState();
}

class _AllLeadsScreenState extends State<AllLeadsScreen> {
  static const Color bgColor = Color(0xFFFAF8FF);
  static const Color cardColor = Colors.white;
  static const Color primaryColor = Color(0xFF5663A0);
  static const Color textColor = Color(0xFF1F2028);

  bool _hasFile(String? path) => path != null && path.trim().isNotEmpty;

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  bool _isImage(String path) {
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

  Future<String?> _pickSingleDoc() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.single.path == null) return null;
    return result.files.single.path!;
  }

  Future<List<String>> _pickMultipleDocs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null) return [];

    return result.files
        .where((e) => e.path != null)
        .map((e) => e.path!)
        .toList();
  }

  void _openFile(String path) {
    if (_isPdf(path)) {
      OpenFilex.open(path);
    } else {
      _openImagePopup(path);
    }
  }

  int _docCount(LeadModel lead) {
    return (_hasFile(lead.aadhaarFrontPath) ? 1 : 0) +
        (_hasFile(lead.aadhaarBackPath) ? 1 : 0) +
        (_hasFile(lead.panFrontPath) ? 1 : 0) +
        (_hasFile(lead.panBackPath) ? 1 : 0) +
        (_hasFile(lead.electricityBillPath) ? 1 : 0) +
        (_hasFile(lead.bankImagePath) ? 1 : 0) +
        (_hasFile(lead.roofImagePath) ? 1 : 0) +
        _docsFromString(lead.customerDocuments).length;
  }

  @override
  Widget build(BuildContext context) {
    final leads = HomeScreen.leads;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: textColor),
        title: const Text(
          'All Leads',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: leads.isEmpty
          ? _emptyLeads()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leads.length,
              itemBuilder: (context, index) {
                final lead = leads[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE7E3F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _leadHeader(lead),
                      const SizedBox(height: 18),
                      _infoTile(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: lead.email,
                      ),
                      _infoTile(
                        icon: Icons.call_outlined,
                        title: 'Mobile',
                        value: lead.mobile,
                      ),
                      _infoTile(
                        icon: Icons.confirmation_number_outlined,
                        title: 'CA No',
                        value: lead.caNo,
                      ),
                      _infoTile(
                        icon: Icons.numbers_outlined,
                        title: 'K No',
                        value: lead.kNo,
                      ),
                      _infoTile(
                        icon: Icons.business_outlined,
                        title: 'Discom',
                        value: lead.discom,
                      ),
                      _infoTile(
                        icon: Icons.location_on_outlined,
                        title: 'Location',
                        value: lead.geoLocation,
                      ),
                      _infoTile(
                        icon: Icons.currency_rupee,
                        title: 'Quotation',
                        value: lead.quotationAmount,
                      ),
                      const SizedBox(height: 14),
                      _documentPreviewWrap(lead),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showLeadDetails(lead),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('View'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: const BorderSide(color: primaryColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showEditLeadSheet(index, lead),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _leadHeader(LeadModel lead) {
    final count = _docCount(lead);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: primaryColor.withOpacity(0.12),
          child: const Icon(
            Icons.person_outline,
            color: primaryColor,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.name.trim().isEmpty ? 'Unknown Customer' : lead.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lead.mobile.trim().isEmpty ? 'No mobile number' : lead.mobile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: count > 0
                ? Colors.green.withOpacity(0.12)
                : primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            count > 0 ? '$count Docs' : 'New Lead',
            style: TextStyle(
              color: count > 0 ? Colors.green : primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _documentPreviewWrap(LeadModel lead) {
    final docs = <Widget>[];

    void addDoc(String title, String? path) {
      if (_hasFile(path)) {
        docs.add(
          SizedBox(
            width: 150,
            child: _smallFileBox(
              title: title,
              path: path!,
            ),
          ),
        );
      }
    }

    addDoc('Aadhaar Front', lead.aadhaarFrontPath);
    addDoc('Aadhaar Back', lead.aadhaarBackPath);
    addDoc('PAN Front', lead.panFrontPath);
    addDoc('PAN Back', lead.panBackPath);
    addDoc('Electricity Bill', lead.electricityBillPath);
    addDoc('Bank Document', lead.bankImagePath);
    addDoc('Roof Document', lead.roofImagePath);

    final customerDocs = _docsFromString(lead.customerDocuments);

    for (int i = 0; i < customerDocs.length; i++) {
      docs.add(
        SizedBox(
          width: 150,
          child: _smallFileBox(
            title: 'Checklist Doc ${i + 1}',
            path: customerDocs[i],
          ),
        ),
      );
    }

    if (docs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: docs,
    );
  }

  Widget _smallFileBox({
    required String title,
    required String path,
  }) {
    final pdf = _isPdf(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openFile(path),
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: pdf
                ? Container(
                    height: 105,
                    width: double.infinity,
                    color: bgColor,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 38,
                        ),
                        SizedBox(height: 6),
                        Text('Open PDF'),
                      ],
                    ),
                  )
                : Image.file(
                    File(path),
                    height: 105,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _imageErrorBox(height: 105);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _emptyLeads() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt_outlined, color: primaryColor, size: 80),
          SizedBox(height: 16),
          Text(
            'No leads added yet',
            style: TextStyle(
              color: primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: primaryColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              title,
              style: const TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeadDetails(LeadModel lead) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (context, scrollController) {
            final customerDocs = _docsFromString(lead.customerDocuments);

            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bottomSheetHandle(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primaryColor.withOpacity(0.12),
                        child: const Icon(
                          Icons.person_outline,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          lead.name.trim().isEmpty
                              ? 'Unknown Customer'
                              : lead.name,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _detailSection(
                    title: 'Basic KYC',
                    children: [
                      _detailRow('Name', lead.name),
                      _detailRow('Mobile', lead.mobile),
                      _detailRow('Email', lead.email),
                      _detailRow('CA No', lead.caNo),
                      _detailRow('K No', lead.kNo),
                      _detailRow('Ref No', lead.refNo),
                      _detailRow('Discom', lead.discom),
                    ],
                  ),
                  _detailSection(
                    title: 'Customer Documents',
                    children: [
                      _detailFile('Aadhaar Front', lead.aadhaarFrontPath),
                      _detailFile('Aadhaar Back', lead.aadhaarBackPath),
                      _detailFile('PAN Front', lead.panFrontPath),
                      _detailFile('PAN Back', lead.panBackPath),
                      _detailFile('Electricity Bill', lead.electricityBillPath),
                    ],
                  ),
                  _detailSection(
                    title: 'Multiple Checklist Documents',
                    children: [
                      if (customerDocs.isEmpty)
                        const Text(
                          'No checklist documents uploaded',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ...customerDocs.asMap().entries.map(
                            (entry) => _detailFile(
                              'Checklist Doc ${entry.key + 1}',
                              entry.value,
                            ),
                          ),
                    ],
                  ),
                  _detailSection(
                    title: 'Location',
                    children: [
                      _detailRow('Geo Location', lead.geoLocation),
                      _detailRow('Longitude', lead.longitude),
                      _detailRow('Latitude', lead.latitude),
                    ],
                  ),
                  _detailSection(
                    title: 'Bank Details',
                    children: [
                      _detailRow('Bank Account', lead.bankDetails),
                      _detailFile('Bank / Passbook Document', lead.bankImagePath),
                    ],
                  ),
                  _detailSection(
                    title: 'Roof Document',
                    children: [
                      _detailFile('Roof Site Document', lead.roofImagePath),
                    ],
                  ),
                  _detailSection(
                    title: 'Site Checklist',
                    children: [
                      _detailRow('Roof Area', lead.roofArea),
                      _detailRow('Quotation Amount', lead.quotationAmount),
                      _detailRow('Employee Name', lead.employeeName),
                      _detailRow('Staff Contact', lead.staffContact),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailFile(String title, String? path) {
    if (!_hasFile(path)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          '$title: Not uploaded',
          style: const TextStyle(color: Colors.black45),
        ),
      );
    }

    final pdf = _isPdf(path!);

    if (pdf) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: InkWell(
          onTap: () => OpenFilex.open(path),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 90,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E3F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.open_in_new, color: primaryColor),
              ],
            ),
          ),
        ),
      );
    }

    return _largeImageBox(title, path);
  }

  Widget _largeImageBox(String title, String path) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _openImagePopup(path),
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(path),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _imageErrorBox(height: 160);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E3F0)),
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

  Widget _detailRow(String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditLeadSheet(int index, LeadModel lead) {
    final name = TextEditingController(text: lead.name);
    final mobile = TextEditingController(text: lead.mobile);
    final email = TextEditingController(text: lead.email);
    final caNo = TextEditingController(text: lead.caNo);
    final kNo = TextEditingController(text: lead.kNo);
    final refNo = TextEditingController(text: lead.refNo);
    final discom = TextEditingController(text: lead.discom);
    final geoLocation = TextEditingController(text: lead.geoLocation);
    final longitude = TextEditingController(text: lead.longitude);
    final latitude = TextEditingController(text: lead.latitude);
    final bankDetails = TextEditingController(text: lead.bankDetails);
    final roofArea = TextEditingController(text: lead.roofArea);
    final quotationAmount = TextEditingController(text: lead.quotationAmount);
    final employeeName = TextEditingController(text: lead.employeeName);
    final staffContact = TextEditingController(text: lead.staffContact);

    String? updatedAadhaarFront = lead.aadhaarFrontPath;
    String? updatedAadhaarBack = lead.aadhaarBackPath;
    String? updatedPanFront = lead.panFrontPath;
    String? updatedPanBack = lead.panBackPath;
    String? updatedElectricityBill = lead.electricityBillPath;
    String? updatedBankImage = lead.bankImagePath;
    String? updatedRoofImage = lead.roofImagePath;

    List<String> updatedDocs = _docsFromString(lead.customerDocuments);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> changeSingle(String type) async {
              final file = await _pickSingleDoc();
              if (file == null) return;

              setModalState(() {
                if (type == 'aadhaarFront') updatedAadhaarFront = file;
                if (type == 'aadhaarBack') updatedAadhaarBack = file;
                if (type == 'panFront') updatedPanFront = file;
                if (type == 'panBack') updatedPanBack = file;
                if (type == 'electricity') updatedElectricityBill = file;
                if (type == 'bank') updatedBankImage = file;
                if (type == 'roof') updatedRoofImage = file;
              });
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              maxChildSize: 0.97,
              minChildSize: 0.50,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 22,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bottomSheetHandle(),
                      const SizedBox(height: 22),
                      const Text(
                        'Edit Lead',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Uploaded Documents',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _editableFilePreview(
                            title: 'Aadhaar Front',
                            path: updatedAadhaarFront,
                            onChange: () => changeSingle('aadhaarFront'),
                            onRemove: () => setModalState(
                              () => updatedAadhaarFront = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'Aadhaar Back',
                            path: updatedAadhaarBack,
                            onChange: () => changeSingle('aadhaarBack'),
                            onRemove: () => setModalState(
                              () => updatedAadhaarBack = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'PAN Front',
                            path: updatedPanFront,
                            onChange: () => changeSingle('panFront'),
                            onRemove: () => setModalState(
                              () => updatedPanFront = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'PAN Back',
                            path: updatedPanBack,
                            onChange: () => changeSingle('panBack'),
                            onRemove: () => setModalState(
                              () => updatedPanBack = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'Electricity Bill',
                            path: updatedElectricityBill,
                            onChange: () => changeSingle('electricity'),
                            onRemove: () => setModalState(
                              () => updatedElectricityBill = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'Bank Document',
                            path: updatedBankImage,
                            onChange: () => changeSingle('bank'),
                            onRemove: () => setModalState(
                              () => updatedBankImage = null,
                            ),
                          ),
                          _editableFilePreview(
                            title: 'Roof Document',
                            path: updatedRoofImage,
                            onChange: () => changeSingle('roof'),
                            onRemove: () => setModalState(
                              () => updatedRoofImage = null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Multiple Checklist Documents',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _editableMultiDocs(
                        docs: updatedDocs,
                        setModalState: setModalState,
                      ),
                      const SizedBox(height: 24),
                      _editInput('Name', name),
                      _editInput('Mobile', mobile,
                          keyboardType: TextInputType.phone),
                      _editInput('Email', email,
                          keyboardType: TextInputType.emailAddress),
                      _editInput('CA No', caNo),
                      _editInput('K No', kNo),
                      _editInput('Ref No', refNo),
                      _editInput('Discom', discom),
                      _editInput('Geo Location', geoLocation),
                      _editInput('Longitude', longitude),
                      _editInput('Latitude', latitude),
                      _editInput('Bank Details', bankDetails),
                      _editInput('Roof Area', roofArea),
                      _editInput('Quotation Amount', quotationAmount),
                      _editInput('Employee Name', employeeName),
                      _editInput(
                        'Staff Contact',
                        staffContact,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HomeScreen.leads[index] = lead.copyWith(
                              name: name.text.trim(),
                              mobile: mobile.text.trim(),
                              email: email.text.trim(),
                              caNo: caNo.text.trim(),
                              kNo: kNo.text.trim(),
                              refNo: refNo.text.trim(),
                              discom: discom.text.trim(),
                              geoLocation: geoLocation.text.trim(),
                              longitude: longitude.text.trim(),
                              latitude: latitude.text.trim(),
                              bankDetails: bankDetails.text.trim(),
                              roofArea: roofArea.text.trim(),
                              quotationAmount: quotationAmount.text.trim(),
                              employeeName: employeeName.text.trim(),
                              staffContact: staffContact.text.trim(),
                              aadhaarFrontPath: updatedAadhaarFront,
                              aadhaarBackPath: updatedAadhaarBack,
                              panFrontPath: updatedPanFront,
                              panBackPath: updatedPanBack,
                              electricityBillPath: updatedElectricityBill,
                              electricityBillIsPdf:
                                  updatedElectricityBill != null &&
                                      _isPdf(updatedElectricityBill!),
                              bankImagePath: updatedBankImage,
                              roofImagePath: updatedRoofImage,
                              customerDocuments: _docsToString(updatedDocs),
                            );
                            await HomeScreen.saveLeads();

                            setState(() {});
                            if (!mounted) return;
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lead updated successfully'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _editableFilePreview({
    required String title,
    required String? path,
    required VoidCallback onChange,
    required VoidCallback onRemove,
  }) {
    final hasFile = _hasFile(path);
    final pdf = hasFile && _isPdf(path!);

    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E3F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: hasFile ? () => _openFile(path!) : onChange,
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasFile
                    ? pdf
                        ? Container(
                            height: 115,
                            width: double.infinity,
                            color: bgColor,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                  size: 38,
                                ),
                                SizedBox(height: 6),
                                Text('PDF'),
                              ],
                            ),
                          )
                        : Image.file(
                            File(path!),
                            height: 115,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _imageErrorBox(height: 115);
                            },
                          )
                    : Container(
                        height: 115,
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: bgColor,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file_outlined,
                              color: primaryColor,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Add File',
                              style: TextStyle(color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onChange,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(hasFile ? 'Change' : 'Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasFile)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
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

  Widget _editableMultiDocs({
    required List<String> docs,
    required void Function(void Function()) setModalState,
  }) {
    return Column(
      children: [
        if (docs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: const Text(
              'No checklist documents uploaded',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (docs.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: docs.map((path) {
              return SizedBox(
                width: 150,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7E3F0)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _openFile(path),
                        borderRadius: BorderRadius.circular(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _isPdf(path)
                              ? Container(
                                  height: 105,
                                  color: bgColor,
                                  child: const Center(
                                    child: Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(path),
                                  height: 105,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _imageErrorBox(height: 105);
                                  },
                                ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            docs.remove(path);
                          });
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await _pickMultipleDocs();
            if (picked.isEmpty) return;

            setModalState(() {
              docs.addAll(picked);
            });
          },
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Add More Checklist Docs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _editInput(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _imageErrorBox({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      color: bgColor,
      alignment: Alignment.center,
      child: const Text(
        'Image not found',
        style: TextStyle(color: Colors.black45),
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

  Widget _bottomSheetHandle() {
    return Center(
      child: Container(
        width: 54,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}

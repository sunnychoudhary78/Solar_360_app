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

  List<String> _docsFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split('|||').where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
  }

  String _docsToString(List<String> docs) => docs.join('|||');

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

  Future<String?> _pickSingleDoc() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    return result?.files.single.path;
  }

  Future<List<String>> _pickMultipleDocs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null) return [];
    return result.files.where((e) => e.path != null).map((e) => e.path!).toList();
  }

  void _openFile(String path) {
    if (_isPdf(path)) {
      OpenFilex.open(path);
    } else {
      _openImagePopup(path);
    }
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
          style: TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.w600),
        ),
      ),
      body: leads.isEmpty
          ? _emptyLeads()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leads.length,
              itemBuilder: (context, index) {
                final lead = leads[index];
                return _leadCard(index, lead);
              },
            ),
    );
  }

  Widget _leadCard(int index, LeadModel lead) {
    final count = _docCount(lead);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E3F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: primaryColor.withOpacity(0.12),
                child: const Icon(Icons.person_outline, color: primaryColor, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lead.name.trim().isEmpty ? 'Unknown Customer' : lead.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textColor, fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ),
              _statusPill(count > 0 ? '$count Docs' : 'New Lead', count > 0),
            ],
          ),
          const SizedBox(height: 20),
          _infoTile(Icons.call_outlined, 'Mobile', lead.mobile),
          _infoTile(Icons.email_outlined, 'Email', lead.email),
          _infoTile(Icons.confirmation_number_outlined, 'CA No', lead.caNo),
          _infoTile(Icons.numbers_outlined, 'K No', lead.kNo),
          _infoTile(Icons.business_outlined, 'Discom', lead.discom),
          _infoTile(Icons.attach_file, 'Documents', '$count files available'),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showEditLeadSheet(index, lead),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, bool green) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: green ? Colors.green.withOpacity(0.12) : primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: green ? Colors.green : primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 22),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              '$title:',
              style: const TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showLeadDetails(LeadModel lead) {
    final customerDocs = _docsFromString(lead.customerDocuments);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.90,
          maxChildSize: 0.96,
          minChildSize: 0.45,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bottomSheetHandle(),
                  const SizedBox(height: 22),
                  Text(
                    lead.name.trim().isEmpty ? 'Unknown Customer' : lead.name,
                    style: const TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  _detailSection('Basic Details', [
                    _detailRow('Name', lead.name),
                    _detailRow('Mobile', lead.mobile),
                    _detailRow('Email', lead.email),
                    _detailRow('CA No', lead.caNo),
                    _detailRow('K No', lead.kNo),
                    _detailRow('Ref No', lead.refNo),
                    _detailRow('Discom', lead.discom),
                  ]),

                  _detailSection('Location Details', [
                    _detailRow('Geo Location', lead.geoLocation),
                    _detailRow('Longitude', lead.longitude),
                    _detailRow('Latitude', lead.latitude),
                  ]),

                  _detailSection('Site / Quotation Details', [
                    _detailRow('Roof Area', lead.roofArea),
                    _detailRow('Quotation Amount', lead.quotationAmount),
                    _detailRow('Employee Name', lead.employeeName),
                    _detailRow('Staff Contact', lead.staffContact),
                  ]),

                  _detailSection('Documents', [
                    _detailFile('Aadhaar Front', lead.aadhaarFrontPath),
                    _detailFile('Aadhaar Back', lead.aadhaarBackPath),
                    _detailFile('PAN Front', lead.panFrontPath),
                    _detailFile('PAN Back', lead.panBackPath),
                    _detailFile('Electricity Bill', lead.electricityBillPath),
                    _detailFile('Bank Document', lead.bankImagePath),
                    _detailFile('Roof Document', lead.roofImagePath),
                  ]),

                  _detailSection('Multiple Checklist Documents', [
                    if (customerDocs.isEmpty)
                      const Text('No checklist documents uploaded', style: TextStyle(color: Colors.black45)),
                    ...customerDocs.asMap().entries.map(
                          (e) => _detailFile('Checklist Doc ${e.key + 1}', e.value),
                        ),
                  ]),
                ],
              ),
            );
          },
        );
      },
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

    String? aadhaarFront = lead.aadhaarFrontPath;
    String? aadhaarBack = lead.aadhaarBackPath;
    String? panFront = lead.panFrontPath;
    String? panBack = lead.panBackPath;
    String? electricityBill = lead.electricityBillPath;
    String? bankImage = lead.bankImagePath;
    String? roofImage = lead.roofImagePath;
    List<String> customerDocs = _docsFromString(lead.customerDocuments);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> changeDoc(String key) async {
              final file = await _pickSingleDoc();
              if (file == null) return;

              setModalState(() {
                if (key == 'aadhaarFront') aadhaarFront = file;
                if (key == 'aadhaarBack') aadhaarBack = file;
                if (key == 'panFront') panFront = file;
                if (key == 'panBack') panBack = file;
                if (key == 'electricity') electricityBill = file;
                if (key == 'bank') bankImage = file;
                if (key == 'roof') roofImage = file;
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
                      const SizedBox(height: 20),
                      const Text(
                        'Edit Lead',
                        style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      _editHeading('Step 1: Basic Details'),
                      _editInput('Name', name),
                      _editInput('Mobile', mobile, keyboardType: TextInputType.phone),
                      _editInput('Email', email, keyboardType: TextInputType.emailAddress),
                      _editInput('CA No', caNo),
                      _editInput('K No', kNo),
                      _editInput('Ref No', refNo),
                      _editInput('Discom', discom),

                      _editHeading('Step 2: Location Details'),
                      _editInput('Geo Location', geoLocation),
                      _editInput('Longitude', longitude),
                      _editInput('Latitude', latitude),

                      _editHeading('Step 3: Bank / Site Details'),
                      _editInput('Bank Details', bankDetails),
                      _editInput('Roof Area', roofArea),
                      _editInput('Quotation Amount', quotationAmount),
                      _editInput('Employee Name', employeeName),
                      _editInput('Staff Contact', staffContact, keyboardType: TextInputType.phone),

                      _editHeading('Step 4: Customer Documents'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _editableFilePreview('Aadhaar Front', aadhaarFront, () => changeDoc('aadhaarFront'), () => setModalState(() => aadhaarFront = null)),
                          _editableFilePreview('Aadhaar Back', aadhaarBack, () => changeDoc('aadhaarBack'), () => setModalState(() => aadhaarBack = null)),
                          _editableFilePreview('PAN Front', panFront, () => changeDoc('panFront'), () => setModalState(() => panFront = null)),
                          _editableFilePreview('PAN Back', panBack, () => changeDoc('panBack'), () => setModalState(() => panBack = null)),
                          _editableFilePreview('Electricity Bill', electricityBill, () => changeDoc('electricity'), () => setModalState(() => electricityBill = null)),
                        ],
                      ),

                      _editHeading('Step 5: Bank / Roof Documents'),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _editableFilePreview('Bank Document', bankImage, () => changeDoc('bank'), () => setModalState(() => bankImage = null)),
                          _editableFilePreview('Roof Document', roofImage, () => changeDoc('roof'), () => setModalState(() => roofImage = null)),
                        ],
                      ),

                      _editHeading('Step 6: Multiple Checklist Documents'),
                      _editableMultiDocs(customerDocs, setModalState),

                      const SizedBox(height: 18),
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
                              aadhaarFrontPath: aadhaarFront,
                              aadhaarBackPath: aadhaarBack,
                              panFrontPath: panFront,
                              panBackPath: panBack,
                              electricityBillPath: electricityBill,
                              electricityBillIsPdf: electricityBill != null && _isPdf(electricityBill!),
                              bankImagePath: bankImage,
                              roofImagePath: roofImage,
                              customerDocuments: _docsToString(customerDocs),
                            );

                            await HomeScreen.saveLeads();
                            setState(() {});

                            if (!mounted) return;
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lead updated successfully')),
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save Changes', style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _editHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _editInput(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _editableFilePreview(String title, String? path, VoidCallback onChange, VoidCallback onRemove) {
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: hasFile ? () => _openFile(path!) : onChange,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasFile
                    ? pdf
                        ? _pdfBox(110, 'PDF')
                        : Image.file(File(path!), height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageErrorBox(110))
                    : Container(
                        height: 110,
                        width: double.infinity,
                        color: bgColor,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_outlined, color: primaryColor),
                            SizedBox(height: 6),
                            Text('Add File', style: TextStyle(color: Colors.black45)),
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
                    style: TextButton.styleFrom(foregroundColor: primaryColor, padding: EdgeInsets.zero),
                  ),
                ),
                if (hasFile)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableMultiDocs(List<String> docs, void Function(void Function()) setModalState) {
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
            child: const Text('No checklist documents uploaded', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _isPdf(path)
                              ? _pdfBox(105, 'PDF')
                              : Image.file(File(path), height: 105, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageErrorBox(105)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setModalState(() => docs.remove(path)),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
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
            setModalState(() => docs.addAll(picked));
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

  Widget _detailSection(String title, List<Widget> children) {
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
          Text(title, style: const TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
          SizedBox(width: 125, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _detailFile(String title, String? path) {
    if (!_hasFile(path)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('$title: Not uploaded', style: const TextStyle(color: Colors.black45)),
      );
    }

    if (_isPdf(path!)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => OpenFilex.open(path),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E3F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                const Icon(Icons.open_in_new, color: primaryColor),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _openImagePopup(path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(path), width: double.infinity, height: 190, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageErrorBox(150)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pdfBox(double height, String text) {
    return Container(
      height: height,
      width: double.infinity,
      color: bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 38),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _imageErrorBox(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: bgColor,
      alignment: Alignment.center,
      child: const Text('Image not found', style: TextStyle(color: Colors.black45)),
    );
  }

  Widget _emptyLeads() {
    return const Center(
      child: Text(
        'No leads added yet',
        style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold),
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
                      errorBuilder: (_, __, ___) {
                        return Container(
                          height: 260,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
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
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
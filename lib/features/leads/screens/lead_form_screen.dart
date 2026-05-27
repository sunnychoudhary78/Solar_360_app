import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../home/screens/home_screen.dart';
import '../models/lead_model.dart';

class LeadFormScreen extends StatefulWidget {
  const LeadFormScreen({super.key});

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  static const bgColor = Color(0xFFFAF8FF);
  static const cardColor = Color(0xFFFEFBFF);
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  final name = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final caNo = TextEditingController();
  final kNo = TextEditingController();
  final refNo = TextEditingController();
  final discom = TextEditingController();
  final geoLocation = TextEditingController();
  final longitude = TextEditingController();
  final latitude = TextEditingController();
  final bankDetails = TextEditingController();
  final roofArea = TextEditingController();
  final quotationAmount = TextEditingController();
  final employeeName = TextEditingController();
  final staffContact = TextEditingController();

  String? aadhaarFrontPath;
  String? aadhaarBackPath;
  String? panFrontPath;
  String? panBackPath;
  String? electricityBillPath;
  String? bankImagePath;
  String? roofImagePath;

  bool electricityBillIsPdf = false;

  List<String> customerDocs = [];

  bool _hasFile(String? path) => path != null && path.trim().isNotEmpty;

  bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
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

  Future<void> _pickDocFor(String type) async {
    final path = await _pickSingleDoc();
    if (path == null) return;

    setState(() {
      if (type == 'aadhaarFront') aadhaarFrontPath = path;
      if (type == 'aadhaarBack') aadhaarBackPath = path;
      if (type == 'panFront') panFrontPath = path;
      if (type == 'panBack') panBackPath = path;
      if (type == 'electricity') {
        electricityBillPath = path;
        electricityBillIsPdf = _isPdf(path);
      }
      if (type == 'bank') bankImagePath = path;
      if (type == 'roof') roofImagePath = path;
    });
  }

  Future<void> _pickMultipleDocs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null) return;

    setState(() {
      customerDocs.addAll(
        result.files.where((e) => e.path != null).map((e) => e.path!),
      );
    });
  }

  void _openFile(String path) {
    if (_isPdf(path)) {
      OpenFilex.open(path);
    } else {
      _openImagePopup(path);
    }
  }

  Future<void> saveLead() async {
    if (name.text.trim().isEmpty || mobile.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Mobile are required')),
      );
      return;
    }

    HomeScreen.leads.add(
      LeadModel(
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
        aadhaarFrontPath: aadhaarFrontPath,
        aadhaarBackPath: aadhaarBackPath,
        panFrontPath: panFrontPath,
        panBackPath: panBackPath,
        electricityBillPath: electricityBillPath,
        electricityBillIsPdf: electricityBillIsPdf,
        bankImagePath: bankImagePath,
        roofImagePath: roofImagePath,
        customerDocuments: _docsToString(customerDocs),
      ),
    );

    await HomeScreen.saveLeads();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lead saved successfully')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    email.dispose();
    caNo.dispose();
    kNo.dispose();
    refNo.dispose();
    discom.dispose();
    geoLocation.dispose();
    longitude.dispose();
    latitude.dispose();
    bankDetails.dispose();
    roofArea.dispose();
    quotationAmount.dispose();
    employeeName.dispose();
    staffContact.dispose();
    super.dispose();
  }

  Widget input(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget uploadBox({
    required String title,
    required String? path,
    required VoidCallback onTap,
    required VoidCallback? onRemove,
  }) {
    final hasFile = _hasFile(path);
    final isPdf = hasFile && _isPdf(path!);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
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
            onTap: hasFile ? () => _openFile(path!) : onTap,
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 150,
                width: double.infinity,
                color: Colors.white,
                child: !hasFile
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: primaryColor,
                            size: 42,
                          ),
                          SizedBox(height: 8),
                          Text('Upload Image / PDF'),
                        ],
                      )
                    : isPdf
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                                size: 52,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'PDF Selected - Tap to Open',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : Image.file(
                            File(path!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Text('Image not found'),
                              );
                            },
                          ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(hasFile ? Icons.edit : Icons.add),
                  label: Text(hasFile ? 'Change' : 'Add'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget multipleDocsBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (customerDocs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: const Text(
              'No extra checklist document uploaded yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (customerDocs.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: customerDocs.map((path) {
              final pdf = _isPdf(path);

              return SizedBox(
                width: 155,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE4E1EA)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _openFile(path),
                        borderRadius: BorderRadius.circular(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 110,
                            width: double.infinity,
                            color: bgColor,
                            child: pdf
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        color: Colors.red,
                                        size: 42,
                                      ),
                                      SizedBox(height: 6),
                                      Text('Open PDF'),
                                    ],
                                  )
                                : Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return const Center(
                                        child: Text('Image not found'),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            customerDocs.remove(path);
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
          onPressed: _pickMultipleDocs,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Upload Multiple Checklist Docs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Create Lead',
          style: TextStyle(color: textColor),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Basic KYC'),
                input('Name', name),
                input('Mobile', mobile, keyboardType: TextInputType.phone),
                input('Email', email, keyboardType: TextInputType.emailAddress),
                input('CA No.', caNo),
                input('K. No.', kNo),
                input('Reff. No.', refNo),
                input('Discom', discom),

                sectionTitle('Customer Documents'),
                uploadBox(
                  title: 'Aadhaar Card Front Image / PDF',
                  path: aadhaarFrontPath,
                  onTap: () => _pickDocFor('aadhaarFront'),
                  onRemove: () => setState(() => aadhaarFrontPath = null),
                ),
                uploadBox(
                  title: 'Aadhaar Card Back Image / PDF',
                  path: aadhaarBackPath,
                  onTap: () => _pickDocFor('aadhaarBack'),
                  onRemove: () => setState(() => aadhaarBackPath = null),
                ),
                uploadBox(
                  title: 'PAN Card Front Image / PDF',
                  path: panFrontPath,
                  onTap: () => _pickDocFor('panFront'),
                  onRemove: () => setState(() => panFrontPath = null),
                ),
                uploadBox(
                  title: 'PAN Card Back Image / PDF',
                  path: panBackPath,
                  onTap: () => _pickDocFor('panBack'),
                  onRemove: () => setState(() => panBackPath = null),
                ),
                uploadBox(
                  title: 'Electricity Bill Image / PDF',
                  path: electricityBillPath,
                  onTap: () => _pickDocFor('electricity'),
                  onRemove: () {
                    setState(() {
                      electricityBillPath = null;
                      electricityBillIsPdf = false;
                    });
                  },
                ),

                sectionTitle('Multiple Checklist Documents'),
                multipleDocsBox(),

                sectionTitle('Location'),
                input('Geo Location', geoLocation),
                input(
                  'Longitude',
                  longitude,
                  keyboardType: TextInputType.number,
                ),
                input(
                  'Latitude',
                  latitude,
                  keyboardType: TextInputType.number,
                ),

                sectionTitle('Bank Details For Subsidy'),
                input('National Bank Account Details', bankDetails),
                uploadBox(
                  title: 'Cheque / Passbook Image / PDF',
                  path: bankImagePath,
                  onTap: () => _pickDocFor('bank'),
                  onRemove: () => setState(() => bankImagePath = null),
                ),

                sectionTitle('Roof Photo'),
                uploadBox(
                  title: 'Pre-Installation Site Image / PDF',
                  path: roofImagePath,
                  onTap: () => _pickDocFor('roof'),
                  onRemove: () => setState(() => roofImagePath = null),
                ),

                sectionTitle('Site Checklist'),
                input('Shadow free roof area in sq. meter', roofArea),
                input(
                  'Quotation amount',
                  quotationAmount,
                  keyboardType: TextInputType.number,
                ),
                input('Name of KG Employee Visited the Site', employeeName),
                input(
                  'Contact number of visited staff',
                  staffContact,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      saveLead();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Save Lead',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

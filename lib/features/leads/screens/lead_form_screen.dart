import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/upload_url.dart';
import '../../../core/widgets/app_message.dart';
import '../models/lead_model.dart';
import '../providers/lead_provider.dart';

enum LeadFormMode { basicCreate, completeDetails }

class TitledLocalFile {
  final String title;
  final String path;

  const TitledLocalFile({
    required this.title,
    required this.path,
  });

  Map<String, String> toPayload() {
    return {
      'title': title.trim(),
      'path': path,
    };
  }

  TitledLocalFile copyWith({
    String? title,
    String? path,
  }) {
    return TitledLocalFile(
      title: title ?? this.title,
      path: path ?? this.path,
    );
  }
}

class LeadFormScreen extends ConsumerStatefulWidget {
  final LeadFormMode mode;
  final LeadModel? existingLead;

  const LeadFormScreen({
    super.key,
    this.mode = LeadFormMode.basicCreate,
    this.existingLead,
  });

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  static const bgColor = Color(0xFFFAF8FF);
  static const cardColor = Color(0xFFFEFBFF);
  static const primaryColor = Color(0xFF5663A0);
  static const textColor = Color(0xFF1F2028);

  static const List<String> indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Other',
  ];

  static const List<String> discomOptions = [
    'BSES Rajdhani',
    'BSES Yamuna',
    'TPDDL',
    'NPCL',
    'UPPCL',
    'DHBVN',
    'UHBVN',
    'PSPCL',
    'JVVNL',
    'MSEDCL',
    'BESCOM',
    'TANGEDCO',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();

  final fullName = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final pincode = TextEditingController();
  final kw = TextEditingController();

  final caNumber = TextEditingController();
  final kNumber = TextEditingController();
  final referenceNumber = TextEditingController();
  final discom = TextEditingController();

  final geoLocation = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();

  final bankAccountName = TextEditingController();
  final bankName = TextEditingController();
  final accountNumber = TextEditingController();
  final ifscCode = TextEditingController();

  final availableShadowFreeArea = TextEditingController();
  final quotationAmount = TextEditingController();
  final visitedEmployeeName = TextEditingController();
  final visitedEmployeeContact = TextEditingController();

  final notes = TextEditingController();

  String projectType = 'Residential';
  String source = 'Website';
  String priority = 'Medium';

  bool roofLoadBearingCapacity = false;
  bool shadowFreeRoof = false;
  bool vendorVisitedSite = false;

  final ImagePicker _imagePicker = ImagePicker();

  String? roofPhotoPath;
  String? bankClearPhotoPath;
  String? chequePassbookPath;

  final List<TitledLocalFile> additionalImages = [];
  final List<TitledLocalFile> additionalDocs = [];

  bool isLoading = false;
  bool isFetchingLocation = false;

  @override
  void dispose() {
    fullName.dispose();
    mobile.dispose();
    email.dispose();
    address.dispose();
    city.dispose();
    state.dispose();
    pincode.dispose();
    kw.dispose();

    caNumber.dispose();
    kNumber.dispose();
    referenceNumber.dispose();
    discom.dispose();

    geoLocation.dispose();
    latitude.dispose();
    longitude.dispose();

    bankAccountName.dispose();
    bankName.dispose();
    accountNumber.dispose();
    ifscCode.dispose();

    availableShadowFreeArea.dispose();
    quotationAmount.dispose();
    visitedEmployeeName.dispose();
    visitedEmployeeContact.dispose();

    notes.dispose();
    super.dispose();
  }

  String? _textOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    return value;
  }

  String? _validateFullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 3) return 'Full name minimum 3 letters hona chahiye';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
      return 'Full name me sirf alphabets allowed hain';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
      return 'Valid 10 digit mobile number enter karo';
    }
    return null;
  }

  String? _validateOptionalMobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return _validateMobile(v);
  }

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(v)) {
      return 'Email sirf @gmail.com hona chahiye';
    }
    return null;
  }

  String? _validateOptionalAlpha(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
      return '$label me sirf alphabets allowed hain';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Pincode 6 digits ka hona chahiye';
    }
    return null;
  }

  String? _validateNumber(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v)) {
      return '$label valid number hona chahiye';
    }
    return null;
  }

  String? _validateAccount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{9,18}$').hasMatch(v)) {
      return 'Account number 9 to 18 digits hona chahiye';
    }
    return null;
  }

  String? _validateIfsc(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) {
      return 'Valid IFSC code enter karo';
    }
    return null;
  }

  Future<void> _fetchCurrentLocation() async {
    if (isFetchingLocation) return;

    try {
      setState(() => isFetchingLocation = true);

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location service')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable it from app settings.',
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      latitude.text = position.latitude.toString();
      longitude.text = position.longitude.toString();

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        geoLocation.text = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to fetch location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isFetchingLocation = false);
      }
    }
  }

  bool get _isBasicCreate => widget.mode == LeadFormMode.basicCreate;
  bool get _isCompleteDetails => widget.mode == LeadFormMode.completeDetails;

  @override
  void initState() {
    super.initState();
    final lead = widget.existingLead;
    if (lead != null) {
    fullName.text = lead.fullName;
    mobile.text = lead.mobile;
    email.text = lead.email;
    address.text = lead.address;
    city.text = lead.city;
    state.text = lead.state;
    pincode.text = lead.pincode;
    caNumber.text = lead.caNumber;
    kNumber.text = lead.kNumber;
    referenceNumber.text = lead.referenceNumber;
    discom.text = lead.discom;
    geoLocation.text = lead.geoLocation;
    latitude.text = lead.latitude;
    longitude.text = lead.longitude;
    bankAccountName.text = lead.bankAccountName;
    bankName.text = lead.bankName;
    accountNumber.text = lead.accountNumber;
    ifscCode.text = lead.ifscCode;
    availableShadowFreeArea.text = lead.availableShadowFreeArea;
    quotationAmount.text = lead.quotationAmount;
    visitedEmployeeName.text = lead.visitedEmployeeName;
    visitedEmployeeContact.text = lead.visitedEmployeeContact;
    notes.text = lead.notes;
    projectType = lead.projectType.isNotEmpty ? lead.projectType : projectType;
    source = lead.source.isNotEmpty ? lead.source : source;
    priority = lead.priority.isNotEmpty ? lead.priority : priority;
    }

    if (_isBasicCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchCurrentLocation();
      });
    }
  }

  Future<void> saveLead() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      showAppMessage(context, 'Please fix validation errors', isError: true);
      return;
    }

    final data = <String, dynamic>{
      'full_name': fullName.text.trim(),
      'mobile': mobile.text.trim(),
      'email': _textOrNull(email),
      'address': _textOrNull(address),
      'city': _textOrNull(city),
      'state': _textOrNull(state),
      'pincode': _textOrNull(pincode),
     'load_section_kw': _textOrNull(kw),
      'ca_number': _textOrNull(caNumber),
      'k_number': _textOrNull(kNumber),
      'reference_number': _textOrNull(referenceNumber),
      'discom': _textOrNull(discom),
      'geo_location': _textOrNull(geoLocation),
      'latitude': _textOrNull(latitude),
      'longitude': _textOrNull(longitude),
      'bank_account_name': _textOrNull(bankAccountName),
      'bank_name': _textOrNull(bankName),
      'account_number': _textOrNull(accountNumber),
      'ifsc_code': _textOrNull(ifscCode)?.toUpperCase(),
      'project_type': projectType,
      'source': source,
      'priority': priority,
      'notes': _textOrNull(notes),
      'roof_photo_status': 'Pending',
      'available_shadow_free_area': _textOrNull(availableShadowFreeArea),
      'quotation_amount': _textOrNull(quotationAmount),
      'visited_employee_name': _textOrNull(visitedEmployeeName),
      'visited_employee_contact': _textOrNull(visitedEmployeeContact),
      'roof_load_bearing_capacity': roofLoadBearingCapacity.toString(),
      'shadow_free_roof': shadowFreeRoof.toString(),
      'vendor_visited_site': vendorVisitedSite.toString(),
    };

    try {
      setState(() => isLoading = true);

      final repo = ref.read(leadRepositoryProvider);

      if (_isCompleteDetails && widget.existingLead != null) {
        await repo.updateLeadWithFiles(
          widget.existingLead!.id,
          data,
          singleFilePaths: {
            if (roofPhotoPath != null) 'roof_photo': roofPhotoPath!,
            if (bankClearPhotoPath != null) 'bank_clear_photo': bankClearPhotoPath!,
            if (chequePassbookPath != null)
              'cheque_passbook_copy': chequePassbookPath!,
          },
          additionalImageEntries:
              additionalImages.map((item) => item.toPayload()).toList(),
          additionalDocumentEntries:
              additionalDocs.map((item) => item.toPayload()).toList(),
        );
      } else if (_isBasicCreate) {
        final basicData = <String, dynamic>{
          'full_name': data['full_name'],
          'mobile': data['mobile'],
          'email': data['email'],
          'address': data['address'],
          'city': data['city'],
          'state': data['state'],
          'pincode': data['pincode'],
          'load_section_kw': data['load_section_kw'],
          'project_type': data['project_type'],
          'source': data['source'],
          'priority': data['priority'],
          'notes': data['notes'],
        };
        await repo.createLead(basicData);
      } else {
        await repo.createLead(
          data,
          singleFilePaths: {
            if (roofPhotoPath != null) 'roof_photo': roofPhotoPath!,
            if (chequePassbookPath != null)
              'cheque_passbook_copy': chequePassbookPath!,
          },
          additionalImageEntries:
              additionalImages.map((item) => item.toPayload()).toList(),
          additionalDocumentEntries:
              additionalDocs.map((item) => item.toPayload()).toList(),
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.invalidate(allLeadsProvider);
        }
      });

      if (!mounted) return;

      showAppMessage(
        context,
        _isCompleteDetails
            ? 'Lead details saved successfully'
            : 'Lead created and sent to Support for approval',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      showAppMessage(context, 'Failed to save lead: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget input(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        enabled: !isLoading,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: bgColor,
          errorMaxLines: 2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget controllerDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hintText,
  }) {
    final currentValue =
        items.contains(controller.text.trim()) ? controller.text.trim() : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          filled: true,
          fillColor: bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: isLoading
            ? null
            : (value) {
                if (value == null) return;
                setState(() => controller.text = value);
              },
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return '$label is required';
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: bgColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: isLoading ? null : onChanged,
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

  Widget switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: SwitchListTile(
        value: value,
        title: Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        activeColor: primaryColor,
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget formCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget locationStatusBox() {
    if (!isFetchingLocation) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fetching current location...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureImage(ValueChanged<String?> onPicked) async {
    FocusScope.of(context).unfocus();

    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    if (!mounted) return;

    setState(() => onPicked(file.path));
  }

  Future<void> _pickImage(ValueChanged<String?> onPicked) async {
    FocusScope.of(context).unfocus();

    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    if (!mounted) return;

    setState(() => onPicked(file.path));
  }

  Future<String?> _pickSingleFile({required bool imageOnly}) async {
    FocusScope.of(context).unfocus();

    if (imageOnly) {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      return file?.path;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
    );

    return result?.files.single.path;
  }

  Future<void> _showAddTitledFileDialog({
    required String dialogTitle,
    required String titleLabel,
    required String uploadLabel,
    required String defaultTitlePrefix,
    required bool imageOnly,
    required List<TitledLocalFile> target,
  }) async {
    final titleController = TextEditingController(
      text: '$defaultTitlePrefix ${target.length + 1}',
    );

    String? selectedPath;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(dialogTitle),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: titleLabel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          FocusScope.of(context).unfocus();

                          final path =
                              await _pickSingleFile(imageOnly: imageOnly);

                          if (path == null) return;
                          if (!mounted) return;

                          setDialogState(() => selectedPath = path);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE4E1EA),
                            ),
                          ),
                          child: selectedPath == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      imageOnly
                                          ? Icons.add_photo_alternate_outlined
                                          : Icons.upload_file_outlined,
                                      color: primaryColor,
                                      size: 38,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(uploadLabel),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: isImagePath(selectedPath!)
                                      ? Image.file(
                                          File(selectedPath!),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        )
                                      : _docPreview(selectedPath!),
                                ),
                        ),
                      ),
                      if (selectedPath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          fileDisplayName(selectedPath!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();

                    final title = titleController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$titleLabel is required')),
                      );
                      return;
                    }

                    if (selectedPath == null || selectedPath!.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$uploadLabel is required')),
                      );
                      return;
                    }

                    setState(() {
                      target.add(
                        TitledLocalFile(
                          title: title,
                          path: selectedPath!,
                        ),
                      );
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _singleImagePicker({
    required String title,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final hasFile = value != null && value.isNotEmpty;
    final isImage = hasFile && isImagePath(value);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          if (hasFile)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: isImage
                        ? Image.file(File(value), fit: BoxFit.cover)
                        : _docPreview(value),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isLoading
                          ? null
                          : () => setState(() => onChanged(null)),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E1EA)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: primaryColor,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'No file selected',
                    style: TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : () => _captureImage(onChanged),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Capture'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : () => _pickImage(onChanged),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docPreview(String path) {
    final pdf = isPdfPath(path);

    return Container(
      color: const Color(0xFFEEF0F8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 42,
              color: pdf ? Colors.red : primaryColor,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                fileDisplayName(path),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _multiFilePicker({
    required String title,
    required List<TitledLocalFile> files,
    required VoidCallback onAdd,
    required void Function(int index) onRemove,
    required void Function(int index) onReplace,
    bool imagesOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${files.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: isLoading ? null : onAdd,
                style: FilledButton.styleFrom(backgroundColor: primaryColor),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (files.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E1EA)),
              ),
              child: Text(
                imagesOnly
                    ? 'No additional images added.'
                    : 'No extra documents added.',
                style: const TextStyle(color: Colors.black45),
              ),
            ),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: files.asMap().entries.map((entry) {
                final item = entry.value;
                final idx = entry.key;
                final image = isImagePath(item.path);

                return SizedBox(
                  width: 120,
                  height: 178,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 105,
                              width: 120,
                              child: image
                                  ? Image.file(
                                      File(item.path),
                                      fit: BoxFit.cover,
                                    )
                                  : _docPreview(item.path),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: isLoading ? null : () => onRemove(idx),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(
                        height: 34,
                        child: TextButton(
                          onPressed: isLoading ? null : () => onReplace(idx),
                          child: const Text(
                            'Replace',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _replaceFileAt(
    List<TitledLocalFile> target,
    int index, {
    required bool imageOnly,
  }) async {
    final path = await _pickSingleFile(imageOnly: imageOnly);
    if (path == null) return;
    if (!mounted) return;

    setState(() {
      target[index] = target[index].copyWith(path: path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          _isCompleteDetails
              ? 'Complete Lead Details'
              : 'Create Lead (Basic)',
          style: const TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(18),
          child: formCard(
            children: [
              sectionTitle('Basic Details'),
              input(
                'Full Name *',
                fullName,
                validator: _validateFullName,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                ],
                textCapitalization: TextCapitalization.words,
              ),
              input(
                'Mobile *',
                mobile,
                keyboardType: TextInputType.phone,
                validator: _validateMobile,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              input(
                'Email',
                email,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              input('Address', address),
              input(
                'City',
                city,
                validator: (v) => _validateOptionalAlpha(v, 'City'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                ],
                textCapitalization: TextCapitalization.words,
              ),
              controllerDropdown(
                label: 'State',
                controller: state,
                items: indianStates,
                hintText: 'Select state',
              ),
              input(
                'Pincode',
                pincode,
                keyboardType: TextInputType.number,
                validator: _validatePincode,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
              input(
                'KW',
                kw,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => _validateNumber(v, 'KW'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),

              if (!_isBasicCreate) ...[
              sectionTitle('Connection Details'),
              input('CA Number', caNumber),
              input('K Number', kNumber),
              input('Reference Number', referenceNumber),
              controllerDropdown(
                label: 'DISCOM',
                controller: discom,
                items: discomOptions,
                hintText: 'Select DISCOM',
              ),

              sectionTitle('Location'),
              locationStatusBox(),
              input(
                'Geo Location',
                geoLocation,
                suffixIcon: IconButton(
                  tooltip: 'Use Current Location',
                  onPressed: isLoading || isFetchingLocation
                      ? null
                      : _fetchCurrentLocation,
                  icon: const Icon(Icons.my_location),
                ),
              ),
              input(
                'Latitude',
                latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _validateNumber(v, 'Latitude'),
              ),
              input(
                'Longitude',
                longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => _validateNumber(v, 'Longitude'),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoading || isFetchingLocation
                      ? null
                      : _fetchCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                ),
              ),

              sectionTitle('Bank Details'),
              input('Bank Account Name', bankAccountName),
              input('Bank Name', bankName),
              input(
                'Account Number',
                accountNumber,
                keyboardType: TextInputType.number,
                validator: _validateAccount,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(18),
                ],
              ),
              input(
                'IFSC Code',
                ifscCode,
                validator: _validateIfsc,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(11),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return newValue.copyWith(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    );
                  }),
                ],
              ),

              sectionTitle('Project Details'),
              dropdown(
                label: 'Project Type',
                value: projectType,
                items: const ['Residential', 'Commercial', 'Industrial'],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => projectType = value);
                },
              ),
              dropdown(
                label: 'Source',
                value: source,
                items: const [
                  'Website',
                  'Referral',
                  'Walk-in',
                  'Call',
                  'Other',
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => source = value);
                },
              ),
              dropdown(
                label: 'Priority',
                value: priority,
                items: const ['Low', 'Medium', 'High'],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => priority = value);
                },
              ),

              sectionTitle('Site Checklist'),
              input(
                'Available Shadow Free Area',
                availableShadowFreeArea,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    _validateNumber(v, 'Available Shadow Free Area'),
              ),
              input(
                'Quotation Amount',
                quotationAmount,
                keyboardType: TextInputType.number,
                validator: (v) => _validateNumber(v, 'Quotation Amount'),
              ),
              input(
                'Visited Employee Name',
                visitedEmployeeName,
                validator: (v) =>
                    _validateOptionalAlpha(v, 'Visited Employee Name'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                ],
                textCapitalization: TextCapitalization.words,
              ),
              input(
                'Visited Employee Contact',
                visitedEmployeeContact,
                keyboardType: TextInputType.phone,
                validator: _validateOptionalMobile,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              switchTile(
                title: 'Roof Load Bearing Capacity',
                value: roofLoadBearingCapacity,
                onChanged: (value) {
                  setState(() => roofLoadBearingCapacity = value);
                },
              ),
              switchTile(
                title: 'Shadow Free Roof',
                value: shadowFreeRoof,
                onChanged: (value) {
                  setState(() => shadowFreeRoof = value);
                },
              ),
              switchTile(
                title: 'Vendor Visited Site',
                value: vendorVisitedSite,
                onChanged: (value) {
                  setState(() => vendorVisitedSite = value);
                },
              ),

              sectionTitle('Notes'),
              input('Notes', notes, maxLines: 4),

              sectionTitle('Images & Documents'),
              _singleImagePicker(
                title: 'Roof Photo',
                value: roofPhotoPath,
                onChanged: (v) => setState(() => roofPhotoPath = v),
              ),
              _singleImagePicker(
                title: 'Cheque/Passbook Copy',
                value: chequePassbookPath,
                onChanged: (v) => setState(() => chequePassbookPath = v),
              ),
              _multiFilePicker(
                title: 'Additional Images',
                files: additionalImages,
                imagesOnly: true,
                onAdd: () => _showAddTitledFileDialog(
                  dialogTitle: 'Add Additional Image',
                  titleLabel: 'Image title',
                  uploadLabel: 'Choose Image',
                  defaultTitlePrefix: 'Image',
                  imageOnly: true,
                  target: additionalImages,
                ),
                onRemove: (i) => setState(() => additionalImages.removeAt(i)),
                onReplace: (i) =>
                    _replaceFileAt(additionalImages, i, imageOnly: true),
              ),
              _multiFilePicker(
                title: 'Additional Documents',
                files: additionalDocs,
                imagesOnly: false,
                onAdd: () => _showAddTitledFileDialog(
                  dialogTitle: 'Add Additional Document',
                  titleLabel: 'Document title',
                  uploadLabel: 'Choose File',
                  defaultTitlePrefix: 'Document',
                  imageOnly: false,
                  target: additionalDocs,
                ),
                onRemove: (i) => setState(() => additionalDocs.removeAt(i)),
                onReplace: (i) =>
                    _replaceFileAt(additionalDocs, i, imageOnly: false),
              ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveLead,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isCompleteDetails
                              ? 'Save Details'
                              : _isBasicCreate
                                  ? 'Submit to Support'
                                  : 'Save Lead',
                          style: const TextStyle(
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
    );
  }
}
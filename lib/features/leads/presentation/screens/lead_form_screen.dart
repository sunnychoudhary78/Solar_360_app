import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';

enum LeadFormMode { basicCreate, completeDetails }

class TitledLocalFile {
  final String title;
  final String path;

  const TitledLocalFile({required this.title, required this.path});

  Map<String, String> toPayload() {
    return {'title': title.trim(), 'path': path};
  }

  TitledLocalFile copyWith({String? title, String? path}) {
    return TitledLocalFile(title: title ?? this.title, path: path ?? this.path);
  }
}

class _PredefinedLeadFile {
  final String title;
  final bool imageOnly;

  const _PredefinedLeadFile(this.title, {this.imageOnly = false});
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

  static const List<_PredefinedLeadFile> predefinedDocumentSlots = [
    _PredefinedLeadFile('Aadhaar Front'),
    _PredefinedLeadFile('Aadhaar Back'),
    _PredefinedLeadFile('PAN Card'),
    _PredefinedLeadFile('Electricity Bill'),
    _PredefinedLeadFile('House Registry'),
    _PredefinedLeadFile('House Tax'),
    _PredefinedLeadFile('Gharoni'),
    _PredefinedLeadFile('NOC'),
    _PredefinedLeadFile('Application Acknowledgment'),
    _PredefinedLeadFile('E-Token'),
    _PredefinedLeadFile('Feasibility Letter'),
    _PredefinedLeadFile('Net Metering Agreement'),
    _PredefinedLeadFile('Work Agreement'),
  ];

  /// Matches backend KYC_REQUIRED_DOC_TITLES for Edit/Complete Details.
  static const Set<String> kycRequiredDocumentTitles = {
    'Aadhaar Front',
    'Aadhaar Back',
    'PAN Card',
    'Electricity Bill',
  };

  static const List<_PredefinedLeadFile> predefinedImageSlots = [
    _PredefinedLeadFile('Geo Tag Photo', imageOnly: true),
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

  final bankName = TextEditingController();
  final accountNumber = TextEditingController();
  final ifscCode = TextEditingController();

  final availableShadowFreeArea = TextEditingController();
  final quotationAmount = TextEditingController();
  final visitedEmployeeName = TextEditingController();
  final visitedEmployeeContact = TextEditingController();

  final notes = TextEditingController();
  String? selectedCustomerId;

  String projectType = 'Residential';
  String source = 'Website';
  String priority = 'Medium';
  String bankAccountType = 'Saving';

  bool roofLoadBearingCapacity = false;
  bool shadowFreeRoof = false;
  bool vendorVisitedSite = false;
  bool isLeadActive = true;

  final ImagePicker _imagePicker = ImagePicker();

  String? roofPhotoPath;
  String? bankClearPhotoPath;
  String? chequePassbookPath;
  String? preInstallationPhotoPath;
  String? quotationDocumentPath;

  final List<TitledLocalFile> additionalImages = [];
  final List<TitledLocalFile> additionalDocs = [];
  final Map<String, String?> predefinedDocPaths = {
    for (final item in predefinedDocumentSlots) item.title: null,
  };
  final Map<String, String?> predefinedImagePaths = {
    for (final item in predefinedImageSlots) item.title: null,
  };

  bool isLoading = false;
  bool isFetchingLocation = false;
  bool _isClosing = false;
  bool _mediaSectionReady = false;

  late final List<DropdownMenuItem<String>> _stateMenuItems = indianStates
      .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
      .toList(growable: false);

  late final List<DropdownMenuItem<String>> _discomMenuItems = discomOptions
      .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
      .toList(growable: false);

  bool get _isBasicCreate => widget.mode == LeadFormMode.basicCreate;
  bool get _isCompleteDetails => widget.mode == LeadFormMode.completeDetails;

  @override
  void initState() {
    super.initState();

    if (_isCompleteDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isClosing) return;
        setState(() => _mediaSectionReady = true);
      });
    } else {
      _mediaSectionReady = true;
    }

    final lead = widget.existingLead;

    if (lead != null) {
      fullName.text = lead.fullName;
      mobile.text = lead.mobile;
      email.text = lead.email;
      address.text = lead.address;
      city.text = lead.city;
      state.text = lead.state;
      pincode.text = lead.pincode;
      kw.text = lead.loadSectionKw;

      caNumber.text = lead.caNumber;
      kNumber.text = lead.kNumber;
      referenceNumber.text = lead.referenceNumber;
      discom.text = lead.discom;

      geoLocation.text = lead.geoLocation;
      latitude.text = lead.latitude;
      longitude.text = lead.longitude;

      bankName.text = lead.bankName;
      accountNumber.text = lead.accountNumber;
      ifscCode.text = lead.ifscCode;

      availableShadowFreeArea.text = lead.availableShadowFreeArea;
      quotationAmount.text = lead.quotationAmount;
      visitedEmployeeName.text = lead.visitedEmployeeName;
      visitedEmployeeContact.text = lead.visitedEmployeeContact;

      notes.text = lead.notes;
      selectedCustomerId = lead.customerId.isEmpty ? null : lead.customerId;

      projectType = lead.projectType.isNotEmpty
          ? lead.projectType
          : projectType;
      source = lead.source.isNotEmpty ? lead.source : source;
      priority = lead.priority.isNotEmpty ? lead.priority : priority;

      bankAccountType =
          lead.resolvedBankAccountType ?? bankAccountType;
      roofLoadBearingCapacity = lead.roofLoadBearingCapacity;
      shadowFreeRoof = lead.shadowFreeRoof;
      vendorVisitedSite = lead.vendorVisitedSite;
      isLeadActive = lead.isActive;
      _prefillStoredTitledFiles(lead.additionalDocuments, predefinedDocPaths);
      _prefillStoredTitledFiles(lead.additionalImages, predefinedImagePaths);
    }

    if (_isBasicCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchCurrentLocation();
      });
    }
  }

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
    return value.isEmpty ? null : value;
  }

  bool isImagePath(String? path) {
    if (path == null) return false;
    final p = path.toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }

  bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  String fileDisplayName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  /// Decode images at display size to avoid lag from full-resolution bitmaps.
  Widget _thumbImage(
    String path, {
    double? width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final resolvedWidth =
        (width != null && width.isFinite) ? width : screenW;
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      cacheWidth: (resolvedWidth * dpr).round().clamp(1, 4096),
      cacheHeight: (height * dpr).round().clamp(1, 4096),
      errorBuilder: (_, error, stackTrace) => _docPreview(path),
    );
  }

  Future<XFile?> _pickCompressedImage(ImageSource source) {
    return _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }

  bool _isExistingRemotePath(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('/uploads/') ||
        normalized.startsWith('uploads/');
  }

  void _prefillStoredTitledFiles(String raw, Map<String, String?> target) {
    if (raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final title = item['title']?.toString().trim() ?? '';
        final path = item['path']?.toString().trim() ?? '';
        if (title.isEmpty || path.isEmpty) continue;
        if (target.containsKey(title)) {
          target[title] = path;
        }
      }
    } catch (_) {
      return;
    }
  }

  List<TitledLocalFile> _predefinedUploads(Map<String, String?> source) {
    return source.entries
        .where((entry) {
          final path = entry.value?.trim() ?? '';
          return path.isNotEmpty && !_isExistingRemotePath(path);
        })
        .map(
          (entry) =>
              TitledLocalFile(title: entry.key, path: entry.value!.trim()),
        )
        .toList();
  }

  String? _validateFullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 3) return 'Full name must be at least 3 letters';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
      return 'Only alphabets are allowed in full name';
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
      return 'Please enter a valid 10-digit mobile number';
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
    if (!RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(v)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateOptionalAlpha(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(v)) {
      return 'Only alphabets are allowed in $label';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'Please enter a valid 6-digit pincode';
    }
    return null;
  }

  String? _validateNumber(String? value, String label) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v)) {
      return 'Please enter a valid $label';
    }
    return null;
  }

  String? _validateMaxDigitNumber(String? value, String label, int maxLength) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(v)) return '$label must be numeric only';
    if (v.length > maxLength) return '$label must be maximum $maxLength digits';
    return null;
  }

  String? _validateAccount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{9,18}$').hasMatch(v)) {
      return 'Account number must be 9 to 18 digits';
    }
    return null;
  }

  String? _validateIfsc(String? value) {
    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v)) {
      return 'Please enter a valid IFSC code';
    }
    return null;
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isClosing) return;
    setState(fn);
  }

  Future<void> _fetchCurrentLocation() async {
    if (isFetchingLocation || _isClosing) return;

    try {
      _safeSetState(() => isFetchingLocation = true);

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        showAppMessage(
          context,
          'Please enable location service',
          isError: true,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        showAppMessage(context, 'Location permission denied', isError: true);
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showAppMessage(
          context,
          'Location permission permanently denied. Please enable it from app settings.',
          isError: true,
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

      _safeSetState(() {});
    } catch (e) {
      if (!mounted || _isClosing) return;
      showAppMessage(context, 'Unable to fetch location: $e', isError: true);
    } finally {
      _safeSetState(() => isFetchingLocation = false);
    }
  }

  Future<void> saveLead() async {
    FocusScope.of(context).unfocus();

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
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
      'bank_account_name': bankAccountType,
      'account_type': bankAccountType,
      'bank_name': _textOrNull(bankName),
      'account_number': _textOrNull(accountNumber),
      'ifsc_code': _textOrNull(ifscCode)?.toUpperCase(),
      'project_type': projectType,
      'source': source,
      'priority': priority,
      'notes': _textOrNull(notes),
      'customer_id': selectedCustomerId,
      'roof_photo_status': 'Pending',
      'available_shadow_free_area': _textOrNull(availableShadowFreeArea),
      'quotation_amount': _textOrNull(quotationAmount),
      'visited_employee_name': _textOrNull(visitedEmployeeName),
      'visited_employee_contact': _textOrNull(visitedEmployeeContact),
      'roof_load_bearing_capacity': roofLoadBearingCapacity.toString(),
      'shadow_free_roof': shadowFreeRoof.toString(),
      'vendor_visited_site': vendorVisitedSite.toString(),
      'is_active': isLeadActive.toString(),
    };
    final mergedAdditionalImages = [
      ..._predefinedUploads(predefinedImagePaths),
      ...additionalImages,
    ];
    final mergedAdditionalDocs = [
      ..._predefinedUploads(predefinedDocPaths),
      ...additionalDocs,
    ];

    if (mounted) setState(() => isLoading = true);
    _isClosing = true;

    try {
      final repo = ref.read(leadRepositoryProvider);

      if (_isCompleteDetails && widget.existingLead != null) {
        await repo.updateLeadWithFiles(
          widget.existingLead!.id,
          data,
          singleFilePaths: {
            if (roofPhotoPath != null) 'roof_photo': roofPhotoPath!,
            if (bankClearPhotoPath != null)
              'bank_clear_photo': bankClearPhotoPath!,
            if (chequePassbookPath != null)
              'cheque_passbook_copy': chequePassbookPath!,
            if (preInstallationPhotoPath != null)
              'pre_installation_photo': preInstallationPhotoPath!,
            if (quotationDocumentPath != null)
              'quotation_document': quotationDocumentPath!,
          },
          additionalImageEntries: mergedAdditionalImages
              .map((e) => e.toPayload())
              .toList(),
          additionalDocumentEntries: mergedAdditionalDocs
              .map((e) => e.toPayload())
              .toList(),
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
          if (selectedCustomerId != null && selectedCustomerId!.isNotEmpty)
            'customer_id': selectedCustomerId,
        };
        await repo.createLead(basicData);
      } else {
        await repo.createLead(
          data,
          singleFilePaths: {
            if (roofPhotoPath != null) 'roof_photo': roofPhotoPath!,
            if (chequePassbookPath != null)
              'cheque_passbook_copy': chequePassbookPath!,
            if (preInstallationPhotoPath != null)
              'pre_installation_photo': preInstallationPhotoPath!,
            if (quotationDocumentPath != null)
              'quotation_document': quotationDocumentPath!,
          },
          additionalImageEntries: mergedAdditionalImages
              .map((e) => e.toPayload())
              .toList(),
          additionalDocumentEntries: mergedAdditionalDocs
              .map((e) => e.toPayload())
              .toList(),
        );
      }

      if (!mounted) return;

      final successMessage = _isCompleteDetails
          ? 'Lead details saved successfully'
          : 'Lead created and sent to Support for approval';

      // Close the form before refreshing providers or showing feedback so we
      // never rebuild this route while it is being removed from the tree.
      Navigator.of(context).pop(true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          ref.invalidate(allLeadsProvider);
        } catch (_) {}
        showAppMessage(null, successMessage);
      });
    } catch (e) {
      _isClosing = false;
      if (!mounted) return;
      setState(() => isLoading = false);
      showAppMessage(context, 'Failed to save lead: $e', isError: true);
    }
  }

  Widget _requiredFieldLabel(String text, {bool isRequired = false}) {
    if (!isRequired) return Text(text);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: '* ',
            style: TextStyle(
              color: Color(0xFFE53935),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
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
    String? suffixText,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    FocusNode? focusNode,
    bool isRequired = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedKeyboardType =
        maxLines > 1 && identical(keyboardType, TextInputType.text)
            ? TextInputType.multiline
            : keyboardType;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isLoading,
        readOnly: readOnly,
        keyboardType: resolvedKeyboardType,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        textInputAction: textInputAction ??
            (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
        onFieldSubmitted: onFieldSubmitted,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          label: _requiredFieldLabel(label, isRequired: isRequired),
          suffixIcon: suffixIcon,
          suffixText: suffixText,
          suffixStyle: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
          errorMaxLines: 2,
        ),
      ),
    );
  }

  Widget controllerDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hintText,
    List<DropdownMenuItem<String>>? menuItems,
    bool isRequired = false,
  }) {
    final textValue = controller.text.trim();
    final currentValue = items.contains(textValue) ? textValue : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        isExpanded: true,
        decoration: InputDecoration(
          label: _requiredFieldLabel(label, isRequired: isRequired),
          hintText: hintText,
        ),
        items: menuItems ??
            items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(growable: false),
        onChanged: isLoading
            ? null
            : (value) {
                if (value == null) return;
                // FormField updates its own UI; avoid rebuilding the whole form.
                controller.text = value;
              },
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    final safeValue = items.contains(value) ? value : items.first;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return '$label is required';
          return null;
        },
        decoration: InputDecoration(
          label: _requiredFieldLabel(label, isRequired: isRequired),
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(growable: false),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget sectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md + 4,
        bottom: AppSpacing.md - 4,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .75),
        ),
      ),
      child: SwitchListTile(
        value: value,
        title: Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  /// Local rebuild only — avoids rebuilding the entire edit form on toggle.
  Widget localSwitchTile({
    required String title,
    required bool Function() getter,
    required ValueChanged<bool> setter,
  }) {
    return StatefulBuilder(
      builder: (context, setLocal) {
        return switchTile(
          title: title,
          value: getter(),
          onChanged: (value) {
            setter(value);
            setLocal(() {});
          },
        );
      },
    );
  }

  Widget formCard({required List<Widget> children}) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderRadius: AppRadius.xxl - 4,
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

    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .75),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm + 2),
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

    final file = await _pickCompressedImage(ImageSource.camera);
    if (file == null) return;
    if (!mounted) return;

    setState(() => onPicked(file.path));
  }

  Future<void> _pickImage(ValueChanged<String?> onPicked) async {
    FocusScope.of(context).unfocus();

    final file = await _pickCompressedImage(ImageSource.gallery);
    if (file == null) return;
    if (!mounted) return;

    setState(() => onPicked(file.path));
  }

  Future<String?> _pickSingleFile({required bool imageOnly}) async {
    FocusScope.of(context).unfocus();

    if (imageOnly) {
      final file = await _pickCompressedImage(ImageSource.gallery);
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
        final scheme = Theme.of(dialogContext).colorScheme;

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
                        decoration: InputDecoration(labelText: titleLabel),
                      ),
                      const SizedBox(height: AppSpacing.md - 2),
                      InkWell(
                        onTap: () async {
                          FocusScope.of(context).unfocus();

                          final path = await _pickSingleFile(
                            imageOnly: imageOnly,
                          );

                          if (path == null) return;
                          if (!mounted) return;

                          setDialogState(() => selectedPath = path);
                        },
                        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              AppRadius.lg - 2,
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: .75,
                              ),
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
                                      color: scheme.primary,
                                      size: 38,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(uploadLabel),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg - 2,
                                  ),
                                  child: isImagePath(selectedPath!)
                                      ? _thumbImage(selectedPath!, height: 130)
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
                        TitledLocalFile(title: title, path: selectedPath!),
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
    bool isRequired = false,
  }) {
    final hasFile = value != null && value.isNotEmpty;
    final isImage = hasFile && isImagePath(value);
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
            child: _requiredFieldLabel(title, isRequired: isRequired),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (hasFile)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: isImage
                        ? _thumbImage(value, height: 160)
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
                      tooltip: 'Remove file',
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
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    'No file selected',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm + 2),
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

  Widget _singleDocumentPicker({
    required String title,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          if (value != null && value.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: _docPreview(value),
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
                      tooltip: 'Remove file',
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
              height: 100,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
              ),
              child: Text(
                'No document selected',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.sm + 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      final path = await _pickSingleFile(imageOnly: false);
                      if (path == null || !mounted) return;
                      setState(() => onChanged(path));
                    },
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Choose File'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predefinedFilesSection({
    required String title,
    required List<_PredefinedLeadFile> items,
    required Map<String, String?> values,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          ...items.map((item) {
            final path = values[item.title]?.trim() ?? '';
            final hasFile = path.isNotEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
              padding: const EdgeInsets.all(AppSpacing.md - 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    child: _requiredFieldLabel(
                      item.title,
                      isRequired:
                          kycRequiredDocumentTitles.contains(item.title),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hasFile ? fileDisplayName(path) : 'No file selected',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final picked = await _pickSingleFile(
                                    imageOnly: item.imageOnly,
                                  );
                                  if (picked == null || !mounted) return;
                                  setState(() => values[item.title] = picked);
                                },
                          icon: Icon(
                            item.imageOnly
                                ? Icons.photo_library_outlined
                                : Icons.upload_file_outlined,
                            size: 18,
                          ),
                          label: Text(hasFile ? 'Replace' : 'Choose'),
                        ),
                      ),
                      if (hasFile) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Remove file',
                          onPressed: isLoading
                              ? null
                              : () =>
                                  setState(() => values[item.title] = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _docPreview(String path) {
    final pdf = isPdfPath(path);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs + 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              size: 42,
              color: pdf ? scheme.error : scheme.primary,
            ),
            const SizedBox(height: AppSpacing.xs + 2),
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
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md - 2),
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${files.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: isLoading ? null : onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (files.isEmpty) ...[
            const SizedBox(height: AppSpacing.md - 4),
            Container(
              height: 90,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg - 2),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
              ),
              child: Text(
                imagesOnly
                    ? 'No additional images added.'
                    : 'No extra documents added.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
          if (files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 14,
              children: files.asMap().entries.map((entry) {
                final item = entry.value;
                final idx = entry.key;
                final image = isImagePath(item.path);

                return SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 105,
                              width: 120,
                              child: image
                                  ? _thumbImage(
                                      item.path,
                                      width: 120,
                                      height: 105,
                                    )
                                  : _docPreview(item.path),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Tooltip(
                              message: 'Remove file',
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TextButton(
                        onPressed: isLoading ? null : () => onReplace(idx),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        child: const Text(
                          'Replace',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 4),
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

  Future<void> _openAddCustomer() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.pushNamed(context, '/customers/form');
    if (!mounted) return;
    await ref.read(customerListProvider.notifier).refresh();
    if (!mounted) return;

    CustomerModel? created;
    final items = ref.read(customerListProvider).items;
    if (result is String && result.isNotEmpty) {
      final match = items.where((c) => c.id == result).toList();
      if (match.isNotEmpty) {
        created = match.first;
      } else {
        try {
          created = await ref.read(customerRepositoryProvider).getById(result);
        } catch (_) {}
      }
    } else if (result == true && items.isNotEmpty) {
      created = items.first;
    }

    if (!mounted || created == null) return;
    _applyCustomer(created);
  }

  void _applyCustomer(CustomerModel? customer) {
    setState(() {
      selectedCustomerId = customer?.id;
      if (customer == null) return;

      if (customer.name.trim().isNotEmpty) {
        fullName.text = customer.name.trim();
      }
      if ((customer.phone ?? '').trim().isNotEmpty) {
        mobile.text = customer.phone!.trim();
      }
      if ((customer.email ?? '').trim().isNotEmpty) {
        email.text = customer.email!.trim();
      }
      if ((customer.address ?? '').trim().isNotEmpty) {
        address.text = customer.address!.trim();
      }
      if ((customer.city ?? '').trim().isNotEmpty) {
        city.text = customer.city!.trim();
      }
      if ((customer.state ?? '').trim().isNotEmpty) {
        state.text = customer.state!.trim();
      }
      if ((customer.pincode ?? '').trim().isNotEmpty) {
        pincode.text = customer.pincode!.trim();
      }
    });
  }

  String _customerMenuLabel(CustomerModel customer) {
    final parts = <String>[
      customer.name.trim().isEmpty ? 'Unnamed' : customer.name.trim(),
      if ((customer.phone ?? '').trim().isNotEmpty) customer.phone!.trim(),
      if ((customer.city ?? '').trim().isNotEmpty) customer.city!.trim(),
    ];
    return parts.join(' - ');
  }

  /// Shared Linked Customer UI used by Create Lead and Complete Details.
  Widget _linkedCustomerSection({
    required List<CustomerModel> customerOptions,
    required bool allowAddCustomer,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelected =
        selectedCustomerId != null &&
        customerOptions.any((c) => c.id == selectedCustomerId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            value: hasSelected ? selectedCustomerId : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Link to customer',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Enter manually / new contact'),
              ),
              ...customerOptions.map(
                (customer) => DropdownMenuItem<String?>(
                  value: customer.id,
                  child: Text(
                    _customerMenuLabel(customer),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: isLoading
                ? null
                : (value) {
                    if (value == null) {
                      setState(() => selectedCustomerId = null);
                      return;
                    }
                    final match = customerOptions
                        .where((c) => c.id == value)
                        .toList();
                    _applyCustomer(match.isEmpty ? null : match.first);
                  },
          ),
          if (allowAddCustomer) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isLoading ? null : _openAddCustomer,
              icon: Icon(Icons.person_add_alt_1_rounded, color: scheme.primary),
              label: const Text('Add Customer'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerOptions = ref.watch(
      customerListProvider.select((s) => s.items),
    );
    final canCreateCustomer = ref.watch(
      authProvider.select((a) => a.hasPermission('customer.create')),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: _isCompleteDetails
            ? 'Complete Lead Details'
            : 'Create Lead (Basic)',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(18),
          child: formCard(
            children: [
              if (_isBasicCreate) ...[
                sectionTitle('Customer'),
                _linkedCustomerSection(
                  customerOptions: customerOptions,
                  allowAddCustomer: canCreateCustomer,
                ),
              ],
              sectionTitle('Basic Details'),
              if (!_isBasicCreate)
                _linkedCustomerSection(
                  customerOptions: customerOptions,
                  allowAddCustomer: canCreateCustomer,
                ),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input(
                      'Full Name',
                      fullName,
                      isRequired: true,
                      validator: _validateFullName,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z ]'),
                        ),
                      ],
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                    ),
                    input(
                      'Mobile Number',
                      mobile,
                      isRequired: true,
                      keyboardType: TextInputType.phone,
                      validator: _validateMobile,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                    ),
                    input(
                      'Email Address',
                      email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                    ),
                    input(
                      'Address',
                      address,
                      isRequired: _isCompleteDetails,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                      textInputAction: TextInputAction.next,
                    ),
                    input(
                      'City',
                      city,
                      isRequired: _isCompleteDetails,
                      validator: (v) => _validateOptionalAlpha(v, 'City'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z ]'),
                        ),
                      ],
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.addressCity],
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
              ),
              controllerDropdown(
                label: 'State',
                controller: state,
                items: indianStates,
                menuItems: _stateMenuItems,
                hintText: 'Select state',
                isRequired: _isCompleteDetails,
              ),
              input(
                'Pincode',
                pincode,
                isRequired: _isCompleteDetails,
                keyboardType: TextInputType.number,
                validator: _validatePincode,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
              input(
                'System Size (kW)',
                kw,
                isRequired: _isCompleteDetails,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => _validateNumber(v, 'System Size'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              if (!_isBasicCreate) ...[
                sectionTitle('Connection Details'),
                input(
                  'CA Number',
                  caNumber,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateMaxDigitNumber(v, 'CA Number', 10),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                input(
                  'K Number',
                  kNumber,
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateMaxDigitNumber(v, 'K Number', 20),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                input(
                  'Reference Number',
                  referenceNumber,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      _validateMaxDigitNumber(v, 'Reference Number', 10),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                controllerDropdown(
                  label: 'DISCOM',
                  controller: discom,
                  items: discomOptions,
                  menuItems: _discomMenuItems,
                  hintText: 'Select DISCOM',
                  isRequired: true,
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
                dropdown(
                  label: 'Bank Account Type',
                  value: bankAccountType,
                  items: const ['Saving', 'Current'],
                  isRequired: true,
                  onChanged: (value) {
                    if (value == null) return;
                    bankAccountType = value;
                  },
                ),
                input('Bank Name', bankName, isRequired: true),
                input(
                  'Account Number',
                  accountNumber,
                  isRequired: true,
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
                  isRequired: true,
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
                    projectType = value;
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
                    source = value;
                  },
                ),
                dropdown(
                  label: 'Priority',
                  value: priority,
                  items: const ['Low', 'Medium', 'High'],
                  onChanged: (value) {
                    if (value == null) return;
                    priority = value;
                  },
                ),
                sectionTitle('Site Checklist'),
                input(
                  'Available Shadow Free Area',
                  availableShadowFreeArea,
                  keyboardType: TextInputType.number,
                  validator: (v) => _validateMaxDigitNumber(
                    v,
                    'Available Shadow Free Area',
                    5,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  suffixText: 'sqmtr',
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
                localSwitchTile(
                  title: 'Roof Load Bearing Capacity',
                  getter: () => roofLoadBearingCapacity,
                  setter: (value) => roofLoadBearingCapacity = value,
                ),
                localSwitchTile(
                  title: 'Shadow Free Roof',
                  getter: () => shadowFreeRoof,
                  setter: (value) => shadowFreeRoof = value,
                ),
                localSwitchTile(
                  title: 'Vendor Visited Site',
                  getter: () => vendorVisitedSite,
                  setter: (value) => vendorVisitedSite = value,
                ),
                localSwitchTile(
                  title: 'Lead Active',
                  getter: () => isLeadActive,
                  setter: (value) => isLeadActive = value,
                ),
                sectionTitle('Notes'),
                input('Notes', notes, maxLines: 4),
                sectionTitle('Images & Documents'),
                if (!_mediaSectionReady)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else ...[
                  RepaintBoundary(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _singleImagePicker(
                          title: 'Roof Photo',
                          value: roofPhotoPath,
                          onChanged: (v) => setState(() => roofPhotoPath = v),
                        ),
                        _singleImagePicker(
                          title: 'Cheque/Passbook Copy',
                          value: chequePassbookPath,
                          isRequired: true,
                          onChanged: (v) =>
                              setState(() => chequePassbookPath = v),
                        ),
                        _singleImagePicker(
                          title: 'Pre-Installation Photo',
                          value: preInstallationPhotoPath,
                          onChanged: (v) =>
                              setState(() => preInstallationPhotoPath = v),
                        ),
                        _singleDocumentPicker(
                          title: 'Quotation Document',
                          value: quotationDocumentPath,
                          onChanged: (v) =>
                              setState(() => quotationDocumentPath = v),
                        ),
                        _predefinedFilesSection(
                          title: 'KYC & Agreement Documents',
                          items: predefinedDocumentSlots,
                          values: predefinedDocPaths,
                        ),
                        _predefinedFilesSection(
                          title: 'Predefined Images',
                          items: predefinedImageSlots,
                          values: predefinedImagePaths,
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
                          onRemove: (i) =>
                              setState(() => additionalImages.removeAt(i)),
                          onReplace: (i) => _replaceFileAt(
                            additionalImages,
                            i,
                            imageOnly: true,
                          ),
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
                          onRemove: (i) =>
                              setState(() => additionalDocs.removeAt(i)),
                          onReplace: (i) => _replaceFileAt(
                            additionalDocs,
                            i,
                            imageOnly: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: isLoading ? null : saveLead,
                  child: isLoading
                      ? SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isCompleteDetails
                              ? 'Save Details'
                              : _isBasicCreate
                              ? 'Submit'
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

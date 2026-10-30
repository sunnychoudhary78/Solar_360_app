import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:solar_sales/core/theme/app_design.dart';
import 'package:solar_sales/core/utils/upload_url.dart';
import 'package:solar_sales/core/widgets/app_message.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/customer_portal/data/customer_lead_rules.dart';
import 'package:solar_sales/features/customer_portal/presentation/providers/customer_portal_providers.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/features/customers/presentation/providers/customer_providers.dart';
import 'package:solar_sales/features/leads/data/electricity_bill_autofill.dart';
import 'package:solar_sales/features/leads/data/india_cities.dart';
import 'package:solar_sales/features/leads/data/india_states.dart';
import 'package:solar_sales/features/leads/data/lead_files.dart';
import 'package:solar_sales/features/leads/data/lead_repository.dart';
import 'package:solar_sales/features/leads/data/models/electricity_bill_model.dart';
import 'package:solar_sales/features/leads/data/models/lead_model.dart';
import 'package:solar_sales/features/leads/data/postal_pincode_lookup.dart';
import 'package:solar_sales/features/leads/presentation/providers/lead_providers.dart';
import 'package:solar_sales/shared/utils/validators.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';
import 'package:solar_sales/shared/widgets/india_state_city_fields.dart';
import 'package:solar_sales/shared/widgets/premium_feature_components.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// AI electricity-bill autofill is temporarily hidden from users.
/// Flip to `true` to bring back the summary banner, the "Auto-fills the form"
/// upload card, the per-field "From bill" tags and the bill-parse autofill.
const bool kAiBillAutofillEnabled = false;

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
  final bool customerPortal;
  /// Basic-details draft passed from the customer "Save & continue" step.
  final Map<String, String>? customerDraft;

  const LeadFormScreen({
    super.key,
    this.mode = LeadFormMode.basicCreate,
    this.existingLead,
    this.customerPortal = false,
    this.customerDraft,
  });

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  /// Matches backend `lead.source` ENUM / web SOURCES.
  static const List<String> sourceOptions = [
    'Website',
    'Facebook',
    'Instagram',
    'LinkedIn',
    'Google',
    'Referral',
    'Call',
    'WhatsApp',
    'Vendor',
    'Other',
    'Customer Portal',
  ];

  /// Matches backend `lead.priority` ENUM / web PRIORITIES.
  static const List<String> priorityOptions = [
    'Low',
    'Medium',
    'High',
    'Urgent',
  ];

  static const List<String> projectTypeOptions = [
    'Residential',
    'Commercial',
    'Industrial',
    'Agriculture',
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

  final bankAccountName = TextEditingController();
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
  String? _lastPickError;

  /// AI electricity-bill autofill state (parse is stateless, no lead created).
  bool isParsingBill = false;
  bool _discomOtherMode = false;
  int _autofillRevision = 0;
  bool _billAutofillActive = false;
  String _billParseMessage = '';
  final List<String> _billWarnings = [];
  final Set<String> _billFilledKeys = {};
  final Set<String> _billReviewKeys = {};
  final Set<String> _billMaskedKeys = {};

  /// Anchors used by the "Still needed" chips to jump to a section.
  final _basicSectionKey = GlobalKey();
  final _connectionSectionKey = GlobalKey();
  final _bankSectionKey = GlobalKey();
  final _projectSectionKey = GlobalKey();
  final _siteSectionKey = GlobalKey();
  final _documentsSectionKey = GlobalKey();

  late final List<DropdownMenuItem<String>> _discomMenuItems = discomOptions
      .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
      .toList(growable: false);

  bool get _isBasicCreate => widget.mode == LeadFormMode.basicCreate;
  bool get _isCompleteDetails => widget.mode == LeadFormMode.completeDetails;

  @override
  void initState() {
    super.initState();

    if (_isCompleteDetails || widget.customerPortal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isClosing) return;
        setState(() => _mediaSectionReady = true);
      });
    } else {
      _mediaSectionReady = true;
    }

    final lead = widget.existingLead;

    if (lead != null) {
      _applyLeadToForm(lead);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLeadFromApi(lead.id);
      });
    } else if (widget.customerDraft != null &&
        widget.customerDraft!.isNotEmpty) {
      _applyDraftToForm(widget.customerDraft!);
    } else if (widget.customerPortal) {
      source = 'Customer Portal';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prefillFromCustomerProfile();
      });
    }

    _applyCustomerSiteChecklistDefaults();

    if (_isBasicCreate || widget.customerPortal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchCurrentLocation();
      });
    }
  }

  void _applyCustomerSiteChecklistDefaults() {
    if (!widget.customerPortal || !_isCompleteDetails) return;
    roofLoadBearingCapacity = true;
    shadowFreeRoof = true;
    vendorVisitedSite = true;
  }

  Future<void> _refreshLeadFromApi(String leadId) async {
    try {
      final LeadModel fresh;
      if (widget.customerPortal) {
        final leads = await ref
            .read(customerLeadRepositoryProvider)
            .getAllLeads();
        final match = leads.where((item) => item.id == leadId);
        if (match.isEmpty) return;
        fresh = match.first;
      } else {
        fresh = await ref.read(leadRepositoryProvider).getLeadById(leadId);
      }
      if (!mounted || _isClosing) return;
      setState(() {
        _applyLeadToForm(fresh, keepCurrentMediaIfIncomingEmpty: true);
        _applyCustomerSiteChecklistDefaults();
      });
    } catch (_) {
      // Keep whatever was already prefilled from existingLead.
    }
  }

  void _applyLeadMediaOnly(
    LeadModel lead, {
    bool keepCurrentIfIncomingEmpty = false,
  }) {
    String? pick(String incoming, String? current) {
      final currentPath = (current ?? '').trim();
      // Never replace a file the user just picked locally with a server value.
      if (currentPath.isNotEmpty && !_isExistingRemotePath(currentPath)) {
        return currentPath;
      }
      final path = _nonEmptyPath(incoming);
      if (path != null) return path;
      return keepCurrentIfIncomingEmpty ? current : null;
    }

    roofPhotoPath = pick(lead.roofPhoto, roofPhotoPath);
    bankClearPhotoPath = pick(lead.bankClearPhoto, bankClearPhotoPath);
    chequePassbookPath = pick(lead.chequePassbookCopy, chequePassbookPath);
    preInstallationPhotoPath = pick(
      lead.preInstallationPhoto,
      preInstallationPhotoPath,
    );
    quotationDocumentPath = pick(
      lead.quotationDocument,
      quotationDocumentPath,
    );

    final incomingDocs = lead.additionalDocuments.trim();
    final incomingImages = lead.additionalImages.trim();
    final hadDocs =
        predefinedDocPaths.values.any((value) => (value ?? '').trim().isNotEmpty) ||
        additionalDocs.isNotEmpty;
    final hadImages =
        predefinedImagePaths.values.any(
          (value) => (value ?? '').trim().isNotEmpty,
        ) ||
        additionalImages.isNotEmpty;
    final hasLocalDocs = _hasLocalTitledPick(predefinedDocPaths, additionalDocs);
    final hasLocalImages = _hasLocalTitledPick(
      predefinedImagePaths,
      additionalImages,
    );

    if (!hasLocalDocs &&
        (incomingDocs.isNotEmpty || !keepCurrentIfIncomingEmpty || !hadDocs)) {
      for (final key in predefinedDocPaths.keys) {
        predefinedDocPaths[key] = null;
      }
      additionalDocs.clear();
      _prefillStoredTitledFiles(
        incomingDocs,
        predefinedDocPaths,
        additionalDocs,
      );
    }
    if (!hasLocalImages &&
        (incomingImages.isNotEmpty ||
            !keepCurrentIfIncomingEmpty ||
            !hadImages)) {
      for (final key in predefinedImagePaths.keys) {
        predefinedImagePaths[key] = null;
      }
      additionalImages.clear();
      _prefillStoredTitledFiles(
        incomingImages,
        predefinedImagePaths,
        additionalImages,
      );
    }
  }

  void _applyLeadToForm(
    LeadModel lead, {
    bool keepCurrentMediaIfIncomingEmpty = false,
  }) {
    fullName.text = lead.fullName;
    mobile.text = lead.mobile;
    email.text = lead.email;
    address.text = lead.address;
    _applyStateCity(lead.state, lead.city);
    pincode.text = lead.pincode;
    kw.text = lead.loadSectionKw;

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
    selectedCustomerId = lead.customerId.isEmpty ? null : lead.customerId;

    projectType = _matchedOption(
      lead.projectType,
      projectTypeOptions,
      projectType,
    );
    source = _matchedOption(
      lead.source,
      sourceOptions,
      widget.customerPortal ? 'Customer Portal' : source,
    );
    priority = _matchedOption(lead.priority, priorityOptions, priority);

    bankAccountType = lead.resolvedBankAccountType ?? bankAccountType;
    roofLoadBearingCapacity = lead.roofLoadBearingCapacity;
    shadowFreeRoof = lead.shadowFreeRoof;
    vendorVisitedSite = lead.vendorVisitedSite;

    _applyLeadMediaOnly(
      lead,
      keepCurrentIfIncomingEmpty: keepCurrentMediaIfIncomingEmpty,
    );
    _applyCustomerSiteChecklistDefaults();
  }

  void _applyStateCity(String? rawState, String? rawCity) {
    final nextState = normalizeStateName(rawState);
    state.text = nextState;
    city.text = resolveIndiaCityName(rawCity, nextState);
  }

  void _applyDraftToForm(Map<String, String> draft) {
    String read(String key) => draft[key]?.trim() ?? '';

    fullName.text = read('full_name');
    mobile.text = read('mobile');
    email.text = read('email');
    address.text = read('address');
    _applyStateCity(read('state'), read('city'));
    pincode.text = read('pincode');
    kw.text = read('load_section_kw');
    source = 'Customer Portal';
  }

  String _matchedOption(
    String current,
    List<String> options,
    String fallback,
  ) {
    final value = current.trim();
    if (value.isEmpty) return fallback;
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return value;
  }

  List<String> _menuItemsWithCurrent(List<String> options, String current) {
    final value = current.trim();
    if (value.isEmpty || options.contains(value)) return options;
    return [value, ...options];
  }

  // ---------------------------------------------------------------------------
  // AI electricity-bill autofill
  // ---------------------------------------------------------------------------

  /// Current value of a bill key, so a typed value is never overwritten.
  String? _billCurrentValue(String key) {
    switch (key) {
      case 'full_name':
        return fullName.text;
      case 'mobile':
        return mobile.text;
      case 'email':
        return email.text;
      case 'address':
        return address.text;
      case 'city':
        return city.text;
      case 'state':
        return state.text;
      case 'pincode':
        return pincode.text;
      case 'load_section_kw':
        return kw.text;
      case 'ca_number':
        return caNumber.text;
      case 'k_number':
        return kNumber.text;
      case 'reference_number':
        return referenceNumber.text;
      case 'discom':
        return discom.text;
      case 'project_type':
        return projectType;
      case 'bank_account_name':
        return bankAccountName.text;
      case 'bank_name':
        return bankName.text;
      case 'account_number':
        return accountNumber.text;
      case 'account_type':
        return bankAccountType;
      case 'ifsc_code':
        return ifscCode.text;
      case 'available_shadow_free_area':
        return availableShadowFreeArea.text;
      case 'quotation_amount':
        return quotationAmount.text;
      case 'visited_employee_name':
        return visitedEmployeeName.text;
      case 'visited_employee_contact':
        return visitedEmployeeContact.text;
      case 'electricity_bill':
        return predefinedDocPaths['Electricity Bill'];
      case 'aadhaar_front':
        return predefinedDocPaths['Aadhaar Front'];
      case 'aadhaar_back':
        return predefinedDocPaths['Aadhaar Back'];
      case 'pan_card':
        return predefinedDocPaths['PAN Card'];
      case 'cheque_passbook':
        return chequePassbookPath;
      case 'pre_installation_photo':
        return preInstallationPhotoPath;
      case 'roof_load_bearing_capacity':
        return roofLoadBearingCapacity ? 'true' : '';
      case 'shadow_free_roof':
        return shadowFreeRoof ? 'true' : '';
      case 'vendor_visited_site':
        return vendorVisitedSite ? 'true' : '';
      default:
        return null;
    }
  }

  /// Staff: `POST /leads/parse-electricity-bill`. Customer portal:
  /// `POST /customers/leads/parse-electricity-bill`. Parse never saves.
  Future<void> _parseElectricityBill(String path) async {
    final filePath = path.trim();
    if (filePath.isEmpty || isParsingBill || isLoading) return;

    final rejection = _billFileRejection(filePath);
    if (rejection != null) {
      showAppMessage(context, rejection, isError: true);
      return;
    }

    setState(() {
      isParsingBill = true;
      _billAutofillActive = false;
    });

    final repo = widget.customerPortal
        ? ref.read(customerLeadRepositoryProvider)
        : ref.read(leadRepositoryProvider);

    try {
      final result = await repo.parseElectricityBill(filePath);
      if (!mounted || _isClosing) return;
      await _applyBillAutofill(result);
    } on ElectricityBillParseException catch (e) {
      // Parse failure never blocks the form — keep the file, let the user type.
      if (!mounted) return;
      setState(() => isParsingBill = false);
      showAppMessage(
        context,
        e.message.isEmpty ? 'Could not read the electricity bill.' : e.message,
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => isParsingBill = false);
      showAppMessage(
        context,
        'Could not read the electricity bill. Fill the form manually.',
        isError: true,
      );
    }
  }

  String? _billFileRejection(String path) {
    int? size;
    try {
      final file = File(path);
      if (file.existsSync()) size = file.lengthSync();
    } catch (_) {}
    return billUploadRejection(
      sizeBytes: size ?? 0,
      filename: fileDisplayName(path),
    );
  }

  /// Applies the parse JSON on device: empty fields only, masked values
  /// skipped, `confidence < 0.75` flagged for review, and the name copied to
  /// the account holder when that is still empty.
  Future<void> _applyBillAutofill(ElectricityBillParseResult result) async {
    final outcome = planBillAutofill(
      result: result,
      typedValue: _billCurrentValue,
    );

    // Work on copies so values rejected below are not reported as "filled".
    final filledKeys = <String>{...outcome.filledKeys};
    final reviewKeys = <String>{...outcome.reviewKeys};
    final maskedKeys = <String>{...result.maskedKeys, ...outcome.maskedKeys};

    void setText(TextEditingController controller, String key) {
      final value = outcome.values[key];
      if (value != null && value.isNotEmpty) controller.text = value;
    }

    setText(fullName, 'full_name');
    setText(caNumber, 'ca_number');
    setText(kNumber, 'k_number');
    setText(referenceNumber, 'reference_number');
    setText(discom, 'discom');
    setText(kw, 'load_section_kw');
    setText(address, 'address');
    setText(pincode, 'pincode');
    setText(bankAccountName, 'bank_account_name');

    // Mobile: only a real 10-digit number. A masked value (98XXXXXX12,
    // ******1234) is never written into the field.
    if (outcome.values.containsKey('mobile')) {
      final cleanMobile = _cleanBillMobile(outcome.values['mobile']);
      if (cleanMobile != null) {
        if (mobile.text.trim().isEmpty) mobile.text = cleanMobile;
      } else {
        filledKeys.remove('mobile');
        reviewKeys.remove('mobile');
        maskedKeys.add('mobile');
      }
    }

    // Email: must be a syntactically valid address, otherwise leave it empty.
    if (outcome.values.containsKey('email')) {
      final cleanEmail = _cleanBillEmail(outcome.values['email']);
      if (cleanEmail != null) {
        if (email.text.trim().isEmpty) email.text = cleanEmail;
      } else {
        filledKeys.remove('email');
        reviewKeys.remove('email');
      }
    }

    // State/City: normalise to the dropdown values, otherwise the selects
    // show nothing even though the bill was read correctly.
    final rawState = outcome.values['state'];
    final rawCity = outcome.values['city'];
    if ((rawState ?? '').trim().isNotEmpty ||
        (rawCity ?? '').trim().isNotEmpty) {
      var nextState = state.text;
      if ((rawState ?? '').trim().isNotEmpty) {
        final normalized = normalizeStateName(rawState);
        nextState = normalized.trim().isNotEmpty
            ? normalized
            : rawState!.trim();
        state.text = nextState;
      }
      if ((rawCity ?? '').trim().isNotEmpty) {
        final resolved = resolveIndiaCityName(rawCity, nextState);
        // Never drop a city the bill gave us just because it is not in the list.
        city.text = resolved.trim().isNotEmpty ? resolved : rawCity!.trim();
      }
    }

    final nextProjectType = outcome.values['project_type'];
    final filledCity = outcome.values['city'];
    final filledState = outcome.values['state'];

    setState(() {
      if (nextProjectType != null && nextProjectType.isNotEmpty) {
        projectType = _matchedOption(
          nextProjectType,
          projectTypeOptions,
          projectType,
        );
      }
      _billFilledKeys
        ..clear()
        ..addAll(filledKeys);
      _billReviewKeys
        ..clear()
        ..addAll(reviewKeys);
      _billMaskedKeys
        ..clear()
        ..addAll(maskedKeys);
      _billWarnings
        ..clear()
        ..addAll(result.warnings);
      // Rebuild the dropdown-style fields so they pick up controller values
      // that were set after they were first built.
      _autofillRevision++;
      _discomOtherMode = false;

      // Count only fields that are visible AND really hold a value now, so the
      // banner number always matches what is on screen.
      filledKeys.removeWhere(
        (k) =>
            !_isBillKeyVisible(k) ||
            (_billCurrentValue(k) ?? '').trim().isEmpty,
      );
      reviewKeys.removeWhere((k) => !filledKeys.contains(k));
      _billFilledKeys
        ..clear()
        ..addAll(filledKeys);
      _billReviewKeys
        ..clear()
        ..addAll(reviewKeys);
      final shown = filledKeys.length;
      _billParseMessage = shown == 0
          ? 'No fields could be read from the bill'
          : 'Filled $shown field${shown == 1 ? '' : 's'} from the bill. '
              'Please review the green labels.';
      _billAutofillActive = true;
      isParsingBill = false;
    });

    // Jump to the most relevant section so the user can check the read values.
    // Backend doc: after a parse, jump to Electricity Details so the user
    // checks consumer number / DISCOM / load.
    _scrollToAnchor(_connectionSectionKey);

    // Optional public pincode lookup — fills state/city only when still empty.
    if (outcome.filledKeys.contains('pincode') &&
        RegExp(r'^\d{6}$').hasMatch(pincode.text.trim()) &&
        (filledState == null || filledCity == null)) {
      final lookup = await lookupPostalPincode(pincode.text);
      if (!mounted || lookup == null) return;
      setState(() {
        if (state.text.trim().isEmpty && lookup.state.isNotEmpty) {
          state.text = lookup.state;
        }
        if (city.text.trim().isEmpty && lookup.city.isNotEmpty) {
          city.text = lookup.city;
        }
      });
    }
  }

  static final RegExp _validEmailRe = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  /// Returns a clean 10-digit mobile, or null when missing/masked.
  String? _cleanBillMobile(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (RegExp(r'[xX*•#]').hasMatch(value)) return null; // masked on the bill
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(digits.length - 10);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
  }

  /// Returns a valid email, or null (never partial/garbled text).
  String? _cleanBillEmail(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || !_validEmailRe.hasMatch(value)) return null;
    if (RegExp(r'[xX*•]{3,}').hasMatch(value)) return null;
    return value;
  }

  /// Bill keys that have a visible field in the current form mode.
  bool _isBillKeyVisible(String key) {
    const basicKeys = {
      'full_name',
      'mobile',
      'email',
      'address',
      'city',
      'state',
      'pincode',
      'load_section_kw',
      'ca_number',
      'k_number',
      'reference_number',
      'discom',
      'project_type',
    };
    if (key == 'electricity_bill') return false; // the uploaded file itself
    return _isBasicCreate ? basicKeys.contains(key) : true;
  }

  void _resetBillAutofill() {
    if (!_billAutofillActive && !isParsingBill) return;
    setState(() {
      isParsingBill = false;
      _billAutofillActive = false;
      _billParseMessage = '';
      _billWarnings.clear();
      _billFilledKeys.clear();
      _billReviewKeys.clear();
      _billMaskedKeys.clear();
    });
  }

  void _scrollToAnchor(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  GlobalKey _anchorForBillSection(String section) {
    switch (section) {
      case 'electricity':
        return _connectionSectionKey;
      case 'bank':
        return _bankSectionKey;
      case 'documents':
        return _documentsSectionKey;
      case 'site':
        return _siteSectionKey;
      case 'source':
        return _projectSectionKey;
      default:
        return _basicSectionKey;
    }
  }

  List<String> _billLabelsFor(Set<String> keys) {
    final labels = <String>[];
    for (final key in kBillFieldOrder) {
      if (keys.contains(key)) labels.add(billFieldLabel(key));
    }
    for (final key in keys) {
      if (!kBillFieldOrder.contains(key)) labels.add(billFieldLabel(key));
    }
    return labels;
  }

  Widget? _billTag(String key) {
    if (!kAiBillAutofillEnabled || !_billAutofillActive) return null;
    if (_billMaskedKeys.contains(key)) {
      return _billTagChip('Masked on the bill', const Color(0xFF6D4C41));
    }
    if (_billReviewKeys.contains(key)) {
      return _billTagChip('Review from bill', const Color(0xFFEF6C00));
    }
    if (_billFilledKeys.contains(key)) {
      return _billTagChip('From bill', const Color(0xFF2E7D32));
    }
    return null;
  }

  Widget _billTagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _billAutofillBanner() {
    if (!isParsingBill && !_billAutofillActive) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    if (isParsingBill) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Reading electricity bill…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final stillNeeded = stillNeededBillKeys(
      fullForm: !_isBasicCreate,
      typedValue: _billCurrentValue,
    );
    final reviewLabels = _billLabelsFor(_billReviewKeys);
    final maskedLabels = _billLabelsFor(_billMaskedKeys);
    final filledCount = _billFilledKeys.where(_isBillKeyVisible).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _billParseMessage.isNotEmpty
                      ? _billParseMessage
                      : '$filledCount fields read from the bill',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Hide summary',
                onPressed: _resetBillAutofill,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (_billWarnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final warning in _billWarnings)
              Text(
                '• $warning',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _billTagChip('From bill: $filledCount', const Color(0xFF2E7D32)),
              if (reviewLabels.isNotEmpty)
                _billTagChip(
                  'Review from bill: ${reviewLabels.join(', ')}',
                  const Color(0xFFEF6C00),
                ),
              if (maskedLabels.isNotEmpty)
                _billTagChip(
                  'Masked on the bill: ${maskedLabels.join(', ')}',
                  const Color(0xFF6D4C41),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Still needed (${stillNeeded.length})',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (stillNeeded.isEmpty)
            Text(
              'All required fields are filled. Review and save.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in stillNeeded)
                  ActionChip(
                    label: Text(billFieldLabel(key)),
                    onPressed: () => _scrollToAnchor(
                      _anchorForBillSection(billFieldSection(key)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _billAutofillUploadSection() {
    final scheme = Theme.of(context).colorScheme;
    final path = predefinedDocPaths['Electricity Bill']?.trim() ?? '';
    final hasFile = path.isNotEmpty;

    return AppCard(
      variant: AppCardVariant.outlined,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Electricity Bill',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Auto-fills the form',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: isLoading || isParsingBill
                ? null
                : () async {
                    final picked = await _pickSingleFile(imageOnly: false);
                    if (picked == null || !mounted) return;
                    setState(() => predefinedDocPaths['Electricity Bill'] = picked);

                    // Trigger parse
                    final rejection = _billFileRejection(picked);
                    if (rejection != null) {
                      setState(() => predefinedDocPaths['Electricity Bill'] = null);
                      showAppMessage(context, rejection, isError: true);
                      return;
                    }
                    _parseElectricityBill(picked);
                  },
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    hasFile
                        ? Icons.file_present_rounded
                        : Icons.cloud_upload_outlined,
                    size: 32,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFile ? fileDisplayName(path) : 'Upload File',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, JPG, PNG and more (Max 5MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasFile) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tap to replace',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    return value.isEmpty ? null : value;
  }

  bool isImagePath(String? path) {
    if (path == null || path.isEmpty) return false;
    final p = path.toLowerCase();
    if (RegExp(
      r'\.(jpg|jpeg|png|gif|webp|bmp|heic|heif)$',
    ).hasMatch(p)) {
      return true;
    }
    return p.startsWith('content://') && p.contains('image');
  }

  bool _isLocalPickedPath(String? path) {
    final value = (path ?? '').trim();
    return value.isNotEmpty && !_isExistingRemotePath(value);
  }

  bool _hasLocalTitledPick(
    Map<String, String?> predefined,
    List<TitledLocalFile> freeform,
  ) {
    return predefined.values.any(_isLocalPickedPath) ||
        freeform.any((item) => _isLocalPickedPath(item.path));
  }

  bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');

  String fileDisplayName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  String? _nonEmptyPath(String? value) {
    final path = LeadModel.filePathFrom(value);
    return path.isEmpty ? null : path;
  }

  bool _isExistingRemotePath(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return false;
    final lower = normalized.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    if (lower.startsWith('/api/uploads/') ||
        lower.startsWith('api/uploads/') ||
        lower.startsWith('/uploads/') ||
        lower.startsWith('uploads/') ||
        lower.startsWith('leads/')) {
      return true;
    }
    // Absolute device paths are new local picks.
    if (normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(normalized) ||
        lower.startsWith('content://') ||
        lower.startsWith('file://')) {
      return false;
    }
    // Anything else is treated as an already-stored relative server path.
    return true;
  }

  void _prefillStoredTitledFiles(
    String raw,
    Map<String, String?> predefinedTarget,
    List<TitledLocalFile> freeformTarget,
  ) {
    if (raw.trim().isEmpty) return;
    for (final item in parseTitledFileEntries(raw)) {
      final title = item.title.trim();
      final path = item.path.trim();
      if (path.isEmpty) continue;
      if (title.isNotEmpty && predefinedTarget.containsKey(title)) {
        // Last path wins for a named slot so edit/replace never duplicates it.
        predefinedTarget[title] = path;
      } else {
        freeformTarget.add(
          TitledLocalFile(
            title: title.isEmpty ? 'Document' : title,
            path: path,
          ),
        );
      }
    }
  }

  /// All current titled slots (predefined + freeform), including unchanged
  /// remote paths so the API can keep them via `existingPath`.
  List<TitledLocalFile> _allTitledEntries(
    Map<String, String?> predefined,
    List<TitledLocalFile> freeform,
  ) {
    final seenPredefined = <String>{};
    final out = <TitledLocalFile>[];
    for (final entry in predefined.entries) {
      final path = (entry.value ?? '').trim();
      if (path.isEmpty) continue;
      seenPredefined.add(entry.key.trim().toLowerCase());
      out.add(TitledLocalFile(title: entry.key, path: path));
    }
    for (final item in freeform) {
      if (item.path.trim().isEmpty) continue;
      final key = item.title.trim().toLowerCase();
      if (key.isNotEmpty && seenPredefined.contains(key)) continue;
      out.add(item);
    }
    return out;
  }

  Map<String, String> _singleFileUploadsForSave() {
    final lead = widget.existingLead;
    final map = <String, String>{};

    void put(String field, String? current, String previous) {
      final value = current?.trim() ?? '';
      if (value.isNotEmpty) {
        map[field] = value;
        return;
      }
      // Explicit clear only when a previously saved file was removed.
      if (previous.trim().isNotEmpty) {
        map[field] = '';
      }
    }

    put('roof_photo', roofPhotoPath, lead?.roofPhoto ?? '');
    put('bank_clear_photo', bankClearPhotoPath, lead?.bankClearPhoto ?? '');
    put(
      'cheque_passbook_copy',
      chequePassbookPath,
      lead?.chequePassbookCopy ?? '',
    );
    put(
      'pre_installation_photo',
      preInstallationPhotoPath,
      lead?.preInstallationPhoto ?? '',
    );
    put(
      'quotation_document',
      quotationDocumentPath,
      lead?.quotationDocument ?? '',
    );
    return map;
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

    if (_isExistingRemotePath(path)) {
      final url = resolveUploadUrl(path);
      if (url.isEmpty) return _docPreview(path);
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: (resolvedWidth * dpr).round().clamp(1, 4096),
        memCacheHeight: (height * dpr).round().clamp(1, 4096),
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => _docPreview(path),
      );
    }

    return Image.file(
      File(path),
      key: ValueKey(path),
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

  String _guessPickedExtension({
    String? name,
    String? path,
    List<int>? bytes,
    required bool imageOnly,
  }) {
    final candidates = [name, path]
        .whereType<String>()
        .map((value) => value.toLowerCase().split(RegExp(r'[?#]')).first)
        .toList();
    for (final ext in [
      '.jpeg',
      '.jpg',
      '.png',
      '.webp',
      '.gif',
      '.jfif',
      '.bmp',
      '.pdf',
      '.docx',
      '.doc',
      '.xlsx',
      '.xls',
      '.csv',
      '.txt',
      '.rtf',
      '.heic',
      '.heif',
    ]) {
      if (candidates.any((value) => value.endsWith(ext))) {
        return ext == '.jpeg' ? '.jpg' : ext;
      }
    }
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return '.png';
      if (bytes[0] == 0x47 && bytes[1] == 0x49) return '.gif';
      if (bytes[0] == 0x25 && bytes[1] == 0x50) return '.pdf';
    }
    return imageOnly ? '.jpg' : '.bin';
  }

  Future<String?> _persistPickedBytes({
    String? path,
    List<int>? bytes,
    String? originalName,
    required bool imageOnly,
  }) async {
    _lastPickError = null;
    final rawPath = path?.trim() ?? '';
    List<int>? data = bytes;
    if ((data == null || data.isEmpty) && rawPath.isNotEmpty) {
      try {
        final file = File(rawPath);
        if (await file.exists()) {
          data = await file.readAsBytes();
        }
      } catch (_) {}
    }
    if (data == null || data.isEmpty) {
      return rawPath.isEmpty ? null : rawPath;
    }

    _lastPickError = leadUploadRejection(
      sizeBytes: data.length,
      filename: originalName ?? rawPath,
      imageOnly: imageOnly,
    );
    if (_lastPickError != null) return null;

    try {
      final dir = await getTemporaryDirectory();
      final mediaDir = Directory('${dir.path}/lead_picks');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      final ext = _guessPickedExtension(
        name: originalName,
        path: rawPath,
        bytes: data,
        imageOnly: imageOnly,
      );
      final saved = File(
        '${mediaDir.path}/${DateTime.now().microsecondsSinceEpoch}$ext',
      );
      await saved.writeAsBytes(data, flush: true);
      return saved.path;
    } catch (_) {
      return rawPath.isEmpty ? null : rawPath;
    }
  }

  Future<String?> _persistXFile(XFile file, {bool imageOnly = true}) async {
    List<int>? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {}
    return _persistPickedBytes(
      path: file.path,
      bytes: bytes,
      originalName: file.name,
      imageOnly: imageOnly,
    );
  }

  Future<XFile?> _pickCompressedImage(ImageSource source) async {
    try {
      return await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      try {
        return await _imagePicker.pickImage(source: source);
      } catch (_) {
        return null;
      }
    }
  }

  String? _validateMobile(String? value) => AppValidators.phone(value);

  String? _validateOptionalMobile(String? value) =>
      AppValidators.optionalPhone(value);

  String? _validateEmail(String? value) => AppValidators.optionalEmail(value);

  String? _requiredThen(String? value, String label, String? Function(String?)? next) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return next?.call(value);
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

  /// Customer portal save uses the same backend endpoints as the web app:
  /// POST `/customers/leads` only when this customer has no lead yet.
  /// Edit always multipart-PUTs `/customers/leads/:id` (multer is on that route).
  Future<void> _saveCustomerPortalLead({
    required LeadRepository repo,
    required Map<String, dynamic> data,
    required Map<String, String> singleFiles,
    required List<TitledLocalFile> documents,
    required List<TitledLocalFile> images,
  }) async {
    data.remove('status');
    data.remove('lead_stage');
    data.remove('workflow_step');
    data.remove('current_department');

    final existingLeads = await repo.getAllLeads();
    final leadId = reusableCustomerLeadId(
          existingLeadId: widget.existingLead?.id,
          existingLeads: existingLeads,
        ) ??
        '';

    if (hasConvertedCustomerLead(existingLeads) &&
        (leadId.isEmpty ||
            !existingLeads.any(
              (lead) => lead.id == leadId && canCustomerEditLead(lead),
            ))) {
      throw Exception(
        'This lead is converted. Details can no longer be filled or updated.',
      );
    }

    final imagePayload = images.map((e) => e.toPayload()).toList();
    final documentPayload = documents.map((e) => e.toPayload()).toList();

    if (leadId.isEmpty) {
      data['status'] = 'New Lead';
      data['is_active'] = true;
      await repo.createLead(
        data,
        singleFilePaths: {
          for (final e in singleFiles.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
        additionalImageEntries: imagePayload,
        additionalDocumentEntries: documentPayload,
      );
      return;
    }

    data['is_active'] = true;
    data['roof_load_bearing_capacity'] = roofLoadBearingCapacity;
    data['shadow_free_roof'] = shadowFreeRoof;
    data['vendor_visited_site'] = vendorVisitedSite;

    await repo.updateLeadWithFiles(
      leadId,
      data,
      singleFilePaths: singleFiles,
      additionalImageEntries: imagePayload,
      additionalDocumentEntries: documentPayload,
    );

    // Clean leftover scratch leads from older app versions. Do not POST extras.
    for (final extra in existingLeads) {
      if (extra.id == leadId) continue;
      if (!extra.notes.toLowerCase().contains('[file-scratch]')) continue;
      await _deactivateCustomerLead(repo, extra.id);
    }
  }

  Future<void> _deactivateCustomerLead(LeadRepository repo, String leadId) async {
    final id = leadId.trim();
    if (id.isEmpty) return;
    try {
      await repo.updateLead(id, {'is_active': false});
    } catch (_) {}
  }

  Future<void> saveLead() async {
    FocusScope.of(context).unfocus();

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      showAppMessage(context, 'Please fix validation errors', isError: true);
      return;
    }

    if (_isCompleteDetails) {
      final missingUploads = _missingRequiredUploads();
      if (missingUploads.isNotEmpty) {
        showAppMessage(
          context,
          '${missingUploads.first} is required',
          isError: true,
        );
        return;
      }
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
      'bank_account_name': _textOrNull(bankAccountName) ?? _textOrNull(fullName),
      'account_type': bankAccountType,
      'bank_name': _textOrNull(bankName),
      'account_number': _textOrNull(accountNumber),
      'ifsc_code': _textOrNull(ifscCode)?.toUpperCase(),
      'project_type': projectType,
      'source': source.trim().isEmpty
          ? (widget.customerPortal ? 'Customer Portal' : 'Website')
          : source,
      'priority': priority.trim().isEmpty ? 'Medium' : priority,
      'notes': _textOrNull(notes),
      'customer_id': widget.customerPortal
          ? (ref.read(authProvider).customer?.id ?? selectedCustomerId)
          : selectedCustomerId,
      'roof_photo_status': 'Pending',
      'available_shadow_free_area': _textOrNull(availableShadowFreeArea),
      'quotation_amount': _textOrNull(quotationAmount),
      'visited_employee_name': _textOrNull(visitedEmployeeName),
      'visited_employee_contact': _textOrNull(visitedEmployeeContact),
      'roof_load_bearing_capacity': roofLoadBearingCapacity.toString(),
      'shadow_free_roof': shadowFreeRoof.toString(),
      'vendor_visited_site': vendorVisitedSite.toString(),
      'is_active': 'true',
    };
    final mergedAdditionalImages = _allTitledEntries(
      predefinedImagePaths,
      additionalImages,
    );
    final mergedAdditionalDocs = _allTitledEntries(
      predefinedDocPaths,
      additionalDocs,
    );
    final singleFiles = _singleFileUploadsForSave();

    if (mounted) setState(() => isLoading = true);
    _isClosing = true;

    try {
      final repo = widget.customerPortal
          ? ref.read(customerLeadRepositoryProvider)
          : ref.read(leadRepositoryProvider);

      if (widget.customerPortal) {
        await _saveCustomerPortalLead(
          repo: repo,
          data: data,
          singleFiles: singleFiles,
          documents: mergedAdditionalDocs,
          images: mergedAdditionalImages,
        );
      } else if (_isCompleteDetails && widget.existingLead != null) {
        await repo.updateLeadWithFiles(
          widget.existingLead!.id,
          data,
          singleFilePaths: singleFiles,
          additionalImageEntries: mergedAdditionalImages
              .map((e) => e.toPayload())
              .toList(),
          additionalDocumentEntries: mergedAdditionalDocs
              .map((e) => e.toPayload())
              .toList(),
        );
      } else if (_isBasicCreate) {
        final customerId = widget.customerPortal
            ? (ref.read(authProvider).customer?.id ?? selectedCustomerId)
            : selectedCustomerId;
        final basicData = <String, dynamic>{
          'full_name': data['full_name'],
          'mobile': data['mobile'],
          'email': data['email'],
          'address': data['address'],
          'city': data['city'],
          'state': data['state'],
          'pincode': data['pincode'],
          'load_section_kw': data['load_section_kw'],
          'ca_number': data['ca_number'],
          'k_number': data['k_number'],
          'reference_number': data['reference_number'],
          'discom': data['discom'],
          'project_type': data['project_type'],
          'source': data['source'],
          'priority': data['priority'],
          'notes': data['notes'],
          if (customerId != null && customerId.isNotEmpty)
            'customer_id': customerId,
        };
        final created = await repo.createLead(
          basicData,
          singleFilePaths: {
            for (final e in singleFiles.entries)
              if (e.value.isNotEmpty) e.key: e.value,
          },
          additionalImageEntries: mergedAdditionalImages
              .map((e) => e.toPayload())
              .toList(),
          additionalDocumentEntries: mergedAdditionalDocs
              .map((e) => e.toPayload())
              .toList(),
        );
        if (!mounted) return;

        if (widget.customerPortal) {
          Navigator.of(context).pop(created ?? true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showAppMessage(
              null,
              created != null
                  ? 'Basic details saved. Continue with the full form.'
                  : 'Lead created. Open it again to complete the remaining details.',
            );
          });
          return;
        }

        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            ref.invalidate(allLeadsProvider);
          } catch (_) {}
          showAppMessage(null, 'Lead created and sent to Support for approval');
        });
        return;
      } else {
        await repo.createLead(
          data,
          singleFilePaths: {
            for (final e in singleFiles.entries)
              if (e.value.isNotEmpty) e.key: e.value,
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

      final successMessage = widget.customerPortal && _isCompleteDetails
          ? 'Lead details submitted successfully'
          : _isCompleteDetails
          ? 'Lead details saved successfully'
          : 'Lead created and sent to Support for approval';

      // Close the form before refreshing providers or showing feedback so we
      // never rebuild this route while it is being removed from the tree.
      Navigator.of(context).pop(true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (widget.customerPortal) {
            ref.invalidate(customerLeadsProvider);
          } else {
            ref.invalidate(allLeadsProvider);
          }
        } catch (_) {}
        showAppMessage(null, successMessage);
      });
    } catch (e) {
      _isClosing = false;
      if (!mounted) return;
      setState(() => isLoading = false);
      showAppMessage(context, 'Failed to save lead: ${_saveErrorMessage(e)}', isError: true);
    }
  }

  List<String> _missingRequiredUploads() {
    final missing = <String>[];
    if ((chequePassbookPath ?? '').trim().isEmpty) {
      missing.add('Cheque/Passbook Copy');
    }
    for (final title in kycRequiredDocumentTitles) {
      if ((predefinedDocPaths[title] ?? '').trim().isEmpty) {
        missing.add(title);
      }
    }
    return missing;
  }

  String _saveErrorMessage(Object error) {
    var message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }
    return message;
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
    Widget? tag,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedKeyboardType =
        maxLines > 1 && identical(keyboardType, TextInputType.text)
            ? TextInputType.multiline
            : keyboardType;
    final resolvedValidator = isRequired
        ? (String? value) => _requiredThen(value, label, validator)
        : validator;

    final field = Padding(
      padding: EdgeInsets.only(bottom: tag == null ? AppSpacing.md - 2 : 4),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: !isLoading,
        readOnly: readOnly,
        keyboardType: resolvedKeyboardType,
        maxLines: maxLines,
        validator: resolvedValidator,
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

    if (tag == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: AppSpacing.md - 2,
          ),
          child: Align(alignment: Alignment.centerLeft, child: tag),
        ),
      ],
    );
  }

  Widget controllerDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    required String hintText,
    List<DropdownMenuItem<String>>? menuItems,
    bool isRequired = false,
    Widget? tag,
  }) {
    final textValue = controller.text.trim();
    final resolvedItems = _menuItemsWithCurrent(items, textValue);
    final currentValue =
        resolvedItems.contains(textValue) && textValue.isNotEmpty
            ? textValue
            : null;
    final resolvedMenuItems = textValue.isNotEmpty && !items.contains(textValue)
        ? [
            DropdownMenuItem<String>(
              value: textValue,
              child: Text(textValue),
            ),
            ...(menuItems ??
                items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(growable: false)),
          ]
        : menuItems ??
            resolvedItems
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                .toList(growable: false);

    final field = Padding(
      padding: EdgeInsets.only(bottom: tag == null ? AppSpacing.md - 2 : 4),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        isExpanded: true,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: isRequired
            ? (value) {
                final selected = (value ?? controller.text).trim();
                if (selected.isEmpty) return '$label is required';
                return null;
              }
            : null,
        decoration: InputDecoration(
          label: _requiredFieldLabel(label, isRequired: isRequired),
          hintText: hintText,
        ),
        items: resolvedMenuItems,
        onChanged: isLoading
            ? null
            : (value) {
                if (value == null) return;
                // FormField updates its own UI; avoid rebuilding the whole form.
                controller.text = value;
              },
      ),
    );

    if (tag == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: AppSpacing.md - 2,
          ),
          child: Align(alignment: Alignment.centerLeft, child: tag),
        ),
      ],
    );
  }

  /// DISCOM per backend doc: a known name selects that option; anything else
  /// selects "Other" and the raw name goes into a free-text box.
  Widget _discomField({bool isRequired = false}) {
    final text = discom.text.trim();
    final isOther =
        _discomOtherMode || (text.isNotEmpty && !discomOptions.contains(text));
    final dropdownValue = isOther
        ? 'Other'
        : (text.isNotEmpty ? text : null);
    final tag = _billTag('discom');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: tag == null ? AppSpacing.md - 2 : 4),
          child: DropdownButtonFormField<String>(
            value: dropdownValue,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: isRequired
                ? (_) => discom.text.trim().isEmpty ? 'DISCOM is required' : null
                : null,
            decoration: InputDecoration(
              label: _requiredFieldLabel('DISCOM', isRequired: isRequired),
              hintText: 'Select DISCOM',
            ),
            items: _discomMenuItems,
            onChanged: isLoading
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == 'Other') {
                        _discomOtherMode = true;
                        if (discomOptions.contains(discom.text.trim())) {
                          discom.clear();
                        }
                      } else {
                        _discomOtherMode = false;
                        discom.text = value;
                      }
                    });
                  },
          ),
        ),
        if (tag != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md - 2),
            child: Align(alignment: Alignment.centerLeft, child: tag),
          ),
        if (isOther)
          input(
            'Other DISCOM name',
            discom,
            textCapitalization: TextCapitalization.words,
            isRequired: isRequired,
          ),
      ],
    );
  }

  Widget dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) {
    final menuItems = _menuItemsWithCurrent(items, value);
    final safeValue = menuItems.contains(value) ? value : menuItems.first;

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
        items: menuItems
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(growable: false),
        onChanged: isLoading ? null : onChanged,
      ),
    );
  }

  Widget sectionTitle(String title, {GlobalKey? anchor}) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      key: anchor,
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
    bool isRequired = false,
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
        title: DefaultTextStyle.merge(
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          child: _requiredFieldLabel(title, isRequired: isRequired),
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
    bool isRequired = false,
  }) {
    return StatefulBuilder(
      builder: (context, setLocal) {
        Widget tile({ValueChanged<bool>? onChanged}) {
          return switchTile(
            title: title,
            value: getter(),
            isRequired: isRequired,
            onChanged: (value) {
              setter(value);
              onChanged?.call(value);
              setLocal(() {});
            },
          );
        }

        if (!isRequired) return tile();

        return FormField<bool>(
          initialValue: getter(),
          validator: (_) {
            if (!getter()) return '$title must be confirmed';
            return null;
          },
          builder: (field) {
            final scheme = Theme.of(context).colorScheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tile(onChanged: field.didChange),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: AppSpacing.sm + 2,
                    ),
                    child: Text(
                      field.errorText!,
                      style: TextStyle(
                        color: scheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
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
    try {
      final file = await _pickCompressedImage(ImageSource.camera);
      if (file == null) return;
      final path = await _persistXFile(file);
      if (path == null || path.isEmpty || !mounted) {
        if (mounted) {
          showAppMessage(context, 'Unable to capture image', isError: true);
        }
        return;
      }
      onPicked(path);
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, 'Unable to capture image', isError: true);
    }
  }

  Future<void> _pickImage(ValueChanged<String?> onPicked) async {
    FocusScope.of(context).unfocus();
    try {
      final file = await _pickCompressedImage(ImageSource.gallery);
      if (file == null) return;
      final path = await _persistXFile(file);
      if (path == null || path.isEmpty || !mounted) {
        if (mounted) {
          showAppMessage(
            context,
            _lastPickError ?? 'Unable to pick image',
            isError: true,
          );
        }
        return;
      }
      onPicked(path);
    } catch (e) {
      if (!mounted) return;
      showAppMessage(context, 'Unable to pick image', isError: true);
    }
  }

  Future<String?> _pickSingleFile({required bool imageOnly}) async {
    FocusScope.of(context).unfocus();
    try {
      if (imageOnly) {
        final file = await _pickCompressedImage(ImageSource.gallery);
        if (file == null) return null;
        final path = await _persistXFile(file);
        if (path == null && mounted && _lastPickError != null) {
          showAppMessage(context, _lastPickError!, isError: true);
        }
        return path;
      }

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: kLeadDocumentExtensions,
      );
      if (result == null || result.files.isEmpty) return null;
      final picked = result.files.single;
      final path = await _persistPickedBytes(
        path: picked.path,
        bytes: picked.bytes,
        originalName: picked.name,
        imageOnly: false,
      );
      if (path == null && mounted && _lastPickError != null) {
        showAppMessage(context, _lastPickError!, isError: true);
      }
      return path;
    } catch (_) {
      return null;
    }
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
                      onChanged(path);
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
    void Function(String itemTitle, String? path)? onFileChanged,
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
                  if (hasFile) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: isImagePath(path)
                            ? _thumbImage(path, height: 110)
                            : _docPreview(path),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading || isParsingBill
                              ? null
                              : () async {
                                  final picked = await _pickSingleFile(
                                    imageOnly: item.imageOnly,
                                  );
                                  if (picked == null || !mounted) return;
                                  setState(() => values[item.title] = picked);
                                  onFileChanged?.call(item.title, picked);
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
                          onPressed: isLoading || isParsingBill
                              ? null
                              : () {
                                  setState(() => values[item.title] = null);
                                  onFileChanged?.call(item.title, null);
                                },
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
            SizedBox(
              width: double.infinity,
              child: Wrap(
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
      _applyStateCity(customer.state, customer.city);
      if ((customer.pincode ?? '').trim().isNotEmpty) {
        pincode.text = customer.pincode!.trim();
      }
    });
  }

  void _prefillFromCustomerProfile() {
    final customer = ref.read(authProvider).customer;
    if (customer == null) return;
    setState(() {
      source = 'Customer Portal';
      selectedCustomerId = customer.id;
      if (customer.name.trim().isNotEmpty) {
        fullName.text = customer.name.trim();
      }
      final phone = (customer.phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (phone.isNotEmpty) {
        mobile.text = phone.length > 10 ? phone.substring(phone.length - 10) : phone;
      }
      if (customer.email.trim().isNotEmpty) {
        email.text = customer.email.trim();
      }
      if ((customer.address ?? '').trim().isNotEmpty) {
        address.text = customer.address!.trim();
      }
      _applyStateCity(customer.state, customer.city);
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
    final customerOptions = widget.customerPortal
        ? const <CustomerModel>[]
        : ref.watch(customerListProvider.select((s) => s.items));
    final canCreateCustomer = widget.customerPortal
        ? false
        : ref.watch(
            authProvider.select((a) => a.hasPermission('customer.create')),
          );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppAppBar(
        title: widget.customerPortal
            ? (widget.existingLead != null &&
                    isCustomerLeadIncomplete(widget.existingLead!)
                ? 'Complete lead details'
                : widget.existingLead != null
                    ? 'Edit lead details'
                    : 'Fill lead details')
            : _isCompleteDetails
            ? 'Complete Lead Details'
            : 'Create Lead (Basic)',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(18),
          child: formCard(
            children: [
              if (kAiBillAutofillEnabled) ...[
                _billAutofillBanner(),
                _billAutofillUploadSection(),
              ],
              if (!widget.customerPortal && _isBasicCreate) ...[
                sectionTitle('Customer'),
                _linkedCustomerSection(
                  customerOptions: customerOptions,
                  allowAddCustomer: canCreateCustomer,
                ),
              ],
              sectionTitle('Basic Details', anchor: _basicSectionKey),
              if (!widget.customerPortal && !_isBasicCreate)
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
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      tag: _billTag('full_name'),
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
                      tag: _billTag('mobile'),
                    ),
                    input(
                      'Email Address',
                      email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      tag: _billTag('email'),
                    ),
                    input(
                      'Address',
                      address,
                      isRequired: _isCompleteDetails,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                      textInputAction: TextInputAction.next,
                      tag: _billTag('address'),
                    ),
                  ],
                ),
              ),
              IndiaStateCityFields(
                key: ValueKey('state_city_$_autofillRevision'),
                stateController: state,
                cityController: city,
                stateRequired: _isCompleteDetails,
                cityRequired: _isCompleteDetails,
                enabled: !isLoading,
              ),
              input(
                'Pincode',
                pincode,
                isRequired: _isCompleteDetails,
                keyboardType: TextInputType.number,
                tag: _billTag('pincode'),
              ),
              input(
                'Load Section (kW)',
                kw,
                isRequired: _isCompleteDetails,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                tag: _billTag('load_section_kw'),
              ),
              // Shown in both modes so values read from the bill are visible
              // (and saved) even on the basic "Create Lead" form.
              sectionTitle('Connection Details', anchor: _connectionSectionKey),
              input(
                'CA Number',
                caNumber,
                isRequired: !_isBasicCreate,
                tag: _billTag('ca_number'),
              ),
              input(
                'K Number',
                kNumber,
                tag: _billTag('k_number'),
              ),
              input(
                'Reference Number',
                referenceNumber,
                tag: _billTag('reference_number'),
              ),
              KeyedSubtree(
                key: ValueKey('discom_$_autofillRevision'),
                child: _discomField(isRequired: !_isBasicCreate),
              ),
              if (_isBasicCreate)
                KeyedSubtree(
                  key: ValueKey('ptype_basic_$_autofillRevision'),
                  child: dropdown(
                    label: 'Project Type',
                    value: projectType,
                    items: projectTypeOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      projectType = value;
                    },
                  ),
                ),
              if (!_isBasicCreate) ...[
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
                ),
                input(
                  'Longitude',
                  longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
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
                sectionTitle('Bank Details', anchor: _bankSectionKey),
                input(
                  'Account Holder Name',
                  bankAccountName,
                  isRequired: true,
                  textCapitalization: TextCapitalization.words,
                  tag: _billTag('bank_account_name'),
                ),
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
                ),
                input(
                  'IFSC Code',
                  ifscCode,
                  isRequired: true,
                  textCapitalization: TextCapitalization.characters,
                ),
                sectionTitle('Project Details', anchor: _projectSectionKey),
                dropdown(
                  label: 'Project Type',
                  value: projectType,
                  items: projectTypeOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    projectType = value;
                  },
                ),
                dropdown(
                  label: 'Main Source',
                  value: source,
                  items: sourceOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    source = value;
                  },
                ),
                dropdown(
                  label: 'Priority',
                  value: priority,
                  items: priorityOptions,
                  onChanged: (value) {
                    if (value == null) return;
                    priority = value;
                  },
                ),
                sectionTitle('Site Checklist', anchor: _siteSectionKey),
                input(
                  'Available Shadow Free Area',
                  availableShadowFreeArea,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  suffixText: 'sqmtr',
                ),
                input(
                  'Quotation Amount',
                  quotationAmount,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                ),
                input(
                  'Visited Employee Name',
                  visitedEmployeeName,
                  isRequired: true,
                  textCapitalization: TextCapitalization.words,
                ),
                input(
                  'Visited Employee Contact',
                  visitedEmployeeContact,
                  isRequired: true,
                  keyboardType: TextInputType.phone,
                  validator: _validateOptionalMobile,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                localSwitchTile(
                  title: 'Roof Load Bearing Capacity',
                  isRequired: true,
                  getter: () => roofLoadBearingCapacity,
                  setter: (value) => roofLoadBearingCapacity = value,
                ),
                localSwitchTile(
                  title: 'Shadow Free Roof',
                  isRequired: true,
                  getter: () => shadowFreeRoof,
                  setter: (value) => shadowFreeRoof = value,
                ),
                localSwitchTile(
                  title: 'Vendor Visited Site',
                  isRequired: true,
                  getter: () => vendorVisitedSite,
                  setter: (value) => vendorVisitedSite = value,
                ),
                sectionTitle('Notes'),
                input('Notes', notes, maxLines: 4),
                sectionTitle('Images & Documents', anchor: _documentsSectionKey),
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
                          onFileChanged: (itemTitle, path) {
                            if (itemTitle != 'Electricity Bill') return;
                            if (path == null) {
                              _resetBillAutofill();
                              return;
                            }
                            // 5 MB / jpg-pdf check before the parse upload.
                            final rejection = _billFileRejection(path);
                            if (rejection != null) {
                              setState(
                                () => predefinedDocPaths[itemTitle] = null,
                              );
                              showAppMessage(context, rejection, isError: true);
                              return;
                            }
                            if (!kAiBillAutofillEnabled) return;
                            _parseElectricityBill(path);
                          },
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
                  // Disabled while saving or while the bill parse is in flight.
                  onPressed: isLoading || isParsingBill ? null : saveLead,
                  child: isLoading || isParsingBill
                      ? SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          widget.customerPortal
                              ? 'Submit details'
                              : _isCompleteDetails
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
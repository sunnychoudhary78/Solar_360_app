import 'dart:convert';

class LeadModel {
  final String id;
  final String leadCode;

  final String fullName;
  final String mobile;
  final String email;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String loadSectionKw;

  final String caNumber;
  final String kNumber;
  final String referenceNumber;
  final String discom;

  final String geoLocation;
  final String latitude;
  final String longitude;

  final String bankAccountName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;

  final String projectType;
  final String source;
  final String status;
  final String currentDepartment;
  final String workflowStep;
  final String leadStage;

  final String assignedTo;
  final String assignedBy;
  final String createdBy;
  final String updatedBy;

  final String priority;
  final String notes;

  final String roofPhotoStatus;
  final String availableShadowFreeArea;
  final String quotationAmount;
  final String visitedEmployeeName;
  final String visitedEmployeeContact;
  final String followUpDate;
  final String lastContactedAt;

  final bool roofLoadBearingCapacity;
  final bool shadowFreeRoof;
  final bool vendorVisitedSite;
  final bool isActive;

  final String additionalDocuments;
  final String additionalImages;

  final String chequePassbookCopy;
  final String bankClearPhoto;
  final String roofPhoto;
  final String preInstallationPhoto;
  final String quotationDocument;
  final String installationReport;
  final String installationImages;
  final String statusRemarks;

  final String registrationId;
  final String registrationDate;
  final String registrationTime;

  final Map<String, dynamic>? installationDetails;

  final String createdAt;
  final String updatedAt;

  const LeadModel({
    required this.id,
    required this.leadCode,
    required this.fullName,
    required this.mobile,
    required this.email,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.loadSectionKw,
    required this.caNumber,
    required this.kNumber,
    required this.referenceNumber,
    required this.discom,
    required this.geoLocation,
    required this.latitude,
    required this.longitude,
    required this.bankAccountName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.projectType,
    required this.source,
    required this.status,
    required this.currentDepartment,
    required this.workflowStep,
    required this.leadStage,
    required this.assignedTo,
    required this.assignedBy,
    required this.createdBy,
    required this.updatedBy,
    required this.priority,
    required this.notes,
    required this.roofPhotoStatus,
    required this.availableShadowFreeArea,
    required this.quotationAmount,
    required this.visitedEmployeeName,
    required this.visitedEmployeeContact,
    required this.followUpDate,
    required this.lastContactedAt,
    required this.roofLoadBearingCapacity,
    required this.shadowFreeRoof,
    required this.vendorVisitedSite,
    required this.isActive,
    required this.additionalDocuments,
    required this.additionalImages,
    required this.chequePassbookCopy,
    required this.bankClearPhoto,
    required this.roofPhoto,
    required this.preInstallationPhoto,
    required this.quotationDocument,
    required this.installationReport,
    required this.installationImages,
    required this.statusRemarks,
    required this.registrationId,
    required this.registrationDate,
    required this.registrationTime,
    this.installationDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    final installationRaw = json['installationDetails'] ??
        json['installation_details'] ??
        json['InstallationDetails'] ??
        json['installation'] ??
        json['Installation'] ??
        json['lead_installation'] ??
        json['leadInstallation'];

    final parsedInstallationDetails = _mapFromDynamic(installationRaw);

    return LeadModel(
      id: _str(json['id']),
      leadCode: _str(json['lead_code'] ?? json['leadCode']),
      fullName: _str(json['full_name'] ?? json['fullName']),
      mobile: _str(json['mobile']),
      email: _str(json['email']),
      address: _str(json['address']),
      city: _str(json['city']),
      state: _str(json['state']),
      pincode: _str(json['pincode']),
      loadSectionKw: _str(json['load_section_kw'] ?? json['loadSectionKw']),
      caNumber: _str(json['ca_number'] ?? json['caNumber']),
      kNumber: _str(json['k_number'] ?? json['kNumber']),
      referenceNumber: _str(json['reference_number'] ?? json['referenceNumber']),
      discom: _str(json['discom']),
      geoLocation: _str(json['geo_location'] ?? json['geoLocation']),
      latitude: _str(json['latitude']),
      longitude: _str(json['longitude']),
      bankAccountName: _str(json['bank_account_name'] ?? json['bankAccountName']),
      bankName: _str(json['bank_name'] ?? json['bankName']),
      accountNumber: _str(json['account_number'] ?? json['accountNumber']),
      ifscCode: _str(json['ifsc_code'] ?? json['ifscCode']),
      projectType: _str(json['project_type'] ?? json['projectType']),
      source: _str(json['source']),
      status: _str(json['status']),
      currentDepartment: _str(json['current_department'] ?? json['currentDepartment']),
      workflowStep: _str(json['workflow_step'] ?? json['workflowStep']),
      leadStage: _str(json['lead_stage'] ?? json['leadStage']),
      assignedTo: _str(json['assigned_to'] ?? json['assignedTo']),
      assignedBy: _str(json['assigned_by'] ?? json['assignedBy']),
      createdBy: _str(json['created_by'] ?? json['createdBy']),
      updatedBy: _str(json['updated_by'] ?? json['updatedBy']),
      priority: _str(json['priority']),
      notes: _str(json['notes']),
      roofPhotoStatus: _str(json['roof_photo_status'] ?? json['roofPhotoStatus']),
      availableShadowFreeArea: _str(json['available_shadow_free_area'] ?? json['availableShadowFreeArea']),
      quotationAmount: _str(json['quotation_amount'] ?? json['quotationAmount']),
      visitedEmployeeName: _str(json['visited_employee_name'] ?? json['visitedEmployeeName']),
      visitedEmployeeContact: _str(json['visited_employee_contact'] ?? json['visitedEmployeeContact']),
      followUpDate: _str(json['follow_up_date'] ?? json['followUpDate']),
      lastContactedAt: _str(json['last_contacted_at'] ?? json['lastContactedAt']),
      roofLoadBearingCapacity: _bool(json['roof_load_bearing_capacity'] ?? json['roofLoadBearingCapacity']),
      shadowFreeRoof: _bool(json['shadow_free_roof'] ?? json['shadowFreeRoof']),
      vendorVisitedSite: _bool(json['vendor_visited_site'] ?? json['vendorVisitedSite']),
      isActive: _bool(json['is_active'] ?? json['isActive']),
      additionalDocuments: _str(json['additional_documents'] ?? json['additionalDocuments']),
      additionalImages: _str(json['additional_images'] ?? json['additionalImages']),
      chequePassbookCopy: _str(json['cheque_passbook_copy'] ?? json['chequePassbookCopy']),
      bankClearPhoto: _str(json['bank_clear_photo'] ?? json['bankClearPhoto']),
      roofPhoto: _str(json['roof_photo'] ?? json['roofPhoto']),
      preInstallationPhoto: _str(json['pre_installation_photo'] ?? json['preInstallationPhoto']),
      quotationDocument: _str(json['quotation_document'] ?? json['quotationDocument']),
      installationReport: _str(json['installation_report'] ?? json['installationReport']),
      installationImages: _str(json['installation_images'] ?? json['installationImages']),
      statusRemarks: _str(json['status_remarks'] ?? json['statusRemarks']),
      registrationId: _str(json['registration_id'] ?? json['registrationId']),
      registrationDate: _str(json['registration_date'] ?? json['registrationDate']),
      registrationTime: _str(json['registration_time'] ?? json['registrationTime']),
      installationDetails: parsedInstallationDetails,
      createdAt: _str(json['created_at'] ?? json['createdAt']),
      updatedAt: _str(json['updated_at'] ?? json['updatedAt']),
    );
  }

  bool get hasInstallationDetails {
    final d = installationDetails;
    if (d == null || d.isEmpty) return false;

    final spNumbers = d['sp_numbers'] ?? d['spNumbers'] ?? d['solar_panel_serial_numbers'];

    return _mapValue(d, ['id', '_id']).isNotEmpty ||
        _mapValue(d, ['file_no', 'fileNo']).isNotEmpty ||
        _mapValue(d, ['capacity']).isNotEmpty ||
        _mapValue(d, ['solar_panel_brand', 'solarPanelBrand']).isNotEmpty ||
        _mapValue(d, [
          'number_of_solar_panels',
          'number_of_solar_panel',
          'numberOfSolarPanels',
          'panel_count',
          'panelCount',
        ]).isNotEmpty ||
        _mapValue(d, ['invoice_no', 'invoiceNo']).isNotEmpty ||
        _mapValue(d, ['panel_type', 'panelType']).isNotEmpty ||
        _mapValue(d, ['inverter_serial_number', 'inverterSerialNumber']).isNotEmpty ||
        _mapValue(d, ['battery_serial_number', 'batterySerialNumber']).isNotEmpty ||
        _mapValue(d, ['installation_status', 'installationStatus']).isNotEmpty ||
        (spNumbers is List && spNumbers.isNotEmpty);
  }

  bool get hasRegistrationDetails {
    return registrationId.trim().isNotEmpty &&
        registrationDate.trim().isNotEmpty &&
        registrationTime.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lead_code': leadCode,
      'full_name': fullName,
      'mobile': mobile,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'load_section_kw': loadSectionKw,
      'ca_number': caNumber,
      'k_number': kNumber,
      'reference_number': referenceNumber,
      'discom': discom,
      'geo_location': geoLocation,
      'latitude': latitude,
      'longitude': longitude,
      'bank_account_name': bankAccountName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'project_type': projectType,
      'source': source,
      'status': status,
      'current_department': currentDepartment,
      'workflow_step': workflowStep,
      'lead_stage': leadStage,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'priority': priority,
      'notes': notes,
      'roof_photo_status': roofPhotoStatus,
      'available_shadow_free_area': availableShadowFreeArea,
      'quotation_amount': quotationAmount,
      'visited_employee_name': visitedEmployeeName,
      'visited_employee_contact': visitedEmployeeContact,
      'follow_up_date': followUpDate,
      'last_contacted_at': lastContactedAt,
      'roof_load_bearing_capacity': roofLoadBearingCapacity,
      'shadow_free_roof': shadowFreeRoof,
      'vendor_visited_site': vendorVisitedSite,
      'is_active': isActive,
      'additional_documents': additionalDocuments,
      'additional_images': additionalImages,
      'cheque_passbook_copy': chequePassbookCopy,
      'bank_clear_photo': bankClearPhoto,
      'roof_photo': roofPhoto,
      'pre_installation_photo': preInstallationPhoto,
      'quotation_document': quotationDocument,
      'installation_report': installationReport,
      'installation_images': installationImages,
      'status_remarks': statusRemarks,
      'registration_id': registrationId,
      'registration_date': registrationDate,
      'registration_time': registrationTime,
      'installation_details': installationDetails,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  LeadModel copyWith({
    String? id,
    String? leadCode,
    String? fullName,
    String? mobile,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? loadSectionKw,
    String? caNumber,
    String? kNumber,
    String? referenceNumber,
    String? discom,
    String? geoLocation,
    String? latitude,
    String? longitude,
    String? bankAccountName,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? projectType,
    String? source,
    String? status,
    String? currentDepartment,
    String? workflowStep,
    String? leadStage,
    String? assignedTo,
    String? assignedBy,
    String? createdBy,
    String? updatedBy,
    String? priority,
    String? notes,
    String? roofPhotoStatus,
    String? availableShadowFreeArea,
    String? quotationAmount,
    String? visitedEmployeeName,
    String? visitedEmployeeContact,
    String? followUpDate,
    String? lastContactedAt,
    bool? roofLoadBearingCapacity,
    bool? shadowFreeRoof,
    bool? vendorVisitedSite,
    bool? isActive,
    String? additionalDocuments,
    String? additionalImages,
    String? chequePassbookCopy,
    String? bankClearPhoto,
    String? roofPhoto,
    String? preInstallationPhoto,
    String? quotationDocument,
    String? installationReport,
    String? installationImages,
    String? statusRemarks,
    String? registrationId,
    String? registrationDate,
    String? registrationTime,
    Map<String, dynamic>? installationDetails,
    String? createdAt,
    String? updatedAt,
  }) {
    return LeadModel(
      id: id ?? this.id,
      leadCode: leadCode ?? this.leadCode,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      loadSectionKw: loadSectionKw ?? this.loadSectionKw,
      caNumber: caNumber ?? this.caNumber,
      kNumber: kNumber ?? this.kNumber,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      discom: discom ?? this.discom,
      geoLocation: geoLocation ?? this.geoLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      projectType: projectType ?? this.projectType,
      source: source ?? this.source,
      status: status ?? this.status,
      currentDepartment: currentDepartment ?? this.currentDepartment,
      workflowStep: workflowStep ?? this.workflowStep,
      leadStage: leadStage ?? this.leadStage,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      roofPhotoStatus: roofPhotoStatus ?? this.roofPhotoStatus,
      availableShadowFreeArea: availableShadowFreeArea ?? this.availableShadowFreeArea,
      quotationAmount: quotationAmount ?? this.quotationAmount,
      visitedEmployeeName: visitedEmployeeName ?? this.visitedEmployeeName,
      visitedEmployeeContact: visitedEmployeeContact ?? this.visitedEmployeeContact,
      followUpDate: followUpDate ?? this.followUpDate,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      roofLoadBearingCapacity: roofLoadBearingCapacity ?? this.roofLoadBearingCapacity,
      shadowFreeRoof: shadowFreeRoof ?? this.shadowFreeRoof,
      vendorVisitedSite: vendorVisitedSite ?? this.vendorVisitedSite,
      isActive: isActive ?? this.isActive,
      additionalDocuments: additionalDocuments ?? this.additionalDocuments,
      additionalImages: additionalImages ?? this.additionalImages,
      chequePassbookCopy: chequePassbookCopy ?? this.chequePassbookCopy,
      bankClearPhoto: bankClearPhoto ?? this.bankClearPhoto,
      roofPhoto: roofPhoto ?? this.roofPhoto,
      preInstallationPhoto: preInstallationPhoto ?? this.preInstallationPhoto,
      quotationDocument: quotationDocument ?? this.quotationDocument,
      installationReport: installationReport ?? this.installationReport,
      installationImages: installationImages ?? this.installationImages,
      statusRemarks: statusRemarks ?? this.statusRemarks,
      registrationId: registrationId ?? this.registrationId,
      registrationDate: registrationDate ?? this.registrationDate,
      registrationTime: registrationTime ?? this.registrationTime,
      installationDetails: installationDetails ?? this.installationDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Map<String, dynamic>? _mapFromDynamic(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static String _mapValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static String _str(dynamic value) {
    if (value == null) return '';
    if (value is List || value is Map) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  static bool _bool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;
    if (value == 1) return true;
    if (value == 0) return false;

    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }

    return false;
  }
}

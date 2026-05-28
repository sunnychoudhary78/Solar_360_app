class LeadModel {
  final String name;
  final String mobile;
  final String email;
  final String caNo;
  final String kNo;
  final String refNo;
  final String discom;

  final String geoLocation;
  final String longitude;
  final String latitude;

  final String bankDetails;
  final String roofArea;
  final String quotationAmount;
  final String employeeName;
  final String staffContact;

  final String? aadhaarFrontPath;
  final String? aadhaarBackPath;
  final String? panFrontPath;
  final String? panBackPath;
  final String? electricityBillPath;
  final String? bankImagePath;
  final String? roofImagePath;

  final bool electricityBillIsPdf;

  final String? customerDocuments;

  final String supportNotes;
  final String? supportDocumentPath;

  String status;
  String liaisonNote;

  final String liaisonDocumentPath;

  // Installation Team fields
  final String installationNote;
  final String installationDocumentPath;

  LeadModel({
    required this.name,
    required this.mobile,
    required this.email,
    required this.caNo,
    required this.kNo,
    required this.refNo,
    required this.discom,
    required this.geoLocation,
    required this.longitude,
    required this.latitude,
    required this.bankDetails,
    required this.roofArea,
    required this.quotationAmount,
    required this.employeeName,
    required this.staffContact,
    this.aadhaarFrontPath,
    this.aadhaarBackPath,
    this.panFrontPath,
    this.panBackPath,
    this.electricityBillPath,
    this.bankImagePath,
    this.roofImagePath,
    this.electricityBillIsPdf = false,
    this.customerDocuments,
    this.supportNotes = '',
    this.supportDocumentPath,
    this.status = 'New Lead',
    this.liaisonNote = '',
    this.liaisonDocumentPath = '',
    this.installationNote = '',
    this.installationDocumentPath = '',
  });

  LeadModel copyWith({
    String? name,
    String? mobile,
    String? email,
    String? caNo,
    String? kNo,
    String? refNo,
    String? discom,
    String? geoLocation,
    String? longitude,
    String? latitude,
    String? bankDetails,
    String? roofArea,
    String? quotationAmount,
    String? employeeName,
    String? staffContact,
    String? aadhaarFrontPath,
    String? aadhaarBackPath,
    String? panFrontPath,
    String? panBackPath,
    String? electricityBillPath,
    String? bankImagePath,
    String? roofImagePath,
    bool? electricityBillIsPdf,
    String? customerDocuments,
    String? supportNotes,
    String? supportDocumentPath,
    String? status,
    String? liaisonNote,
    String? liaisonDocumentPath,
    String? installationNote,
    String? installationDocumentPath,
  }) {
    return LeadModel(
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      caNo: caNo ?? this.caNo,
      kNo: kNo ?? this.kNo,
      refNo: refNo ?? this.refNo,
      discom: discom ?? this.discom,
      geoLocation: geoLocation ?? this.geoLocation,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      bankDetails: bankDetails ?? this.bankDetails,
      roofArea: roofArea ?? this.roofArea,
      quotationAmount: quotationAmount ?? this.quotationAmount,
      employeeName: employeeName ?? this.employeeName,
      staffContact: staffContact ?? this.staffContact,
      aadhaarFrontPath: aadhaarFrontPath ?? this.aadhaarFrontPath,
      aadhaarBackPath: aadhaarBackPath ?? this.aadhaarBackPath,
      panFrontPath: panFrontPath ?? this.panFrontPath,
      panBackPath: panBackPath ?? this.panBackPath,
      electricityBillPath: electricityBillPath ?? this.electricityBillPath,
      bankImagePath: bankImagePath ?? this.bankImagePath,
      roofImagePath: roofImagePath ?? this.roofImagePath,
      electricityBillIsPdf:
          electricityBillIsPdf ?? this.electricityBillIsPdf,
      customerDocuments: customerDocuments ?? this.customerDocuments,
      supportNotes: supportNotes ?? this.supportNotes,
      supportDocumentPath: supportDocumentPath ?? this.supportDocumentPath,
      status: status ?? this.status,
      liaisonNote: liaisonNote ?? this.liaisonNote,
      liaisonDocumentPath:
          liaisonDocumentPath ?? this.liaisonDocumentPath,
      installationNote: installationNote ?? this.installationNote,
      installationDocumentPath:
          installationDocumentPath ?? this.installationDocumentPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile': mobile,
      'email': email,
      'caNo': caNo,
      'kNo': kNo,
      'refNo': refNo,
      'discom': discom,
      'geoLocation': geoLocation,
      'longitude': longitude,
      'latitude': latitude,
      'bankDetails': bankDetails,
      'roofArea': roofArea,
      'quotationAmount': quotationAmount,
      'employeeName': employeeName,
      'staffContact': staffContact,
      'aadhaarFrontPath': aadhaarFrontPath,
      'aadhaarBackPath': aadhaarBackPath,
      'panFrontPath': panFrontPath,
      'panBackPath': panBackPath,
      'electricityBillPath': electricityBillPath,
      'bankImagePath': bankImagePath,
      'roofImagePath': roofImagePath,
      'electricityBillIsPdf': electricityBillIsPdf,
      'customerDocuments': customerDocuments,
      'supportNotes': supportNotes,
      'supportDocumentPath': supportDocumentPath,
      'status': status,
      'liaisonNote': liaisonNote,
      'liaisonDocumentPath': liaisonDocumentPath,
      'installationNote': installationNote,
      'installationDocumentPath': installationDocumentPath,
    };
  }

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      caNo: json['caNo'] as String? ?? '',
      kNo: json['kNo'] as String? ?? '',
      refNo: json['refNo'] as String? ?? '',
      discom: json['discom'] as String? ?? '',
      geoLocation: json['geoLocation'] as String? ?? '',
      longitude: json['longitude'] as String? ?? '',
      latitude: json['latitude'] as String? ?? '',
      bankDetails: json['bankDetails'] as String? ?? '',
      roofArea: json['roofArea'] as String? ?? '',
      quotationAmount: json['quotationAmount'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      staffContact: json['staffContact'] as String? ?? '',
      aadhaarFrontPath: json['aadhaarFrontPath'] as String?,
      aadhaarBackPath: json['aadhaarBackPath'] as String?,
      panFrontPath: json['panFrontPath'] as String?,
      panBackPath: json['panBackPath'] as String?,
      electricityBillPath: json['electricityBillPath'] as String?,
      bankImagePath: json['bankImagePath'] as String?,
      roofImagePath: json['roofImagePath'] as String?,
      electricityBillIsPdf: json['electricityBillIsPdf'] as bool? ?? false,
      customerDocuments: json['customerDocuments'] as String?,
      supportNotes: json['supportNotes'] as String? ?? '',
      supportDocumentPath: json['supportDocumentPath'] as String?,
      status: json['status'] as String? ?? 'New Lead',
      liaisonNote: json['liaisonNote'] as String? ?? '',
      liaisonDocumentPath: json['liaisonDocumentPath'] as String? ?? '',
      installationNote: json['installationNote'] as String? ?? '',
      installationDocumentPath:
          json['installationDocumentPath'] as String? ?? '',
    );
  }
}
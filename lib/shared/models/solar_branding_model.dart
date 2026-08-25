class BranchAddressModel {
  final String? id;
  final String label;
  final String address;
  final bool isDefault;

  const BranchAddressModel({
    this.id,
    this.label = '',
    this.address = '',
    this.isDefault = false,
  });

  factory BranchAddressModel.fromJson(Map<String, dynamic> json) {
    return BranchAddressModel(
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isDefault: json['is_default'] == true || json['isDefault'] == true,
    );
  }
}

/// Company branding from `GET /company-settings/solar-branding`.
class SolarBrandingModel {
  final String companyName;
  final String companyAddress;
  final String companyGst;
  final String companyPan;
  final String companyPhone;
  final String companyEmail;
  final List<BranchAddressModel> branchAddresses;

  const SolarBrandingModel({
    this.companyName = '',
    this.companyAddress = '',
    this.companyGst = '',
    this.companyPan = '',
    this.companyPhone = '',
    this.companyEmail = '',
    this.branchAddresses = const [],
  });

  factory SolarBrandingModel.fromJson(Map<String, dynamic> json) {
    final branchesRaw = json['branchAddresses'] ?? json['branch_addresses'];
    return SolarBrandingModel(
      companyName:
          json['companyName']?.toString() ??
          json['company_name']?.toString() ??
          '',
      companyAddress:
          json['companyAddress']?.toString() ??
          json['company_address']?.toString() ??
          '',
      companyGst:
          json['companyGst']?.toString() ??
          json['company_gst']?.toString() ??
          '',
      companyPan:
          json['companyPan']?.toString() ??
          json['company_pan']?.toString() ??
          '',
      companyPhone:
          json['companyPhone']?.toString() ??
          json['company_phone']?.toString() ??
          '',
      companyEmail:
          json['companyEmail']?.toString() ??
          json['company_email']?.toString() ??
          '',
      branchAddresses: branchesRaw is List
          ? branchesRaw
                .whereType<Map>()
                .map(
                  (e) =>
                      BranchAddressModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
    );
  }

  /// Web `__hq__` sentinel — empty branch id means head office.
  static const hqBranchId = '';

  String addressForBranch(String? branchId) {
    if (branchId == null || branchId.isEmpty) return companyAddress;
    for (final b in branchAddresses) {
      if (b.id == branchId) return b.address;
    }
    return companyAddress;
  }

  /// Payload for backend [fromParty] when saving documents.
  Map<String, dynamic> fromPartyPayload(String? branchId) {
    if (branchId != null && branchId.isNotEmpty) {
      return {'branchId': branchId};
    }
    return {'useHeadOffice': true};
  }
}

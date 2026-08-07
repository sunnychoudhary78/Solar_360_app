import 'package:solar_sales/features/customers/data/models/customer_model.dart';

/// Bill-to / ship-to party snapshot (web [PartyAddress] parity).
class PartyAddressModel {
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String gstNumber;
  final String aadharNumber;
  final String phone;
  final String email;

  const PartyAddressModel({
    this.name = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.gstNumber = '',
    this.aadharNumber = '',
    this.phone = '',
    this.email = '',
  });

  factory PartyAddressModel.empty() => const PartyAddressModel();

  factory PartyAddressModel.fromCustomer(CustomerModel? customer) {
    if (customer == null) return PartyAddressModel.empty();
    return PartyAddressModel(
      name: customer.name,
      address: customer.address ?? '',
      city: customer.city ?? '',
      state: customer.state ?? '',
      pincode: customer.pincode ?? '',
      gstNumber: customer.gstNumber ?? '',
      aadharNumber: customer.aadharNumber ?? '',
      phone: customer.phone ?? '',
      email: customer.email ?? '',
    );
  }

  factory PartyAddressModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PartyAddressModel.empty();
    return PartyAddressModel(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      gstNumber: json['gst_number']?.toString() ?? '',
      aadharNumber: json['aadhar_number']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'gst_number': gstNumber,
        'aadhar_number': aadharNumber,
        'phone': phone,
        'email': email,
      };

  PartyAddressModel copyWith({
    String? name,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstNumber,
    String? aadharNumber,
    String? phone,
    String? email,
  }) {
    return PartyAddressModel(
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstNumber: gstNumber ?? this.gstNumber,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  bool get isEmpty =>
      name.isEmpty &&
      address.isEmpty &&
      city.isEmpty &&
      state.isEmpty &&
      pincode.isEmpty;
}

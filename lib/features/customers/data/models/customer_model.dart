import 'package:solar_sales/shared/utils/formatters.dart';

class CustomerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstNumber;
  final String? aadharNumber;

  const CustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstNumber,
    this.aadharNumber,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: asString(json['id']),
      name: asString(json['name']),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      gstNumber: json['gst_number']?.toString(),
      aadharNumber: json['aadhar_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'gst_number': gstNumber,
      'aadhar_number': aadharNumber,
    };
  }

  String get subtitle {
    final parts = <String>[
      if (phone != null && phone!.isNotEmpty) phone!,
      if (city != null && city!.isNotEmpty) city!,
    ];
    return parts.isEmpty ? (email ?? '') : parts.join(' · ');
  }
}

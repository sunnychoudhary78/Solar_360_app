import 'package:solar_sales/shared/utils/formatters.dart';

class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({required this.email, required this.password});

  bool get isValid => email.trim().isNotEmpty && password.trim().isNotEmpty;

  factory LoginCredentials.fromJson(dynamic json) {
    if (json is! Map) {
      return const LoginCredentials(email: '', password: '');
    }
    return LoginCredentials(
      email: asString(json['email']),
      password: asString(json['password']),
    );
  }
}

class CustomerWriteResult {
  final CustomerModel customer;
  final LoginCredentials? credentials;

  const CustomerWriteResult({required this.customer, this.credentials});
}

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

  static Map<String, dynamic> unwrap(dynamic json) {
    if (json is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(json);
    if (map['customer'] is Map) {
      return Map<String, dynamic>.from(map['customer'] as Map);
    }
    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final source = unwrap(json);
    return CustomerModel(
      id: asString(source['id']),
      name: asString(source['name']),
      email: source['email']?.toString(),
      phone: source['phone']?.toString(),
      address: source['address']?.toString(),
      city: source['city']?.toString(),
      state: source['state']?.toString(),
      pincode: source['pincode']?.toString(),
      gstNumber: source['gst_number']?.toString(),
      aadharNumber: source['aadhar_number']?.toString(),
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

import 'package:dio/dio.dart';

/// Optional pincode lookup used after the bill fills a 6-digit pincode.
///
/// This is a public API (not Billbook), so it runs on its own Dio instance
/// without the auth interceptor. Failures are silent — offline skips it.
class PostalPincodeResult {
  final String city;
  final String state;

  const PostalPincodeResult({required this.city, required this.state});
}

final Dio _postalDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    responseType: ResponseType.json,
  ),
);

Future<PostalPincodeResult?> lookupPostalPincode(String pincode) async {
  final pin = pincode.trim();
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) return null;

  try {
    final res = await _postalDio.get(
      'https://api.postalpincode.in/pincode/$pin',
    );
    final data = res.data;
    if (data is! List || data.isEmpty) return null;

    final first = data.first;
    if (first is! Map) return null;
    if ('${first['Status']}'.toLowerCase() != 'success') return null;

    final offices = first['PostOffice'];
    if (offices is! List || offices.isEmpty) return null;

    final office = offices.first;
    if (office is! Map) return null;

    final city = (office['District'] ?? office['Block'] ?? '')
        .toString()
        .trim();
    final state = (office['State'] ?? '').toString().trim();
    if (city.isEmpty && state.isEmpty) return null;

    return PostalPincodeResult(city: city, state: state);
  } catch (_) {
    return null;
  }
}

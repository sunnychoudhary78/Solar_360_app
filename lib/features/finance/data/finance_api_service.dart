import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/core/providers/network_providers.dart';
import 'package:solar_sales/features/finance/data/emi_calculator.dart';

final financeApiServiceProvider = Provider<FinanceApiService>((ref) {
  return FinanceApiService(ref.watch(apiServiceProvider));
});

class FinanceApiService {
  FinanceApiService(this._api);

  final ApiService _api;

  /// Downloads the EMI PDF from the public Billbook endpoint.
  Future<Uint8List> downloadEmiPdf({
    required String segment,
    required EmiScheme scheme,
    required double amount,
    required int months,
    required double rate,
    String? customerName,
    bool includeGuide = false,
  }) async {
    final bytes = await _api.postBytes(ApiEndpoints.publicEmiPdf, {
      'segment': segment,
      'scheme': scheme.apiValue,
      'amount': amount,
      'months': months,
      'rate': rate,
      if (customerName != null && customerName.trim().isNotEmpty)
        'customerName': customerName.trim(),
      'includeGuide': includeGuide,
    });

    // Error responses may arrive as JSON with responseType: bytes.
    if (bytes.length >= 2 && bytes[0] == 0x7B /* '{' */) {
      try {
        final text = utf8.decode(bytes);
        final map = jsonDecode(text);
        if (map is Map && map['message'] != null) {
          throw ApiException(map['message'].toString());
        }
      } on ApiException {
        rethrow;
      } catch (_) {
        // Not JSON — treat as PDF bytes.
      }
    }

    if (bytes.length < 4 ||
        bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46) {
      throw const ApiException('Could not download PDF');
    }

    return bytes;
  }
}

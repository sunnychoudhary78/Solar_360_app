import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/support_ticket_model.dart';

class CustomerPortalApiService {
  final ApiService _api;

  CustomerPortalApiService(this._api);

  Future<List<SupportTicketModel>> listTickets() async {
    final res = await _api.get(
      ApiEndpoints.supportTickets,
      queryParams: {'page': 1, 'limit': 50},
    );
    return _parseTickets(res);
  }

  Future<SupportTicketModel> getTicket(String id) async {
    final res = await _api.get(ApiEndpoints.supportTicket(id));
    final map = _unwrapMap(res);
    return SupportTicketModel.fromJson(map);
  }

  Future<List<SupportTicketHistoryItem>> getTicketHistory(String id) async {
    final res = await _api.get(ApiEndpoints.supportTicketHistory(id));
    final list = _unwrapList(res);
    return list
        .whereType<Map>()
        .map((e) => SupportTicketHistoryItem.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  Future<void> createTicket(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.supportTickets, body);
  }

  List<SupportTicketModel> _parseTickets(dynamic res) {
    return _unwrapList(res)
        .whereType<Map>()
        .map(
          (e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Map<String, dynamic> _unwrapMap(dynamic res) {
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      if (map['ticket'] is Map) {
        return Map<String, dynamic>.from(map['ticket'] as Map);
      }
      return map;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(dynamic res) {
    if (res is List) return res;
    if (res is Map) {
      final raw = res['data'] ?? res['rows'] ?? res['tickets'] ?? res['history'];
      if (raw is List) return raw;
      if (raw is Map && raw['rows'] is List) return raw['rows'] as List;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
    }
    return const [];
  }
}

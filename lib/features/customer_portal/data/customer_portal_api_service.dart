import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';

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
    return SupportTicketModel.fromJson(_unwrapMap(res));
  }

  Future<List<SupportTicketHistoryItem>> getTicketHistory(String id) async {
    final res = await _api.get(ApiEndpoints.supportTicketHistory(id));
    return _unwrapList(res)
        .whereType<Map>()
        .map(
          (e) => SupportTicketHistoryItem.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<void> createTicket(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.supportTickets, body);
  }

  Future<SupportTicketMessage> addMessage(String id, String message) async {
    final res = await _api.post(
      ApiEndpoints.supportTicketMessages(id),
      {'message': message, 'is_internal': false},
    );
    return SupportTicketMessage.fromJson(_unwrapMap(res));
  }

  Future<void> markMessagesRead(String id) async {
    await _api.patch(ApiEndpoints.supportTicketMessagesRead(id), <String, dynamic>{});
  }

  List<SupportTicketModel> _parseTickets(dynamic res) {
    return _unwrapList(res)
        .whereType<Map>()
        .map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)))
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
      final raw =
          res['data'] ?? res['rows'] ?? res['tickets'] ?? res['history'];
      if (raw is List) return raw;
      if (raw is Map && raw['rows'] is List) return raw['rows'] as List;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
    }
    return const [];
  }
}

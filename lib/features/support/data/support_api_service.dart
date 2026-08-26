import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

class SupportApiService {
  final ApiService _api;

  SupportApiService(this._api);

  Future<PaginatedResult<SupportTicketModel>> list({
    String? search,
    String? status,
    String? priority,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.adminSupportTickets,
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'limit': limit,
      },
    );
    return _parsePage(res, page, limit);
  }

  Future<SupportTicketModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.adminSupportTicket(id));
    return SupportTicketModel.fromJson(_unwrapMap(res));
  }

  Future<SupportTicketModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.adminSupportTicketCreate, body);
    return SupportTicketModel.fromJson(_unwrapMap(res));
  }

  Future<SupportTicketModel> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put(ApiEndpoints.adminSupportTicket(id), body);
    return SupportTicketModel.fromJson(_unwrapMap(res));
  }

  Future<SupportTicketMessage> addMessage(
    String id,
    String message, {
    bool isInternal = false,
  }) async {
    final res = await _api.post(
      ApiEndpoints.adminSupportTicketMessages(id),
      {'message': message, 'is_internal': isInternal},
    );
    return SupportTicketMessage.fromJson(_unwrapMap(res));
  }

  Future<void> markMessagesRead(String id) async {
    await _api.patch(
      ApiEndpoints.adminSupportTicketMessagesRead(id),
      <String, dynamic>{},
    );
  }

  Future<List<SupportTicketHistoryItem>> history(String id) async {
    final res = await _api.get(ApiEndpoints.adminSupportTicketHistory(id));
    return _unwrapList(res)
        .whereType<Map>()
        .map(
          (e) => SupportTicketHistoryItem.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  PaginatedResult<SupportTicketModel> _parsePage(
    dynamic res,
    int page,
    int limit,
  ) {
    final rows = _unwrapList(res)
        .whereType<Map>()
        .map((e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    var total = rows.length;
    var resolvedPage = page;
    var resolvedLimit = limit;
    if (res is Map) {
      final pagination = res['pagination'];
      if (pagination is Map) {
        final map = Map<String, dynamic>.from(pagination);
        if (map['total'] is num) total = (map['total'] as num).toInt();
        if (map['page'] is num) resolvedPage = (map['page'] as num).toInt();
        if (map['limit'] is num) resolvedLimit = (map['limit'] as num).toInt();
      } else {
        if (res['total'] is num) total = (res['total'] as num).toInt();
      }
    }
    return PaginatedResult(
      data: rows,
      total: total,
      page: resolvedPage,
      limit: resolvedLimit,
    );
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

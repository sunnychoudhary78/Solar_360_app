import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/customer_portal/data/models/support_ticket_model.dart';
import 'package:solar_sales/features/support/data/support_ticket_constants.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

class CustomerPortalApiService {
  final ApiService _api;

  CustomerPortalApiService(this._api);

  Future<PaginatedResult<SupportTicketModel>> listTickets({
    String? search,
    String? status,
    String? priority,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.supportTickets,
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

  Future<int> countTickets({
    String? search,
    String? status,
    String? priority,
    String? category,
  }) async {
    final result = await listTickets(
      search: search,
      status: status,
      priority: priority,
      category: category,
      page: 1,
      limit: 1,
    );
    return result.total;
  }

  Future<SupportTicketCounts> dashboard() async {
    final res = await _api.get(ApiEndpoints.supportTicketsDashboard);
    return SupportTicketCounts.fromJson(res);
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
          (e) =>
              SupportTicketHistoryItem.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<void> createTicket(Map<String, dynamic> body) async {
    await _api.post(ApiEndpoints.supportTickets, body);
  }

  Future<SupportTicketMessage> addMessage(String id, String message) async {
    final res = await _api.post(ApiEndpoints.supportTicketMessages(id), {
      'message': message,
      'is_internal': false,
    });
    return SupportTicketMessage.fromJson(_unwrapMap(res));
  }

  Future<void> markMessagesRead(String id) async {
    await _api.patch(
      ApiEndpoints.supportTicketMessagesRead(id),
      <String, dynamic>{},
    );
  }

  Future<SupportTicketModel> verifyResolution(
    String id, {
    required bool verified,
    int? rating,
    String? feedback,
  }) async {
    final res = await _api.patch(ApiEndpoints.supportTicketVerify(id), {
      'verified': verified,
      'rating': ?rating,
      if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
    });
    return SupportTicketModel.fromJson(_unwrapMap(res));
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
      } else if (res['total'] is num) {
        total = (res['total'] as num).toInt();
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
        final data = Map<String, dynamic>.from(map['data'] as Map);
        if (data['ticket'] is Map) {
          final ticket = Map<String, dynamic>.from(data['ticket'] as Map);
          ticket['messages'] ??= data['messages'];
          ticket['history'] ??= data['history'];
          return ticket;
        }
        return data;
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
          res['data'] ??
          res['rows'] ??
          res['tickets'] ??
          res['history'] ??
          res['messages'] ??
          res['conversation'];
      if (raw is List) return raw;
      if (raw is Map && raw['rows'] is List) return raw['rows'] as List;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
    }
    return const [];
  }
}

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';
import 'package:solar_sales/shared/utils/formatters.dart';

import 'models/item_model.dart';

class ItemApiService {
  final ApiService _api;

  ItemApiService(this._api);

  Future<PaginatedResult<ItemModel>> list({
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.items,
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, ItemModel.fromJson);
  }

  Future<ItemModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.item(id));
    return ItemModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<ItemModel>> listApproved() async {
    final res = await _api.get(ApiEndpoints.itemsApproved);
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ItemModel>> listStockable() async {
    final res = await _api.get(ApiEndpoints.itemsStockable);
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ItemModel>> pendingApprovals() async {
    final res = await _api.get(ApiEndpoints.itemsPending);
    final list = res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    return list
        .whereType<Map>()
        .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ItemModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.items, body);
    return ItemModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<ItemModel> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.item(id), body);
    return ItemModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> deactivate(String id) async {
    await _api.post(ApiEndpoints.itemDeactivate(id));
  }

  Future<ItemModel> approve(String id) async {
    final res = await _api.post(ApiEndpoints.itemApprove(id));
    return ItemModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<ItemModel> reject(String id, String reason) async {
    final res = await _api.post(ApiEndpoints.itemReject(id), {'reason': reason});
    return ItemModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Map<String, dynamic> unwrap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    return Map<String, dynamic>.from(res as Map);
  }

  String errorMessage(Object e) => cleanError(e);
}

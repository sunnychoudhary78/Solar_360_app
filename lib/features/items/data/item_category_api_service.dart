import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/item_category_model.dart';

class ItemCategoryApiService {
  final ApiService _api;

  ItemCategoryApiService(this._api);

  Future<List<ItemCategoryModel>> list({bool includeInactive = false}) async {
    final res = await _api.get(
      ApiEndpoints.itemCategories,
      queryParams: includeInactive ? const {'all': 'true'} : null,
    );
    final list =
        res is List ? res : (res is Map ? (res['data'] as List? ?? []) : []);
    final categories = list
        .whereType<Map>()
        .map((e) => ItemCategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    categories.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return categories;
  }

  Future<ItemCategoryModel> create({
    required String label,
    bool isActive = true,
  }) async {
    final res = await _api.post(ApiEndpoints.itemCategories, {
      'label': label.trim(),
      'is_active': isActive,
    });
    return ItemCategoryModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<ItemCategoryModel> update(
    String id, {
    String? label,
    bool? isActive,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{
      if (label != null) 'label': label.trim(),
      ?'is_active': isActive,
      ?'sort_order': sortOrder,
    };
    final res = await _api.patch(ApiEndpoints.itemCategory(id), body);
    return ItemCategoryModel.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

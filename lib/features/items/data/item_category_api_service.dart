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
    return list
        .whereType<Map>()
        .map((e) => ItemCategoryModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

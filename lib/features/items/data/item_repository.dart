import 'package:solar_sales/shared/models/paginated_result.dart';

import 'item_api_service.dart';
import 'models/item_model.dart';

class ItemRepository {
  final ItemApiService _api;

  ItemRepository(this._api);

  Future<PaginatedResult<ItemModel>> list({
    String? search,
    String? status,
    int page = 1,
    int limit = 20,
  }) =>
      _api.list(search: search, status: status, page: page, limit: limit);

  Future<ItemModel> getById(String id) => _api.getById(id);

  Future<List<ItemModel>> listApproved() => _api.listApproved();

  Future<List<ItemModel>> listStockable() => _api.listStockable();

  Future<List<ItemModel>> pendingApprovals() => _api.pendingApprovals();

  Future<ItemModel> create(ItemModel item, {String? warehouseId}) {
    final body = item.toJson();
    if (warehouseId != null && warehouseId.isNotEmpty) {
      body['warehouse_id'] = warehouseId;
    }
    return _api.create(body);
  }

  Future<ItemModel> update(String id, ItemModel item) =>
      _api.update(id, item.toJson());

  Future<void> deactivate(String id) => _api.deactivate(id);

  Future<ItemModel> approve(String id) => _api.approve(id);

  Future<ItemModel> reject(String id, String reason) =>
      _api.reject(id, reason);
}

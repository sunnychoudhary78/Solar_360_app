import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/shared/models/paginated_result.dart';

import 'models/customer_model.dart';

class CustomerApiService {
  final ApiService _api;

  CustomerApiService(this._api);

  Future<PaginatedResult<CustomerModel>> list({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get(
      ApiEndpoints.customers,
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedResult.fromJson(res, CustomerModel.fromJson);
  }

  Future<CustomerModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.customer(id));
    return CustomerModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<CustomerModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.customers, body);
    return CustomerModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<CustomerModel> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.customer(id), body);
    return CustomerModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> remove(String id) async {
    await _api.delete(ApiEndpoints.customer(id));
  }
}

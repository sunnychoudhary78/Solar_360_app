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
    return CustomerModel.fromJson(
      Map<String, dynamic>.from(res as Map? ?? {}),
    );
  }

  Future<CustomerWriteResult> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.customers, body);
    final map = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final credentialsRaw = map['login_credentials'];
    final credentials = credentialsRaw is Map
        ? LoginCredentials.fromJson(credentialsRaw)
        : null;
    return CustomerWriteResult(
      customer: CustomerModel.fromJson(map),
      credentials: credentials != null && credentials.isValid
          ? credentials
          : null,
    );
  }

  Future<CustomerModel> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.customer(id), body);
    return CustomerModel.fromJson(
      Map<String, dynamic>.from(res as Map? ?? {}),
    );
  }

  Future<LoginCredentials> resetDefaultPassword(String id) async {
    final res = await _api.post(ApiEndpoints.customerResetPassword(id));
    final map = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final credentials = LoginCredentials.fromJson(map['login_credentials']);
    if (!credentials.isValid) {
      throw Exception('Login credentials were not returned');
    }
    return credentials;
  }

  Future<void> remove(String id) async {
    await _api.delete(ApiEndpoints.customer(id));
  }
}

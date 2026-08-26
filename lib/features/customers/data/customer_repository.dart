import 'package:solar_sales/shared/models/paginated_result.dart';

import 'customer_api_service.dart';
import 'models/customer_model.dart';

class CustomerRepository {
  final CustomerApiService _api;

  CustomerRepository(this._api);

  Future<PaginatedResult<CustomerModel>> list({
    String? search,
    int page = 1,
    int limit = 20,
  }) =>
      _api.list(search: search, page: page, limit: limit);

  Future<CustomerModel> getById(String id) => _api.getById(id);

  Future<CustomerWriteResult> create(CustomerModel customer) =>
      _api.create(customer.toJson());

  Future<LoginCredentials> resetDefaultPassword(String id) =>
      _api.resetDefaultPassword(id);

  Future<CustomerModel> update(String id, CustomerModel customer) =>
      _api.update(id, customer.toJson());

  Future<void> remove(String id) => _api.remove(id);
}

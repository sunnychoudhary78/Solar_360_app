import 'models/report_models.dart';
import 'reports_api_service.dart';

class ReportsRepository {
  final ReportsApiService _api;

  ReportsRepository(this._api);

  Future<ReportsBundle> loadAll() => _api.loadAll();
}

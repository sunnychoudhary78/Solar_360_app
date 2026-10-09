import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/solar_tasks/data/models/solar_task_models.dart';

class SolarTaskApiService {
  SolarTaskApiService(this._api);

  final ApiService _api;

  Future<SolarTaskMeta> meta() async {
    final res = await _api.get(ApiEndpoints.solarTasksMeta);
    if (res is Map) {
      return SolarTaskMeta.fromJson(Map<String, dynamic>.from(res));
    }
    return const SolarTaskMeta();
  }

  Future<List<SolarTaskProject>> projects({String? scope}) async {
    final res = await _api.get(
      ApiEndpoints.solarTasksProjects,
      queryParams: {
        if (scope != null && scope.isNotEmpty) 'scope': scope,
      },
    );
    return _unwrapList(res)
        .whereType<Map>()
        .map((e) => SolarTaskProject.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<SolarTaskAssignee>> assignees() async {
    final res = await _api.get(ApiEndpoints.solarTasksAssignees);
    return _unwrapList(res)
        .whereType<Map>()
        .map((e) => SolarTaskAssignee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<SolarTaskListResult> list({
    String? leadId,
    String? scope,
    String? phaseKey,
    String? status,
    String? search,
    String? overdue,
    String? assigneeId,
  }) async {
    final res = await _api.get(
      ApiEndpoints.solarTasks,
      queryParams: {
        if (leadId != null && leadId.isNotEmpty) 'lead_id': leadId,
        if (scope != null && scope.isNotEmpty) 'scope': scope,
        if (phaseKey != null && phaseKey.isNotEmpty) 'phase_key': phaseKey,
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        if (overdue != null && overdue.isNotEmpty) 'overdue': overdue,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
      },
    );
    if (res is Map) {
      return SolarTaskListResult.fromJson(Map<String, dynamic>.from(res));
    }
    return SolarTaskListResult(
      data: _unwrapList(res)
          .whereType<Map>()
          .map((e) => SolarTaskModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<SolarTaskModel> getById(String id) async {
    final res = await _api.get(ApiEndpoints.solarTask(id));
    return SolarTaskModel.fromJson(_unwrapMap(res));
  }

  Future<SolarTaskModel> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.solarTasks, body);
    return SolarTaskModel.fromJson(_unwrapMap(res));
  }

  Future<SolarTaskModel> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.solarTask(id), body);
    return SolarTaskModel.fromJson(_unwrapMap(res));
  }

  Future<SolarTaskModel> updateStatus(String id, String status) async {
    final res = await _api.patch(ApiEndpoints.solarTaskStatus(id), {
      'status': status,
    });
    return SolarTaskModel.fromJson(_unwrapMap(res));
  }

  Future<void> remove(String id) async {
    await _api.delete(ApiEndpoints.solarTask(id));
  }

  Future<SolarTaskListResult> checklist({
    required String leadId,
    String? phaseKey,
  }) async {
    final res = await _api.post(ApiEndpoints.solarTasksChecklist, {
      'lead_id': leadId,
      if (phaseKey != null && phaseKey.isNotEmpty) 'phase_key': phaseKey,
    });
    if (res is Map) {
      return SolarTaskListResult.fromJson(Map<String, dynamic>.from(res));
    }
    return const SolarTaskListResult();
  }

  Map<String, dynamic> _unwrapMap(dynamic res) {
    if (res is Map) {
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(res);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(dynamic res) {
    if (res is List) return res;
    if (res is Map) {
      final data = res['data'];
      if (data is List) return data;
    }
    return const [];
  }
}

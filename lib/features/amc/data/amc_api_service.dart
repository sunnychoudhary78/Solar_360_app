import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';
import 'package:solar_sales/features/amc/data/models/amc_models.dart';

class AmcApiService {
  AmcApiService(this._api);

  final ApiService _api;

  Future<AmcMeta> meta() async {
    final res = await _api.get(ApiEndpoints.amcMeta);
    if (res is Map) {
      return AmcMeta.fromJson(Map<String, dynamic>.from(res));
    }
    return const AmcMeta();
  }

  Future<AmcSummary> summary() async {
    final res = await _api.get(ApiEndpoints.amcSummary);
    return AmcSummary.fromJson(_unwrapMap(res));
  }

  Future<List<AmcPlant>> plants({
    String? search,
    String? amc,
  }) async {
    final res = await _api.get(
      ApiEndpoints.amcPlants,
      queryParams: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (amc != null && amc.isNotEmpty) 'amc': amc,
      },
    );
    return _unwrapList(res)
        .whereType<Map>()
        .map((e) => AmcPlant.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AmcPlant> plant(String leadId) async {
    final res = await _api.get(ApiEndpoints.amcPlant(leadId));
    return AmcPlant.fromJson(_unwrapMap(res));
  }

  Future<List<AmcAssignee>> assignees() async {
    final res = await _api.get(ApiEndpoints.amcAssignees);
    return _unwrapList(res)
        .whereType<Map>()
        .map((e) => AmcAssignee.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AmcVisitListResult> visits({
    String? search,
    String? status,
    String? leadId,
    String? contractId,
    String? assigneeId,
    bool overdue = false,
    String? due,
    String? completed,
  }) async {
    final res = await _api.get(
      ApiEndpoints.amcVisits,
      queryParams: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (leadId != null && leadId.isNotEmpty) 'lead_id': leadId,
        if (contractId != null && contractId.isNotEmpty)
          'contract_id': contractId,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assignee_id': assigneeId,
        if (overdue) 'overdue': 'true',
        if (due != null && due.isNotEmpty) 'due': due,
        if (completed != null && completed.isNotEmpty) 'completed': completed,
      },
    );
    if (res is Map) {
      return AmcVisitListResult.fromJson(Map<String, dynamic>.from(res));
    }
    return AmcVisitListResult(
      data: _unwrapList(res)
          .whereType<Map>()
          .map((e) => AmcVisit.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<AmcVisit> visit(String id) async {
    final res = await _api.get(ApiEndpoints.amcVisit(id));
    return AmcVisit.fromJson(_unwrapMap(res));
  }

  Future<AmcPlant> startContract(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.amcContracts, body);
    return AmcPlant.fromJson(_unwrapMap(res));
  }

  Future<AmcPlant> updateContract(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put(ApiEndpoints.amcContract(id), body);
    return AmcPlant.fromJson(_unwrapMap(res));
  }

  Future<AmcPlant> renewContract(String id) async {
    final res = await _api.post(ApiEndpoints.amcContractRenew(id));
    return AmcPlant.fromJson(_unwrapMap(res));
  }

  Future<AmcVisit> createVisit(Map<String, dynamic> body) async {
    final res = await _api.post(ApiEndpoints.amcVisits, body);
    return AmcVisit.fromJson(_unwrapMap(res));
  }

  Future<AmcVisit> updateVisit(String id, Map<String, dynamic> body) async {
    final res = await _api.put(ApiEndpoints.amcVisit(id), body);
    return AmcVisit.fromJson(_unwrapMap(res));
  }

  Future<AmcVisit> uploadPhotos(String id, List<String> filePaths) async {
    final files = <MultipartFile>[];
    for (final path in filePaths) {
      final name = path.replaceAll('\\', '/').split('/').last;
      files.add(
        await MultipartFile.fromFile(
          path,
          filename: name,
          contentType: _imageContentType(name),
        ),
      );
    }
    final form = FormData();
    for (final file in files) {
      form.files.add(MapEntry('photos', file));
    }
    final res = await _api.postFormData(ApiEndpoints.amcVisitPhotos(id), form);
    return AmcVisit.fromJson(_unwrapMap(res));
  }

  Future<void> removeVisit(String id) async {
    await _api.delete(ApiEndpoints.amcVisit(id));
  }

  MediaType _imageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
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

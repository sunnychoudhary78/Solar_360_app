import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/lead_model.dart';

class LeadApiService {
  final ApiService _api;
  final Dio _dio;

  LeadApiService(this._api, this._dio);

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> createLead(
    Map<String, dynamic> data, {
    Map<String, String>? singleFilePaths,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) async {
    final formDataMap = <String, dynamic>{...data};

    if (singleFilePaths != null) {
      for (final entry in singleFilePaths.entries) {
        final filePath = entry.value.trim();
        if (filePath.isEmpty) continue;

        formDataMap[entry.key] = await MultipartFile.fromFile(
          filePath,
          filename: _fileName(filePath),
        );
      }
    }

    await _attachAdditionalFiles(
      formDataMap,
      additionalImageEntries: additionalImageEntries,
      additionalDocumentEntries: additionalDocumentEntries,
    );

    try {
      await _dio.post(ApiEndpoints.leads, data: FormData.fromMap(formDataMap));
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> uploadLeadDocuments({
    required String leadId,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) async {
    final formDataMap = <String, dynamic>{};

    await _attachAdditionalFiles(
      formDataMap,
      additionalImageEntries: additionalImageEntries,
      additionalDocumentEntries: additionalDocumentEntries,
    );

    if (formDataMap.isEmpty) return;

    try {
      await _dio.put(
        ApiEndpoints.lead(leadId),
        data: FormData.fromMap(formDataMap),
      );
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> _attachAdditionalFiles(
    Map<String, dynamic> formDataMap, {
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) async {
    final imageEntries = (additionalImageEntries ?? [])
        .where(
          (item) =>
              (item['path'] ?? '').trim().isNotEmpty &&
              (item['title'] ?? '').trim().isNotEmpty,
        )
        .toList();

    if (imageEntries.isNotEmpty) {
      formDataMap['additional_images_entries_json'] = jsonEncode(
        imageEntries
            .map(
              (item) => {'title': item['title']!.trim(), 'existingPath': null},
            )
            .toList(),
      );

      formDataMap['additional_images_files'] = await Future.wait(
        imageEntries.map(
          (item) => MultipartFile.fromFile(
            item['path']!.trim(),
            filename: _fileName(item['path']!.trim()),
          ),
        ),
      );
    }

    final documentEntries = (additionalDocumentEntries ?? [])
        .where(
          (item) =>
              (item['path'] ?? '').trim().isNotEmpty &&
              (item['title'] ?? '').trim().isNotEmpty,
        )
        .toList();

    if (documentEntries.isNotEmpty) {
      formDataMap['additional_documents_entries_json'] = jsonEncode(
        documentEntries
            .map(
              (item) => {'title': item['title']!.trim(), 'existingPath': null},
            )
            .toList(),
      );

      formDataMap['additional_documents_files'] = await Future.wait(
        documentEntries.map(
          (item) => MultipartFile.fromFile(
            item['path']!.trim(),
            filename: _fileName(item['path']!.trim()),
          ),
        ),
      );
    }
  }

  Future<List<LeadModel>> getAllLeads() async {
    final res = await _api.get(ApiEndpoints.leads);
    return _parseLeadList(res);
  }

  Future<LeadModel> getLeadById(String id) async {
    final res = await _api.get(ApiEndpoints.lead(id));
    return LeadModel.fromJson(_extractLeadJson(res));
  }

  Future<List<Map<String, dynamic>>> getLeadHistory(String leadId) async {
    final data = await _api.get(ApiEndpoints.leadHistory(leadId));

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> updateLeadStatus({
    required String leadId,
    required String status,
    String? remarks,
  }) async {
    final data = await _api.patch(ApiEndpoints.leadStatus(leadId), {
      'status': status,
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });

    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {'new_status': status};
  }

  Future<LeadModel> assignLead(String leadId, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch(ApiEndpoints.leadAssign(leadId), data);
      return LeadModel.fromJson(_extractLeadJson(res));
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<List<Map<String, dynamic>>> getUsersByRole(List<String> roles) async {
    final cleanRoles = roles
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList();

    if (cleanRoles.isEmpty) return [];

    final data = await _api.get(
      '${ApiEndpoints.usersByRole}?roles=${Uri.encodeQueryComponent(cleanRoles.join(','))}',
    );

    final list = data is Map && data['data'] is List
        ? data['data'] as List
        : data is List
        ? data
        : const [];

    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> updateLeadWithFiles(
    String leadId,
    Map<String, dynamic> data, {
    Map<String, String>? singleFilePaths,
    List<String>? registrationImagePaths,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) async {
    final formDataMap = <String, dynamic>{...data};

    if (singleFilePaths != null) {
      for (final entry in singleFilePaths.entries) {
        final filePath = entry.value.trim();
        if (filePath.isEmpty) continue;
        if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
          continue;
        }

        formDataMap[entry.key] = await MultipartFile.fromFile(
          filePath,
          filename: _fileName(filePath),
        );
      }
    }

    final registrationFiles = (registrationImagePaths ?? [])
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (registrationFiles.isNotEmpty) {
      formDataMap['registration_images'] = await Future.wait(
        registrationFiles.map(
          (path) => MultipartFile.fromFile(path, filename: _fileName(path)),
        ),
      );
    }

    await _attachAdditionalFiles(
      formDataMap,
      additionalImageEntries: additionalImageEntries,
      additionalDocumentEntries: additionalDocumentEntries,
    );

    try {
      await _dio.put(
        ApiEndpoints.lead(leadId),
        data: FormData.fromMap(formDataMap),
      );
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<LeadModel?> updateLead(
    String leadId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _api.put(ApiEndpoints.lead(leadId), data);

      try {
        return LeadModel.fromJson(_extractLeadJson(res));
      } catch (_) {
        return null;
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> getWorkflowMeta() async {
    final data = await _api.get(ApiEndpoints.leadsWorkflowMeta);

    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }

    if (data is Map) return Map<String, dynamic>.from(data);

    return {};
  }

  Map<String, dynamic> _extractLeadJson(dynamic data) {
    dynamic lead = data;

    if (data is Map) {
      lead = data['lead'] ?? data['data'] ?? data['result'] ?? data;
    }

    if (lead is Map && lead['lead'] is Map) {
      lead = lead['lead'];
    }

    if (lead is Map && lead['dataValues'] is Map) {
      lead = lead['dataValues'];
    }

    if (lead is! Map) {
      throw Exception('Invalid lead response');
    }

    final map = Map<String, dynamic>.from(lead);

    if (map['installationDetails'] is Map) {
      map['installationDetails'] = Map<String, dynamic>.from(
        map['installationDetails'] as Map,
      );
    }

    return map;
  }

  List<LeadModel> _parseLeadList(dynamic rawData) {
    final List data;

    if (rawData is List) {
      data = rawData;
    } else if (rawData is Map && rawData['data'] is List) {
      data = rawData['data'] as List;
    } else if (rawData is Map && rawData['leads'] is List) {
      data = rawData['leads'] as List;
    } else {
      data = [];
    }

    return data
        .whereType<Map>()
        .map((item) => LeadModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _handleDioError(DioException e) {
    final data = e.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }

    if (e.response?.statusCode != null) {
      return 'Request failed (${e.response?.statusCode})';
    }

    return e.message ?? 'Network error';
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

import 'models/lead_model.dart';

class LeadApiService {
  final ApiService _api;
  final Dio _dio;
  final String _leadsPath;
  final String Function(String id) _leadPath;

  LeadApiService(
    this._api,
    this._dio, {
    String leadsPath = ApiEndpoints.leads,
    String Function(String id)? leadPath,
  })  : _leadsPath = leadsPath,
        _leadPath = leadPath ?? ApiEndpoints.lead;

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  MediaType _contentTypeFor(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.webp')) return MediaType('image', 'webp');
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (name.endsWith('.doc')) return MediaType('application', 'msword');
    if (name.endsWith('.docx')) {
      return MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    return MediaType('image', 'jpeg');
  }

  Future<MultipartFile> _multipartFromPath(String path) {
    final filename = _fileName(path);
    return MultipartFile.fromFile(
      path,
      filename: filename,
      contentType: _contentTypeFor(filename),
    );
  }

  bool _isExistingRemotePath(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return false;
    final lower = normalized.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }
    if (lower.startsWith('/api/uploads/') ||
        lower.startsWith('api/uploads/') ||
        lower.startsWith('/uploads/') ||
        lower.startsWith('uploads/') ||
        lower.startsWith('leads/')) {
      return true;
    }
    if (lower.startsWith('content://') || lower.startsWith('file://')) {
      return false;
    }
    if (normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(normalized)) {
      return false;
    }
    return true;
  }

  Future<LeadModel?> createLead(
    Map<String, dynamic> data, {
    Map<String, String>? singleFilePaths,
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
  }) async {
    final formDataMap = <String, dynamic>{...data};

    if (singleFilePaths != null) {
      for (final entry in singleFilePaths.entries) {
        final filePath = entry.value.trim();
        if (filePath.isEmpty || _isExistingRemotePath(filePath)) continue;

        formDataMap[entry.key] = await _multipartFromPath(filePath);
      }
    }

    await _attachAdditionalFiles(
      formDataMap,
      additionalImageEntries: additionalImageEntries,
      additionalDocumentEntries: additionalDocumentEntries,
    );

    try {
      final res = await _dio.post(
        _leadsPath,
        data: FormData.fromMap(formDataMap, ListFormat.multi),
      );
      try {
        return LeadModel.fromJson(_extractLeadJson(res.data));
      } catch (_) {
        return null;
      }
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
        _leadPath(leadId),
        data: FormData.fromMap(formDataMap, ListFormat.multi),
      );
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<void> _attachAdditionalFiles(
    Map<String, dynamic> formDataMap, {
    List<Map<String, String>>? additionalImageEntries,
    List<Map<String, String>>? additionalDocumentEntries,
    bool alwaysSendMeta = false,
  }) async {
    Future<void> attach({
      required String metaField,
      required String filesField,
      required String leadField,
      required List<Map<String, String>>? entries,
    }) async {
      final items = (entries ?? [])
          .where(
            (item) =>
                (item['title'] ?? '').trim().isNotEmpty &&
                (item['path'] ?? '').trim().isNotEmpty,
          )
          .toList();

      if (items.isEmpty) {
        // On edit, send [] so intentional clears persist; otherwise omit.
        if (alwaysSendMeta) {
          formDataMap[metaField] = '[]';
          formDataMap[leadField] = '[]';
        }
        return;
      }

      final meta = <Map<String, dynamic>>[];
      final files = <MultipartFile>[];

      for (final item in items) {
        final title = item['title']!.trim();
        final path = item['path']!.trim();
        if (_isExistingRemotePath(path)) {
          meta.add({'title': title, 'existingPath': path, 'file': path});
        } else {
          meta.add({'title': title, 'existingPath': null});
          files.add(await _multipartFromPath(path));
        }
      }

      formDataMap[metaField] = jsonEncode(meta);
      if (files.isNotEmpty) {
        formDataMap[filesField] = files;
      } else {
        // Customer PUT copies Lead columns from the body. Persist titled
        // remotes on additional_documents / additional_images, not only
        // the unused *_entries_json field.
        formDataMap[leadField] = jsonEncode([
          for (final item in meta)
            if (item['file'] != null)
              {'title': item['title'], 'file': item['file']},
        ]);
      }
    }

    await attach(
      metaField: 'additional_images_entries_json',
      filesField: 'additional_images_files',
      leadField: 'additional_images',
      entries: additionalImageEntries,
    );
    await attach(
      metaField: 'additional_documents_entries_json',
      filesField: 'additional_documents_files',
      leadField: 'additional_documents',
      entries: additionalDocumentEntries,
    );
  }

  Future<List<LeadModel>> getAllLeads() async {
    final res = await _api.get(_leadsPath);
    return _parseLeadList(res);
  }

  Future<LeadModel> getLeadById(String id) async {
    final res = await _api.get(_leadPath(id));
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
        if (filePath.isEmpty) {
          // Explicit clear of a previously saved single-slot file.
          formDataMap[entry.key] = '';
          continue;
        }
        if (_isExistingRemotePath(filePath)) {
          formDataMap[entry.key] ??= filePath;
          continue;
        }

        formDataMap[entry.key] = await _multipartFromPath(filePath);
      }
    }

    final registrationFiles = (registrationImagePaths ?? [])
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty && !_isExistingRemotePath(path))
        .toList();
    if (registrationFiles.isNotEmpty) {
      formDataMap['registration_images'] = await Future.wait(
        registrationFiles.map(_multipartFromPath),
      );
    }

    await _attachAdditionalFiles(
      formDataMap,
      additionalImageEntries: additionalImageEntries,
      additionalDocumentEntries: additionalDocumentEntries,
      alwaysSendMeta: true,
    );

    try {
      await _dio.put(
        _leadPath(leadId),
        data: FormData.fromMap(formDataMap, ListFormat.multi),
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
      final payload = <String, dynamic>{
        for (final entry in data.entries)
          if (entry.value != null) entry.key: entry.value,
      };

      final res = await _dio.put(
        _leadPath(leadId),
        data: payload,
      );

      try {
        return LeadModel.fromJson(_extractLeadJson(res.data));
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
        .map((item) => LeadModel.fromJson(_asLeadMap(item)))
        .toList();
  }

  Map<String, dynamic> _asLeadMap(Map item) {
    var map = Map<String, dynamic>.from(item);
    if (map['dataValues'] is Map) {
      map = Map<String, dynamic>.from(map['dataValues'] as Map);
    }
    return map;
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

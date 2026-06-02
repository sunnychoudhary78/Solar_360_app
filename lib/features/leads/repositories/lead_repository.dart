import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/lead_model.dart';

class LeadRepository {
  final Dio dio;

  LeadRepository(this.dio);

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
    try {
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

      final imageEntries = (additionalImageEntries ?? [])
          .where((item) =>
              (item['path'] ?? '').trim().isNotEmpty &&
              (item['title'] ?? '').trim().isNotEmpty)
          .toList();

      if (imageEntries.isNotEmpty) {
        formDataMap['additional_images_entries_json'] = jsonEncode(
          imageEntries
              .map((item) => {
                    'title': item['title']!.trim(),
                    'existingPath': null,
                  })
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
          .where((item) =>
              (item['path'] ?? '').trim().isNotEmpty &&
              (item['title'] ?? '').trim().isNotEmpty)
          .toList();

      if (documentEntries.isNotEmpty) {
        formDataMap['additional_documents_entries_json'] = jsonEncode(
          documentEntries
              .map((item) => {
                    'title': item['title']!.trim(),
                    'existingPath': null,
                  })
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

      await dio.post('/leads', data: FormData.fromMap(formDataMap));
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<List<LeadModel>> getAllLeads() async {
    try {
      final response = await dio.get('/leads');
      return _parseLeadList(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<LeadModel> getLeadById(String id) async {
    try {
      final response = await dio.get('/leads/$id');
      final leadJson = _extractLeadJson(response.data);
      return LeadModel.fromJson(leadJson);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<List<Map<String, dynamic>>> getLeadHistory(String leadId) async {
    try {
      final response = await dio.get('/leads/$leadId/history');
      final data = response.data;

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
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<List<String>> getAllowedNextStatuses(String leadId) async {
    try {
      final response = await dio.get('/leads/$leadId');
      final data = response.data;

      if (data is Map && data['meta'] is Map) {
        final meta = data['meta'] as Map;
        final allowed = meta['allowedNextStatuses'];

        if (allowed is List) {
          return allowed.map((e) => e.toString()).toList();
        }
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateLeadStatus({
    required String leadId,
    required String status,
    String? remarks,
  }) async {
    try {
      final response = await dio.patch(
        '/leads/$leadId/status',
        data: {
          'status': status,
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      );

      final data = response.data;

      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return {
        'new_status': status,
      };
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<LeadModel?> updateLead(String leadId, Map<String, dynamic> data) async {
    try {
      final response = await dio.put('/leads/$leadId', data: data);

      try {
        final leadJson = _extractLeadJson(response.data);
        return LeadModel.fromJson(leadJson);
      } catch (_) {
        return null;
      }
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<Map<String, dynamic>> getWorkflowMeta() async {
    try {
      final response = await dio.get('/leads/workflow/meta');
      final data = response.data;

      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }

      if (data is Map) return Map<String, dynamic>.from(data);

      return {};
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
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
      map['installationDetails'] =
          Map<String, dynamic>.from(map['installationDetails'] as Map);
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

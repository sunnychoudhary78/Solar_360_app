import 'package:dio/dio.dart';

import 'package:solar_sales/core/network/api_endpoints.dart';
import 'package:solar_sales/core/network/api_service.dart';

class InstallationApiService {
  final ApiService _api;
  final Dio _dio;

  InstallationApiService(this._api, this._dio);

  Future<Map<String, dynamic>?> getByLeadId(String leadId) async {
    try {
      final data = await _api.get(ApiEndpoints.installationByLead(leadId));
      if (data is Map && data['data'] != null) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('404') || message.contains('not found')) return null;
      rethrow;
    }
  }

  Future<void> createForLead(
    String leadId,
    Map<String, dynamic> body, {
    List<String>? installationImagePaths,
  }) async {
    await _sendInstallationPayload(
      'POST',
      ApiEndpoints.installationByLead(leadId),
      body,
      installationImagePaths: installationImagePaths,
    );
  }

  Future<void> update(
    String installationId,
    Map<String, dynamic> body, {
    List<String>? installationImagePaths,
  }) async {
    await _sendInstallationPayload(
      'PUT',
      ApiEndpoints.installation(installationId),
      body,
      installationImagePaths: installationImagePaths,
    );
  }

  Future<void> _sendInstallationPayload(
    String method,
    String path,
    Map<String, dynamic> body, {
    List<String>? installationImagePaths,
  }) async {
    final cleanImagePaths = (installationImagePaths ?? [])
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();

    if (cleanImagePaths.isEmpty) {
      if (method == 'POST') {
        await _api.post(path, body);
      } else {
        await _api.put(path, body);
      }
      return;
    }

    final formDataMap = <String, dynamic>{...body};
    formDataMap['installation_images'] = await Future.wait(
      cleanImagePaths.map(
        (path) => MultipartFile.fromFile(
          path,
          filename: path.split(RegExp(r'[\\/]')).last,
        ),
      ),
    );

    if (method == 'POST') {
      await _dio.post(path, data: FormData.fromMap(formDataMap));
    } else {
      await _dio.put(path, data: FormData.fromMap(formDataMap));
    }
  }
}

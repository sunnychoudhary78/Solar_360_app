import 'package:dio/dio.dart';

class InstallationRepository {
  final Dio dio;

  InstallationRepository(this.dio);

  Future<Map<String, dynamic>?> getByLeadId(String leadId) async {
    try {
      final response = await dio.get('/installations/lead/$leadId');
      final data = response.data;
      if (data is Map && data['data'] != null) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(_message(e));
    }
  }

  Future<void> createForLead(String leadId, Map<String, dynamic> body) async {
    try {
      await dio.post('/installations/lead/$leadId', data: body);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  Future<void> update(String installationId, Map<String, dynamic> body) async {
    try {
      await dio.put('/installations/$installationId', data: body);
    } on DioException catch (e) {
      throw Exception(_message(e));
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Installation request failed';
  }
}

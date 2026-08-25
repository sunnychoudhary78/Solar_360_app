import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        _path(endpoint),
        queryParameters: queryParams,
      );
      return _handle(response);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Future<dynamic> post(String endpoint, [Map<String, dynamic>? data]) async {
    try {
      final response = await _dio.post(_path(endpoint), data: data ?? {});
      return _handle(response);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.put(
        _path(endpoint),
        data: data,
        queryParameters: queryParams,
      );
      return _handle(response);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(_path(endpoint), data: data);
      return _handle(response);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await _dio.delete(_path(endpoint));
      return _handle(response);
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  Future<Uint8List> getBytes(String endpoint) async {
    try {
      final response = await _dio.get(
        _path(endpoint),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);
      throw Exception('Invalid PDF response');
    } on DioException catch (e) {
      throw _extractException(e);
    }
  }

  String _path(String endpoint) {
    return endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  }

  dynamic _handle(Response response) {
    final code = response.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return response.data;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
    );
  }

  Exception _extractException(DioException e) {
    final errorData = e.response?.data;

    if (errorData is Map) {
      final code = errorData['code']?.toString() ?? '';
      final message = errorData['message'] ?? errorData['error'];
      if (code == 'SUBSCRIPTION_INACTIVE' ||
          (message != null &&
              message.toString().toUpperCase().contains('SUBSCRIPTION'))) {
        return Exception('SUBSCRIPTION_INACTIVE');
      }
      if (message != null) {
        return Exception(message.toString());
      }
    }

    if (e.response?.statusCode == 403) {
      final raw = errorData?.toString() ?? '';
      if (raw.toUpperCase().contains('SUBSCRIPTION')) {
        return Exception('SUBSCRIPTION_INACTIVE');
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout');
    }

    if (e.type == DioExceptionType.connectionError) {
      if (kDebugMode) {
        debugPrint('Connection error to ${e.requestOptions.uri}: ${e.message}');
      }
      return Exception(
        'Cannot reach server. Check API URL and network.',
      );
    }

    if (e.response?.statusCode == 401) {
      return Exception('Session expired. Please sign in again.');
    }

    if (kDebugMode) {
      debugPrint('Unhandled API error: $e');
    }

    return Exception('Something went wrong');
  }
}

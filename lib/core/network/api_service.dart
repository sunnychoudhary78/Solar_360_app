import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

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
    final status = e.response?.statusCode;
    final errorData = e.response?.data;

    if (errorData is Map) {
      final code = errorData['code']?.toString() ?? '';
      final message = errorData['message'] ?? errorData['error'];
      if (code == 'SUBSCRIPTION_INACTIVE' ||
          (message != null &&
              message.toString().toUpperCase().contains('SUBSCRIPTION'))) {
        return ApiException('SUBSCRIPTION_INACTIVE', statusCode: status);
      }
      if (message != null) {
        return ApiException(message.toString(), statusCode: status);
      }
    }

    if (status == 403) {
      final raw = errorData?.toString() ?? '';
      if (raw.toUpperCase().contains('SUBSCRIPTION')) {
        return const ApiException('SUBSCRIPTION_INACTIVE', statusCode: 403);
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException('Connection timeout', statusCode: status);
    }

    if (e.type == DioExceptionType.connectionError) {
      if (kDebugMode) {
        debugPrint('Connection error to ${e.requestOptions.uri}: ${e.message}');
      }
      return ApiException(
        'Cannot reach server. Check API URL and network.',
        statusCode: status,
      );
    }

    if (status == 401) {
      return const ApiException(
        'Session expired. Please sign in again.',
        statusCode: 401,
      );
    }

    if (kDebugMode) {
      debugPrint('Unhandled API error: $e');
    }

    return ApiException('Something went wrong', statusCode: status);
  }
}

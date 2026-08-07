import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records HTTP calls and returns scripted JSON/binary responses for tests.
class RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, dynamic Function(RequestOptions)> handlers = {};

  void on(String method, String pathContains, dynamic Function(RequestOptions) handler) {
    handlers['$method ${pathContains.toLowerCase()}'] = handler;
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path.toLowerCase();
    final method = options.method.toUpperCase();

    for (final entry in handlers.entries) {
      final parts = entry.key.split(' ');
      final m = parts.first;
      final needle = parts.sublist(1).join(' ');
      if (m == method && path.contains(needle)) {
        final result = entry.value(options);
        if (result is Uint8List) {
          return ResponseBody.fromBytes(
            result,
            200,
            headers: {
              Headers.contentTypeHeader: ['application/pdf'],
            },
          );
        }
        final json = jsonEncode(result);
        return ResponseBody.fromString(
          json,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }

    return ResponseBody.fromString(
      jsonEncode({'message': 'No mock for $method ${options.path}'}),
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  List<RequestOptions> of(String method, String pathContains) {
    return requests
        .where(
          (r) =>
              r.method.toUpperCase() == method.toUpperCase() &&
              r.path.toLowerCase().contains(pathContains.toLowerCase()),
        )
        .toList();
  }
}

ApiServicePair createTestApi() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test.local/api/',
      contentType: 'application/json',
    ),
  );
  final adapter = RecordingAdapter();
  dio.httpClientAdapter = adapter;
  return ApiServicePair(dio: dio, adapter: adapter);
}

class ApiServicePair {
  final Dio dio;
  final RecordingAdapter adapter;

  ApiServicePair({required this.dio, required this.adapter});
}

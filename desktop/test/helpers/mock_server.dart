import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A recorded request captured by [MockServerAdapter].
class RecordedRequest {
  final String path;
  final dynamic body;
  final Map<String, dynamic> headers;

  RecordedRequest(this.path, this.body, this.headers);

  String? header(String name) {
    final direct = headers[name];
    if (direct != null) return direct;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }
}

/// In-process stand-in for the real API server.
///
/// Routes are matched by path suffix (e.g. `'auth/login'` matches
/// `/api/auth/login`). Each route returns a JSON body and status code, and
/// every request is recorded for assertions.
class MockServerAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = [];

  /// path suffix -> async handler returning (status, body).
  /// [RecordedRequest] is passed so a route can echo request data
  /// (e.g. processedOpIds).
  final Map<String, Future<ResponseBody> Function(RecordedRequest)> routes;

  MockServerAdapter(this.routes);

  factory MockServerAdapter.json(
      Map<String, dynamic Function(RecordedRequest)> routeBodies) {
    return MockServerAdapter(routeBodies.map((suffix, build) =>
        MapEntry(suffix, (req) async => _json(200, build(req)))));
  }

  static ResponseBody jsonResponse(int status, dynamic body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  static ResponseBody _json(int status, dynamic body) =>
      jsonResponse(status, body);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic body;
    if (requestStream != null) {
      final bytes = await requestStream
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    final path = options.uri.toString();
    final recorded =
        RecordedRequest(path, body, Map<String, dynamic>.from(options.headers));
    requests.add(recorded);

    for (final entry in routes.entries) {
      if (path.endsWith(entry.key)) return entry.value(recorded);
    }
    return _json(404, {'error': 'no route for $path'});
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// A transport-level failure (backend unreachable / HTTP error / bad JSON).
///
/// IMPORTANT: this is only for the backend being *down*. Subsystem outages
/// (qBittorrent offline, SMART unavailable, path missing) are NOT errors —
/// they arrive as `reachable`/`available`/`exists` flags in a 200 response and
/// are rendered as "degraded" states, not thrown.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errCode;

  const ApiException(this.message, {this.statusCode, this.errCode});

  @override
  String toString() => message;
}

/// Tiny fetch wrapper around the read-only Dell Media Server API.
///
/// Everything is `GET` under `/api/v1` with no auth in v1. The `Authorization`
/// header is attached whenever an auth token is configured, so v2 control
/// actions (POST) can reuse this client unchanged.
class ApiClient {
  ApiClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final AppConfig config;
  final http.Client _http;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final qp = query
        ?.map((k, v) => MapEntry(k, v?.toString()))
      ?..removeWhere((_, v) => v == null);
    return Uri.parse('$base/api/v1$path').replace(
      queryParameters: (qp == null || qp.isEmpty) ? null : qp.cast<String, String>(),
    );
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (config.hasAuthToken) 'Authorization': 'Bearer ${config.authToken}',
      };

  /// GET + JSON-decode, mapping into [T] via [parse].
  Future<T> getJson<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    final decoded = await _get(path, query: query);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response shape (expected a JSON object).');
    }
    return parse(decoded);
  }

  /// POST a JSON body to a control endpoint, attaching `X-API-Key`, and
  /// JSON-decode the reply into [T]. Non-2xx (e.g. 401 bad key, 503 no key
  /// configured server-side) throws an [ApiException]; a `200` with
  /// `{"ok": false, …}` is a *successful* HTTP response and is returned as-is
  /// for the caller to surface as a soft failure.
  Future<T> postJson<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _send(
      http.Request('POST', _uri(path))
        ..headers.addAll(_actionHeaders(json: true))
        ..body = jsonEncode(body ?? const {}),
    );
    return _decodeAsObject(res, parse);
  }

  /// POST a file as `multipart/form-data` (field name [field]) to a control
  /// endpoint, attaching `X-API-Key`.
  Future<T> postMultipart<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_actionHeaders())
      ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    final res = await _send(request);
    return _decodeAsObject(res, parse);
  }

  Map<String, String> _actionHeaders({bool json = false}) => {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (config.hasAuthToken) 'Authorization': 'Bearer ${config.authToken}',
        if (config.hasApiKey) 'X-API-Key': config.apiKey.trim(),
      };

  Future<http.Response> _send(http.BaseRequest request) async {
    try {
      final streamed = await _http.send(request).timeout(AppConfig.actionTimeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('The request timed out.', errCode: '0x0004_TIMEOUT');
    } catch (_) {
      throw const ApiException(
        'Server unreachable. Check the base URL and that you are on the same network.',
        errCode: '0x0001_NO_ROUTE',
      );
    }
  }

  T _decodeAsObject<T>(http.Response res, T Function(Map<String, dynamic>) parse) {
    if (res.statusCode == 401) {
      throw const ApiException(
        'API key rejected — check the key in Settings.',
        statusCode: 401,
        errCode: '0x0401_UNAUTHORIZED',
      );
    }
    if (res.statusCode == 503) {
      throw const ApiException(
        'Control actions are disabled on the server (no API key configured).',
        statusCode: 503,
        errCode: '0x0503_UNAVAILABLE',
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Server returned HTTP ${res.statusCode}.',
          statusCode: res.statusCode, errCode: '0x00${res.statusCode}_HTTP');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw const ApiException('Malformed JSON in server response.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response shape (expected a JSON object).');
    }
    return parse(decoded);
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    http.Response res;
    try {
      res = await _http
          .get(uri, headers: _headers)
          .timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(
        'Connection to the server timed out.',
        errCode: '0x0004_TIMEOUT',
      );
    } catch (e) {
      throw ApiException(
        'Server unreachable. Check the base URL and that you are on the same network.',
        errCode: '0x0001_NO_ROUTE',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Server returned HTTP ${res.statusCode}.',
        statusCode: res.statusCode,
        errCode: '0x00${res.statusCode}_HTTP',
      );
    }

    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw const ApiException('Malformed JSON in server response.');
    }
  }

  void dispose() => _http.close();
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'exceptions.dart';

class HttpClient {
  final ElmahdiPayConfig _config;
  final http.Client _inner;

  HttpClient(this._config, {http.Client? client})
      : _inner = client ?? http.Client();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String?>? query,
  }) =>
      _call(() => _inner.get(_uri(path, query), headers: _headers()));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _call(() => _inner.post(
            _uri(path, null),
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          ));

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri(path, null));
    request.headers.addAll({
      'Accept': 'application/json',
      ..._config.defaultHeaders,
    });
    request.fields.addAll(fields);
    request.files.addAll(files);

    try {
      final streamed = await _inner.send(request).timeout(_config.timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on ElmahdiPayException {
      rethrow;
    } catch (e) {
      throw ElmahdiPayNetworkException('Network error', cause: e);
    }
  }

  void close() => _inner.close();

  // ── internal ────────────────────────────────────────────────────────────

  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ..._config.defaultHeaders,
      };

  Uri _uri(String path, Map<String, String?>? query) {
    final base = Uri.parse('${_config.apiBase}$path');
    if (query == null || query.isEmpty) return base;
    final filtered = {
      for (final e in query.entries)
        if (e.value != null) e.key: e.value!,
    };
    return filtered.isEmpty
        ? base
        : base.replace(queryParameters: {
            ...base.queryParameters,
            ...filtered,
          });
  }

  Future<Map<String, dynamic>> _call(
    Future<http.Response> Function() fn,
  ) async {
    try {
      final response = await fn().timeout(_config.timeout);
      return _handleResponse(response);
    } on ElmahdiPayException {
      rethrow;
    } catch (e) {
      throw ElmahdiPayNetworkException('Network error', cause: e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = _parseBody(response);
    final correlationId = body['correlation_id'] as String? ??
        response.headers['x-correlation-id'];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (correlationId != null && !body.containsKey('correlation_id')) {
        body['correlation_id'] = correlationId;
      }
      return body;
    }

    final message = body['message'] as String? ??
        'Request failed (${response.statusCode})';
    final errors = body['errors'] as Map<String, dynamic>?;

    switch (response.statusCode) {
      case 401:
        throw ElmahdiPayUnauthorizedException(
          message: message,
          errorCode: body['error'] as String?,
          rawBody: body,
          correlationId: correlationId,
        );
      case 403:
        throw ElmahdiPayForbiddenException(
          message: message,
          maxDevices: body['max_devices'] as int?,
          activeDevices: body['active'] as int?,
          correlationId: correlationId,
        );
      case 404:
        throw ElmahdiPayNotFoundException(
          message: message,
          correlationId: correlationId,
        );
      case 409:
        throw ElmahdiPayAlreadyActivatedException(
          message: message,
          correlationId: correlationId,
        );
      case 422:
        throw ElmahdiPayValidationException(
          message: message,
          errors: errors,
          correlationId: correlationId,
        );
      case 429:
        throw ElmahdiPayRateLimitException(
          message: message,
          correlationId: correlationId,
        );
      default:
        throw ElmahdiPayApiException(
          statusCode: response.statusCode,
          message: message,
          errors: errors,
          correlationId: correlationId,
        );
    }
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': response.body};
    } catch (_) {
      return {'message': response.body};
    }
  }
}

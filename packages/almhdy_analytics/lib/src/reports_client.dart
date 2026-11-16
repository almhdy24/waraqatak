import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exception thrown when an AlmHdy Reports API request fails.
class AlmHdyReportsException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  AlmHdyReportsException(this.statusCode, this.message, [this.details]);

  @override
  String toString() => 'AlmHdyReportsException($statusCode): $message';
}

/// Client for interacting with the centralized AlmHdy Analytics & Reports API.
class AlmHdyReportsClient {
  final String baseUrl;
  final String? token;
  final int defaultProjectId;
  final http.Client _client;

  AlmHdyReportsClient({
    this.baseUrl = 'https://api.almhdy24.com',
    this.token,
    this.defaultProjectId = 1,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders() {
    return {
      'Accept': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String path, Map<String, dynamic> queryParams) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uriStr = '$cleanBase$path';
    final filteredParams = <String, String>{};
    queryParams.forEach((k, v) {
      if (v != null) filteredParams[k] = v.toString();
    });
    return Uri.parse(uriStr).replace(queryParameters: filteredParams.isEmpty ? null : filteredParams);
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, dynamic> params) async {
    final uri = _buildUri(path, params);
    final response = await _client.get(uri, headers: _buildHeaders());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw AlmHdyReportsException(
        response.statusCode,
        'Invalid response format: expected JSON object',
      );
    } else {
      String errMsg = 'Request failed with status ${response.statusCode}';
      dynamic errDetails;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errMsg = decoded['message'] as String? ?? decoded['error'] as String? ?? errMsg;
          errDetails = decoded;
        }
      } catch (_) {}
      throw AlmHdyReportsException(response.statusCode, errMsg, errDetails);
    }
  }

  /// Fetches executive overview KPIs (DAU, WAU, MAU, total sessions, events).
  Future<Map<String, dynamic>> getOverview({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/overview', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches unified monitoring & reliability health (crash rate, crash groups, server errors).
  Future<Map<String, dynamic>> getUnifiedMonitoring({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/monitoring', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches geographic distribution metrics (countries, regions, device counts).
  Future<Map<String, dynamic>> getGeographicDistribution({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/geo', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches device intelligence (device models, OS versions, platforms, app versions).
  Future<Map<String, dynamic>> getDeviceIntelligence({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/devices', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches funnels and conversion analysis (funnel steps, drop-offs, trial conversion).
  Future<Map<String, dynamic>> getFunnels({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/funnels', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches feature adoption segmentation (high, moderate, low adoption features).
  Future<Map<String, dynamic>> getFeatures({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/features', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches weekly cohort retention statistics.
  Future<dynamic> getCohorts({int? projectId, int weeks = 6}) async {
    final res = await _getJson('/api/v1/analytics/cohorts', {
      'project_id': projectId ?? defaultProjectId,
      'weeks': weeks,
    });
    return res['data'] ?? res;
  }

  /// Fetches user analytics and active user trends.
  Future<Map<String, dynamic>> getUserAnalytics({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/users', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches product analytics.
  Future<Map<String, dynamic>> getProductAnalytics({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/products', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches technical metrics (platform breakdown, version adoption, error rate).
  Future<Map<String, dynamic>> getTechnical({int? projectId, int days = 30}) async {
    final res = await _getJson('/api/v1/analytics/technical', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
    });
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  /// Fetches live real-time event feed.
  Future<List<dynamic>> getLiveActivity({int? projectId, int limit = 50}) async {
    final res = await _getJson('/api/v1/analytics/live', {
      'project_id': projectId ?? defaultProjectId,
      'limit': limit,
    });
    return (res['events'] as List<dynamic>?) ?? [];
  }

  /// Exports comprehensive analytics dataset as JSON or CSV.
  Future<dynamic> exportData({int? projectId, int days = 30, String format = 'json'}) async {
    final uri = _buildUri('/api/v1/analytics/export', {
      'project_id': projectId ?? defaultProjectId,
      'days': days,
      'format': format,
    });
    final headers = _buildHeaders();
    if (format == 'csv') {
      headers['Accept'] = 'text/csv';
    }
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (format == 'csv') {
        return response.body;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['data'] ?? decoded;
      }
      return decoded;
    }
    throw AlmHdyReportsException(response.statusCode, 'Export failed: ${response.statusCode}');
  }

  /// Closes client resources.
  void close() {
    _client.close();
  }
}

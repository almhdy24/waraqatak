import 'dart:convert';
import 'package:almhdy_analytics/almhdy_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AlmHdyReportsClient Centralized API Integration', () {
    test('getOverview dispatches GET /api/v1/analytics/overview with query params & bearer token', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'dau': 120,
              'wau': 450,
              'mau': 1200,
              'total_sessions': 3200,
              'total_events': 15400,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AlmHdyReportsClient(
        baseUrl: 'https://api.almhdy24.com',
        token: 'test_admin_token_123',
        defaultProjectId: 42,
        client: mockClient,
      );

      final data = await client.getOverview(days: 14);

      expect(capturedUri.path, equals('/api/v1/analytics/overview'));
      expect(capturedUri.queryParameters['project_id'], equals('42'));
      expect(capturedUri.queryParameters['days'], equals('14'));
      expect(capturedHeaders['Authorization'], equals('Bearer test_admin_token_123'));
      expect(data['dau'], equals(120));
      expect(data['mau'], equals(1200));
    });

    test('getUnifiedMonitoring fetches crash rate, groups, and reliability health', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/analytics/monitoring'));
        expect(request.url.queryParameters['project_id'], equals('5'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'crash_free_session_rate': 99.4,
              'unresolved_crashes': 2,
              'resolved_crashes': 10,
              'crash_groups': [
                {'id': 1, 'fingerprint': 'fp_1', 'occurrences': 5},
              ],
              'reliability': {
                'crash_free_sessions_pct': 99.4,
                'total_crashes': 5,
                'impacted_devices': 3,
              },
              'health': {'database': 'connected', 'cache': 'operational'},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AlmHdyReportsClient(
        baseUrl: 'https://api.almhdy24.com',
        token: 'pat_token',
        client: mockClient,
      );

      final data = await client.getUnifiedMonitoring(projectId: 5);
      expect(data['crash_free_session_rate'], equals(99.4));
      expect(data['unresolved_crashes'], equals(2));
      expect(data['health']['database'], equals('connected'));
    });

    test('getGeographicDistribution & getDeviceIntelligence return respective dimensions', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/analytics/geo') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'success': true,
              'data': {
                'countries': [
                  {'code': 'SA', 'name_ar': 'المملكة العربية السعودية', 'devices': 50},
                  {'code': 'EG', 'name_ar': 'مصر', 'devices': 30},
                ],
                'regions': [
                  {'country_code': 'SA', 'region': 'Riyadh', 'devices': 35},
                ],
              },
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/v1/analytics/devices') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'device_models': [
                  {'model': 'Samsung Galaxy S24', 'devices': 25},
                  {'model': 'Dell XPS 15', 'devices': 10},
                ],
                'platforms': [
                  {'platform': 'android', 'devices': 60},
                  {'platform': 'windows', 'devices': 20},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = AlmHdyReportsClient(client: mockClient);

      final geo = await client.getGeographicDistribution();
      expect(geo['countries'].length, equals(2));
      expect(geo['countries'][0]['code'], equals('SA'));

      final dev = await client.getDeviceIntelligence();
      expect(dev['device_models'].length, equals(2));
      expect(dev['device_models'][0]['model'], equals('Samsung Galaxy S24'));
    });

    test('getFunnels & getFeatures parse funnel steps and adoption breakdown', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/analytics/funnels') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'funnel_steps': [
                  {'step': 1, 'step_key': 'app_open', 'users': 100},
                  {'step': 2, 'step_key': 'doc_create', 'users': 75},
                  {'step': 3, 'step_key': 'doc_export', 'users': 50},
                  {'step': 4, 'step_key': 'license_activate', 'users': 25},
                ],
                'trial_stats': {'total_trials': 10, 'converted_trials': 4},
              },
            }),
            200,
          );
        } else if (request.url.path == '/api/v1/analytics/features') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'total_active_users': 100,
                'high_adoption': [
                  {'feature': 'document_created', 'unique_users': 85},
                ],
                'low_adoption': [
                  {'feature': 'stocktake_finalized', 'unique_users': 5},
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = AlmHdyReportsClient(client: mockClient);

      final funnels = await client.getFunnels();
      expect(funnels['funnel_steps'].length, equals(4));
      expect(funnels['trial_stats']['converted_trials'], equals(4));

      final features = await client.getFeatures();
      expect(features['high_adoption'][0]['feature'], equals('document_created'));
      expect(features['low_adoption'][0]['feature'], equals('stocktake_finalized'));
    });

    test('exportData returns CSV text or JSON map based on format', () async {
      final mockClient = MockClient((request) async {
        if (request.url.queryParameters['format'] == 'csv') {
          return http.Response("Section,Metric,Value\nOverview,DAU,100", 200, headers: {'content-type': 'text/csv'});
        } else {
          return http.Response(jsonEncode({'success': true, 'data': {'overview': {'dau': 100}}}), 200);
        }
      });

      final client = AlmHdyReportsClient(client: mockClient);

      final csv = await client.exportData(format: 'csv');
      expect(csv, contains('Section,Metric,Value'));

      final json = await client.exportData(format: 'json');
      expect(json['overview']['dau'], equals(100));
    });

    test('throws AlmHdyReportsException with server error details on failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'unauthorized', 'message': 'Invalid token'}),
          401,
        );
      });

      final client = AlmHdyReportsClient(token: 'bad_token', client: mockClient);

      expect(
        () => client.getOverview(),
        throwsA(isA<AlmHdyReportsException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('Invalid token'))),
      );
    });
  });
}

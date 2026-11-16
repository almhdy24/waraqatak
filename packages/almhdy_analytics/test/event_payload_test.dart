import 'package:almhdy_analytics/almhdy_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlmHdyEvent Payload Serialization & Deserialization', () {
    test('serializes all unified fields including event_id, device_model, country, region', () {
      final ev = AlmHdyEvent(
        eventId: 'ev_test_12345',
        event: 'document_created',
        platform: 'android',
        platformVersion: '14.0',
        appVersion: '2.1.0',
        deviceModel: 'Samsung Galaxy S24',
        country: 'SA',
        region: 'Riyadh',
        installationId: 'inst_abc_1',
        sessionId: 'sess_xyz_1',
        userPseudoId: 'usr_pseudo_1',
        properties: {'type': 'invoice', 'has_payment': true},
        timestamp: '2026-11-15T12:00:00Z',
      );

      final json = ev.toJson();
      expect(json['event_id'], equals('ev_test_12345'));
      expect(json['event'], equals('document_created'));
      expect(json['platform'], equals('android'));
      expect(json['platform_version'], equals('14.0'));
      expect(json['app_version'], equals('2.1.0'));
      expect(json['device_model'], equals('Samsung Galaxy S24'));
      expect(json['country'], equals('SA'));
      expect(json['region'], equals('Riyadh'));
      expect(json['installation_id'], equals('inst_abc_1'));
      expect(json['session_id'], equals('sess_xyz_1'));
      expect(json['user_pseudo_id'], equals('usr_pseudo_1'));
      expect(json['properties'], equals({'type': 'invoice', 'has_payment': true}));
      expect(json['timestamp'], equals('2026-11-15T12:00:00Z'));
    });

    test('deserializes properly from JSON map with backward compatibility', () {
      final map = {
        'event_id': 'ev_rec_9876',
        'event': 'app_opened',
        'platform': 'windows',
        'platform_version': '10.0.22631',
        'app_version': '2.1.0',
        'device_model': 'Dell XPS 15',
        'country': 'EG',
        'region': 'Cairo',
        'installation_id': 'inst_win_1',
        'session_id': 'sess_win_1',
        'user_pseudo_id': 'usr_win_1',
        'properties': {'theme': 'dark'},
        'timestamp': '2026-11-15T13:00:00Z',
      };

      final ev = AlmHdyEvent.fromJson(map);
      expect(ev.eventId, equals('ev_rec_9876'));
      expect(ev.event, equals('app_opened'));
      expect(ev.platform, equals('windows'));
      expect(ev.platformVersion, equals('10.0.22631'));
      expect(ev.appVersion, equals('2.1.0'));
      expect(ev.deviceModel, equals('Dell XPS 15'));
      expect(ev.country, equals('EG'));
      expect(ev.region, equals('Cairo'));
      expect(ev.installationId, equals('inst_win_1'));
      expect(ev.sessionId, equals('sess_win_1'));
      expect(ev.userPseudoId, equals('usr_win_1'));
      expect(ev.properties, equals({'theme': 'dark'}));
      expect(ev.timestamp, equals('2026-11-15T13:00:00Z'));
    });

    test('omits null optional dimensions from JSON serialization', () {
      final ev = AlmHdyEvent(
        event: 'simple_event',
        platform: 'android',
        appVersion: '1.0.0',
        installationId: 'inst_1',
      );

      final json = ev.toJson();
      expect(json.containsKey('event_id'), isFalse);
      expect(json.containsKey('device_model'), isFalse);
      expect(json.containsKey('country'), isFalse);
      expect(json.containsKey('region'), isFalse);
      expect(json.containsKey('platform_version'), isFalse);
      expect(json.containsKey('session_id'), isFalse);
      expect(json.containsKey('user_pseudo_id'), isFalse);
    });
  });
}

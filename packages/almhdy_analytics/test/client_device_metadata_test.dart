import 'dart:io';
import 'package:almhdy_analytics/almhdy_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlmHdyAnalytics Technical & Geographic Metadata', () {
    late Directory tempDir;
    late String storagePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('almhdy_meta_test_');
      storagePath = '${tempDir.path}/buffer.json';
    });

    tearDown(() async {
      AlmHdyAnalytics.instance.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initializes with deviceModel, country, and region and attaches them to tracked events', () async {
      await AlmHdyAnalytics.instance.initialize(
        projectKey: 'ak_test_meta_123',
        deviceModel: 'Samsung Galaxy A16',
        country: 'SD',
        region: 'Khartoum',
        platform: 'android',
        platformVersion: '14.0',
        storagePath: storagePath,
      );

      expect(AlmHdyAnalytics.instance.deviceModel, equals('Samsung Galaxy A16'));
      expect(AlmHdyAnalytics.instance.country, equals('SD'));
      expect(AlmHdyAnalytics.instance.region, equals('Khartoum'));
      expect(AlmHdyAnalytics.instance.platformVersion, equals('14.0'));

      AlmHdyAnalytics.instance.track('test_action', properties: {'test_key': 'val'});

      expect(AlmHdyAnalytics.instance.queueLength, equals(1));
      final ev = AlmHdyAnalytics.instance.queue.first;

      expect(ev.eventId, isNotNull);
      expect(ev.eventId, startsWith('ev_'));
      expect(ev.deviceModel, equals('Samsung Galaxy A16'));
      expect(ev.country, equals('SD'));
      expect(ev.region, equals('Khartoum'));
      expect(ev.platform, equals('android'));
      expect(ev.platformVersion, equals('14.0'));
      expect(ev.properties['test_key'], equals('val'));
    });

    test('setDeviceInfo dynamically updates technical metadata', () async {
      await AlmHdyAnalytics.instance.initialize(
        projectKey: 'ak_test_meta_456',
        storagePath: storagePath,
      );

      AlmHdyAnalytics.instance.setDeviceInfo(
        deviceModel: 'Pixel 8 Pro',
        country: 'SA',
        region: 'Makkah',
        platformVersion: '15.0',
      );

      expect(AlmHdyAnalytics.instance.deviceModel, equals('Pixel 8 Pro'));
      expect(AlmHdyAnalytics.instance.country, equals('SA'));
      expect(AlmHdyAnalytics.instance.region, equals('Makkah'));
      expect(AlmHdyAnalytics.instance.platformVersion, equals('15.0'));

      AlmHdyAnalytics.instance.track('updated_meta_event');
      final ev = AlmHdyAnalytics.instance.queue.last;
      expect(ev.deviceModel, equals('Pixel 8 Pro'));
      expect(ev.country, equals('SA'));
      expect(ev.region, equals('Makkah'));
      expect(ev.eventId, startsWith('ev_'));
    });
  });
}

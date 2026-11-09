import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almhdy_analytics/almhdy_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('almhdy_storage_path_test_');
    AlmHdyAnalytics.resetForTesting();
  });

  tearDown(() {
    AlmHdyAnalytics.resetForTesting();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('explicit storagePath is used directly without auto-resolution',
      () async {
    final customFile = '${tempDir.path}/custom_explicit_buffer.json';
    var autoResolverCalled = false;
    AlmHdyAnalytics.pathProviderResolver = () async {
      autoResolverCalled = true;
      return tempDir;
    };

    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      storagePath: customFile,
      platform: 'android',
    );

    expect(client.bufferFilePath, equals(customFile));
    expect(autoResolverCalled, isFalse);
    expect(File(customFile).existsSync(), isTrue);
  });

  test(
      'automatic storagePath resolution on mobile targets uses getApplicationSupportDirectory',
      () async {
    final mockSupportDir = Directory('${tempDir.path}/mock_app_support')
      ..createSync(recursive: true);
    var autoResolverCalled = false;
    AlmHdyAnalytics.pathProviderResolver = () async {
      autoResolverCalled = true;
      return mockSupportDir;
    };

    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      // storagePath omitted!
      platform: 'android',
    );

    expect(autoResolverCalled, isTrue);
    expect(client.bufferFilePath,
        equals('${mockSupportDir.path}/almhdy_analytics_buffer.json'));
    expect(
        File('${mockSupportDir.path}/almhdy_analytics_buffer.json')
            .existsSync(),
        isTrue);
  });

  test(
      'automatic storagePath resolution falls back gracefully if resolver throws',
      () async {
    AlmHdyAnalytics.pathProviderResolver = () async {
      throw MissingPluginException(
          'No implementation found for method getApplicationSupportDirectory');
    };

    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      // storagePath omitted!
      platform: 'ios',
    );

    expect(client.bufferFilePath, equals('almhdy_analytics_buffer.json'));
    // Clean up fallback file if created in test execution root
    final fallbackFile = File('almhdy_analytics_buffer.json');
    if (fallbackFile.existsSync()) {
      fallbackFile.deleteSync();
    }
  });

  test(
      'desktop target defaults to local almhdy_analytics_buffer.json when omitted',
      () async {
    var autoResolverCalled = false;
    AlmHdyAnalytics.pathProviderResolver = () async {
      autoResolverCalled = true;
      return tempDir;
    };

    final client = AlmHdyAnalytics.instance;
    await client.initialize(
      projectKey: 'ak_test_key',
      platform: 'windows',
    );

    expect(autoResolverCalled, isFalse);
    expect(client.bufferFilePath, equals('almhdy_analytics_buffer.json'));
    final fallbackFile = File('almhdy_analytics_buffer.json');
    if (fallbackFile.existsSync()) {
      fallbackFile.deleteSync();
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/core/analytics/analytics_config.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/analytics/analytics_service.dart';

class FakeAnalyticsSink implements AnalyticsSink {
  bool isInitialized = false;
  String? projectKey;
  String? appVersion;
  String? platform;
  String? platformVersion;
  String? deviceModel;
  String? country;
  String? region;
  String? storagePath;
  int? maxQueueSize;
  bool isOptedOut = false;
  bool shouldThrowOnInit = false;
  bool shouldThrowOnTrack = false;

  final List<Map<String, dynamic>> trackedEvents = [];

  @override
  Future<void> initialize({
    required String projectKey,
    String? appVersion,
    String? platform,
    String? platformVersion,
    String? deviceModel,
    String? country,
    String? region,
    String? storagePath,
    int? maxQueueSize,
    bool debug = false,
  }) async {
    if (shouldThrowOnInit) {
      throw Exception('Simulated network/disk crash during init');
    }
    isInitialized = true;
    this.projectKey = projectKey;
    this.appVersion = appVersion;
    this.platform = platform;
    this.platformVersion = platformVersion;
    this.deviceModel = deviceModel;
    this.country = country;
    this.region = region;
    this.storagePath = storagePath;
    this.maxQueueSize = maxQueueSize;
  }

  @override
  void track(String event, {Map<String, dynamic>? properties}) {
    if (shouldThrowOnTrack) {
      throw Exception('Server rejected key: HTTP 403 Forbidden / Key Revoked');
    }
    if (isOptedOut) return;
    trackedEvents.add({
      'event': event,
      'properties': properties != null
          ? Map<String, dynamic>.from(properties)
          : null,
    });
  }

  @override
  Future<void> optOut() async {
    isOptedOut = true;
    trackedEvents.clear();
  }

  @override
  Future<void> optIn() async {
    isOptedOut = false;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAnalyticsSink fakeSink;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AnalyticsService.kDiagnosticsConsentKey: true,
    });
    fakeSink = FakeAnalyticsSink();
    AnalyticsService.instance.resetForTesting();
    AnalyticsService.instance.setSinkForTesting(fakeSink);
  });

  group('AnalyticsService initialization & plumbing', () {
    test('AnalyticsConfig returns empty key in unit tests by default', () {
      AnalyticsConfig.reset();
      expect(AnalyticsConfig.projectKey, isEmpty);
    });

    test(
      'AnalyticsConfig supports key injection and empty-key override',
      () async {
        AnalyticsConfig.injectKey('ak_live_custom_injection');
        expect(AnalyticsConfig.projectKey, equals('ak_live_custom_injection'));

        AnalyticsConfig.injectKey('');
        expect(AnalyticsConfig.projectKey, isEmpty);

        // Initializing with injected empty key keeps analytics disabled
        await AnalyticsService.instance.initialize();
        expect(AnalyticsService.instance.isInitialized, isFalse);
        expect(fakeSink.isInitialized, isFalse);

        AnalyticsConfig.reset();
        expect(AnalyticsConfig.projectKey, isEmpty);
      },
    );

    test('initializes sink with default maxQueueSize of 500', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
      await AnalyticsService.instance.initialize();

      expect(AnalyticsService.instance.isInitialized, isTrue);
      expect(fakeSink.isInitialized, isTrue);
      expect(fakeSink.maxQueueSize, equals(500));
      expect(fakeSink.storagePath, isNull);
    });

    test('init disabled when project key is empty', () async {
      AnalyticsService.instance.setProjectKeyForTesting('');
      await AnalyticsService.instance.initialize();

      expect(AnalyticsService.instance.isInitialized, isFalse);
      expect(fakeSink.isInitialized, isFalse);

      // Tracking should be a complete no-op
      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
      expect(fakeSink.trackedEvents, isEmpty);
    });

    test(
      'init failure in sink is silently swallowed without throwing',
      () async {
        fakeSink.shouldThrowOnInit = true;
        AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');

        // Should complete normally without uncaught exceptions
        await expectLater(
          AnalyticsService.instance.initialize(forceEnable: true),
          completes,
        );

        expect(AnalyticsService.instance.isInitialized, isFalse);
      },
    );

    test(
      'turning consent off stops usage and error reporting immediately',
      () async {
        AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
        await AnalyticsService.instance.initialize(forceEnable: true);

        expect(AnalyticsService.instance.isUsageEnabled, isTrue);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isTrue);
        expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isTrue);

        // Turn off diagnostics consent
        await AnalyticsService.instance.setConsent(false);
        expect(AnalyticsService.instance.isUsageEnabled, isFalse);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isFalse);
        expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isFalse);
        expect(fakeSink.isOptedOut, isTrue);

        // Usage track is dropped immediately
        AnalyticsService.instance.track(AnalyticsEvent.screenViewed, {
          'screen': 'home',
        });
        expect(fakeSink.trackedEvents, isEmpty);

        // Error track is dropped immediately
        AnalyticsService.instance.recordError(
          Exception('test error'),
          StackTrace.current,
          'sync',
        );
        expect(fakeSink.trackedEvents, isEmpty);

        // Re-enable consent
        await AnalyticsService.instance.setConsent(true);
        expect(AnalyticsService.instance.isUsageEnabled, isTrue);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isTrue);
        expect(fakeSink.isOptedOut, isFalse);

        AnalyticsService.instance.track(AnalyticsEvent.screenViewed, {
          'screen': 'home',
        });
        expect(fakeSink.trackedEvents.length, equals(1));
      },
    );

    test('opt-out stops tracking immediately and notifies sink', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
      await AnalyticsService.instance.initialize(
        storagePath: 'test_buffer.json',
        forceEnable: true,
      );

      expect(AnalyticsService.instance.isInitialized, isTrue);

      // Track an event
      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
      expect(fakeSink.trackedEvents.length, equals(1));

      // User opts out
      await AnalyticsService.instance.setEnabled(false);
      expect(AnalyticsService.instance.isEnabled, isFalse);
      expect(fakeSink.isOptedOut, isTrue);

      // Tracking after opt-out is dropped
      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
      expect(fakeSink.trackedEvents, isEmpty);
    });

    test('re-enabling tracking restores event dispatch', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
      await AnalyticsService.instance.initialize(
        storagePath: 'test_buffer.json',
        forceEnable: true,
      );

      await AnalyticsService.instance.setEnabled(false);
      expect(AnalyticsService.instance.isEnabled, isFalse);

      await AnalyticsService.instance.setEnabled(true);
      expect(AnalyticsService.instance.isEnabled, isTrue);
      expect(fakeSink.isOptedOut, isFalse);

      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
      expect(fakeSink.trackedEvents.length, equals(1));
    });
  });

  group('AnalyticsService error reporting channel', () {
    setUp(() async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
      await AnalyticsService.instance.initialize(
        storagePath: 'test_buffer.json',
        forceEnable: true,
      );
    });

    test('records sanitized error event to sink', () {
      AnalyticsService.instance.recordError(
        FormatException('Invalid phone +249912345678 in payment of 100 USD'),
        StackTrace.fromString('#0 main (package:warqatek/main.dart:10:5)'),
        'payment_flow',
      );

      expect(fakeSink.trackedEvents.length, equals(1));
      final event = fakeSink.trackedEvents.first;
      expect(event['event'], equals('error_report'));
      final props = event['properties'] as Map<String, dynamic>;
      expect(props['error_type'], equals('FormatException'));
      expect(props['sanitized_message'], contains('[number redacted]'));
      expect(props['sanitized_message'], contains('[amount redacted]'));
      expect(props['context'], equals('payment_flow'));
      expect(props['platform'], isNotEmpty);
    });

    test('deduplicates identical repeated errors in same session', () {
      final err = StateError('Duplicate error');
      final stack =
          StackTrace.fromString('#0 run (package:warqatek/main.dart:12:3)');

      AnalyticsService.instance.recordError(err, stack);
      AnalyticsService.instance.recordError(err, stack);
      AnalyticsService.instance.recordError(err, stack);

      // Only first instance is dispatched
      expect(fakeSink.trackedEvents.length, equals(1));
    });

    test('caps error events at 20 per session', () {
      for (int i = 0; i < 25; i++) {
        AnalyticsService.instance.recordError(
          Exception('Unique error #$i'),
          StackTrace.fromString('#0 run$i (package:warqatek/main.dart:$i:1)'),
        );
      }

      expect(fakeSink.trackedEvents.length, equals(20));
    });

    test('drops error reports when error reporting is disabled', () async {
      await AnalyticsService.instance.setErrorReportingEnabled(false);

      AnalyticsService.instance.recordError(
        Exception('Should not report'),
      );

      expect(fakeSink.trackedEvents, isEmpty);
    });

    test('drops error reports when multi-user session is locked', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);

      AnalyticsService.instance.recordError(Exception('Locked session error'));
      expect(fakeSink.trackedEvents, isEmpty);

      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });

    test(
      'error reporting remains uninitialized and silent when project key is empty',
      () async {
        AnalyticsService.instance.resetForTesting();
        AnalyticsService.instance.setSinkForTesting(fakeSink);
        AnalyticsService.instance.setProjectKeyForTesting('');
        await AnalyticsService.instance.initialize();

        expect(AnalyticsService.instance.isInitialized, isFalse);

        AnalyticsService.instance.recordError(Exception('Empty key error'));
        expect(fakeSink.trackedEvents, isEmpty);
      },
    );

    test(
      'recordError does not crash when sink throws on server rejection',
      () {
        fakeSink.shouldThrowOnTrack = true;

        expect(
          () => AnalyticsService.instance.recordError(
            Exception('Server error test'),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('AnalyticsService allowlist enforcement', () {
    setUp(() async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
      await AnalyticsService.instance.initialize(
        storagePath: 'test_buffer.json',
        forceEnable: true,
      );
    });

    test('accepts valid allowlisted event with compliant properties', () {
      AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
        'type': 'invoice',
        'has_payment': true,
        'item_count_bucket': '2-5',
      });

      expect(fakeSink.trackedEvents.length, equals(1));
      expect(fakeSink.trackedEvents.first['event'], equals('document_created'));
      expect(
        fakeSink.trackedEvents.first['properties'],
        equals({
          'type': 'invoice',
          'has_payment': true,
          'item_count_bucket': '2-5',
        }),
      );
    });

    test(
      'rejects forbidden keys such as amount, cost, price, or name in debug',
      () {
        expect(
          () =>
              AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
                'type': 'invoice',
                'amount': 1500, // Forbidden!
              }),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => AnalyticsService.instance.track(AnalyticsEvent.productSaved, {
            'is_new': true,
            'cost': 20.0, // Forbidden!
          }),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => AnalyticsService.instance.track(AnalyticsEvent.contactSaved, {
            'kind': 'customer',
            'name': 'Ahmed', // Forbidden!
          }),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('rejects non-bucketed values or invalid enum values in debug', () {
      expect(
        () => AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
          'type': 'unknown_type', // Invalid enum
          'has_payment': true,
          'item_count_bucket': '2-5',
        }),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
          'type': 'invoice',
          'has_payment': true,
          'item_count_bucket': 12, // Must be bucket string '6-20', not raw int!
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Discretization helpers & migration queue', () {
    test('itemCountBucket discretizes accurately', () {
      expect(AnalyticsService.itemCountBucket(0), equals('1'));
      expect(AnalyticsService.itemCountBucket(1), equals('1'));
      expect(AnalyticsService.itemCountBucket(3), equals('2-5'));
      expect(AnalyticsService.itemCountBucket(5), equals('2-5'));
      expect(AnalyticsService.itemCountBucket(6), equals('6-20'));
      expect(AnalyticsService.itemCountBucket(20), equals('6-20'));
      expect(AnalyticsService.itemCountBucket(21), equals('21+'));
      expect(AnalyticsService.itemCountBucket(100), equals('21+'));
    });

    test('userCountBucket discretizes accurately', () {
      expect(AnalyticsService.userCountBucket(1), equals('1'));
      expect(AnalyticsService.userCountBucket(2), equals('2-3'));
      expect(AnalyticsService.userCountBucket(3), equals('2-3'));
      expect(AnalyticsService.userCountBucket(7), equals('4-10'));
      expect(AnalyticsService.userCountBucket(10), equals('4-10'));
      expect(AnalyticsService.userCountBucket(11), equals('11+'));
    });

    test(
      'migration result is recorded and dispatched on next initialize',
      () async {
        await AnalyticsService.recordMigrationResult(
          fromVersion: 28,
          toVersion: 29,
          ok: true,
        );

        AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
        await AnalyticsService.instance.initialize(
          storagePath: 'test_buffer.json',
          forceEnable: true,
        );

        expect(fakeSink.trackedEvents.length, equals(1));
        expect(
          fakeSink.trackedEvents.first['event'],
          equals('migration_result'),
        );
        expect(
          fakeSink.trackedEvents.first['properties'],
          equals({'from_version': 28, 'to_version': 29, 'ok': true}),
        );
      },
    );
  });

  group('Unified AlmHdy Analytics & Centralized Reports Integration', () {
    test('initialize captures and passes technical deviceModel, country, and region to sink', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_unified_key');
      await AnalyticsService.instance.initialize(
        deviceModel: 'Samsung Galaxy Tab S9',
        country: 'SA',
        region: 'Riyadh',
        storagePath: 'unified_buffer.json',
      );

      expect(fakeSink.isInitialized, isTrue);
      expect(fakeSink.deviceModel, equals('Samsung Galaxy Tab S9'));
      expect(fakeSink.country, equals('SA'));
      expect(fakeSink.region, equals('Riyadh'));
      expect(fakeSink.platform, isNotNull);
      expect(AnalyticsService.instance.deviceModel, equals('Samsung Galaxy Tab S9'));
      expect(AnalyticsService.instance.country, equals('SA'));
      expect(AnalyticsService.instance.region, equals('Riyadh'));
    });

    test('initialize does not masquerade locale country as verified device country when country is null', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_unified_key');
      await AnalyticsService.instance.initialize(
        deviceModel: 'Test Device',
        storagePath: 'unified_buffer_null_country.json',
      );

      expect(fakeSink.isInitialized, isTrue);
      expect(fakeSink.country, isNull);
      expect(AnalyticsService.instance.country, isNull);
    });

    test('recordError includes device_model in error_report properties', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_unified_key');
      await AnalyticsService.instance.initialize(
        deviceModel: 'Pixel 9 Pro',
        country: 'EG',
      );

      AnalyticsService.instance.recordError(
        FormatException('Invalid payload data'),
        StackTrace.current,
        'pdf_export',
      );

      expect(fakeSink.trackedEvents.length, equals(1));
      final errEvent = fakeSink.trackedEvents.first;
      expect(errEvent['event'], equals('error_report'));
      expect(errEvent['properties']['device_model'], equals('Pixel 9 Pro'));
      expect(errEvent['properties']['error_type'], equals('FormatException'));
    });

    test('reportOpened allowlist accepts payments report', () async {
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_unified_key');
      await AnalyticsService.instance.initialize(storagePath: 'buffer.json');

      AnalyticsService.instance.track(AnalyticsEvent.reportOpened, {
        'report': 'payments',
      });

      expect(fakeSink.trackedEvents.length, equals(1));
      expect(fakeSink.trackedEvents.first['event'], equals('report_opened'));
      expect(fakeSink.trackedEvents.first['properties'], equals({'report': 'payments'}));
    });

    test('createReportsClient builds AlmHdyReportsClient targeting centralized API', () {
      final client = AnalyticsService.instance.createReportsClient(
        baseUrl: 'https://api.almhdy24.com',
        token: 'admin_bearer_pat_999',
        projectId: 7,
      );

      expect(client.baseUrl, equals('https://api.almhdy24.com'));
      expect(client.token, equals('admin_bearer_pat_999'));
      expect(client.defaultProjectId, equals(7));
    });
  });
}

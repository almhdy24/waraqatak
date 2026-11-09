import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/analytics/analytics_service.dart';

class FakeAnalyticsSink implements AnalyticsSink {
  bool isInitialized = false;
  bool isOptedOut = false;
  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> initialize({
    required String projectKey,
    String? appVersion,
    String? storagePath,
    int? maxQueueSize,
    bool debug = false,
  }) async {
    isInitialized = true;
  }

  @override
  void track(String event, {Map<String, dynamic>? properties}) {
    if (isOptedOut) return;
    events.add({
      'event': event,
      'properties': properties != null
          ? Map<String, dynamic>.from(properties)
          : null,
    });
  }

  @override
  Future<void> optOut() async {
    isOptedOut = true;
    events.clear();
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeSink = FakeAnalyticsSink();
    AnalyticsService.instance.resetForTesting();
    AnalyticsService.instance.setSinkForTesting(fakeSink);
    AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
    await AnalyticsService.instance.initialize(
      storagePath: 'test_buffer.json',
      forceEnable: true,
    );
  });

  group('Batch 3: Event Taxonomy Instrumentation Verification', () {
    test('tracks app_opened with language, theme, and multi_user flag', () {
      AnalyticsService.instance.track(AnalyticsEvent.appOpened, {
        'language': 'ar',
        'theme': 'light',
        'multi_user': false,
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('app_opened'));
      expect(
        fakeSink.events.first['properties'],
        equals({'language': 'ar', 'theme': 'light', 'multi_user': false}),
      );
    });

    test('tracks screen_viewed for all main navigation screens', () {
      const testScreens = [
        'home',
        'invoices',
        'products',
        'customers',
        'reports',
        'settings',
      ];
      for (final screen in testScreens) {
        AnalyticsService.instance.track(AnalyticsEvent.screenViewed, {
          'screen': screen,
        });
      }

      expect(fakeSink.events.length, equals(testScreens.length));
      for (int i = 0; i < testScreens.length; i++) {
        expect(fakeSink.events[i]['event'], equals('screen_viewed'));
        expect(
          fakeSink.events[i]['properties'],
          equals({'screen': testScreens[i]}),
        );
      }
    });

    test('tracks document_created with bucketed item count', () {
      AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
        'type': 'invoice',
        'has_payment': true,
        'item_count_bucket': AnalyticsService.itemCountBucket(4),
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('document_created'));
      expect(
        fakeSink.events.first['properties'],
        equals({
          'type': 'invoice',
          'has_payment': true,
          'item_count_bucket': '2-5',
        }),
      );
    });

    test('tracks document_cancelled with canonical type', () {
      AnalyticsService.instance.track(AnalyticsEvent.documentCancelled, {
        'type': 'invoice',
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('document_cancelled'));
      expect(fakeSink.events.first['properties'], equals({'type': 'invoice'}));
    });

    test('tracks payment_recorded with method_category', () {
      AnalyticsService.instance.track(AnalyticsEvent.paymentRecorded, {
        'method_category': 'cash',
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('payment_recorded'));
      expect(
        fakeSink.events.first['properties'],
        equals({'method_category': 'cash'}),
      );
    });

    test('tracks product_saved with is_new flag', () {
      AnalyticsService.instance.track(AnalyticsEvent.productSaved, {
        'is_new': true,
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('product_saved'));
      expect(fakeSink.events.first['properties'], equals({'is_new': true}));
    });

    test(
      'tracks contact_saved with customer/supplier kind and is_new flag',
      () {
        AnalyticsService.instance.track(AnalyticsEvent.contactSaved, {
          'kind': 'customer',
          'is_new': false,
        });

        expect(fakeSink.events.length, equals(1));
        expect(fakeSink.events.first['event'], equals('contact_saved'));
        expect(
          fakeSink.events.first['properties'],
          equals({'kind': 'customer', 'is_new': false}),
        );
      },
    );

    test('tracks stocktake_finalized with empty properties', () {
      AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('stocktake_finalized'));
      expect(fakeSink.events.first['properties'], isNull);
    });

    test('tracks report_opened with allowlisted report name', () {
      AnalyticsService.instance.track(AnalyticsEvent.reportOpened, {
        'report': 'sales',
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('report_opened'));
      expect(fakeSink.events.first['properties'], equals({'report': 'sales'}));
    });

    test('tracks pdf_shared for document, report, and statement kinds', () {
      for (final kind in ['document', 'report', 'statement']) {
        AnalyticsService.instance.track(AnalyticsEvent.pdfShared, {
          'kind': kind,
        });
      }

      expect(fakeSink.events.length, equals(3));
      expect(
        fakeSink.events.map((e) => e['properties']!['kind']).toList(),
        equals(['document', 'report', 'statement']),
      );
    });

    test('tracks csv_exported and csv_imported flows', () {
      AnalyticsService.instance.track(AnalyticsEvent.csvExported, {
        'kind': 'products',
      });
      AnalyticsService.instance.track(AnalyticsEvent.csvImported, {
        'kind': 'products',
        'ok': true,
      });

      expect(fakeSink.events.length, equals(2));
      expect(fakeSink.events[0]['event'], equals('csv_exported'));
      expect(fakeSink.events[1]['event'], equals('csv_imported'));
      expect(
        fakeSink.events[1]['properties'],
        equals({'kind': 'products', 'ok': true}),
      );
    });

    test('tracks backup_created and backup_restored flows', () {
      AnalyticsService.instance.track(AnalyticsEvent.backupCreated, {
        'destination': 'drive',
        'encrypted': true,
      });
      AnalyticsService.instance.track(AnalyticsEvent.backupRestored, {
        'ok': true,
      });

      expect(fakeSink.events.length, equals(2));
      expect(fakeSink.events[0]['event'], equals('backup_created'));
      expect(fakeSink.events[1]['event'], equals('backup_restored'));
    });

    test('tracks paywall_viewed and activation flows', () {
      AnalyticsService.instance.track(AnalyticsEvent.paywallViewed, {
        'feature': 'multi_user',
      });
      AnalyticsService.instance.track(AnalyticsEvent.activationStarted);
      AnalyticsService.instance.track(AnalyticsEvent.activationResult, {
        'ok': true,
        'reason': 'success',
      });

      expect(fakeSink.events.length, equals(3));
      expect(fakeSink.events[0]['event'], equals('paywall_viewed'));
      expect(fakeSink.events[1]['event'], equals('activation_started'));
      expect(fakeSink.events[2]['event'], equals('activation_result'));
      expect(
        fakeSink.events[2]['properties'],
        equals({'ok': true, 'reason': 'success'}),
      );
    });

    test('tracks multi_user_enabled with bucketed user count', () {
      AnalyticsService.instance.track(AnalyticsEvent.multiUserEnabled, {
        'user_count_bucket': AnalyticsService.userCountBucket(1),
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('multi_user_enabled'));
      expect(
        fakeSink.events.first['properties'],
        equals({'user_count_bucket': '1'}),
      );
    });

    test('tracks error_caught with fixed area and kind', () {
      AnalyticsService.instance.track(AnalyticsEvent.errorCaught, {
        'area': 'backup',
        'kind': 'network',
      });

      expect(fakeSink.events.length, equals(1));
      expect(fakeSink.events.first['event'], equals('error_caught'));
      expect(
        fakeSink.events.first['properties'],
        equals({'area': 'backup', 'kind': 'network'}),
      );
    });

    test('drops events when multi-user session is locked', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.lock();
      expect(SessionManager.instance.isLocked, isTrue);

      AnalyticsService.instance.track(AnalyticsEvent.documentCreated, {
        'type': 'invoice',
        'has_payment': false,
        'item_count_bucket': '1',
      });

      expect(fakeSink.events, isEmpty);

      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });

    test(
      'when analytics is disabled, calls are complete no-ops without altering flow',
      () async {
        await AnalyticsService.instance.setEnabled(false);

        // Verify no exceptions and no events enqueued
        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        AnalyticsService.instance.track(AnalyticsEvent.screenViewed, {
          'screen': 'home',
        });

        expect(fakeSink.events, isEmpty);
      },
    );
  });
}

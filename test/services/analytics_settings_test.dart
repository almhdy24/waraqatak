import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/analytics/analytics_service.dart';
import 'package:warqatek/widgets/access/permission_gate.dart';

class MockAnalyticsSink implements AnalyticsSink {
  bool isInitialized = false;
  bool isOptedOut = false;
  final List<String> dispatched = [];

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
    isInitialized = true;
  }

  @override
  void track(String event, {Map<String, dynamic>? properties}) {
    if (isOptedOut) return;
    dispatched.add(event);
  }

  @override
  Future<void> optOut() async {
    isOptedOut = true;
    dispatched.clear();
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

  late MockAnalyticsSink mockSink;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSink = MockAnalyticsSink();
    AnalyticsService.instance.resetForTesting();
    AnalyticsService.instance.setSinkForTesting(mockSink);
    AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');
    await AnalyticsService.instance.initialize(
      storagePath: 'test_buffer.json',
      forceEnable: true,
    );
  });

  group('Single unified diagnosticsConsent & migration tests', () {
    test(
      'single consent flag controls both analytics and error reporting, and syncs sink opt-out',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // With forceEnable in setUp, consent is true
        expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isTrue);
        expect(AnalyticsService.instance.isUsageEnabled, isTrue);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isTrue);

        // Turn off consent
        await AnalyticsService.instance.setConsent(false);
        expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isFalse);
        expect(AnalyticsService.instance.isUsageEnabled, isFalse);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isFalse);
        expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isFalse);
        expect(mockSink.isOptedOut, isTrue);

        // Event tracking is dropped
        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, isEmpty);

        // Error recording is dropped
        AnalyticsService.instance.recordError(Exception('test_error'));
        expect(mockSink.dispatched, isEmpty);

        // Turn consent back on
        await AnalyticsService.instance.setConsent(true);
        expect(AnalyticsService.instance.isDiagnosticsConsentGranted, isTrue);
        expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isTrue);
        expect(mockSink.isOptedOut, isFalse);

        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, equals(['stocktake_finalized']));
      },
    );

    test('migration combo 1: both old flags true -> diagnosticsConsent is true, old keys removed', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_enabled': true,
        'error_reporting_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await AnalyticsService.migrateConsentIfNeeded(prefs);

      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isTrue);
      expect(prefs.containsKey('analytics_enabled'), isFalse);
      expect(prefs.containsKey('error_reporting_enabled'), isFalse);
    });

    test('migration combo 2: analytics true, error false -> diagnosticsConsent is false, old keys removed', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_enabled': true,
        'error_reporting_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      await AnalyticsService.migrateConsentIfNeeded(prefs);

      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isFalse);
      expect(prefs.containsKey('analytics_enabled'), isFalse);
      expect(prefs.containsKey('error_reporting_enabled'), isFalse);
    });

    test('migration combo 3: analytics false, error true -> diagnosticsConsent is false, old keys removed', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_enabled': false,
        'error_reporting_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await AnalyticsService.migrateConsentIfNeeded(prefs);

      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isFalse);
      expect(prefs.containsKey('analytics_enabled'), isFalse);
      expect(prefs.containsKey('error_reporting_enabled'), isFalse);
    });

    test('migration combo 4: both old flags false -> diagnosticsConsent is false, old keys removed', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_enabled': false,
        'error_reporting_enabled': false,
        'ops_diagnostic_consent_granted': false,
      });
      final prefs = await SharedPreferences.getInstance();
      await AnalyticsService.migrateConsentIfNeeded(prefs);

      expect(prefs.getBool(AnalyticsService.kDiagnosticsConsentKey), isFalse);
      expect(prefs.containsKey('analytics_enabled'), isFalse);
      expect(prefs.containsKey('error_reporting_enabled'), isFalse);
      expect(prefs.containsKey('ops_diagnostic_consent_granted'), isFalse);
    });

    testWidgets('PermissionGate renders settings toggle when authorized', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionGate(
              permission: PermissionRegistry.settingsManage,
              child: const Text('ANALYTICS_SETTINGS_TOGGLE'),
            ),
          ),
        ),
      );

      expect(find.text('ANALYTICS_SETTINGS_TOGGLE'), findsOneWidget);
    });

    testWidgets('PermissionGate hides settings toggle for locked-down roles', (
      tester,
    ) async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      final restrictedUser = AppUser(
        id: 'user-sales',
        workspaceId: 'default-workspace',
        username: 'sales',
        displayName: 'Salesperson',
        roleId: 'role-salesperson',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      SessionManager.instance.unlock(restrictedUser, {
        PermissionRegistry.salesCreate,
        PermissionRegistry.salesView,
      });

      expect(AccessGuard.can(PermissionRegistry.settingsManage), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionGate(
              permission: PermissionRegistry.settingsManage,
              child: const Text('ANALYTICS_SETTINGS_TOGGLE'),
            ),
          ),
        ),
      );

      expect(find.text('ANALYTICS_SETTINGS_TOGGLE'), findsNothing);

      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });
  });
}

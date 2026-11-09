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

  group('Settings dual toggles, consent persistence & role gating', () {
    test(
      'separate toggles persist choices and sync opt-out when both disabled',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Defaults are both enabled
        expect(AnalyticsService.instance.isUsageEnabled, isTrue);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isTrue);

        // Turn off usage only
        await AnalyticsService.instance.setUsageEnabled(false);
        expect(AnalyticsService.instance.isUsageEnabled, isFalse);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isTrue);
        expect(prefs.getBool('analytics_enabled'), isFalse);
        // Error reporting is still on, so sink is NOT opted out
        expect(mockSink.isOptedOut, isFalse);

        // Usage tracking attempts are silently dropped
        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, isEmpty);

        // Turn off error reports as well
        await AnalyticsService.instance.setErrorReportingEnabled(false);
        expect(AnalyticsService.instance.isErrorReportingEnabled, isFalse);
        expect(prefs.getBool('error_reporting_enabled'), isFalse);
        // Now both are off, sink is opted out
        expect(mockSink.isOptedOut, isTrue);

        // Turn usage back on
        await AnalyticsService.instance.setUsageEnabled(true);
        expect(AnalyticsService.instance.isUsageEnabled, isTrue);
        expect(prefs.getBool('analytics_enabled'), isTrue);
        expect(mockSink.isOptedOut, isFalse);

        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, equals(['stocktake_finalized']));
      },
    );

    test('migrates legacy opt-out so existing opted-out user keeps both off', () async {
      SharedPreferences.setMockInitialValues({
        'analytics_enabled': false,
      });
      AnalyticsService.instance.resetForTesting();
      AnalyticsService.instance.setSinkForTesting(mockSink);
      AnalyticsService.instance.setProjectKeyForTesting('ak_live_test_key');

      await AnalyticsService.instance.initialize(forceEnable: true);

      final prefs = await SharedPreferences.getInstance();
      expect(AnalyticsService.instance.isUsageEnabled, isFalse);
      expect(AnalyticsService.instance.isErrorReportingEnabled, isFalse);
      expect(prefs.getBool('error_reporting_enabled'), isFalse);
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

      // In single-user mode (default), all permissions return true
      expect(find.text('ANALYTICS_SETTINGS_TOGGLE'), findsOneWidget);
    });

    testWidgets('PermissionGate hides settings toggle for locked-down roles', (
      tester,
    ) async {
      // Enable multi-user mode and unlock with a restricted role (e.g. Salesperson lacking settings.manage)
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

      // Grant permissions that do NOT include settings.manage
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

      // The toggle must be hidden (not in widget tree)
      expect(find.text('ANALYTICS_SETTINGS_TOGGLE'), findsNothing);

      // Clean up
      SessionManager.instance.setMultiUserEnabledForTesting(false);
    });
  });
}

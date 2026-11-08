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

  group('Batch 4: Settings toggle, consent persistence & role gating', () {
    test(
      'toggle persists choice to SharedPreferences and syncs opt-out',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Default is enabled
        expect(AnalyticsService.instance.isEnabled, isTrue);

        // User opts out in settings
        await AnalyticsService.instance.setEnabled(false);
        expect(AnalyticsService.instance.isEnabled, isFalse);
        expect(prefs.getBool('analytics_enabled'), isFalse);
        expect(mockSink.isOptedOut, isTrue);

        // Subsequent tracking attempts are silently dropped
        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, isEmpty);

        // User opts back in
        await AnalyticsService.instance.setEnabled(true);
        expect(AnalyticsService.instance.isEnabled, isTrue);
        expect(prefs.getBool('analytics_enabled'), isTrue);
        expect(mockSink.isOptedOut, isFalse);

        AnalyticsService.instance.track(AnalyticsEvent.stocktakeFinalized);
        expect(mockSink.dispatched, equals(['stocktake_finalized']));
      },
    );

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

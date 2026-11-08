import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/services/app_update_service.dart';

AppUpdateInfo createAppUpdateInfo({
  UpdateAvailability updateAvailability = UpdateAvailability.updateNotAvailable,
  bool immediateUpdateAllowed = false,
  bool flexibleUpdateAllowed = false,
  int? availableVersionCode = 10,
  InstallStatus installStatus = InstallStatus.unknown,
  int? clientVersionStalenessDays = 0,
  int updatePriority = 0,
}) {
  return AppUpdateInfo(
    updateAvailability: updateAvailability,
    immediateUpdateAllowed: immediateUpdateAllowed,
    immediateAllowedPreconditions: const [],
    flexibleUpdateAllowed: flexibleUpdateAllowed,
    flexibleAllowedPreconditions: const [],
    availableVersionCode: availableVersionCode,
    installStatus: installStatus,
    packageName: 'com.elmahdi.waraqatak',
    clientVersionStalenessDays: clientVersionStalenessDays,
    updatePriority: updatePriority,
  );
}

class FakePlayUpdatePlatform implements PlayUpdatePlatform {
  AppUpdateInfo? infoToReturn;
  AppUpdateResult startFlexibleResult = AppUpdateResult.success;
  AppUpdateResult performImmediateResult = AppUpdateResult.success;
  bool shouldThrowOnCheck = false;
  String checkErrorMessage =
      'Play Core service unavailable (offline or sideloaded)';
  bool completeFlexibleCalled = false;
  int checkCount = 0;
  int startFlexibleCount = 0;
  int performImmediateCount = 0;

  final StreamController<InstallStatus> installStatusController =
      StreamController<InstallStatus>.broadcast();

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    checkCount++;
    if (shouldThrowOnCheck) {
      throw Exception(checkErrorMessage);
    }
    return infoToReturn ?? createAppUpdateInfo();
  }

  @override
  Future<AppUpdateResult> startFlexibleUpdate() async {
    startFlexibleCount++;
    return startFlexibleResult;
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    completeFlexibleCalled = true;
  }

  @override
  Future<AppUpdateResult> performImmediateUpdate() async {
    performImmediateCount++;
    return performImmediateResult;
  }

  @override
  Stream<InstallStatus> get installUpdateListener =>
      installStatusController.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlayUpdatePlatform fakePlatform;
  late AppUpdateService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakePlatform = FakePlayUpdatePlatform();
    service = AppUpdateService(platform: fakePlatform);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    service.dispose();
  });

  group('AppUpdateService - Core Requirements & Safety Guarantees', () {
    test(
      '1. Non-Android platform returns unsupportedPlatform gracefully',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.unsupportedPlatform);
        expect(fakePlatform.checkCount, 0);
      },
    );

    test(
      '2. Throttling prevents repeated automatic checks within 24 hours for update-availability flow',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // First check executes
        final firstResult = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(firstResult, AppUpdateCheckResult.noUpdateAvailable);
        expect(fakePlatform.checkCount, 1);

        // Immediate second automatic check should query platform for resume/download state,
        // but throttle the update-availability flow.
        final secondResult = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(secondResult, AppUpdateCheckResult.throttled);
        expect(fakePlatform.checkCount, 2);

        // Manual check should bypass 24h throttling
        final manualResult = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(manualResult, AppUpdateCheckResult.noUpdateAvailable);
        expect(fakePlatform.checkCount, 3);
      },
    );

    test(
      '3. Detects already downloaded update from previous session',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability:
              UpdateAvailability.developerTriggeredUpdateInProgress,
          availableVersionCode: 15,
          installStatus: InstallStatus.downloaded,
          clientVersionStalenessDays: 2,
          updatePriority: 1,
        );

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.updateAlreadyDownloaded);
        expect(service.isDownloaded, isTrue);
      },
    );

    test('4. Starts flexible update for standard releases', () async {
      fakePlatform.infoToReturn = createAppUpdateInfo(
        updateAvailability: UpdateAvailability.updateAvailable,
        immediateUpdateAllowed: true,
        flexibleUpdateAllowed: true,
        availableVersionCode: 20,
        clientVersionStalenessDays: 3,
        updatePriority: 2,
      );

      final result = await service.checkForUpdate(manual: true);

      expect(result, AppUpdateCheckResult.flexibleUpdateStarted);
      expect(fakePlatform.startFlexibleCount, 1);
      expect(fakePlatform.performImmediateCount, 0);
    });

    test('5. Handles user cancellation in flexible update', () async {
      fakePlatform.infoToReturn = createAppUpdateInfo(
        updateAvailability: UpdateAvailability.updateAvailable,
        immediateUpdateAllowed: true,
        flexibleUpdateAllowed: true,
        availableVersionCode: 20,
        clientVersionStalenessDays: 3,
        updatePriority: 2,
      );
      fakePlatform.startFlexibleResult = AppUpdateResult.userDeniedUpdate;

      final result = await service.checkForUpdate(manual: true);

      expect(result, AppUpdateCheckResult.userDenied);
    });

    test(
      '6. Triggers immediate update only when staleness reaches critical threshold',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          immediateUpdateAllowed: true,
          flexibleUpdateAllowed: true,
          availableVersionCode: 25,
          clientVersionStalenessDays: 20, // >= 14 days critical threshold
          updatePriority: 2,
        );

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.immediateUpdateStarted);
        expect(fakePlatform.performImmediateCount, 1);
        expect(fakePlatform.startFlexibleCount, 0);
      },
    );

    test(
      '7. Handles network failures or sideloaded APK errors gracefully without crashing',
      () async {
        fakePlatform.shouldThrowOnCheck = true;

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.failed);
        expect(service.isChecking, isFalse);
      },
    );

    test('8. Completes flexible update successfully', () async {
      await service.completeFlexibleUpdate();

      expect(fakePlatform.completeFlexibleCalled, isTrue);
    });

    test(
      '9. installUpdateListener stream updates isDownloaded state',
      () async {
        expect(service.isDownloaded, isFalse);

        fakePlatform.installStatusController.add(InstallStatus.downloading);
        await pumpEventQueue();
        expect(service.isDownloaded, isFalse);

        fakePlatform.installStatusController.add(InstallStatus.downloaded);
        await pumpEventQueue();
        expect(service.isDownloaded, isTrue);
      },
    );

    test(
      '10. Resumes immediate update when updateAvailability == developerTriggeredUpdateInProgress',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability:
              UpdateAvailability.developerTriggeredUpdateInProgress,
          immediateUpdateAllowed: true,
          availableVersionCode: 30,
        );

        final result = await service.checkForUpdate(manual: false);

        expect(result, AppUpdateCheckResult.immediateUpdateStarted);
        expect(fakePlatform.performImmediateCount, 1);
      },
    );

    test(
      '11. Checks installStatus == downloaded on EVERY resume, before and independent of 24h throttle',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // 1st check: sets 24h throttle
        await service.checkForUpdate(manual: false, prefs: prefs);

        // Set platform to return downloaded status
        fakePlatform.infoToReturn = createAppUpdateInfo(
          installStatus: InstallStatus.downloaded,
          availableVersionCode: 35,
        );

        // 2nd check within throttle interval: should detect downloaded update without being blocked by 24h throttle
        final result = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(result, AppUpdateCheckResult.updateAlreadyDownloaded);
        expect(service.isDownloaded, isTrue);
      },
    );

    test(
      '12. Returns alreadyChecking if checkForUpdate is invoked while already running',
      () async {
        final completer = Completer<AppUpdateInfo>();
        fakePlatform.infoToReturn = null;

        // Custom platform to delay completion
        final delayedPlatform = _DelayedPlayUpdatePlatform(completer.future);
        service.setPlatformForTesting(delayedPlatform);

        final future1 = service.checkForUpdate(manual: true);
        final future2 = service.checkForUpdate(manual: true);

        expect(await future2, AppUpdateCheckResult.alreadyChecking);

        completer.complete(createAppUpdateInfo());
        expect(await future1, AppUpdateCheckResult.noUpdateAvailable);
      },
    );

    test(
      '13. Returns updateNotAllowed when update exists but neither immediate nor flexible is allowed',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          immediateUpdateAllowed: false,
          flexibleUpdateAllowed: false,
          availableVersionCode: 40,
        );

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.updateNotAllowed);
      },
    );

    test(
      '14. Handles inAppUpdateFailed as failed for flexible update',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          availableVersionCode: 42,
        );
        fakePlatform.startFlexibleResult = AppUpdateResult.inAppUpdateFailed;

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.failed);
      },
    );

    test(
      '15. Handles inAppUpdateFailed as failed for immediate update',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          immediateUpdateAllowed: true,
          updatePriority: 5, // Triggers immediate
          availableVersionCode: 45,
        );
        fakePlatform.performImmediateResult = AppUpdateResult.inAppUpdateFailed;

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.failed);
      },
    );

    test(
      '16. Triggers immediate update if updatePriority >= 4 regardless of staleness',
      () async {
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          immediateUpdateAllowed: true,
          flexibleUpdateAllowed: true,
          availableVersionCode: 50,
          clientVersionStalenessDays: 1, // < 14
          updatePriority: 4, // >= 4
        );

        final result = await service.checkForUpdate(manual: true);

        expect(result, AppUpdateCheckResult.immediateUpdateStarted);
        expect(fakePlatform.performImmediateCount, 1);
        expect(fakePlatform.startFlexibleCount, 0);
      },
    );

    test(
      '17. Persists declined availableVersionCode and timestamps on denial, throttling for 3 days',
      () async {
        final prefs = await SharedPreferences.getInstance();
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          availableVersionCode: 60,
          updatePriority: 2,
        );
        fakePlatform.startFlexibleResult = AppUpdateResult.userDeniedUpdate;

        // User denies update
        final result1 = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(result1, AppUpdateCheckResult.userDenied);

        // Clear 24h throttle so only 3-day decline cooldown is active
        await prefs.remove('app_update_last_check_ms');

        // Subsequent automatic check for the same version should be throttled
        final result2 = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(result2, AppUpdateCheckResult.throttled);

        // Manual check should bypass 3-day cooldown
        final result3 = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(result3, AppUpdateCheckResult.userDenied);
      },
    );

    test(
      '18. Bypasses 3-day decline cooldown if updatePriority >= 4',
      () async {
        final prefs = await SharedPreferences.getInstance();
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          immediateUpdateAllowed: true,
          availableVersionCode: 65,
          updatePriority: 2,
        );
        fakePlatform.startFlexibleResult = AppUpdateResult.userDeniedUpdate;

        // User denies version 65
        await service.checkForUpdate(manual: true, prefs: prefs);

        // Now an urgent patch is released for version 65 with priority 4
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          immediateUpdateAllowed: true,
          availableVersionCode: 65,
          updatePriority: 4,
        );
        await prefs.remove('app_update_last_check_ms');

        final result = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(result, AppUpdateCheckResult.immediateUpdateStarted);
      },
    );

    test(
      '19. Bypasses 3-day decline cooldown if new version code is available',
      () async {
        final prefs = await SharedPreferences.getInstance();
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          availableVersionCode: 70,
          updatePriority: 2,
        );
        fakePlatform.startFlexibleResult = AppUpdateResult.userDeniedUpdate;

        // User denies version 70
        await service.checkForUpdate(manual: true, prefs: prefs);

        // Version 71 becomes available
        fakePlatform.infoToReturn = createAppUpdateInfo(
          updateAvailability: UpdateAvailability.updateAvailable,
          flexibleUpdateAllowed: true,
          availableVersionCode: 71,
          updatePriority: 2,
        );
        fakePlatform.startFlexibleResult = AppUpdateResult.success;
        await prefs.remove('app_update_last_check_ms');

        final result = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(result, AppUpdateCheckResult.flexibleUpdateStarted);
      },
    );

    test(
      '20. 1h backoff after a failed check throttles automatic checks',
      () async {
        final prefs = await SharedPreferences.getInstance();
        fakePlatform.shouldThrowOnCheck = true;

        // Failed check occurs
        final result1 = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(result1, AppUpdateCheckResult.failed);
        expect(prefs.getInt('app_update_last_failure_ms'), isNotNull);

        fakePlatform.shouldThrowOnCheck = false;

        // Automatic check within 1 hour should be throttled by failure backoff
        final result2 = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(result2, AppUpdateCheckResult.throttled);

        // Manual check ignores backoff
        final result3 = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(result3, AppUpdateCheckResult.noUpdateAvailable);

        // Successful check clears failure timestamp
        expect(prefs.getInt('app_update_last_failure_ms'), isNull);
      },
    );

    test(
      '21. completeFlexibleUpdate resets isDownloaded state on success',
      () async {
        fakePlatform.installStatusController.add(InstallStatus.downloaded);
        await pumpEventQueue();
        expect(service.isDownloaded, isTrue);

        await service.completeFlexibleUpdate();
        expect(service.isDownloaded, isFalse);
        expect(fakePlatform.completeFlexibleCalled, isTrue);
      },
    );

    testWidgets(
      '22. Manual check on non-Play install shows localized message in Arabic and English',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          Widget buildHost(
            Locale locale,
            Widget Function(BuildContext) builder,
          ) {
            return LanguageProvider(
              langCode: locale.languageCode,
              onChangeLanguage: (_) async {},
              child: MaterialApp(
                scaffoldMessengerKey: AppUpdateService.scaffoldMessengerKey,
                locale: locale,
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(body: Builder(builder: builder)),
              ),
            );
          }

          // Test English non-Play install error
          fakePlatform.shouldThrowOnCheck = true;
          fakePlatform.checkErrorMessage = 'Install Error(-10): app_not_owned';

          await tester.pumpWidget(
            buildHost(const Locale('en'), (context) {
              return ElevatedButton(
                onPressed: () =>
                    service.checkForUpdate(context: context, manual: true),
                child: const Text('Check'),
              );
            }),
          );
          await tester.tap(find.text('Check'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'In-app updates are only available for apps installed from Google Play',
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 4));

          // Test Arabic non-Play install error
          await tester.pumpWidget(
            buildHost(const Locale('ar'), (context) {
              return ElevatedButton(
                onPressed: () =>
                    service.checkForUpdate(context: context, manual: true),
                child: const Text('Check'),
              );
            }),
          );
          await tester.tap(find.text('Check'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'التحديثات التلقائية متوفرة فقط للتطبيقات المثبتة عبر متجر Google Play',
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 4));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      '23. Manual check when update exists but is not allowed shows updateNotAllowed and not appUpToDate',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          fakePlatform.shouldThrowOnCheck = false;
          fakePlatform.infoToReturn = createAppUpdateInfo(
            updateAvailability: UpdateAvailability.updateAvailable,
            immediateUpdateAllowed: false,
            flexibleUpdateAllowed: false,
          );

          await tester.pumpWidget(
            LanguageProvider(
              langCode: 'ar',
              onChangeLanguage: (_) async {},
              child: MaterialApp(
                scaffoldMessengerKey: AppUpdateService.scaffoldMessengerKey,
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => service.checkForUpdate(
                        context: context,
                        manual: true,
                      ),
                      child: const Text('Check'),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Check'));
          await tester.pumpAndSettle();

          // Should show updateNotAllowed
          expect(
            find.text('يتوفر تحديث ولكن لا يمكن تثبيته حالياً من داخل التطبيق'),
            findsOneWidget,
          );
          // Must NOT show appUpToDate
          expect(find.text('أنت تستخدم أحدث إصدار من التطبيق'), findsNothing);
          await tester.pump(const Duration(seconds: 4));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}

class _DelayedPlayUpdatePlatform implements PlayUpdatePlatform {
  final Future<AppUpdateInfo> future;
  _DelayedPlayUpdatePlatform(this.future);

  @override
  Future<AppUpdateInfo> checkForUpdate() => future;

  @override
  Future<AppUpdateResult> performImmediateUpdate() async =>
      AppUpdateResult.success;

  @override
  Future<AppUpdateResult> startFlexibleUpdate() async =>
      AppUpdateResult.success;

  @override
  Future<void> completeFlexibleUpdate() async {}

  @override
  Stream<InstallStatus> get installUpdateListener => const Stream.empty();
}

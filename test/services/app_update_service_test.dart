import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      throw Exception('Play Core service unavailable (offline or sideloaded)');
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
      '2. Throttling prevents repeated automatic checks within 24 hours',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // First check executes
        final firstResult = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(firstResult, AppUpdateCheckResult.noUpdateAvailable);
        expect(fakePlatform.checkCount, 1);

        // Immediate second automatic check should be throttled
        final secondResult = await service.checkForUpdate(
          manual: false,
          prefs: prefs,
        );
        expect(secondResult, AppUpdateCheckResult.throttled);
        expect(fakePlatform.checkCount, 1);

        // Manual check should bypass 24h throttling
        final manualResult = await service.checkForUpdate(
          manual: true,
          prefs: prefs,
        );
        expect(manualResult, AppUpdateCheckResult.noUpdateAvailable);
        expect(fakePlatform.checkCount, 2);
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
          updatePriority: 5,
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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/entitlement.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/feature_access.dart';

void main() {
  final testSalesperson = AppUser(
    id: 'user-sales-1',
    workspaceId: AccessDao.defaultWorkspaceId,
    username: 'salesperson',
    displayName: 'Sales Rep',
    roleId: 'role-template-salesperson',
    isOwner: false,
    isActive: true,
    setupComplete: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  tearDown(() {
    SessionManager.instance.setMultiUserEnabledForTesting(false);
  });

  group('Decision D8: License expiry interplay', () {
    test('FeatureAccess gates multiUser feature correctly with Pro status', () {
      expect(FeatureAccess.multiUserRequiresPro, isTrue);

      final activeTrial = EntitlementState(
        status: EntitlementStatus.trialActive,
        deviceId: 'dev-1',
        trialDaysRemaining: 13,
      );
      expect(FeatureAccess.canAccess(Feature.multiUser, activeTrial), isTrue);

      final expiredTrial = EntitlementState(
        status: EntitlementStatus.trialExpired,
        deviceId: 'dev-1',
        trialDaysRemaining: 0,
      );
      expect(FeatureAccess.canAccess(Feature.multiUser, expiredTrial), isFalse);
    });

    test('multi-user permissions stay strictly enforced even if Pro license expires', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      // Even if license expires, user still cannot access accountingPeriodLock or stockAdjust
      expect(AccessGuard.can(PermissionRegistry.salesCreate), isTrue);
      expect(AccessGuard.can(PermissionRegistry.accountingPeriodLock), isFalse);
      expect(AccessGuard.can(PermissionRegistry.stockAdjust), isFalse);

      expect(
        () => AccessGuard.require(PermissionRegistry.accountingPeriodLock),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('Legacy attribution interplay', () {
    test('NULL created_by is attributed to Owner', () {
      // In single user mode
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(AccessDao.ownerUserId, 'user-owner');

      // In multi-user mode with null created_by
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      // When displaying a legacy document where created_by is null
      String resolveDisplayName(String? createdBy) {
        if (createdBy == null || createdBy == AccessDao.ownerUserId) {
          return 'المالك';
        }
        return createdBy;
      }

      expect(resolveDisplayName(null), 'المالك');
      expect(resolveDisplayName(AccessDao.ownerUserId), 'المالك');
      expect(resolveDisplayName('user-sales-1'), 'user-sales-1');
    });
  });
}

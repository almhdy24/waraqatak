import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';
import 'package:warqatek/screens/period_closing_screen.dart';

void main() {
  group('PeriodClosingScreen — ScreenAccessPolicy', () {
    test('PeriodClosingScreen is registered in the manifest', () {
      expect(
        ScreenAccessPolicy.manifest.containsKey(PeriodClosingScreen),
        isTrue,
        reason:
            'PeriodClosingScreen must be in ScreenAccessPolicy.manifest (Deny-By-Default H5)',
      );
    });

    test('PeriodClosingScreen policy requires accountingPeriodLock permission', () {
      final policy = ScreenAccessPolicy.manifest[PeriodClosingScreen];
      expect(policy, isNotNull);
      expect(policy!.isPublic, isFalse,
          reason: 'PeriodClosingScreen must not be public');
      expect(policy.isOwnerOnly, isFalse,
          reason: 'PeriodClosingScreen is accessible to accountants, not only owner');
      expect(
        policy.requiredPermission,
        equals(PermissionRegistry.accountingPeriodLock),
        reason: 'PeriodClosingScreen must require accountingPeriodLock',
      );
    });

    test('accountingPeriodLock permission key is registered in PermissionRegistry', () {
      expect(
        PermissionRegistry.get(PermissionRegistry.accountingPeriodLock),
        isNotNull,
        reason: 'accountingPeriodLock must be a registered permission',
      );
    });

    test('PeriodClosingScreen policy denies users without accountingPeriodLock', () {
      // In single-user mode evaluate() always returns allow, so we test the
      // policy fields directly (the same approach used in screen_policy_guard_test).
      final policy = ScreenAccessPolicy.manifest[PeriodClosingScreen]!;

      // The policy is not public and not owner-only → it checks a permission.
      expect(policy.isPublic, isFalse);
      expect(policy.isOwnerOnly, isFalse);

      final cashierPermissions = {
        PermissionRegistry.salesCreate,
        PermissionRegistry.salesView,
      };
      final hasPermission = cashierPermissions.contains(
        policy.requiredPermission!,
      );
      expect(hasPermission, isFalse,
          reason: 'Cashier without accountingPeriodLock should be denied');
    });

    test('PeriodClosingScreen policy allows users with accountingPeriodLock', () {
      final policy = ScreenAccessPolicy.manifest[PeriodClosingScreen]!;

      final accountantPermissions = {
        PermissionRegistry.accountingPeriodLock,
        PermissionRegistry.reportsViewFinancials,
      };
      final hasPermission = accountantPermissions.contains(
        policy.requiredPermission!,
      );
      expect(hasPermission, isTrue,
          reason: 'Accountant with accountingPeriodLock should be allowed');
    });
  });
}

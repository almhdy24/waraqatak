import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/permission_service.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  group('PermissionRegistry', () {
    test('contains expected core permissions and unique keys', () {
      final all = PermissionRegistry.all;
      expect(all.length, greaterThanOrEqualTo(35));

      final keys = <String>{};
      for (final item in all) {
        expect(keys.contains(item.key), isFalse,
            reason: 'Duplicate key: ${item.key}');
        keys.add(item.key);
        expect(item.nameAr.isNotEmpty, isTrue);
        expect(item.nameEn.isNotEmpty, isTrue);
        expect(item.descriptionAr.isNotEmpty, isTrue);
        expect(item.descriptionEn.isNotEmpty, isTrue);
      }
      expect(PermissionRegistry.allKeys.length, all.length);
    });

    test('get returns item or null', () {
      expect(PermissionRegistry.get(PermissionRegistry.salesCreate), isNotNull);
      expect(PermissionRegistry.get('non_existent_key'), isNull);
    });
  });

  group('AccessSeeder templates', () {
    test('salesperson template has sales and payment permissions', () {
      final perms = AccessSeeder.getPermissionsForTemplate(
        AccessSeeder.roleTemplateSalesperson,
      );
      expect(perms.contains(PermissionRegistry.salesCreate), isTrue);
      expect(perms.contains(PermissionRegistry.salesEdit), isTrue);
      expect(perms.contains(PermissionRegistry.paymentsRecord), isTrue);
      expect(perms.contains(PermissionRegistry.backupRestore), isFalse);
      expect(perms.contains(PermissionRegistry.systemRepair), isFalse);
    });

    test('inventory template has stock and products permissions', () {
      final perms = AccessSeeder.getPermissionsForTemplate(
        AccessSeeder.roleTemplateInventory,
      );
      expect(perms.contains(PermissionRegistry.stockAdjust), isTrue);
      expect(perms.contains(PermissionRegistry.productsManage), isTrue);
      expect(perms.contains(PermissionRegistry.stocktakeManage), isTrue);
      expect(perms.contains(PermissionRegistry.backupRestore), isFalse);
    });

    test('accountant template has financial, sales, and lock permissions', () {
      final perms = AccessSeeder.getPermissionsForTemplate(
        AccessSeeder.roleTemplateAccountant,
      );
      expect(perms.contains(PermissionRegistry.reportsViewFinancials), isTrue);
      expect(perms.contains(PermissionRegistry.vouchersCreate), isTrue);
      expect(perms.contains(PermissionRegistry.accountingPeriodLock), isTrue);
      expect(perms.contains(PermissionRegistry.systemRepair), isFalse);
    });

    test('manager template excludes sensitive system actions', () {
      final perms = AccessSeeder.getPermissionsForTemplate(
        AccessSeeder.roleTemplateManager,
      );
      expect(perms.contains(PermissionRegistry.salesCreate), isTrue);
      expect(perms.contains(PermissionRegistry.stockAdjust), isTrue);
      expect(perms.contains(PermissionRegistry.reportsViewSales), isTrue);
      expect(perms.contains(PermissionRegistry.backupRestore), isFalse);
      expect(perms.contains(PermissionRegistry.systemRepair), isFalse);
      expect(perms.contains(PermissionRegistry.usersManage), isFalse);
      expect(perms.contains(PermissionRegistry.rolesManage), isFalse);
      expect(perms.contains(PermissionRegistry.licenseManage), isFalse);
    });
  });

  group('AccessGuard & System Context', () {
    test('in single-user mode (disabled), can is always true and require does not throw', () {
      // SessionManager default state is disabled
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(AccessGuard.can('any_permission_key'), isTrue);
      expect(() => AccessGuard.require('any_permission_key'), returnsNormally);
    });

    test('runAsSystem sets system context and bypasses checks', () {
      expect(AccessGuard.isSystemContext, isFalse);

      final result = AccessGuard.runAsSystem(() {
        expect(AccessGuard.isSystemContext, isTrue);
        expect(AccessGuard.can('arbitrary_secret_permission'), isTrue);
        AccessGuard.require('arbitrary_secret_permission');
        return 'executed_as_system';
      });

      expect(result, 'executed_as_system');
      expect(AccessGuard.isSystemContext, isFalse);
    });

    test('PermissionDeniedException formatting', () {
      const ex1 = PermissionDeniedException('test.key');
      expect(ex1.toString(), contains('test.key'));

      const ex2 = PermissionDeniedException('test.key', 'Action disallowed');
      expect(ex2.toString(), contains('Action disallowed'));
    });
  });

  group('PermissionService effective permissions logic', () {
    test('Owner gets all registry keys unconditionally', () async {
      final owner = AppUser(
        id: 'user-owner',
        workspaceId: 'ws-1',
        username: 'owner',
        displayName: 'Owner',
        roleId: 'role-owner',
        isOwner: true,
        isActive: true,
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final perms = await PermissionService.instance.getEffectivePermissions(owner);
      expect(perms, PermissionRegistry.allKeys);
    });

    test('Deactivated user gets empty set unconditionally', () async {
      final deactivated = AppUser(
        id: 'user-deactivated',
        workspaceId: 'ws-1',
        username: 'inactive',
        displayName: 'Inactive User',
        roleId: 'role-template-salesperson',
        isOwner: false,
        isActive: false,
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final perms = await PermissionService.instance.getEffectivePermissions(deactivated);
      expect(perms, isEmpty);
    });
  });
}

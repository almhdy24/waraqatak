import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/access/access_context.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/document_service.dart';

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

  group('AccessContext attribution tests', () {
    test('in single-user mode, currentUserId defaults to Owner', () {
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(AccessContext.currentUserId, AccessDao.ownerUserId);
      expect(AccessContext.currentUserName, 'owner');
    });

    test('under runAsSystem, currentUserId returns system', () {
      AccessGuard.runAsSystem(() {
        expect(AccessContext.currentUserId, 'system');
        expect(AccessContext.currentUserName, 'system');
      });
    });

    test('when user logged in, currentUserId returns that user', () {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      expect(AccessContext.currentUserId, 'user-sales-1');
      expect(AccessContext.currentUserName, 'Sales Rep');
    });
  });

  group('Write-path permission enforcement', () {
    final business = Business(
      id: 1,
      name: 'Test Store',
      ownerName: 'Store Owner',
      phone: '0123456789',
      address: 'Khartoum',
      currencyCode: 'SDG',
      taxRate: 0.15,
    );

    test('in single-user mode, document creation does not throw', () {
      expect(SessionManager.instance.isMultiUserEnabled, isFalse);
      expect(AccessGuard.can(PermissionRegistry.salesCreate), isTrue);
      expect(AccessGuard.can(PermissionRegistry.purchasesCreate), isTrue);
    });

    test('manual price override with sales.edit_price check', () {
      final product = Product(
        id: 1,
        name: 'Item 1',
        salePrice: 100,
        purchasePrice: 60,
      );

      // 1. Single-user mode: succeeds
      final res1 = DocumentService.resolveLinePrice(
        product: product,
        quantity: 1,
        currentPrice: 120,
        targetCategory: 'retail',
        isManualPrice: true,
      );
      expect(res1, 120);

      // 2. Multi-user enabled, user WITHOUT sales.edit_price: throws
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      expect(
        () => DocumentService.resolveLinePrice(
          product: product,
          quantity: 1,
          currentPrice: 120,
          targetCategory: 'retail',
          isManualPrice: true,
        ),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.salesEditPrice,
        )),
      );

      // 3. User WITH sales.edit_price: succeeds
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
        PermissionRegistry.salesEditPrice,
      });

      final res2 = DocumentService.resolveLinePrice(
        product: product,
        quantity: 1,
        currentPrice: 120,
        targetCategory: 'retail',
        isManualPrice: true,
      );
      expect(res2, 120);
    });

    test('sales.edit_discount check in createDocument', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      // User with salesCreate but WITHOUT salesEditDiscount
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      expect(
        () => DocumentService.createDocument(
          type: 'invoice',
          business: business,
          items: [
            const DocumentItemInput(
              description: 'Service',
              quantity: 1,
              price: 100,
            ),
          ],
          discount: 10, // Applying discount without permission
        ),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.salesEditDiscount,
        )),
      );
    });

    test('setBooksClosedThrough checks accounting.period_lock', () async {
      SessionManager.instance.setMultiUserEnabledForTesting(true);
      // User without accountingPeriodLock
      SessionManager.instance.setSession(testSalesperson, {
        PermissionRegistry.salesCreate,
      });

      expect(
        () => DatabaseHelper.instance.setBooksClosedThrough(DateTime.now()),
        throwsA(isA<PermissionDeniedException>().having(
          (e) => e.permissionKey,
          'permissionKey',
          PermissionRegistry.accountingPeriodLock,
        )),
      );

      // Under runAsSystem, bypasses check
      AccessGuard.runAsSystem(() {
        expect(
          AccessGuard.can(PermissionRegistry.accountingPeriodLock),
          isTrue,
        );
      });
    });
  });
}

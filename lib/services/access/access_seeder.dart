import 'package:sqflite/sqflite.dart';
import '../../database/access_dao.dart';
import 'permission_registry.dart';

/// Seeds default template roles and their base permissions.
abstract final class AccessSeeder {
  static const String roleTemplateSalesperson = 'role-template-salesperson';
  static const String roleTemplateInventory = 'role-template-inventory';
  static const String roleTemplateAccountant = 'role-template-accountant';
  static const String roleTemplateManager = 'role-template-manager';

  /// Returns default permission keys associated with a template role.
  static Set<String> getPermissionsForTemplate(String roleId) {
    switch (roleId) {
      case roleTemplateSalesperson:
        return {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.salesEdit,
          PermissionRegistry.salesEditPrice,
          PermissionRegistry.salesEditDiscount,
          PermissionRegistry.paymentsRecord,
          PermissionRegistry.productsView,
          PermissionRegistry.productsViewWholesale,
          PermissionRegistry.contactsView,
          PermissionRegistry.contactsManage,
          PermissionRegistry.contactsViewBalances,
          PermissionRegistry.reportsViewSales,
          PermissionRegistry.reportsViewReceivables,
          PermissionRegistry.reportsExportPdf,
        };

      case roleTemplateInventory:
        return {
          PermissionRegistry.productsView,
          PermissionRegistry.productsManage,
          PermissionRegistry.productsViewCost,
          PermissionRegistry.productsViewWholesale,
          PermissionRegistry.stockAdjust,
          PermissionRegistry.stockViewCost,
          PermissionRegistry.stocktakeManage,
          PermissionRegistry.stocktakeFinalize,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
          PermissionRegistry.purchasesEdit,
          PermissionRegistry.dataExportCsv,
          PermissionRegistry.dataImportCsv,
        };

      case roleTemplateAccountant:
        return {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.salesEdit,
          PermissionRegistry.salesCancel,
          PermissionRegistry.salesRefund,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
          PermissionRegistry.purchasesEdit,
          PermissionRegistry.purchasesCancel,
          PermissionRegistry.paymentsRecord,
          PermissionRegistry.vouchersCreate,
          PermissionRegistry.expensesView,
          PermissionRegistry.contactsView,
          PermissionRegistry.contactsViewBalances,
          PermissionRegistry.productsView,
          PermissionRegistry.productsViewCost,
          PermissionRegistry.productsViewWholesale,
          PermissionRegistry.stockViewCost,
          PermissionRegistry.dashboardViewTotals,
          PermissionRegistry.reportsViewSales,
          PermissionRegistry.reportsViewPurchases,
          PermissionRegistry.reportsViewReceivables,
          PermissionRegistry.reportsViewInventoryCost,
          PermissionRegistry.reportsViewFinancials,
          PermissionRegistry.reportsExportPdf,
          PermissionRegistry.accountingPeriodLock,
          PermissionRegistry.dataExportCsv,
        };

      case roleTemplateManager:
        // All permissions except dangerous system/admin actions
        final excluded = {
          PermissionRegistry.backupRestore,
          PermissionRegistry.systemRepair,
          PermissionRegistry.usersManage,
          PermissionRegistry.rolesManage,
          PermissionRegistry.licenseManage,
        };
        return PermissionRegistry.allKeys.difference(excluded);

      default:
        return {};
    }
  }

  /// Inserts template roles and their permissions idempotently.
  static Future<void> ensureDefaults(DatabaseExecutor db) async {
    const templates = [
      (
        id: roleTemplateSalesperson,
        name: '\u0628\u0627\u0626\u0639',
        description:
            '\u0625\u0635\u062f\u0627\u0631 \u0627\u0644\u0641\u0648\u0627\u062a\u064a\u0631\u060c \u0627\u0644\u062a\u062d\u0635\u064a\u0644\u060c \u0648\u0639\u0631\u0636 \u0627\u0644\u0639\u0645\u0644\u0627\u0621 \u0648\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
      ),
      (
        id: roleTemplateInventory,
        name: '\u0645\u0633\u0624\u0648\u0644 \u0645\u062e\u0632\u0648\u0646',
        description:
            '\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a\u060c \u062a\u0633\u0648\u064a\u0629 \u0627\u0644\u0645\u062e\u0632\u0648\u0646\u060c \u0648\u0627\u0644\u062c\u0631\u062f \u0648\u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
      ),
      (
        id: roleTemplateAccountant,
        name: '\u0645\u062d\u0627\u0633\u0628',
        description:
            '\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0645\u0627\u0644\u064a\u0629\u060c \u0627\u0644\u0633\u0646\u062f\u0627\u062a\u060c \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a\u060c \u0648\u0625\u0642\u0641\u0627\u0644 \u0627\u0644\u0641\u062a\u0631\u0627\u062a',
      ),
      (
        id: roleTemplateManager,
        name: '\u0645\u062f\u064a\u0631 \u0641\u0631\u0639',
        description:
            '\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0639\u0645\u0644\u064a\u0627\u062a \u0627\u0644\u064a\u0648\u0645\u064a\u0629 \u0648\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0648\u0627\u0644\u0623\u0633\u0639\u0627\u0631 \u0645\u0639 \u0627\u0633\u062a\u062b\u0646\u0627\u0621 \u0635\u0644\u0627\u062d\u064a\u0627\u062a \u0627\u0644\u0646\u0638\u0627\u0645 \u0627\u0644\u062d\u0633\u0627\u0633\u0629',
      ),
    ];

    for (final t in templates) {
      await db.rawInsert(
        '''
        INSERT OR IGNORE INTO roles (id, workspace_id, name, description, is_system, is_template)
        VALUES (?, ?, ?, ?, 0, 1)
      ''',
        [t.id, AccessDao.defaultWorkspaceId, t.name, t.description],
      );

      final perms = getPermissionsForTemplate(t.id);
      for (final p in perms) {
        await db.rawInsert(
          '''
          INSERT OR IGNORE INTO role_permissions (role_id, permission_key)
          VALUES (?, ?)
        ''',
          [t.id, p],
        );
      }
    }

    await migrateReceivablesPermissions(db);
  }

  /// Grants [PermissionRegistry.reportsViewReceivables] to any role or user override
  /// that previously held [PermissionRegistry.contactsViewBalances].
  static Future<void> migrateReceivablesPermissions(DatabaseExecutor db) async {
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO role_permissions (role_id, permission_key)
      SELECT DISTINCT role_id, ?
      FROM role_permissions
      WHERE permission_key = ?
    ''',
      [
        PermissionRegistry.reportsViewReceivables,
        PermissionRegistry.contactsViewBalances,
      ],
    );

    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO user_permissions (user_id, permission_key, is_granted)
      SELECT DISTINCT user_id, ?, 1
      FROM user_permissions
      WHERE permission_key = ? AND is_granted = 1
    ''',
      [
        PermissionRegistry.reportsViewReceivables,
        PermissionRegistry.contactsViewBalances,
      ],
    );
  }
}

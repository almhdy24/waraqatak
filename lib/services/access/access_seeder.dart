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
        name: 'بائع',
        description: 'إصدار الفواتير، التحصيل، وعرض العملاء والمنتجات',
      ),
      (
        id: roleTemplateInventory,
        name: 'مسؤول مخزون',
        description: 'إدارة المنتجات، تسوية المخزون، والجرد والمشتريات',
      ),
      (
        id: roleTemplateAccountant,
        name: 'محاسب',
        description: 'التقارير المالية، السندات، الحسابات، وإقفال الفترات',
      ),
      (
        id: roleTemplateManager,
        name: 'مدير فرع',
        description:
            'إدارة العمليات اليومية والتقارير والأسعار مع استثناء صلاحيات النظام الحساسة',
      ),
    ];

    for (final t in templates) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO roles (id, workspace_id, name, description, is_system, is_template)
        VALUES (?, ?, ?, ?, 0, 1)
      ''', [t.id, AccessDao.defaultWorkspaceId, t.name, t.description]);

      final perms = getPermissionsForTemplate(t.id);
      for (final p in perms) {
        await db.rawInsert('''
          INSERT OR IGNORE INTO role_permissions (role_id, permission_key)
          VALUES (?, ?)
        ''', [t.id, p]);
      }
    }
  }
}

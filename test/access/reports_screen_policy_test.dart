import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/audit_history_screen.dart';
import 'package:warqatek/screens/reports/accounting_screen.dart';
import 'package:warqatek/screens/reports/advanced_inventory_analytics_screen.dart';
import 'package:warqatek/screens/reports/customer_report_screen.dart';
import 'package:warqatek/screens/reports/inventory_report_screen.dart';
import 'package:warqatek/screens/reports/payments_report_screen.dart';
import 'package:warqatek/screens/reports/product_report_screen.dart';
import 'package:warqatek/screens/reports/purchases_report_screen.dart';
import 'package:warqatek/screens/reports/sales_report_screen.dart';
import 'package:warqatek/screens/reports/supplier_report_screen.dart';
import 'package:warqatek/screens/stock_movements_screen.dart';
import 'package:warqatek/services/access/access_seeder.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/screen_access_policy.dart';
import 'package:warqatek/services/access/session_manager.dart';

void main() {
  tearDown(() {
    SessionManager.instance.resetForTesting();
  });

  group('Reports ScreenAccessPolicy & Seeder Guard Tests', () {
    test(
      'Cashier (salesperson) template has correct report access boundaries',
      () {
        final perms = AccessSeeder.getPermissionsForTemplate(
          AccessSeeder.roleTemplateSalesperson,
        );

        // Can view sales and receivables (customer balance)
        expect(perms.contains(PermissionRegistry.reportsViewSales), isTrue);
        expect(
          perms.contains(PermissionRegistry.reportsViewReceivables),
          isTrue,
        );

        // CANNOT view financials (payments report, ledger, P&L) or inventory cost
        expect(
          perms.contains(PermissionRegistry.reportsViewFinancials),
          isFalse,
        );
        expect(
          perms.contains(PermissionRegistry.reportsViewPurchases),
          isFalse,
        );
        expect(
          perms.contains(PermissionRegistry.reportsViewInventoryCost),
          isFalse,
        );

        final cashierUser = AppUser(
          id: 'usr-cashier',
          workspaceId: 'ws-default',
          roleId: AccessSeeder.roleTemplateSalesperson,
          username: 'cashier',
          displayName: 'Cashier',
          isOwner: false,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        SessionManager.instance.setSessionForTesting(
          cashierUser,
          permissions: perms,
        );

        // Evaluating screen access policy with cashier permissions:
        expect(
          ScreenAccessPolicy.evaluate(
            SalesReportScreen,
            permissions: perms,
          ).isAllowed,
          isTrue,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            CustomerReportScreen,
            permissions: perms,
          ).isAllowed,
          isTrue,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            PaymentsReportScreen,
            permissions: perms,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            AccountingScreen,
            permissions: perms,
          ).isAllowed,
          isFalse,
        );
        expect(
          ScreenAccessPolicy.evaluate(
            InventoryReportScreen,
            permissions: perms,
          ).isAllowed,
          isFalse,
        );
      },
    );

    test(
      'ScreenAccessPolicy defines exact requirements for all report screens',
      () {
        expect(
          ScreenAccessPolicy.manifest[SalesReportScreen]?.requiredPermission,
          PermissionRegistry.reportsViewSales,
        );
        expect(
          ScreenAccessPolicy
              .manifest[PurchasesReportScreen]
              ?.requiredPermission,
          PermissionRegistry.reportsViewPurchases,
        );
        expect(
          ScreenAccessPolicy.manifest[PaymentsReportScreen]?.requiredPermission,
          PermissionRegistry.reportsViewFinancials,
        );
        expect(
          ScreenAccessPolicy.manifest[CustomerReportScreen]?.requiredPermission,
          PermissionRegistry.reportsViewReceivables,
        );
        expect(
          ScreenAccessPolicy.manifest[SupplierReportScreen]?.requiredPermission,
          PermissionRegistry.reportsViewReceivables,
        );
        expect(
          ScreenAccessPolicy.manifest[ProductReportScreen]?.requiredPermission,
          PermissionRegistry.reportsViewSales,
        );
        expect(
          ScreenAccessPolicy
              .manifest[InventoryReportScreen]
              ?.requiredPermission,
          PermissionRegistry.reportsViewInventoryCost,
        );
        expect(
          ScreenAccessPolicy
              .manifest[AdvancedInventoryAnalyticsScreen]
              ?.requiredPermission,
          PermissionRegistry.reportsViewInventoryCost,
        );
        expect(
          ScreenAccessPolicy.manifest[StockMovementsScreen]?.requiredPermission,
          PermissionRegistry.productsView,
        );
        expect(
          ScreenAccessPolicy.manifest[AuditHistoryScreen]?.requiredPermission,
          PermissionRegistry.auditView,
        );
      },
    );
  });
}

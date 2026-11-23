import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/screens/audit_history_screen.dart';
import 'package:warqatek/screens/reports/accounting_screen.dart';
import 'package:warqatek/screens/reports/advanced_inventory_analytics_screen.dart';
import 'package:warqatek/screens/reports/aging_report_screen.dart';
import 'package:warqatek/screens/reports/customer_report_screen.dart';
import 'package:warqatek/screens/reports/daily_closing_report_screen.dart';
import 'package:warqatek/screens/reports/inventory_report_screen.dart';
import 'package:warqatek/screens/reports/low_stock_report_screen.dart';
import 'package:warqatek/screens/reports/payments_report_screen.dart';
import 'package:warqatek/screens/reports/product_report_screen.dart';
import 'package:warqatek/screens/reports/purchases_report_screen.dart';
import 'package:warqatek/screens/reports/sales_report_screen.dart';
import 'package:warqatek/screens/reports/supplier_report_screen.dart';
import 'package:warqatek/screens/reports/tax_discount_report_screen.dart';
import 'package:warqatek/screens/reports_screen.dart';
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
    test('Cashier (salesperson) template has correct report access boundaries', () {
      final perms = AccessSeeder.getPermissionsForTemplate(
        AccessSeeder.roleTemplateSalesperson,
      );

      // Can view sales, daily closing, receivables, and low stock (productsView)
      expect(perms.contains(PermissionRegistry.reportsViewSales), isTrue);
      expect(perms.contains(PermissionRegistry.reportsViewReceivables), isTrue);
      expect(perms.contains(PermissionRegistry.productsView), isTrue);

      // CANNOT view financials (payments report, ledger, P&L), purchases, or inventory valuation/cost
      expect(perms.contains(PermissionRegistry.reportsViewFinancials), isFalse);
      expect(perms.contains(PermissionRegistry.reportsViewPurchases), isFalse);
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
      // ALLOWED:
      expect(
        ScreenAccessPolicy.evaluate(
          SalesReportScreen,
          permissions: perms,
        ).isAllowed,
        isTrue,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          DailyClosingReportScreen,
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
          AgingReportScreen,
          permissions: perms,
        ).isAllowed,
        isTrue,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          ProductReportScreen,
          permissions: perms,
        ).isAllowed,
        isTrue,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          LowStockReportScreen,
          permissions: perms,
        ).isAllowed,
        isTrue,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          StockMovementsScreen,
          permissions: perms,
        ).isAllowed,
        isTrue,
      );

      // DENIED:
      expect(
        ScreenAccessPolicy.evaluate(
          PaymentsReportScreen,
          permissions: perms,
        ).isAllowed,
        isFalse,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          PurchasesReportScreen,
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
          AccountLedgerScreen,
          permissions: perms,
        ).isAllowed,
        isFalse,
      );
      expect(
        ScreenAccessPolicy.evaluate(
          TaxDiscountReportScreen,
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
      expect(
        ScreenAccessPolicy.evaluate(
          AdvancedInventoryAnalyticsScreen,
          permissions: perms,
        ).isAllowed,
        isFalse,
      );
    });

    test(
      'Every Reports hub tile matches the ScreenAccessPolicy requirement of its target screen type',
      () {
        final l10n = AppLocalizations('ar');
        final categories = ReportsScreen.getReportCategories(l10n);

        final allTiles = categories.expand((c) => c.reports).toList();
        expect(allTiles.isNotEmpty, isTrue);

        for (final tile in allTiles) {
          final targetType = tile.screen.runtimeType;
          final policy = ScreenAccessPolicy.manifest[targetType];

          expect(
            policy,
            isNotNull,
            reason:
                'Target screen type $targetType on tile "${tile.title}" must have an entry in ScreenAccessPolicy.manifest',
          );

          if (tile.permission != null) {
            expect(
              tile.permission,
              equals(policy!.requiredPermission),
              reason:
                  'Hub tile "${tile.title}" permission (${tile.permission}) does not match target screen $targetType policy requirement (${policy.requiredPermission})',
            );
          }
        }
      },
    );

    test(
      'All canonical report screens have explicit ScreenAccessPolicy manifest entries',
      () {
        const allReportScreenTypes = [
          AccountingScreen,
          AccountLedgerScreen,
          SalesReportScreen,
          DailyClosingReportScreen,
          PurchasesReportScreen,
          PaymentsReportScreen,
          TaxDiscountReportScreen,
          CustomerReportScreen,
          SupplierReportScreen,
          AgingReportScreen,
          ProductReportScreen,
          InventoryReportScreen,
          LowStockReportScreen,
          StockMovementsScreen,
          AdvancedInventoryAnalyticsScreen,
          AuditHistoryScreen,
        ];

        for (final screenType in allReportScreenTypes) {
          final policy = ScreenAccessPolicy.manifest[screenType];
          expect(
            policy,
            isNotNull,
            reason:
                'Screen $screenType is missing from ScreenAccessPolicy.manifest',
          );
          expect(
            policy!.requiredPermission,
            isNotNull,
            reason:
                'Screen $screenType policy must declare a requiredPermission',
          );
        }
      },
    );
  });
}

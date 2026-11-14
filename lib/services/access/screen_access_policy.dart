import 'access_error.dart';
import 'access_policy.dart';
import 'permission_registry.dart';
import 'session_manager.dart';

import '../../screens/about_screen.dart';
import '../../screens/activation_screen.dart';
import '../../screens/barcode_scanner_screen.dart';
import '../../screens/business_setup_screen.dart';
import '../../screens/contact_form_screen.dart';
import '../../screens/custom_document_screen.dart';
import '../../screens/customer_detail_screen.dart';
import '../../screens/customers_screen.dart';
import '../../screens/document_detail_screen.dart';
import '../../screens/documents_screen.dart';
import '../../screens/edit_document_screen.dart';
import '../../screens/financial_settings_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/inventory_screen.dart';
import '../../screens/invoice_screen.dart';
import '../../screens/license_screen.dart';
import '../../screens/locked_feature_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/payment_methods_screen.dart';
import '../../screens/pdf_customize_screen.dart';
import '../../screens/product_form_screen.dart';
import '../../screens/products_screen.dart';
import '../../screens/purchase_screen.dart';
import '../../screens/quick_sale_screen.dart';
import '../../screens/quotation_screen.dart';
import '../../screens/reports/accounting_screen.dart';
import '../../screens/reports/customer_report_screen.dart';
import '../../screens/reports/inventory_report_screen.dart';
import '../../screens/reports/payments_report_screen.dart';
import '../../screens/reports/product_report_screen.dart';
import '../../screens/reports/purchases_report_screen.dart';
import '../../screens/reports/sales_report_screen.dart';
import '../../screens/reports/supplier_report_screen.dart';
import '../../screens/reports/advanced_inventory_analytics_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/splash_screen.dart';
import '../../screens/tax_profiles_screen.dart';
import '../../screens/transparency_screen.dart';
import '../../screens/voucher_screen.dart';
import '../../screens/notifications_inbox_screen.dart';
import '../../screens/stock_movements_screen.dart';
import '../../screens/stocktake/stocktake_screen.dart';
import '../../screens/stocktake/stocktake_history_screen.dart';
import '../../screens/bulk_pricing_screen.dart';
import '../../screens/csv_import_export_screen.dart';
import '../../screens/audit_history_screen.dart';
import '../../screens/database_diagnostic_screen.dart';
import '../../screens/google_drive_backup_screen.dart';
import '../../screens/exchange_rates_screen.dart';
import '../../screens/period_closing_screen.dart';
import '../../screens/access/audit_trail_screen.dart';
import '../../screens/access/multi_user_wizard_screen.dart';
import '../../screens/access/pin_lock_screen.dart';
import '../../screens/access/recovery_screen.dart';
import '../../screens/access/roles_screen.dart';
import '../../screens/access/user_form_screen.dart';
import '../../screens/access/users_list_screen.dart';
import '../../models/app_user.dart';

/// Access specification for a screen or route.
class ScreenPolicy {
  final bool isPublic;
  final bool isOwnerOnly;
  final String? requiredPermission;

  const ScreenPolicy.public()
      : isPublic = true,
        isOwnerOnly = false,
        requiredPermission = null;

  const ScreenPolicy.ownerOnly()
      : isPublic = false,
        isOwnerOnly = true,
        requiredPermission = null;

  const ScreenPolicy.require(String permission)
      : isPublic = false,
        isOwnerOnly = false,
        requiredPermission = permission;
}

/// Authoritative manifest declaring security policies for every screen in the app.
///
/// Implements Deny-By-Default (H5): any screen not explicitly registered in [manifest]
/// is refused entry automatically.
abstract final class ScreenAccessPolicy {
  static final Map<Type, ScreenPolicy> manifest = {
    // 1. Shell & Public / Auth
    HomeScreen: const ScreenPolicy.public(),
    MainShell: const ScreenPolicy.public(),
    SplashScreen: const ScreenPolicy.public(),
    AboutScreen: const ScreenPolicy.public(),
    TransparencyScreen: const ScreenPolicy.public(),
    BarcodeScannerScreen: const ScreenPolicy.public(),
    NotificationsInboxScreen: const ScreenPolicy.public(),
    LockedFeatureScreen: const ScreenPolicy.public(),
    PinLockScreen: const ScreenPolicy.public(),
    RecoveryScreen: const ScreenPolicy.public(),
    ReportsScreen: const ScreenPolicy.public(),
    SettingsScreen: const ScreenPolicy.public(),

    // 2. OWNER_ONLY Screens (H1)
    MultiUserWizardScreen: const ScreenPolicy.ownerOnly(),
    LicenseScreen: const ScreenPolicy.ownerOnly(),
    ActivationScreen: const ScreenPolicy.ownerOnly(),
    DatabaseDiagnosticScreen: const ScreenPolicy.ownerOnly(),
    GoogleDriveBackupScreen: const ScreenPolicy.ownerOnly(),

    // 3. Admin & Audit
    UsersListScreen: const ScreenPolicy.require(PermissionRegistry.usersManage),
    UserFormScreen: const ScreenPolicy.require(PermissionRegistry.usersManage),
    RolesScreen: const ScreenPolicy.require(PermissionRegistry.rolesManage),
    AuditTrailScreen: const ScreenPolicy.require(PermissionRegistry.auditView),
    AuditHistoryScreen: const ScreenPolicy.require(PermissionRegistry.auditView),

    // 4. Settings & Setup
    BusinessSetupScreen: const ScreenPolicy.require(PermissionRegistry.settingsManage),
    FinancialSettingsScreen: const ScreenPolicy.require(PermissionRegistry.settingsManage),
    ExchangeRatesScreen: const ScreenPolicy.require(PermissionRegistry.pricingRates),
    PaymentMethodsScreen: const ScreenPolicy.require(PermissionRegistry.paymentMethodsManage),
    TaxProfilesScreen: const ScreenPolicy.require(PermissionRegistry.taxProfilesManage),
    PdfCustomizeScreen: const ScreenPolicy.require(PermissionRegistry.settingsManage),
    PeriodClosingScreen: const ScreenPolicy.require(PermissionRegistry.accountingPeriodLock),

    // 5. Products & Inventory
    ProductsScreen: const ScreenPolicy.require(PermissionRegistry.productsView),
    ProductFormScreen: const ScreenPolicy.require(PermissionRegistry.productsManage),
    BulkPricingScreen: const ScreenPolicy.require(PermissionRegistry.pricingManage),
    InventoryScreen: const ScreenPolicy.require(PermissionRegistry.productsView),
    StockMovementsScreen: const ScreenPolicy.require(PermissionRegistry.productsView),
    StocktakeScreen: const ScreenPolicy.require(PermissionRegistry.stocktakeManage),
    StocktakeHistoryScreen: const ScreenPolicy.require(PermissionRegistry.stocktakeManage),
    CsvImportExportScreen: const ScreenPolicy.require(PermissionRegistry.dataImportCsv),

    // 6. Contacts
    CustomersScreen: const ScreenPolicy.require(PermissionRegistry.contactsView),
    CustomerDetailScreen: const ScreenPolicy.require(PermissionRegistry.contactsView),
    ContactFormScreen: const ScreenPolicy.require(PermissionRegistry.contactsManage),

    // 7. Documents & Transactions
    DocumentsScreen: const ScreenPolicy.require(PermissionRegistry.salesView),
    DocumentDetailScreen: const ScreenPolicy.require(PermissionRegistry.salesView),
    InvoiceScreen: const ScreenPolicy.require(PermissionRegistry.salesCreate),
    QuickSaleScreen: const ScreenPolicy.require(PermissionRegistry.salesCreate),
    QuotationScreen: const ScreenPolicy.require(PermissionRegistry.salesCreate),
    EditDocumentScreen: const ScreenPolicy.require(PermissionRegistry.salesEdit),
    PurchaseScreen: const ScreenPolicy.require(PermissionRegistry.purchasesCreate),
    CustomDocumentScreen: const ScreenPolicy.require(PermissionRegistry.salesCreate),
    VoucherScreen: const ScreenPolicy.require(PermissionRegistry.vouchersCreate),

    // 8. Financial & Analytical Reports
    AccountingScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewFinancials),
    AccountLedgerScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewFinancials),
    SalesReportScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewSales),
    PurchasesReportScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewPurchases),
    InventoryReportScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewInventoryCost),
    PaymentsReportScreen: const ScreenPolicy.require(PermissionRegistry.paymentsRecord),
    CustomerReportScreen: const ScreenPolicy.require(PermissionRegistry.contactsViewBalances),
    SupplierReportScreen: const ScreenPolicy.require(PermissionRegistry.contactsViewBalances),
    ProductReportScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewSales),
    AdvancedInventoryAnalyticsScreen: const ScreenPolicy.require(PermissionRegistry.reportsViewInventoryCost),
  };

  /// Evaluates whether the current actor is permitted to enter [screenType].
  static PolicyResult evaluate(
    Type screenType, {
    AppUser? actor,
    Set<String>? permissions,
  }) {
    // 1. Single-user mode: full access to all screens
    if (!SessionManager.instance.isMultiUserEnabled) {
      return const PolicyResult.allow();
    }

    // 2. Deny by default if screen has no declared policy
    final policy = manifest[screenType];
    if (policy == null) {
      return PolicyResult.deny(
        AccessErrorCode.undeclaredScreen,
        'Access denied: Undeclared screen security policy for $screenType',
      );
    }

    // 3. Public screens allowed for anyone
    if (policy.isPublic) {
      return const PolicyResult.allow();
    }

    final effectiveActor = actor ?? SessionManager.instance.currentUser;
    // 4. Unauthenticated or locked session cannot access protected screens
    if (effectiveActor == null) {
      return const PolicyResult.deny(
        AccessErrorCode.unauthenticated,
        'Authentication required to access this screen',
      );
    }
    if (SessionManager.instance.isLocked) {
      return const PolicyResult.deny(
        AccessErrorCode.sessionLocked,
        'Session is locked',
      );
    }

    // 5. System Owner has unconditional access to all declared screens
    if (effectiveActor.isOwner) {
      return const PolicyResult.allow();
    }

    // 6. OWNER_ONLY screens blocked for delegates
    if (policy.isOwnerOnly) {
      return const PolicyResult.deny(
        AccessErrorCode.ownerOnly,
        'This screen is strictly restricted to the system Owner',
      );
    }

    // 7. Check required permission
    final effectivePerms =
        permissions ?? SessionManager.instance.cachedPermissions;
    if (policy.requiredPermission != null) {
      if (!effectivePerms.contains(policy.requiredPermission)) {
        return PolicyResult.deny(
          AccessErrorCode.missingPermission,
          'Missing required permission: ${policy.requiredPermission}',
          permissionKey: policy.requiredPermission,
        );
      }
    }

    return const PolicyResult.allow();
  }

  /// Convenience boolean check for [evaluate].
  static bool canAccess(Type screenType) => evaluate(screenType).isAllowed;
}

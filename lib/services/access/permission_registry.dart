import '../../localization/app_localizations.dart';

/// Permission categories for grouping in UI permission matrix.
enum PermissionGroup {
  sales,
  purchases,
  payments,
  stock,
  products,
  contacts,
  dashboard,
  reports,
  data,
  system,
  settings,
  access;

  String localizedLabel(AppLocalizations l10n) =>
      l10n.permissionGroupLabelByName(name);
}

/// Metadata definition of an application permission key.
class PermissionItem {
  final String key;
  final PermissionGroup group;
  final bool isSensitive;
  final bool isOwnerOnly;

  const PermissionItem({
    required this.key,
    required this.group,
    this.isSensitive = false,
    this.isOwnerOnly = false,
  });

  String localizedName(AppLocalizations l10n) => l10n.permissionName(key);
  String localizedDescription(AppLocalizations l10n) =>
      l10n.permissionDescription(key);
}

abstract final class PermissionRegistry {
  // Sales
  static const String salesView = 'sales.view';
  static const String salesCreate = 'sales.create';
  static const String salesEdit = 'sales.edit';
  static const String salesEditPrice = 'sales.edit_price';
  static const String salesEditDiscount = 'sales.edit_discount';
  static const String salesCancel = 'sales.cancel';
  static const String salesDelete = 'sales.delete';
  static const String salesRefund = 'sales.refund';

  // Purchases
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesEdit = 'purchases.edit';
  static const String purchasesCancel = 'purchases.cancel';
  static const String purchasesDelete = 'purchases.delete';

  // Payments & Vouchers
  static const String paymentsRecord = 'payments.record';
  static const String vouchersCreate = 'vouchers.create';
  static const String expensesView = 'expenses.view';

  // Stock & Inventory
  static const String stockAdjust = 'stock.adjust';
  static const String stockViewCost = 'stock.view_cost';
  static const String stocktakeManage = 'stocktake.manage';
  static const String stocktakeFinalize = 'stocktake.finalize';

  // Products & Pricing
  static const String productsView = 'products.view';
  static const String productsManage = 'products.manage';
  static const String productsDelete = 'products.delete';
  static const String productsViewCost = 'products.view_cost';
  static const String productsViewWholesale = 'products.view_wholesale';
  static const String pricingManage = 'pricing.manage';
  static const String pricingRates = 'pricing.rates';

  // Contacts
  static const String contactsView = 'contacts.view';
  static const String contactsManage = 'contacts.manage';
  static const String contactsDelete = 'contacts.delete';
  static const String contactsViewBalances = 'contacts.view_balances';

  // Dashboard
  static const String dashboardViewTotals = 'dashboard.view_totals';

  // Reports
  static const String reportsViewSales = 'reports.view_sales';
  static const String reportsViewPurchases = 'reports.view_purchases';
  static const String reportsViewReceivables = 'reports.view_receivables';
  static const String reportsViewInventoryCost = 'reports.view_inventory_cost';
  static const String reportsViewFinancials = 'reports.view_financials';
  static const String reportsExportPdf = 'reports.export_pdf';

  // Data
  static const String dataExportCsv = 'data.export_csv';
  static const String dataImportCsv = 'data.import_csv';

  // System & Backup
  static const String backupCreate = 'backup.create';
  static const String backupRestore = 'backup.restore';
  static const String systemRepair = 'system.repair';
  static const String accountingPeriodLock = 'accounting.period_lock';

  // Settings
  static const String settingsManage = 'settings.manage';
  static const String paymentMethodsManage = 'payment_methods.manage';
  static const String taxProfilesManage = 'tax_profiles.manage';

  // Access & Admin
  static const String auditView = 'audit.view';
  static const String usersManage = 'users.manage';
  static const String rolesManage = 'roles.manage';
  static const String licenseManage = 'license.manage';

  static const List<PermissionItem> all = [
    // Sales
    PermissionItem(
      key: salesView,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesCreate,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEdit,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEditPrice,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEditDiscount,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesCancel,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesDelete,
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesRefund,
      group: PermissionGroup.sales,
      isSensitive: true,
    ),

    // Purchases
    PermissionItem(
      key: purchasesView,
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesCreate,
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesEdit,
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesCancel,
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesDelete,
      group: PermissionGroup.purchases,
    ),

    // Payments & Vouchers
    PermissionItem(
      key: paymentsRecord,
      group: PermissionGroup.payments,
    ),
    PermissionItem(
      key: vouchersCreate,
      group: PermissionGroup.payments,
    ),
    PermissionItem(
      key: expensesView,
      group: PermissionGroup.payments,
      isSensitive: true,
    ),

    // Stock & Inventory
    PermissionItem(
      key: stockAdjust,
      group: PermissionGroup.stock,
    ),
    PermissionItem(
      key: stockViewCost,
      group: PermissionGroup.stock,
      isSensitive: true,
    ),
    PermissionItem(
      key: stocktakeManage,
      group: PermissionGroup.stock,
    ),
    PermissionItem(
      key: stocktakeFinalize,
      group: PermissionGroup.stock,
      isSensitive: true,
    ),

    // Products & Pricing
    PermissionItem(
      key: productsView,
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsManage,
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsDelete,
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsViewCost,
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: productsViewWholesale,
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: pricingManage,
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: pricingRates,
      group: PermissionGroup.products,
    ),

    // Contacts
    PermissionItem(
      key: contactsView,
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsManage,
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsDelete,
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsViewBalances,
      group: PermissionGroup.contacts,
      isSensitive: true,
    ),

    // Dashboard
    PermissionItem(
      key: dashboardViewTotals,
      group: PermissionGroup.dashboard,
      isSensitive: true,
    ),

    // Reports
    PermissionItem(
      key: reportsViewSales,
      group: PermissionGroup.reports,
    ),
    PermissionItem(
      key: reportsViewPurchases,
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewReceivables,
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewInventoryCost,
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewFinancials,
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsExportPdf,
      group: PermissionGroup.reports,
    ),

    // Data
    PermissionItem(
      key: dataExportCsv,
      group: PermissionGroup.data,
      isSensitive: true,
    ),
    PermissionItem(
      key: dataImportCsv,
      group: PermissionGroup.data,
    ),

    // System & Backup
    PermissionItem(
      key: backupCreate,
      group: PermissionGroup.system,
      isSensitive: true,
    ),
    PermissionItem(
      key: backupRestore,
      group: PermissionGroup.system,
      isSensitive: true,
      isOwnerOnly: true,
    ),
    PermissionItem(
      key: systemRepair,
      group: PermissionGroup.system,
      isSensitive: true,
      isOwnerOnly: true,
    ),
    PermissionItem(
      key: accountingPeriodLock,
      group: PermissionGroup.system,
      isSensitive: true,
    ),

    // Settings
    PermissionItem(
      key: settingsManage,
      group: PermissionGroup.settings,
      isSensitive: true,
    ),
    PermissionItem(
      key: paymentMethodsManage,
      group: PermissionGroup.settings,
    ),
    PermissionItem(
      key: taxProfilesManage,
      group: PermissionGroup.settings,
    ),

    // Access & Admin
    PermissionItem(
      key: auditView,
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: usersManage,
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: rolesManage,
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: licenseManage,
      group: PermissionGroup.access,
      isSensitive: true,
      isOwnerOnly: true,
    ),
  ];

  static final Map<String, PermissionItem> _byKey = {
    for (final item in all) item.key: item,
  };

  /// Returns [PermissionItem] for [key] if registered, null otherwise.
  static PermissionItem? get(String key) => _byKey[key];

  /// Returns all permission keys registered in the system.
  static Set<String> get allKeys => _byKey.keys.toSet();

  /// Groups registered permissions by their [PermissionGroup].
  static Map<PermissionGroup, List<PermissionItem>> get byGroup {
    final map = <PermissionGroup, List<PermissionItem>>{};
    for (final item in all) {
      map.putIfAbsent(item.group, () => []).add(item);
    }
    return map;
  }
}

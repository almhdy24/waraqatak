import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';
import '../services/analytics/analytics_service.dart';
import '../widgets/pro_upgrade_sheet.dart';
import 'reports/accounting_screen.dart';
import 'reports/customer_report_screen.dart';
import 'reports/inventory_report_screen.dart';
import 'reports/payments_report_screen.dart';
import 'reports/product_report_screen.dart';
import 'reports/purchases_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/supplier_report_screen.dart';
import 'stock_movements_screen.dart';
import '../widgets/responsive.dart';
import 'audit_history_screen.dart';
import 'reports/advanced_inventory_analytics_screen.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_status_colors.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  EntitlementState? _entitlement;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    LicenseService.instance
        .checkEntitlement(force: false)
        .then((e) {
          if (mounted) setState(() => _entitlement = e);
        })
        .catchError((_) {});
  }

  Future<void> _openReport(_ReportEntry entry) async {
    if (_opening) return;
    _opening = true;
    try {
      final feature = entry.proFeature;
      if (feature != null) {
        // Re-evaluate on every open so a running session cannot outlive expiry.
        try {
          final fresh = await LicenseService.instance.checkEntitlement(
            force: true,
          );
          if (mounted) setState(() => _entitlement = fresh);
        } catch (_) {}
      }
      if (feature != null && !FeatureAccess.canAccess(feature, _entitlement)) {
        if (!mounted) return;
        final result = await ProUpgradeSheet.show(context, feature: feature);
        if (result == true && mounted) {
          final e = await LicenseService.instance.checkEntitlement(force: true);
          if (mounted) setState(() => _entitlement = e);
          if (FeatureAccess.canAccess(feature, e)) {
            await _openReport(entry);
          }
        }
        return;
      }
      if (!mounted) return;
      try {
        final reportKey = _resolveReportKey(entry.screen);
        if (reportKey != null) {
          AnalyticsService.instance.track(AnalyticsEvent.reportOpened, {
            'report': reportKey,
          });
        }
      } catch (_) {}
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => entry.screen));
    } finally {
      _opening = false;
    }
  }

  static String? _resolveReportKey(Widget screen) {
    if (screen is AccountingScreen) return 'accounting';
    if (screen is SalesReportScreen) return 'sales';
    if (screen is PurchasesReportScreen) return 'purchases';
    if (screen is InventoryReportScreen) return 'inventory';
    if (screen is ProductReportScreen) return 'products';
    if (screen is AdvancedInventoryAnalyticsScreen) return 'advanced_inventory';
    if (screen is PaymentsReportScreen) return 'payments';
    if (screen is StockMovementsScreen) return 'inventory';
    if (screen is CustomerReportScreen || screen is SupplierReportScreen) {
      return 'statement';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final categories = [
      _ReportCategory(
        title: l10n.reportCatFinancial,
        reports: [
          _ReportEntry(
            icon: Icons.account_balance_outlined,
            color: primaryColor,
            title: l10n.accounting,
            subtitle: l10n.reportSubtitleAccounting,
            screen: const AccountingScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.reportsViewFinancials,
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatSalesPurchases,
        reports: [
          _ReportEntry(
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF2E7D32),
            title: l10n.salesReport,
            subtitle: l10n.reportSubtitleSales,
            screen: const SalesReportScreen(),
            permission: PermissionRegistry.reportsViewSales,
          ),
          _ReportEntry(
            icon: Icons.shopping_cart_outlined,
            color: const Color(0xFFE65100),
            title: l10n.purchasesReport,
            subtitle: l10n.reportSubtitlePurchases,
            screen: const PurchasesReportScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.reportsViewPurchases,
          ),
          _ReportEntry(
            icon: Icons.payments_outlined,
            color: const Color(0xFF00796B),
            title: l10n.paymentsReport,
            subtitle: l10n.reportSubtitlePayments,
            screen: const PaymentsReportScreen(),
            permission: PermissionRegistry.paymentsRecord,
          ),
          _ReportEntry(
            icon: Icons.people_outlined,
            color: const Color(0xFF1565C0),
            title: l10n.customerReport,
            subtitle: l10n.reportSubtitleCustomers,
            screen: const CustomerReportScreen(),
            permission: PermissionRegistry.contactsViewBalances,
          ),
          _ReportEntry(
            icon: Icons.store_outlined,
            color: const Color(0xFF512DA8),
            title: l10n.supplierReport,
            subtitle: l10n.reportSubtitleSuppliers,
            screen: const SupplierReportScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.contactsViewBalances,
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatInventory,
        reports: [
          _ReportEntry(
            icon: Icons.warehouse_outlined,
            color: const Color(0xFF5D4037),
            title: l10n.inventoryReport,
            subtitle: l10n.reportSubtitleInventory,
            screen: const InventoryReportScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.reportsViewInventoryCost,
          ),
          _ReportEntry(
            icon: Icons.notification_important_outlined,
            color: const Color(0xFFE64A19),
            title: l10n.lowStockReport,
            subtitle: l10n.reportSubtitleLowStock,
            screen: const InventoryReportScreen(initialFilter: 'low_stock'),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.stockAdjust,
          ),
          _ReportEntry(
            icon: Icons.history_outlined,
            color: const Color(0xFF455A64),
            title: l10n.stockMovementsReport,
            subtitle: l10n.reportSubtitleMovements,
            screen: const StockMovementsScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.stockViewCost,
          ),
          _ReportEntry(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF283593),
            title: l10n.productReport,
            subtitle: l10n.reportSubtitleProducts,
            screen: const ProductReportScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.reportsViewInventoryCost,
          ),
          _ReportEntry(
            icon: Icons.analytics_outlined,
            color: const Color(0xFF00796B),
            title: l10n.advancedInventoryAnalytics,
            subtitle: l10n.reportSubtitleAdvancedAnalytics,
            screen: const AdvancedInventoryAnalyticsScreen(),
            proFeature: Feature.advancedReports,
            permission: PermissionRegistry.reportsViewInventoryCost,
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatAudit,
        reports: [
          _ReportEntry(
            icon: Icons.history_edu_outlined,
            color: const Color(0xFF455A64),
            title: l10n.auditHistoryTitle,
            subtitle: l10n.reportSubtitleAudit,
            screen: const AuditHistoryScreen(),
            proFeature: Feature.inventoryAudit,
            permission: PermissionRegistry.auditView,
          ),
        ],
      ),
    ];

    final chevronIcon = AppIcons.chevronForward(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports), centerTitle: true),
      body: ResponsiveCenter(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: categories.length,
          itemBuilder: (context, catIndex) {
            final cat = categories[catIndex];
            final availableReports = cat.reports
                .where(
                  (r) => r.permission == null || AccessGuard.can(r.permission!),
                )
                .toList();
            if (availableReports.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: catIndex == 0 ? 8 : 20,
                    bottom: 6,
                  ),
                  child: AppSectionHeader(
                    title: cat.title,
                    count: availableReports.length,
                  ),
                ),
                ...availableReports.map((entry) {
                  final locked = _entitlement != null &&
                      entry.proFeature != null &&
                      !FeatureAccess.canAccess(entry.proFeature!, _entitlement);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDesignTokens.cardRadius,
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppStatusColors.adapt(
                            context,
                            entry.color,
                          ).withValues(alpha: 0.14),
                          child: Icon(
                            entry.icon,
                            color: AppStatusColors.adapt(context, entry.color),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            entry.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locked) ...[
                              const ProBadge(),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              locked ? Icons.lock_outline : chevronIcon,
                              semanticLabel:
                                  locked ? l10n.proFeatureTitle : null,
                              color: locked
                                  ? Theme.of(context).colorScheme.outline
                                  : primaryColor,
                              size: locked ? 18 : 24,
                            ),
                          ],
                        ),
                        onTap: () => _openReport(entry),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportCategory {
  final String title;
  final List<_ReportEntry> reports;
  const _ReportCategory({required this.title, required this.reports});
}

class _ReportEntry {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget screen;
  final Feature? proFeature;
  final String? permission;

  const _ReportEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.screen,
    this.proFeature,
    this.permission,
  });
}

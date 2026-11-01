import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
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
import 'activation_screen.dart';
import '../widgets/responsive.dart';
import 'audit_history_screen.dart';
import 'reports/advanced_inventory_analytics_screen.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_section_header.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  EntitlementState? _entitlement;

  @override
  void initState() {
    super.initState();
    LicenseService.instance
        .checkEntitlement(force: false)
        .then((e) { if (mounted) setState(() => _entitlement = e); })
        .catchError((_) {});
  }

  Future<void> _openReport(_ReportEntry entry) async {
    final feature = entry.proFeature;
    if (feature != null) {
      // Re-evaluate on every open so a running session cannot outlive expiry.
      try {
        final fresh = await LicenseService.instance.checkEntitlement(force: true);
        if (mounted) setState(() => _entitlement = fresh);
      } catch (_) {}
    }
    if (feature != null && !FeatureAccess.canAccess(feature, _entitlement)) {
      if (!mounted) return;
      final result = await ProUpgradeSheet.show(context, feature: feature);
      if (result == true && mounted) {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ActivationScreen()));
        if (!mounted) return;
        LicenseService.instance.invalidateCache();
        final e = await LicenseService.instance.checkEntitlement(force: true);
        if (mounted) setState(() => _entitlement = e);
      }
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => entry.screen));
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
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatSalesPurchases,
        reports: [
          _ReportEntry(
            icon: Icons.trending_up_rounded,
            color: Colors.green,
            title: l10n.salesReport,
            subtitle: l10n.reportSubtitleSales,
            screen: const SalesReportScreen(),
          ),
          _ReportEntry(
            icon: Icons.shopping_cart_outlined,
            color: Colors.orange,
            title: l10n.purchasesReport,
            subtitle: l10n.reportSubtitlePurchases,
            screen: const PurchasesReportScreen(),
            proFeature: Feature.advancedReports,
          ),
          _ReportEntry(
            icon: Icons.payments_outlined,
            color: Colors.teal,
            title: l10n.paymentsReport,
            subtitle: l10n.reportSubtitlePayments,
            screen: const PaymentsReportScreen(),
          ),
          _ReportEntry(
            icon: Icons.people_outlined,
            color: Colors.blue,
            title: l10n.customerReport,
            subtitle: l10n.reportSubtitleCustomers,
            screen: const CustomerReportScreen(),
          ),
          _ReportEntry(
            icon: Icons.store_outlined,
            color: Colors.deepPurple,
            title: l10n.supplierReport,
            subtitle: l10n.reportSubtitleSuppliers,
            screen: const SupplierReportScreen(),
            proFeature: Feature.advancedReports,
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatInventory,
        reports: [
          _ReportEntry(
            icon: Icons.warehouse_outlined,
            color: Colors.brown,
            title: l10n.inventoryReport,
            subtitle: l10n.reportSubtitleInventory,
            screen: const InventoryReportScreen(),
            proFeature: Feature.advancedReports,
          ),
          _ReportEntry(
            icon: Icons.notification_important_outlined,
            color: Colors.deepOrange,
            title: l10n.lowStockReport,
            subtitle: l10n.reportSubtitleLowStock,
            screen: const InventoryReportScreen(initialFilter: 'low_stock'),
            proFeature: Feature.advancedReports,
          ),
          _ReportEntry(
            icon: Icons.history_outlined,
            color: Colors.blueGrey,
            title: l10n.stockMovementsReport,
            subtitle: l10n.reportSubtitleMovements,
            screen: const StockMovementsScreen(),
            proFeature: Feature.advancedReports,
          ),
          _ReportEntry(
            icon: Icons.inventory_2_outlined,
            color: Colors.indigo,
            title: l10n.productReport,
            subtitle: l10n.reportSubtitleProducts,
            screen: const ProductReportScreen(),
            proFeature: Feature.advancedReports,
          ),
          _ReportEntry(
            icon: Icons.analytics_outlined,
            color: Colors.teal,
            title: l10n.advancedInventoryAnalytics,
            subtitle: l10n.reportSubtitleAdvancedAnalytics,
            screen: const AdvancedInventoryAnalyticsScreen(),
            proFeature: Feature.advancedReports,
          ),
        ],
      ),
      _ReportCategory(
        title: l10n.reportCatAudit,
        reports: [
          _ReportEntry(
            icon: Icons.history_edu_outlined,
            color: Colors.blueGrey,
            title: l10n.auditHistoryTitle,
            subtitle: l10n.reportSubtitleAudit,
            screen: const AuditHistoryScreen(),
            proFeature: Feature.inventoryAudit,
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
                    count: cat.reports.length,
                  ),
                ),
                ...cat.reports.map((entry) {
                  final locked = entry.proFeature != null &&
                      !FeatureAccess.canAccess(entry.proFeature!, _entitlement);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignTokens.cardRadius),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: entry.color.withValues(alpha: 0.12),
                          child: Icon(entry.icon, color: entry.color, size: 22),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (entry.proFeature != null) ...[
                              const ProBadge(),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              locked ? Icons.lock_outline : chevronIcon,
                              color: locked ? Colors.grey : primaryColor,
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

  const _ReportEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.screen,
    this.proFeature,
  });
}

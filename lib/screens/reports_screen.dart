import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../models/entitlement.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../widgets/pro_upgrade_sheet.dart';
import 'reports/customer_report_screen.dart';
import 'reports/inventory_report_screen.dart';
import 'reports/payments_report_screen.dart';
import 'reports/product_report_screen.dart';
import 'reports/purchases_report_screen.dart';
import 'reports/sales_report_screen.dart';
import 'reports/supplier_report_screen.dart';
import 'activation_screen.dart';

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

    final reports = [
      _ReportEntry(
        icon: Icons.trending_up_rounded,
        color: Colors.green,
        title: l10n.salesReport,
        screen: const SalesReportScreen(),
      ),
      _ReportEntry(
        icon: Icons.shopping_cart_outlined,
        color: Colors.orange,
        title: l10n.purchasesReport,
        screen: const PurchasesReportScreen(),
        proFeature: Feature.advancedReports,
      ),
      _ReportEntry(
        icon: Icons.payments_outlined,
        color: Colors.teal,
        title: l10n.paymentsReport,
        screen: const PaymentsReportScreen(),
      ),
      _ReportEntry(
        icon: Icons.people_outlined,
        color: Colors.blue,
        title: l10n.customerReport,
        screen: const CustomerReportScreen(),
      ),
      _ReportEntry(
        icon: Icons.store_outlined,
        color: Colors.deepPurple,
        title: l10n.supplierReport,
        screen: const SupplierReportScreen(),
        proFeature: Feature.advancedReports,
      ),
      _ReportEntry(
        icon: Icons.warehouse_outlined,
        color: Colors.brown,
        title: l10n.inventoryReport,
        screen: const InventoryReportScreen(),
        proFeature: Feature.advancedReports,
      ),
      _ReportEntry(
        icon: Icons.inventory_2_outlined,
        color: Colors.indigo,
        title: l10n.productReport,
        screen: const ProductReportScreen(),
        proFeature: Feature.advancedReports,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = reports[index];
          final locked = entry.proFeature != null &&
              !FeatureAccess.canAccess(entry.proFeature!, _entitlement);
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: entry.color.withValues(alpha: 0.12),
                child: Icon(entry.icon, color: entry.color, size: 22),
              ),
              title: Text(entry.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.proFeature != null) ...[
                    const ProBadge(),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    locked ? Icons.lock_outline : Icons.chevron_right,
                    color: locked ? Colors.grey : primaryColor,
                    size: locked ? 18 : 24,
                  ),
                ],
              ),
              onTap: () => _openReport(entry),
            ),
          );
        },
      ),
    );
  }
}

class _ReportEntry {
  final IconData icon;
  final Color color;
  final String title;
  final Widget screen;
  final Feature? proFeature;

  const _ReportEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.screen,
    this.proFeature,
  });
}

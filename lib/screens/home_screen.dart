import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/date_range_filter.dart';
import '../models/document.dart';
import '../models/entitlement.dart';
import '../services/feature_access.dart';
import '../services/license_service.dart';
import '../widgets/app_design_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_metric_card.dart';
import '../widgets/app_section_header.dart';
import '../widgets/pro_upgrade_sheet.dart';
import '../widgets/status_badge.dart';
import 'activation_screen.dart';
import 'business_setup_screen.dart';
import 'custom_document_screen.dart';
import 'document_detail_screen.dart';
import 'invoice_screen.dart';
import 'quick_sale_screen.dart';
import 'inventory_screen.dart';
import 'purchase_screen.dart';
import 'quotation_screen.dart';
import 'reports_screen.dart';
import 'voucher_screen.dart';
import 'notifications_inbox_screen.dart';
import '../services/app_ops_service.dart';
import '../widgets/responsive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Business? _business;
  List<Document> _recentDocuments = [];
  Map<String, dynamic> _dashboardData = {};
  DateRangeFilter _dateRange = DateRangeFilter.thisMonth();
  bool _loading = true;
  String? _error;
  EntitlementState? _entitlement;
  bool _freeModeBannerDismissed = false;

  static final _numFmt = NumberFormat('#,##0');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    AppOpsService.instance.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEntitlement();
      AppOpsService.instance.syncInbox();
    }
  }

  /// Re-evaluates the entitlement (not the cached one) and shows it.
  Future<EntitlementState?> _refreshEntitlement() async {
    try {
      final e = await LicenseService.instance.checkEntitlement(force: true);
      if (mounted) setState(() => _entitlement = e);
      return e;
    } catch (_) {
      return _entitlement;
    }
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final business = await db.getFirstBusiness();
      final results = await Future.wait([
        Future.value(business),
        db.getPeriodSummary(
          from: _dateRange.from,
          to: _dateRange.to,
          currencyCode: business?.currencyCode,
        ),
        db.getRecentDocuments(limit: 5),
      ]);

      // Load entitlement from cache (no I/O if already checked this session).
      LicenseService.instance
          .checkEntitlement(force: false)
          .then((e) {
            if (mounted) setState(() => _entitlement = e);
          })
          .catchError((_) {});

      if (!mounted) return;
      setState(() {
        _business = results[0] as Business?;
        _dashboardData = results[1] as Map<String, dynamic>;
        _recentDocuments = results[2] as List<Document>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  /// Open the activation screen and refresh entitlement on return.
  Future<void> _openActivationScreen() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
    );
    if (!mounted) return;
    LicenseService.instance.invalidateCache();
    _load();
  }

  /// Gate a Pro feature. Shows [ProUpgradeSheet] when access is denied,
  /// then routes to activation screen if the user chooses to enter a key.
  Future<void> _openProGated(
    Feature feature,
    Future<void> Function() open,
  ) async {
    // Never trust the entitlement cached when the screen loaded: it may have
    // expired since.
    final entitlement = await _refreshEntitlement();
    if (!mounted) return;
    if (FeatureAccess.canAccess(feature, entitlement)) {
      await open();
      return;
    }
    if (!mounted) return;
    final result = await ProUpgradeSheet.show(context, feature: feature);
    if (result == true && mounted) {
      await _openActivationScreen();
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _dateRange.from,
        end: _dateRange.to,
      ),
    );
    if (picked != null && mounted) {
      setState(
        () => _dateRange = DateRangeFilter.custom(picked.start, picked.end),
      );
      _load();
    }
  }

  void _showOtherDocumentsSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.createDocument,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: Text(l10n.purchase),
              trailing: const ProBadge(),
              onTap: () async {
                Navigator.pop(ctx);
                await _openProGated(
                  Feature.purchases,
                  () => _openScreen(const PurchaseScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined),
              title: Text(l10n.quotation),
              onTap: () {
                Navigator.pop(ctx);
                _openScreen(const QuotationScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_received),
              title: Text(l10n.paymentReceipt),
              onTap: () {
                Navigator.pop(ctx);
                _openScreen(
                  const VoucherScreen(type: VoucherType.paymentReceipt),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: Text(l10n.expenseVoucher),
              onTap: () {
                Navigator.pop(ctx);
                _openScreen(
                  const VoucherScreen(type: VoucherType.expenseVoucher),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.customDocument),
              onTap: () {
                Navigator.pop(ctx);
                _openScreen(const CustomDocumentScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: ResponsiveCenter(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.operationFailed),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
              ],
            ),
          ),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle), centerTitle: true),
        body: ResponsiveCenter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_center_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.welcomeFirstTime, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _openScreen(const BusinessSetupScreen()),
                      icon: const Icon(Icons.add_business),
                      label: Text(l10n.setupBusiness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currencySymbol = _business!.currencySymbol;
    final d = _dashboardData;
    final double sales = (d['sales'] as num?)?.toDouble() ?? 0;
    final double purchases = (d['purchases'] as num?)?.toDouble() ?? 0;
    final double paymentsIn = (d['paymentsIn'] as num?)?.toDouble() ?? 0;
    final double paymentsOut = (d['paymentsOut'] as num?)?.toDouble() ?? 0;
    final double customerOutstanding =
        (d['customerOutstanding'] as num?)?.toDouble() ?? 0;
    final double supplierPayable =
        (d['supplierPayable'] as num?)?.toDouble() ?? 0;
    final int totalProducts = (d['totalProducts'] as num?)?.toInt() ?? 0;
    final int lowStock = (d['lowStock'] as num?)?.toInt() ?? 0;
    final int outOfStock = (d['outOfStock'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_business!.name),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: AppOpsService.instance.unreadCount,
            builder: (context, unread, _) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: l10n.inboxTitle,
                onPressed: () async {
                  await _openScreen(const NotificationsInboxScreen());
                  AppOpsService.instance.refreshUnreadCount();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: l10n.reports,
            onPressed: () => _openScreen(const ReportsScreen()),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subscription status banner (trial countdown / renewal warning)
                if (_buildSubscriptionBanner(l10n) case final banner?) banner,

                // Quick actions
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openScreen(const QuickSaleScreen()),
                          icon: const Icon(Icons.point_of_sale),
                          label: Text(
                            l10n.posQuickSale,
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openScreen(const InvoiceScreen()),
                          icon: const Icon(Icons.receipt_long),
                          label: Text(
                            l10n.createInvoice,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showOtherDocumentsSheet,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.otherDocument),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                const SizedBox(height: 20),

                // Date range filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _dateChip(l10n.today, DateRangePreset.today, l10n),
                      const SizedBox(width: 6),
                      _dateChip(
                        l10n.last7Days,
                        DateRangePreset.last7Days,
                        l10n,
                      ),
                      const SizedBox(width: 6),
                      _dateChip(
                        l10n.thisMonth,
                        DateRangePreset.thisMonth,
                        l10n,
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: Text(
                          _dateRange.preset == DateRangePreset.custom
                              ? _dateRange.label(l10n)
                              : l10n.customRange,
                        ),
                        selected: _dateRange.preset == DateRangePreset.custom,
                        onSelected: (_) => _pickCustomRange(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Financial cards 2x2
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        l10n.salesPeriod,
                        '${_numFmt.format(sales)} $currencySymbol',
                        icon: Icons.trending_up_rounded,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        l10n.purchasesPeriod,
                        '${_numFmt.format(purchases)} $currencySymbol',
                        icon: Icons.shopping_cart_outlined,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        l10n.paymentsIn,
                        '${_numFmt.format(paymentsIn)} $currencySymbol',
                        icon: Icons.call_received_rounded,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        l10n.paymentsOut,
                        '${_numFmt.format(paymentsOut)} $currencySymbol',
                        icon: Icons.call_made_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Balance cards (all-time)
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        l10n.receivable,
                        '${_numFmt.format(customerOutstanding)} $currencySymbol',
                        icon: Icons.person_outlined,
                        color: customerOutstanding > 0
                            ? Theme.of(context).colorScheme.error
                            : Colors.grey,
                        subtitle: l10n.allTimeBalance,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        l10n.payable,
                        '${_numFmt.format(supplierPayable)} $currencySymbol',
                        icon: Icons.store_outlined,
                        color: supplierPayable > 0
                            ? Colors.deepOrange
                            : Colors.grey,
                        subtitle: l10n.allTimeBalance,
                      ),
                    ),
                  ],
                ),

                // Inventory status (only when there are tracked products)
                if (totalProducts > 0) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _openProGated(
                      Feature.inventory,
                      () => _openScreen(const InventoryScreen()),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.warehouse_outlined, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.inventorySummary,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (outOfStock > 0)
                              _badge(
                                '$outOfStock ${l10n.outOfStock}',
                                Colors.red,
                              ),
                            if (lowStock > 0) ...[
                              const SizedBox(width: 6),
                              _badge(
                                '$lowStock ${l10n.lowStock}',
                                Colors.orange,
                              ),
                            ],
                            if (outOfStock == 0 && lowStock == 0)
                              Text(
                                '$totalProducts ${l10n.trackedProducts}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              l10n.isArabic
                                  ? Icons.chevron_left
                                  : Icons.chevron_right,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Reports shortcut
                OutlinedButton.icon(
                  onPressed: () => _openScreen(const ReportsScreen()),
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: Text(l10n.viewReports),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),

                const SizedBox(height: 24),

                // Recent documents
                AppSectionHeader(
                  title: l10n.recentDocuments,
                  count: _recentDocuments.length,
                  padding: const EdgeInsets.only(bottom: 8),
                ),
                if (_recentDocuments.isEmpty)
                  AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.noDocuments,
                    actionLabel: l10n.createInvoice,
                    onAction: () => _openScreen(const InvoiceScreen()),
                  )
                else
                  ..._recentDocuments.map(
                    (doc) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: AppDesignTokens.br12,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                        boxShadow: AppDesignTokens.softShadow(context),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: AppDesignTokens.br8,
                          ),
                          child: Icon(_iconForType(doc.type), color: primaryColor, size: 20),
                        ),
                        title: Text(
                          doc.documentNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          doc.recipientName?.isNotEmpty == true
                              ? doc.recipientName!
                              : _dateFmt.format(doc.date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            StatusBadge(status: doc.status),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DocumentDetailScreen(documentId: doc.id!),
                          ),
                        ).then((_) => _load()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubscriptionBanner(AppLocalizations l10n) {
    final e = _entitlement;
    if (e == null) return null;

    String? message;
    Color bgColor = Colors.blue.shade50;
    Color textColor = Colors.blue.shade800;
    bool isWarning = false;
    bool dismissible = false;
    String? actionLabel;
    VoidCallback? onAction;

    switch (e.status) {
      case EntitlementStatus.trialActive:
        isWarning = e.trialDaysRemaining <= 5;
        message = '${e.trialDaysRemaining} ${l10n.daysLeftInTrial}';
        bgColor = isWarning ? Colors.amber.shade100 : Colors.green.shade50;
        textColor = isWarning ? Colors.amber.shade900 : Colors.green.shade800;
        actionLabel = l10n.enterActivationKeyAction;
        onAction = _openActivationScreen;
      case EntitlementStatus.licensed:
        if (e.licenseExpiresAt != null) {
          final daysLeft = e.licenseExpiresAt!
              .difference(DateTime.now())
              .inDays;
          if (daysLeft <= 14) {
            message =
                '${l10n.licenseExpiresOn} ${e.licenseExpiresAt!.toLocal().toString().split(' ').first}';
            bgColor = Colors.amber.shade100;
            textColor = Colors.amber.shade900;
            isWarning = true;
            actionLabel = l10n.enterActivationKeyAction;
            onAction = _openActivationScreen;
          }
        }
      case EntitlementStatus.trialExpired:
      case EntitlementStatus.licenseExpired:
        if (_freeModeBannerDismissed) return null;
        dismissible = true;
        message = l10n.freeModeBannerMsg;
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF3730A3);
        actionLabel = l10n.enterActivationKeyAction;
        onAction = _openActivationScreen;
      case EntitlementStatus.licenseRevoked:
        if (_freeModeBannerDismissed) return null;
        dismissible = true;
        message = l10n.freeModeBannerMsg;
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        isWarning = true;
        actionLabel = l10n.enterActivationKeyAction;
        onAction = _openActivationScreen;
    }

    if (message == null) return null;

    // Pastel banners are for light mode; in dark mode tint the surface
    // with the same hue and lighten the text instead.
    if (Theme.of(context).brightness == Brightness.dark) {
      bgColor = Color.alphaBlend(
        textColor.withValues(alpha: 0.22),
        Theme.of(context).colorScheme.surface,
      );
      textColor = Color.lerp(textColor, Colors.white, 0.6)!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 18,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
          if (dismissible) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => _freeModeBannerDismissed = true),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateChip(
    String label,
    DateRangePreset preset,
    AppLocalizations l10n,
  ) {
    final selected = _dateRange.preset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        final newRange = switch (preset) {
          DateRangePreset.today => DateRangeFilter.today(),
          DateRangePreset.last7Days => DateRangeFilter.last7Days(),
          DateRangePreset.thisMonth => DateRangeFilter.thisMonth(),
          DateRangePreset.previousMonth => DateRangeFilter.previousMonth(),
          DateRangePreset.custom => _dateRange,
        };
        setState(() => _dateRange = newRange);
        _load();
      },
    );
  }

  Widget _statCard(
    String title,
    String value, {
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return AppMetricCard(
      title: title,
      value: value,
      icon: icon,
      color: color == Colors.grey ? null : color,
      subtitle: subtitle,
      compact: true,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'invoice' => Icons.receipt_long,
      'purchase' => Icons.shopping_cart_outlined,
      'quotation' => Icons.request_quote,
      'payment_receipt' => Icons.call_received,
      'expense_voucher' => Icons.money_off,
      _ => Icons.description,
    };
  }
}

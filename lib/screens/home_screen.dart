import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/date_range_filter.dart';
import '../models/document.dart';
import '../models/document_status.dart';
import 'business_setup_screen.dart';
import 'custom_document_screen.dart';
import 'document_detail_screen.dart';
import 'invoice_screen.dart';
import 'inventory_screen.dart';
import 'purchase_screen.dart';
import 'quotation_screen.dart';
import 'reports_screen.dart';
import 'voucher_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Business? _business;
  List<Document> _recentDocuments = [];
  Map<String, dynamic> _dashboardData = {};
  DateRangeFilter _dateRange = DateRangeFilter.thisMonth();
  bool _loading = true;
  String? _error;

  static final _numFmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getFirstBusiness(),
        db.getPeriodSummary(from: _dateRange.from, to: _dateRange.to),
        db.getRecentDocuments(limit: 5),
      ]);

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

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _dateRange.from, end: _dateRange.to),
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = DateRangeFilter.custom(picked.start, picked.end));
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
              child: Text(l10n.createDocument,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: Text(l10n.purchase),
              onTap: () { Navigator.pop(ctx); _openScreen(const PurchaseScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined),
              title: Text(l10n.quotation),
              onTap: () { Navigator.pop(ctx); _openScreen(const QuotationScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.call_received),
              title: Text(l10n.paymentReceipt),
              onTap: () { Navigator.pop(ctx); _openScreen(const VoucherScreen(type: VoucherType.paymentReceipt)); },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: Text(l10n.expenseVoucher),
              onTap: () { Navigator.pop(ctx); _openScreen(const VoucherScreen(type: VoucherType.expenseVoucher)); },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.customDocument),
              onTap: () { Navigator.pop(ctx); _openScreen(const CustomDocumentScreen()); },
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.operationFailed),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_business == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle), centerTitle: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business_center_outlined, size: 64, color: Colors.grey),
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
      );
    }

    final currencySymbol = _business!.currencySymbol;
    final d = _dashboardData;
    final double sales = (d['sales'] as num?)?.toDouble() ?? 0;
    final double purchases = (d['purchases'] as num?)?.toDouble() ?? 0;
    final double paymentsIn = (d['paymentsIn'] as num?)?.toDouble() ?? 0;
    final double paymentsOut = (d['paymentsOut'] as num?)?.toDouble() ?? 0;
    final double customerOutstanding = (d['customerOutstanding'] as num?)?.toDouble() ?? 0;
    final double supplierPayable = (d['supplierPayable'] as num?)?.toDouble() ?? 0;
    final int totalProducts = (d['totalProducts'] as num?)?.toInt() ?? 0;
    final int lowStock = (d['lowStock'] as num?)?.toInt() ?? 0;
    final int outOfStock = (d['outOfStock'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_business!.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: l10n.reports,
            onPressed: () => _openScreen(const ReportsScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Quick actions
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _openScreen(const InvoiceScreen()),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(l10n.createInvoice,
                      style: const TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white),
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
                    _dateChip(l10n.last7Days, DateRangePreset.last7Days, l10n),
                    const SizedBox(width: 6),
                    _dateChip(l10n.thisMonth, DateRangePreset.thisMonth, l10n),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: Text(_dateRange.preset == DateRangePreset.custom
                          ? _dateRange.label(l10n)
                          : l10n.customRange),
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
                      color: supplierPayable > 0 ? Colors.deepOrange : Colors.grey,
                      subtitle: l10n.allTimeBalance,
                    ),
                  ),
                ],
              ),

              // Inventory status (only when there are tracked products)
              if (totalProducts > 0) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _openScreen(const InventoryScreen()),
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (outOfStock > 0)
                            _badge('$outOfStock ${l10n.outOfStock}', Colors.red),
                          if (lowStock > 0) ...[
                            const SizedBox(width: 6),
                            _badge('$lowStock ${l10n.lowStock}', Colors.orange),
                          ],
                          if (outOfStock == 0 && lowStock == 0)
                            Text('$totalProducts ${l10n.trackedProducts}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              // Recent documents
              Text(l10n.recentDocuments,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_recentDocuments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(l10n.noDocuments, style: const TextStyle(color: Colors.grey))),
                )
              else
                ..._recentDocuments.map(
                  (doc) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: ListTile(
                      leading: Icon(_iconForType(doc.type), color: primaryColor),
                      title: Text(doc.documentNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${doc.recipientName ?? ''} · ${_numFmt.format(doc.total)} ${doc.currencySymbol}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: doc.status == DocumentStatus.draft
                          ? const Icon(Icons.edit_outlined, size: 16, color: Colors.grey)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(documentId: doc.id!)),
                      ).then((_) => _load()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateChip(String label, DateRangePreset preset, AppLocalizations l10n) {
    final selected = _dateRange.preset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        final newRange = switch (preset) {
          DateRangePreset.today => DateRangeFilter.today(),
          DateRangePreset.last7Days => DateRangeFilter.last7Days(),
          DateRangePreset.thisMonth => DateRangeFilter.thisMonth(),
          DateRangePreset.custom => _dateRange,
        };
        setState(() => _dateRange = newRange);
        _load();
      },
    );
  }

  Widget _statCard(String title, String value,
      {required IconData icon, required Color color, String? subtitle}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color == Colors.grey ? const Color(0xFF202124) : color)),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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

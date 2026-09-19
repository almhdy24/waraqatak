import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/document.dart';
import 'business_setup_screen.dart';
import 'custom_document_screen.dart';
import 'document_detail_screen.dart';
import 'invoice_screen.dart';
import 'purchase_screen.dart';
import 'quotation_screen.dart';
import 'voucher_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Business? _business;
  List<Document> _recentDocuments = [];
  Map<String, double> _summary = {'sales': 0, 'outstanding': 0};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final business = await db.getFirstBusiness();
      final docs = await db.getRecentDocuments(limit: 5);
      final summary = await db.getTodaySummary();

      if (!mounted) return;
      setState(() {
        _business = business;
        _recentDocuments = docs;
        _summary = summary;
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

  void _showOtherDocumentsSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.createDocument, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(l10n.purchase),
                onTap: () {
                  Navigator.pop(context);
                  _openScreen(const PurchaseScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: Text(l10n.quotation),
                onTap: () {
                  Navigator.pop(context);
                  _openScreen(const QuotationScreen());
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_received),
                title: Text(l10n.paymentReceipt),
                onTap: () {
                  Navigator.pop(context);
                  _openScreen(const VoucherScreen(type: VoucherType.paymentReceipt));
                },
              ),
              ListTile(
                leading: const Icon(Icons.money_off),
                title: Text(l10n.expenseVoucher),
                onTap: () {
                  Navigator.pop(context);
                  _openScreen(const VoucherScreen(type: VoucherType.expenseVoucher));
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.customDocument),
                onTap: () {
                  Navigator.pop(context);
                  _openScreen(const CustomDocumentScreen());
                },
              ),
            ],
          ),
        );
      },
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
              ElevatedButton(onPressed: _load, child: Text(l10n.cancel)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_business!.name),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _openScreen(const InvoiceScreen()),
                icon: const Icon(Icons.receipt_long),
                label: Text(l10n.createInvoice, style: const TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _summaryCard(l10n.salesToday, _summary['sales'] ?? 0, currencySymbol),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryCard(l10n.outstanding, _summary['outstanding'] ?? 0, currencySymbol, color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.recentDocuments, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentDocuments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(l10n.noDocuments)),
              )
            else
              ..._recentDocuments.map(
                (doc) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_iconForType(doc.type)),
                    title: Text(doc.documentNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${doc.recipientName ?? ''} - ${NumberFormat('#,##0').format(doc.total)} ${doc.currencySymbol}'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: doc.id!))).then((_) => _load()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String title, double value, String currencySymbol, {Color? color}) {
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
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Text(
              '${NumberFormat('#,##0').format(value)} $currencySymbol',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF202124)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'invoice': return Icons.receipt_long;
      case 'quotation': return Icons.request_quote;
      case 'payment_receipt': return Icons.call_received;
      case 'expense_voucher': return Icons.money_off;
      case 'custom': return Icons.description;
      default: return Icons.description;
    }
  }
}
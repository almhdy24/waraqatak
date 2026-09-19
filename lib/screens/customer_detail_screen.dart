import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import 'contact_form_screen.dart';
import 'document_detail_screen.dart';
import 'invoice_screen.dart';
import 'purchase_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Contact contact;
  const CustomerDetailScreen({super.key, required this.contact});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  List<Document>? _documents;
  Business? _business;
  double _outstanding = 0;
  String? _error;

  bool get _isSupplier => widget.contact.type == 'supplier';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _documents = null;
      _business = null;
      _outstanding = 0;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final business = await db.getFirstBusiness();
      final documents = await db.getDocumentsByContact(widget.contact.id!);
      final docType = _isSupplier ? 'purchase' : 'invoice';
      final outstanding = await db.getContactOutstanding(widget.contact.id!, docType);

      if (!mounted) return;
      setState(() {
        _business = business;
        _documents = documents;
        _outstanding = outstanding;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _editContact() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ContactFormScreen(contact: widget.contact)),
    );
    if (result == true && mounted) {
      _load();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencySymbol = _business?.currencySymbol ?? 'ج.س';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l10n.edit, onPressed: _editContact),
        ],
      ),
      body: _buildBody(context, l10n, currencySymbol),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, String currencySymbol) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.operationFailed),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_documents == null || _business == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final documents = _documents!;
    final relevantType = _isSupplier ? 'purchase' : 'invoice';
    final relevantDocs = documents.where((d) => d.type == relevantType).toList();
    final totalAmount = relevantDocs.fold<double>(0, (sum, d) => sum + d.total);
    final totalPaid = relevantDocs.fold<double>(0, (sum, d) => sum + d.paid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE5E7EB))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        _isSupplier ? Icons.store : Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.contact.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _isSupplier ? l10n.supplier : l10n.customer,
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.contact.active)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(l10n.inactive, style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
                if (widget.contact.phone != null ||
                    widget.contact.email != null ||
                    widget.contact.address != null ||
                    widget.contact.notes != null) ...[
                  const Divider(height: 24),
                  if (widget.contact.phone != null) ...[
                    Row(children: [
                      const Icon(Icons.phone_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(widget.contact.phone!),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (widget.contact.email != null) ...[
                    Row(children: [
                      const Icon(Icons.email_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(widget.contact.email!),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (widget.contact.address != null) ...[
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.contact.address!)),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (widget.contact.notes != null)
                    Row(children: [
                      const Icon(Icons.notes_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.contact.notes!)),
                    ]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE5E7EB))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.documents,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _summaryRow(
                  _isSupplier ? l10n.purchase : l10n.invoice,
                  NumberFormat('#,##0').format(totalAmount),
                  currencySymbol,
                ),
                const SizedBox(height: 8),
                _summaryRow(l10n.paid, NumberFormat('#,##0').format(totalPaid), currencySymbol),
                const SizedBox(height: 8),
                _summaryRow(
                  _isSupplier ? l10n.payable : l10n.receivable,
                  NumberFormat('#,##0').format(_outstanding),
                  currencySymbol,
                  valueColor: _outstanding > 0 ? Theme.of(context).colorScheme.error : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _isSupplier
                    ? PurchaseScreen(preselectedContact: widget.contact)
                    : InvoiceScreen(preselectedContact: widget.contact),
              ),
            ).then((_) => _load()),
            icon: Icon(_isSupplier ? Icons.shopping_cart_outlined : Icons.receipt_long),
            label: Text(_isSupplier ? l10n.newPurchase : l10n.createInvoice),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                  fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.recentDocuments,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (documents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(l10n.noDocuments)),
          )
        else
          ...documents.map(
            (doc) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_iconForType(doc.type)),
                title: Text(doc.documentNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(doc.date)} - ${NumberFormat('#,##0').format(doc.total)} ${doc.currencySymbol}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DocumentDetailScreen(documentId: doc.id!)),
                ).then((_) => _load()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, String currencySymbol,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '$value $currencySymbol',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF202124)),
        ),
      ],
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'invoice':
        return Icons.receipt_long;
      case 'quotation':
        return Icons.request_quote;
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'payment_receipt':
        return Icons.call_received;
      case 'expense_voucher':
        return Icons.money_off;
      case 'custom':
        return Icons.description;
      default:
        return Icons.description;
    }
  }
}

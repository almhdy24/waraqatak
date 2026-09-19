import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';
import '../services/document_service.dart';
import '../services/pdf_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/status_badge.dart';
import 'edit_document_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final int documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _document;
  Business? _business;
  Contact? _contact;
  List<DocumentItem> _items = [];
  List<DocumentPayment> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final doc = await db.getDocumentById(widget.documentId);
      if (doc == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final business = await db.getFirstBusiness();
      final contact = doc.contactId != null ? await db.getContactById(doc.contactId!) : null;
      final items    = await db.getDocumentItems(doc.id!);
      final payments = await db.getDocumentPayments(doc.id!);

      if (!mounted) return;
      setState(() {
        _document = doc;
        _business = business;
        _contact = contact;
        _items = items;
        _payments = payments;
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

  Future<void> _sharePdf() async {
    if (_document == null || _business == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await PdfService.sharePdf(
        doc: _document!,
        business: _business!,
        contact: _contact,
        items: _items,
        l10n: l10n,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: $e')),
      );
    }
  }

  Future<void> _printPdf() async {
    if (_document == null || _business == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await PdfService.generateDocumentPdf(
        doc: _document!,
        business: _business!,
        contact: _contact,
        items: _items,
        l10n: l10n,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${_document!.documentNumber}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.operationFailed}: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteDocumentMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteDocument(_document!.id!);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.operationFailed}: $e')),
        );
      }
    }
  }

  Future<void> _cancelDocument() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmCancel),
        content: Text(l10n.cancelDocumentMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.cancelDocument),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DocumentService.cancelDocument(_document!.id!);
        if (!mounted) return;
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.operationFailed}: $e')),
        );
      }
    }
  }

  Future<void> _showRecordPaymentSheet() async {
    final l10n = AppLocalizations.of(context);
    final doc = _document!;
    final amountController = TextEditingController(
      text: doc.remaining.toStringAsFixed(2),
    );
    String? selectedMethod;
    final allowedMethods = CurrencyUtils.getPaymentMethodsForCurrency(doc.currencyCode);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.recordPayment,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('${l10n.remaining}: ${NumberFormat('#,##0.00').format(doc.remaining)} ${doc.currencySymbol}',
                      style: const TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.paymentAmountLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allowedMethods.map((method) {
                      final label = CurrencyUtils.getPaymentMethodLabel(method, l10n);
                      return ChoiceChip(
                        label: Text(label),
                        selected: selectedMethod == method,
                        onSelected: (_) => setSheetState(() => selectedMethod = method),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      if (amount <= 0 || amount > doc.remaining) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.invalidAmount)),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext);
                      try {
                        await DocumentService.recordPayment(
                          documentId: doc.id!,
                          amount: amount,
                          paymentMethod: selectedMethod,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.paymentRecorded)),
                        );
                        _load();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${l10n.operationFailed}: $e')),
                        );
                      }
                    },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _document == null || _business == null) {
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

    final doc = _document!;
    final currencySymbol = doc.currencySymbol;
    final typeLabel = _documentTypeLabel(doc.type, l10n);
    final isCancelled      = doc.status == DocumentStatus.cancelled;
    final canRecordPayment = doc.type == 'invoice' &&
        (doc.status == DocumentStatus.issued ||
         doc.status == DocumentStatus.partiallyPaid);
    final canCancel = !isCancelled;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.documentNumber),
        centerTitle: true,
        actions: [
          if (!isCancelled)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditDocumentScreen(documentId: doc.id!)),
              ).then((_) => _load()),
            ),
          IconButton(icon: const Icon(Icons.share_outlined), tooltip: l10n.sharePdf, onPressed: _sharePdf),
          IconButton(icon: const Icon(Icons.print_outlined), tooltip: l10n.print, onPressed: _printPdf),
          if (canCancel)
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'cancel') _cancelDocument(); },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'cancel', child: Text(l10n.cancelDocument, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ],
            ),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: _delete),
        ],
      ),
      floatingActionButton: canRecordPayment
          ? FloatingActionButton.extended(
              onPressed: _showRecordPaymentSheet,
              icon: const Icon(Icons.add),
              label: Text(l10n.recordPayment),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(typeLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ),
                      StatusBadge(status: doc.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${l10n.date}: ${DateFormat('dd/MM/yyyy').format(doc.date)}'),
                  if (doc.type == 'quotation' && doc.validUntil != null)
                    Text('${l10n.validUntil}: ${DateFormat('dd/MM/yyyy').format(doc.validUntil!)}'),
                  if ((doc.type == 'payment_receipt' || doc.type == 'expense_voucher') && doc.paymentMethod != null)
                    Text('${l10n.paymentMethod}: ${CurrencyUtils.getPaymentMethodLabel(doc.paymentMethod!, l10n)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_contact != null || doc.recipientName != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.customerOrParty, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_contact?.name ?? doc.recipientName ?? ''),
                    if (_contact?.phone != null || doc.recipientPhone != null)
                      Text('${l10n.phone}: ${_contact?.phone ?? doc.recipientPhone}'),
                    if (_contact?.address != null)
                      Text('${l10n.address}: ${_contact!.address}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_items.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.products, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(item.description)),
                          Text('${item.quantity} × ${item.price} = ${item.total}'),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _totalRow(l10n.subtotal, doc.subtotal, currencySymbol),
                  if (doc.discount > 0) _totalRow(l10n.discount, doc.discount, currencySymbol),
                  if (doc.taxAmount > 0) _totalRow('${l10n.tax} (${doc.taxRate.toStringAsFixed(0)}%)', doc.taxAmount, currencySymbol),
                  _totalRow(l10n.total, doc.total, currencySymbol, bold: true),
                  if (doc.type == 'invoice') ...[
                    _totalRow(l10n.paid, doc.paid, currencySymbol),
                    _totalRow(l10n.remaining, doc.remaining, currencySymbol, bold: true, color: Theme.of(context).colorScheme.error),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (doc.notes != null && doc.notes!.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.notes, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(doc.notes!),
                  ],
                ),
              ),
            ),
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE5E7EB))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.paymentHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._payments.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(p.date),
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                          Text(
                            '${NumberFormat('#,##0.00').format(p.amount)} $currencySymbol',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
          // Extra bottom padding so FAB doesn't overlap last card
          if (canRecordPayment) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, String currencySymbol, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${NumberFormat('#,##0.00').format(value)} $currencySymbol',
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? const Color(0xFF202124)),
          ),
        ],
      ),
    );
  }

  String _documentTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'invoice': return l10n.invoice;
      case 'quotation': return l10n.quotation;
      case 'payment_receipt': return l10n.paymentReceipt;
      case 'expense_voucher': return l10n.expenseVoucher;
      case 'custom': return l10n.customDocument;
      default: return type;
    }
  }
}

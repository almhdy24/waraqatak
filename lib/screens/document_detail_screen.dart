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
  Document? _relatedDocument;
  Document? _convertedInvoice;
  List<String> _paymentMethods = CurrencyUtils.defaultMethods;
  bool _loading = true;
  String? _error;

  static final _fmt = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

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

      final configuredMethods = await CurrencyUtils.getConfiguredMethods();

      final futures = await Future.wait([
        db.getFirstBusiness(),
        if (doc.contactId != null) db.getContactById(doc.contactId!) else Future.value(null),
        db.getDocumentItems(doc.id!),
        db.getDocumentPayments(doc.id!),
        if (doc.relatedDocumentId != null)
          db.getDocumentById(doc.relatedDocumentId!)
        else
          Future.value(null),
        if (doc.type == 'quotation')
          db.getConvertedInvoice(doc.id!)
        else
          Future.value(null),
      ]);

      if (!mounted) return;
      setState(() {
        _document = doc;
        _business = futures[0] as Business?;
        _contact = futures[1] as Contact?;
        _items = (futures[2] as List).cast<DocumentItem>();
        _payments = (futures[3] as List).cast<DocumentPayment>();
        _relatedDocument = futures[4] as Document?;
        _convertedInvoice = doc.type == 'quotation' ? futures[5] as Document? : null;
        _paymentMethods = configuredMethods;
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
        relatedDocument: _relatedDocument,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
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
        relatedDocument: _relatedDocument,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${_document!.documentNumber}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteDocumentMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
      }
    }
  }

  Future<void> _cancelDocument() async {
    final l10n = AppLocalizations.of(context);
    final doc = _document!;
    final isReceipt = doc.type == 'payment_receipt';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmCancel),
        content: Text(isReceipt ? l10n.cancelReceiptMessage : l10n.cancelDocumentMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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
        await DocumentService.cancelDocument(doc.id!);
        if (!mounted) return;
        final msg = isReceipt ? l10n.paymentReversed : l10n.operationSuccessful;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
      }
    }
  }

  Future<void> _issueDocument() async {
    final l10n = AppLocalizations.of(context);
    try {
      await DocumentService.issueDocument(_document!.id!);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
    }
  }

  Future<void> _convertToInvoice() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.convertToInvoice),
        content: Text(l10n.convertConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.convertToInvoice),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final invoiceId = await DocumentService.convertQuotationToInvoice(_document!.id!);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: invoiceId)),
        ).then((_) => _load());
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
      }
    }
  }

  Future<void> _copyDocument() async {
    final l10n = AppLocalizations.of(context);
    try {
      final newId = await DocumentService.copyDocument(_document!.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.documentCopied),
        action: SnackBarAction(
          label: l10n.open,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DocumentDetailScreen(documentId: newId)),
            );
          },
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
    }
  }

  Future<void> _showRecordPaymentSheet() async {
    final l10n = AppLocalizations.of(context);
    final doc = _document!;
    final amountController = TextEditingController(text: doc.remaining.toStringAsFixed(2));
    String? selectedMethod = _paymentMethods.isNotEmpty ? _paymentMethods.first : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.recordPayment,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.remaining}: ${_fmt.format(doc.remaining)} ${doc.currencySymbol}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.paymentAmountLabel,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixText: doc.currencySymbol,
                        ),
                        autofocus: true,
                      ),
                      if (_paymentMethods.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _paymentMethods.map((m) {
                            return ChoiceChip(
                              label: Text(CurrencyUtils.getPaymentMethodLabel(m, l10n)),
                              selected: selectedMethod == m,
                              onSelected: (_) => setSheet(() => selectedMethod = m),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0 || amount > doc.remaining) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
                            return;
                          }
                          Navigator.pop(sheetCtx);
                          try {
                            final receiptId = await DocumentService.recordPayment(
                              documentId: doc.id!,
                              amount: amount,
                              paymentMethod: selectedMethod,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.paymentRecorded),
                              action: SnackBarAction(
                                label: l10n.viewReceipt,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DocumentDetailScreen(documentId: receiptId),
                                    ),
                                  );
                                },
                              ),
                            ));
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('${l10n.operationFailed}: $e')));
                          }
                        },
                        child: Text(l10n.recordPayment),
                      ),
                    ],
                  ),
                ),
              ],
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

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_error != null || _document == null || _business == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(l10n.operationFailed),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final doc = _document!;
    final sym = doc.currencySymbol;
    final typeLabel = _typeLabel(doc.type, l10n);
    final isCancelled   = doc.status == DocumentStatus.cancelled;
    final isDraft       = doc.status == DocumentStatus.draft;
    final isInvoice     = doc.type == 'invoice';
    final isPurchase    = doc.type == 'purchase';
    final isQuotation   = doc.type == 'quotation';
    final isReceipt     = doc.type == 'payment_receipt';
    final canRecordPay  = (isInvoice || isPurchase) &&
        (doc.status == DocumentStatus.issued || doc.status == DocumentStatus.partiallyPaid);
    final canIssue      = isDraft && (isInvoice || isQuotation || isPurchase);
    final canConvert    = isQuotation && !isCancelled && _convertedInvoice == null;
    final canCancel     = !isCancelled;
    final canEdit       = !isCancelled;

    // FAB priority: record payment > issue > convert
    Widget? fab;
    if (canRecordPay) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_pay',
        onPressed: _showRecordPaymentSheet,
        icon: const Icon(Icons.add),
        label: Text(l10n.recordPayment),
      );
    } else if (canIssue) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_issue',
        onPressed: _issueDocument,
        icon: const Icon(Icons.publish_rounded),
        label: Text(isInvoice ? l10n.issueInvoice : (isPurchase ? l10n.finalizePurchase : l10n.issueDocument)),
      );
    } else if (canConvert) {
      fab = FloatingActionButton.extended(
        heroTag: 'fab_convert',
        onPressed: _convertToInvoice,
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(l10n.convertToInvoice),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.documentNumber),
        centerTitle: true,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditDocumentScreen(documentId: doc.id!)),
              ).then((_) => _load()),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: l10n.sharePdf,
            onPressed: _sharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: l10n.print,
            onPressed: _printPdf,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'copy') _copyDocument();
              if (v == 'cancel') _cancelDocument();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(children: [
                  const Icon(Icons.copy_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.copyDocument),
                ]),
              ),
              if (canCancel)
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(children: [
                    Icon(Icons.block_outlined, size: 20, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Text(l10n.cancelDocument,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ]),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 10),
                  Text(l10n.delete,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: fab,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── Header card ──────────────────────────────────
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(typeLabel,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
                StatusBadge(status: doc.status),
              ]),
              const SizedBox(height: 8),
              _infoRow(l10n.date, _dateFmt.format(doc.date)),
              if (isQuotation && doc.validUntil != null)
                _infoRow(l10n.validUntil, _dateFmt.format(doc.validUntil!)),
              if (isReceipt && doc.paymentMethod != null)
                _infoRow(l10n.paymentMethod,
                    CurrencyUtils.getPaymentMethodLabel(doc.paymentMethod!, l10n)),
            ],
          )),

          // ── Relationship cards ───────────────────────────
          if (isReceipt && _relatedDocument != null) ...[
            const SizedBox(height: 10),
            _relatedCard(
              icon: Icons.receipt_long_rounded,
              label: l10n.relatedInvoice,
              docNumber: _relatedDocument!.documentNumber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: _relatedDocument!.id!),
                ),
              ).then((_) => _load()),
            ),
          ],
          if (isInvoice && _relatedDocument != null && _relatedDocument!.type == 'quotation') ...[
            const SizedBox(height: 10),
            _relatedCard(
              icon: Icons.request_quote_rounded,
              label: l10n.sourceQuotation,
              docNumber: _relatedDocument!.documentNumber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: _relatedDocument!.id!),
                ),
              ).then((_) => _load()),
            ),
          ],
          if (isQuotation && _convertedInvoice != null) ...[
            const SizedBox(height: 10),
            _relatedCard(
              icon: Icons.receipt_long_rounded,
              label: l10n.convertedToInvoice,
              docNumber: _convertedInvoice!.documentNumber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentDetailScreen(documentId: _convertedInvoice!.id!),
                ),
              ).then((_) => _load()),
            ),
          ],

          // ── Customer card ────────────────────────────────
          if (_contact != null || doc.recipientName != null) ...[
            const SizedBox(height: 10),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.customerOrParty,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_contact?.name ?? doc.recipientName ?? '',
                    style: const TextStyle(fontSize: 15)),
                if ((_contact?.phone ?? doc.recipientPhone) != null)
                  _infoRow(l10n.phone, _contact?.phone ?? doc.recipientPhone!),
                if (_contact?.address != null && _contact!.address!.isNotEmpty)
                  _infoRow(l10n.address, _contact!.address!),
              ],
            )),
          ],

          // ── Items card ───────────────────────────────────
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 10),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.items,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(item.description)),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmt.format(item.quantity)} × ${_fmt.format(item.price)}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      ),
                    ],
                  ),
                )),
              ],
            )),
          ],

          // ── Totals card ──────────────────────────────────
          const SizedBox(height: 10),
          _card(Column(
            children: [
              _totalRow(l10n.subtotal, doc.subtotal, sym),
              if (doc.discount > 0) _totalRow(l10n.discount, doc.discount, sym),
              if (doc.taxAmount > 0)
                _totalRow('${l10n.tax} (${doc.taxRate.toStringAsFixed(0)}%)', doc.taxAmount, sym),
              _totalRow(l10n.total, doc.total, sym, bold: true),
              if (isInvoice) ...[
                _totalRow(l10n.paid, doc.paid, sym),
                _totalRow(
                  l10n.remaining,
                  doc.remaining,
                  sym,
                  bold: true,
                  color: doc.remaining > 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.secondary,
                ),
              ],
              if (isReceipt)
                _totalRow(l10n.amount, doc.total, sym, bold: true),
            ],
          )),

          // ── Notes card ───────────────────────────────────
          if (doc.notes != null && doc.notes!.isNotEmpty && !isReceipt) ...[
            const SizedBox(height: 10),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.notes,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(doc.notes!),
              ],
            )),
          ],

          // ── Payment history card ──────────────────────────
          if (isInvoice) ...[
            const SizedBox(height: 10),
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.paymentHistory,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_payments.isEmpty)
                  Text(l10n.noPaymentsYet,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13))
                else
                  ..._payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_dateFmt.format(p.date),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12)),
                              if (p.paymentMethod != null)
                                Text(
                                  CurrencyUtils.getPaymentMethodLabel(p.paymentMethod!, l10n),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${_fmt.format(p.amount)} $sym',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (p.receiptDocumentId != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentDetailScreen(
                                      documentId: p.receiptDocumentId!,
                                    ),
                                  ),
                                ).then((_) => _load()),
                                child: Icon(
                                  Icons.receipt_outlined,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  )),
              ],
            )),
          ],

          if (fab != null) const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _relatedCard({
    required IconData icon,
    required String label,
    required String docNumber,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
                    children: [
                      TextSpan(text: '$label: ',
                          style: const TextStyle(color: Color(0xFF6B7280))),
                      TextSpan(text: docNumber,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: colors.primary)),
                    ],
                  ),
                ),
              ),
              Icon(
                Directionality.of(context).index == 0
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(color: muted, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, String sym,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${_fmt.format(value)} $sym', style: style),
        ],
      ),
    );
  }

  String _typeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'invoice'         => l10n.invoice,
      'purchase'        => l10n.purchase,
      'quotation'       => l10n.quotation,
      'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      'custom'          => l10n.customDocument,
      _                 => type,
    };
  }
}

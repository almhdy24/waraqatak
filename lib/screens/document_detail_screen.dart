import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../database/database_helper.dart';
import '../localization/app_localizations.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';
import '../services/access/access_guard.dart';
import '../services/access/permission_registry.dart';
import '../services/document_service.dart';
import '../services/pdf_service.dart';
import '../models/payment_method.dart';
import '../utils/currency_utils.dart';
import '../utils/error_utils.dart';
import '../utils/format_utils.dart';
import '../utils/money_utils.dart';
import '../utils/number_input.dart';
import '../widgets/amount_field.dart';
import '../widgets/status_badge.dart';
import 'customer_detail_screen.dart';
import 'edit_document_screen.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/app_status_colors.dart';
import '../widgets/cancel_paid_document_dialog.dart';
import '../widgets/responsive.dart';

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
  List<PaymentMethod> _enabledMethods = [];
  List<PaymentMethod> _allMethods = [];
  Map<String, dynamic>? _refundStatusInfo;
  bool _isAllocatedVoucher = false;
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
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.show(
            context,
            l10n.documentNotFoundDesc,
            severity: AppSnackBarSeverity.warning,
          );
          Navigator.pop(context);
        }
        return;
      }

      final enabledMethods = await DatabaseHelper.instance
          .getEnabledPaymentMethods();
      final allMethods = await DatabaseHelper.instance.getPaymentMethods();

      final futures = await Future.wait([
        db.getFirstBusiness(),
        if (doc.contactId != null)
          db.getContactById(doc.contactId!)
        else
          Future.value(null),
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

      Map<String, dynamic>? refundInfo;
      if (doc.status == DocumentStatus.cancelled && doc.paid > 0) {
        refundInfo = await DocumentService.getLatestDocumentRefundStatus(
          doc.id!,
        );
      }

      bool isAllocatedVoucher = false;
      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        final hasAlloc = await db.hasActiveAllocations(doc.id!);
        isAllocatedVoucher = hasAlloc || doc.relatedDocumentId != null;
      }

      if (!mounted) return;
      setState(() {
        _document = doc;
        _business = futures[0] as Business?;
        _contact = futures[1] as Contact?;
        _items = (futures[2] as List).cast<DocumentItem>();
        _payments = (futures[3] as List).cast<DocumentPayment>();
        _relatedDocument = futures[4] as Document?;
        _convertedInvoice = doc.type == 'quotation'
            ? futures[5] as Document?
            : null;
        _enabledMethods = enabledMethods;
        _allMethods = allMethods;
        _refundStatusInfo = refundInfo;
        _isAllocatedVoucher = isAllocatedVoucher;
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
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
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
        relatedDocument: _relatedDocument,
      );
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: '${_document!.documentNumber}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final isDraft = _document?.status == DocumentStatus.draft;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDraft ? l10n.deleteDraft : l10n.confirmDelete),
        content: Text(
          isDraft ? l10n.deleteDraftMessage : l10n.deleteDocumentMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(isDraft ? l10n.deleteDraft : l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deleteDocument(_document!.id!);
        if (!mounted) return;
        AppSnackBar.show(
          context,
          l10n.deletedSuccessfully,
          severity: AppSnackBarSeverity.success,
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        final errorMsg = ErrorUtils.toFriendlyMessage(e, l10n);
        AppSnackBar.show(
          context,
          errorMsg,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _cancelDocument() async {
    final l10n = AppLocalizations.of(context);
    final doc = _document!;
    final isReceipt = doc.type == 'payment_receipt';
    final isInvoiceOrPurchase = doc.type == 'invoice' || doc.type == 'purchase';

    String? chosenRefundStatus;
    bool confirmed = false;

    if (isInvoiceOrPurchase && doc.paid > 0) {
      final res = await CancelPaidDocumentDialog.show(context, document: doc);
      if (res != null && res.confirmed) {
        confirmed = true;
        chosenRefundStatus = res.refundStatus;
      }
    } else {
      final String cancelMessage;
      if (isReceipt) {
        cancelMessage = l10n.cancelReceiptMessage;
      } else if (doc.type == 'invoice') {
        cancelMessage = l10n.cancelInvoiceInventoryNotice;
      } else if (doc.type == 'purchase') {
        cancelMessage = l10n.cancelPurchaseInventoryNotice;
      } else {
        cancelMessage = l10n.cancelDocumentMessage;
      }

      final res = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.confirmCancel),
          content: Text(cancelMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(l10n.cancelDocument),
            ),
          ],
        ),
      );
      confirmed = res == true;
    }

    if (confirmed && mounted) {
      try {
        await DocumentService.cancelDocument(
          doc.id!,
          refundStatus: chosenRefundStatus,
        );
        if (!mounted) return;
        final msg = isReceipt ? l10n.paymentReversed : l10n.operationSuccessful;
        AppSnackBar.show(context, msg, severity: AppSnackBarSeverity.success);
        _load();
      } catch (e) {
        if (!mounted) return;
        final errorMsg = ErrorUtils.toFriendlyMessage(e, l10n);
        AppSnackBar.show(
          context,
          errorMsg,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _updateRefundStatus() async {
    if (_document == null) return;
    final currentStatus = _refundStatusInfo?['status'] as String?;
    final newStatus = await UpdateRefundStatusDialog.show(
      context,
      initialStatus: currentStatus,
    );
    if (newStatus != null && mounted) {
      try {
        await DocumentService.updateDocumentRefundStatus(
          documentId: _document!.id!,
          status: newStatus,
        );
        if (!mounted) return;
        AppSnackBar.show(
          context,
          AppLocalizations.of(context).operationSuccessful,
          severity: AppSnackBarSeverity.success,
        );
        _load();
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.show(
          context,
          '${AppLocalizations.of(context).operationFailed}: $e',
          severity: AppSnackBarSeverity.error,
        );
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
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.convertToInvoice),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final invoiceId = await DocumentService.convertQuotationToInvoice(
          _document!.id!,
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(documentId: invoiceId),
          ),
        ).then((_) => _load());
      } catch (e) {
        if (!mounted) return;
        final errorMsg = ErrorUtils.toFriendlyMessage(e, l10n);
        AppSnackBar.show(
          context,
          errorMsg,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }

  Future<void> _copyDocument() async {
    final l10n = AppLocalizations.of(context);
    try {
      final newId = await DocumentService.copyDocument(_document!.id!);
      if (!mounted) return;
      AppSnackBar.show(
        context,
        l10n.documentCopied,
        actionLabel: l10n.open,
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(documentId: newId),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        '${l10n.operationFailed}: $e',
        severity: AppSnackBarSeverity.error,
      );
    }
  }

  Future<void> _showRecordPaymentSheet() async {
    final l10n = AppLocalizations.of(context);
    final doc = _document!;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _RecordPaymentSheet(
        document: doc,
        enabledMethods: _enabledMethods,
        onSubmit: (amount, selectedMethod) async {
          Navigator.pop(sheetCtx);
          try {
            final receiptId = await DocumentService.recordPayment(
              documentId: doc.id!,
              amount: amount,
              paymentMethod: selectedMethod,
            );
            if (!mounted) return;
            AppSnackBar.show(
              context,
              l10n.paymentRecorded,
              actionLabel: l10n.viewReceipt,
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentDetailScreen(
                      documentId: receiptId,
                    ),
                  ),
                );
              },
            );
            _load();
          } catch (e) {
            if (!mounted) return;
            AppSnackBar.show(
              context,
              ErrorUtils.getFriendlyErrorMessage(e, l10n: l10n),
              severity: AppSnackBarSeverity.error,
            );
          }
        },
      ),
    );
  }

  String _methodLabel(String key, AppLocalizations l10n) {
    final m = _allMethods.where((m) => m.key == key).firstOrNull;
    if (m != null) return m.label(l10n.langCode);
    return CurrencyUtils.getPaymentMethodLabel(key, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _document == null || _business == null) {
      return Scaffold(
        body: ResponsiveCenter(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(l10n.operationFailed),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
              ],
            ),
          ),
        ),
      );
    }

    final doc = _document!;
    final sym = doc.currencySymbol;
    final typeLabel = _typeLabel(doc.type, l10n);
    final isCancelled = doc.status == DocumentStatus.cancelled;
    final isDraft = doc.status == DocumentStatus.draft;
    final isInvoice = doc.type == 'invoice';
    final isPurchase = doc.type == 'purchase';
    final isQuotation = doc.type == 'quotation';
    final isReceipt = doc.type == 'payment_receipt';
    final canRecordPay =
        (isInvoice || isPurchase) &&
        (doc.status == DocumentStatus.issued ||
            doc.status == DocumentStatus.partiallyPaid) &&
        AccessGuard.can(PermissionRegistry.paymentsRecord);
    final canIssue =
        isDraft &&
        (isInvoice || isQuotation || isPurchase) &&
        (isPurchase
            ? AccessGuard.can(PermissionRegistry.purchasesCreate)
            : AccessGuard.can(PermissionRegistry.salesCreate)) &&
        (doc.paid <= 0 || AccessGuard.can(PermissionRegistry.paymentsRecord));
    final canConvert = isQuotation && !isCancelled && _convertedInvoice == null;
    final canCancel = !isCancelled && !isDraft;
    final canDelete = isDraft || isCancelled;
    final canEdit = !isCancelled &&
        !_isAllocatedVoucher &&
        (isPurchase
            ? AccessGuard.can(PermissionRegistry.purchasesEdit)
            : AccessGuard.can(PermissionRegistry.salesEdit));

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
        label: Text(
          isInvoice
              ? l10n.issueInvoice
              : (isPurchase ? l10n.finalizePurchase : l10n.issueDocument),
        ),
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
                MaterialPageRoute(
                  builder: (_) => EditDocumentScreen(documentId: doc.id!),
                ),
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
                child: Row(
                  children: [
                    const Icon(Icons.copy_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(l10n.copyDocument),
                  ],
                ),
              ),
              if (canCancel)
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.cancelDocument,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              if (canDelete)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isDraft ? l10n.deleteDraft : l10n.delete,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: fab,
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_isAllocatedVoucher && !isCancelled) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.isArabic
                            ? 'لا يمكن تعديل سند تم تخصيصه. لتعديله، يرجى إلغاء السند وإصدار سند جديد.'
                            : 'Allocated vouchers cannot be edited. Cancel and re-issue to modify.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isCancelled && doc.paid > 0 && (isInvoice || isPurchase)) ...[
              _refundStatusCard(l10n, sym),
              const SizedBox(height: 10),
            ],

            // ── Header card ──────────────────────────────────
            _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      StatusBadge(status: doc.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow(l10n.date, _dateFmt.format(doc.date)),
                  if (isQuotation && doc.validUntil != null)
                    _infoRow(l10n.validUntil, _dateFmt.format(doc.validUntil!)),
                  if (isReceipt && doc.paymentMethod != null)
                    _infoRow(
                      l10n.paymentMethod,
                      _methodLabel(doc.paymentMethod!, l10n),
                    ),
                ],
              ),
            ),

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
                    builder: (_) =>
                        DocumentDetailScreen(documentId: _relatedDocument!.id!),
                  ),
                ).then((_) => _load()),
              ),
            ],
            if (isInvoice &&
                _relatedDocument != null &&
                _relatedDocument!.type == 'quotation') ...[
              const SizedBox(height: 10),
              _relatedCard(
                icon: Icons.request_quote_rounded,
                label: l10n.sourceQuotation,
                docNumber: _relatedDocument!.documentNumber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DocumentDetailScreen(documentId: _relatedDocument!.id!),
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
                    builder: (_) => DocumentDetailScreen(
                      documentId: _convertedInvoice!.id!,
                    ),
                  ),
                ).then((_) => _load()),
              ),
            ],

            // ── Customer / Supplier card ────────────────────
            if (_contact != null || doc.recipientName != null) ...[
              const SizedBox(height: 10),
              _card(
                InkWell(
                  onTap: _contact != null
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerDetailScreen(contact: _contact!),
                          ),
                        ).then((_) => _load())
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.type == 'purchase'
                                  ? l10n.supplier
                                  : l10n.customerOrParty,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_contact != null)
                            Icon(
                              AppIcons.chevronForward(context),
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _contact?.name ?? doc.recipientName ?? '',
                        style: const TextStyle(fontSize: 15),
                      ),
                      if ((_contact?.phone ?? doc.recipientPhone) != null)
                        _infoRow(
                          l10n.phone,
                          _contact?.phone ?? doc.recipientPhone!,
                        ),
                      if (_contact?.address != null &&
                          _contact!.address!.isNotEmpty)
                        _infoRow(l10n.address, _contact!.address!),
                    ],
                  ),
                ),
              ),
            ],

            // ── Items card ───────────────────────────────────
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 10),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.items,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._items.map((item) {
                      final hasUnit =
                          item.saleUnit != null &&
                          item.saleUnit!.trim().isNotEmpty;
                      final qtyText = hasUnit
                          ? '${_fmt.format(item.quantity)} ${item.saleUnit}'
                          : _fmt.format(item.quantity);
                      final tierText = item.pricingCategory == 'wholesale'
                          ? l10n.itemTierWholesaleBadge
                          : (item.pricingCategory == 'retail'
                                ? l10n.itemTierRetailBadge
                                : null);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.description),
                                  if (tierText != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        tierText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              item.pricingCategory ==
                                                  'wholesale'
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_fmt.format(item.total)} $sym',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '$qtyText × ${_fmt.format(item.price)}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // ── Totals card ──────────────────────────────────
            const SizedBox(height: 10),
            _card(
              Column(
                children: [
                  _totalRow(l10n.subtotal, doc.subtotal, sym),
                  if (doc.discount > 0)
                    _totalRow(l10n.discount, doc.discount, sym),
                  if (doc.taxAmount > 0)
                    _totalRow(
                      doc.taxRate > 0
                          ? '${l10n.tax} (${FormatUtils.formatTaxRate(doc.taxRate)})'
                          : l10n.tax,
                      doc.taxAmount,
                      sym,
                    ),
                  _totalRow(l10n.total, doc.total, sym, bold: true),
                  if (isInvoice || isPurchase) ...[
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
              ),
            ),

            // ── Notes card ───────────────────────────────────
            if (doc.notes != null && doc.notes!.isNotEmpty && !isReceipt) ...[
              const SizedBox(height: 10),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notes,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(doc.notes!),
                  ],
                ),
              ),
            ],

            // ── Payment history card ──────────────────────────
            if (isInvoice || isPurchase) ...[
              const SizedBox(height: 10),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.paymentHistory,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_payments.isEmpty)
                      Text(
                        l10n.noPaymentsYet,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      )
                    else
                      ..._payments.map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dateFmt.format(p.date),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (p.paymentMethod != null)
                                      Text(
                                        _methodLabel(p.paymentMethod!, l10n),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${_fmt.format(p.amount)} $sym',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            if (fab != null) const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _refundStatusCard(AppLocalizations l10n, String sym) {
    final cs = Theme.of(context).colorScheme;
    final statusKey = _refundStatusInfo?['status'] as String?;
    final date = _refundStatusInfo?['timestamp'] as DateTime?;

    final String statusLabel;
    final Color badgeColor;
    final IconData statusIcon;

    if (statusKey == 'refunded') {
      statusLabel = l10n.refundStatusRefunded;
      badgeColor = AppStatusColors.fg(context, AppStatus.success);
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (statusKey == 'unrefunded') {
      statusLabel = l10n.refundStatusNotRefunded;
      badgeColor = AppStatusColors.fg(context, AppStatus.warning);
      statusIcon = Icons.schedule_rounded;
    } else {
      statusLabel = l10n.refundStatusNotRecorded;
      badgeColor = cs.onSurfaceVariant;
      statusIcon = Icons.help_outline_rounded;
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.cancelledDocumentMoneyCardTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _updateRefundStatus,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: Text(l10n.changeStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(l10n.paid, '${_fmt.format(_document!.paid)} $sym'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.refundStatusLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 6),
            _infoRow(l10n.date, _dateFmt.format(date)),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              l10n.refundAuditCardDisclaimer,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
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
                    style: DefaultTextStyle.of(
                      context,
                    ).style.copyWith(fontSize: 14),
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: docNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                AppIcons.chevronForward(context),
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

  Widget _totalRow(
    String label,
    double value,
    String sym, {
    bool bold = false,
    Color? color,
  }) {
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
      'invoice' => l10n.invoice,
      'purchase' => l10n.purchase,
      'quotation' => l10n.quotation,
      'payment_receipt' => l10n.paymentReceipt,
      'expense_voucher' => l10n.expenseVoucher,
      'custom' => l10n.customDocument,
      _ => type,
    };
  }
}


class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.document,
    required this.enabledMethods,
    required this.onSubmit,
  });

  final Document document;
  final List<PaymentMethod> enabledMethods;
  final Future<void> Function(double amount, String? method) onSubmit;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  static final _fmt = NumberFormat('#,##0.00');
  late final TextEditingController _amountController;
  String? _selectedMethod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: NumberInput.formatForInput(widget.document.remaining, maxDecimals: 4),
    );
    _selectedMethod = widget.enabledMethods.isNotEmpty
        ? widget.enabledMethods.first.key
        : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final doc = widget.document;

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
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            (MediaQuery.viewInsetsOf(context).bottom > 0
                    ? MediaQuery.viewInsetsOf(context).bottom
                    : MediaQuery.viewPaddingOf(context).bottom) +
                24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.recordPayment,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.remaining}: ${_fmt.format(doc.remaining)} ${doc.currencySymbol}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text(l10n.voucherPayFullBalance),
                    onPressed: () {
                      setState(() {
                        _amountController.text = NumberInput.formatForInput(
                          doc.remaining,
                          maxDecimals: 4,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AmountField(
                controller: _amountController,
                maxDecimals: 4,
                showMultipliers: true,
                decoration: InputDecoration(
                  labelText: l10n.paymentAmountLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixText: doc.currencySymbol,
                ),
                autofocus: true,
              ),
              if (widget.enabledMethods.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.enabledMethods.map((m) {
                    return ChoiceChip(
                      label: Text(m.label(l10n.langCode)),
                      selected: _selectedMethod == m.key,
                      onSelected: (_) =>
                          setState(() => _selectedMethod = m.key),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (_isSubmitting) return;
                        final amount =
                            NumberInput.parse(_amountController.text) ?? 0;
                        final decimalDigits = Currency.decimalDigitsForCode(
                          doc.currencyCode,
                        );
                        if (amount <= 0) {
                          AppSnackBar.show(
                            context,
                            l10n.invalidAmount,
                            severity: AppSnackBarSeverity.warning,
                          );
                          return;
                        }
                        if (MoneyUtils.isOverpayment(
                          amount,
                          doc.remaining,
                          decimalDigits,
                        )) {
                          AppSnackBar.show(
                            context,
                            l10n.voucherAmountExceedsOutstanding(
                              _fmt.format(doc.remaining),
                            ),
                            severity: AppSnackBarSeverity.warning,
                          );
                          return;
                        }
                        setState(() => _isSubmitting = true);
                        await widget.onSubmit(amount, _selectedMethod);
                      },
                child: Text(l10n.recordPayment),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

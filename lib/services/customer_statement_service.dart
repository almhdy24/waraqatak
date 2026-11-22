import '../database/database_helper.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/customer_statement.dart';
import '../models/document.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';

class CustomerStatementService {
  CustomerStatementService._();

  static const double _eps = 1e-6;

  /// Returns all distinct currencies present among a contact's documents.
  static List<String> getAvailableCurrencies(
    List<Document> documents, {
    String fallbackCurrency = 'SDG',
  }) {
    final currencies = <String>{};
    for (final doc in documents) {
      if (doc.status == DocumentStatus.draft) continue;
      final code = doc.currencyCode.trim().isNotEmpty
          ? doc.currencyCode
          : fallbackCurrency;
      currencies.add(code);
    }
    if (currencies.isEmpty) currencies.add(fallbackCurrency);
    return currencies.toList()..sort();
  }

  /// Loads documents and generates the statement from the local database.
  static Future<CustomerStatement> getStatementForContact({
    required int contactId,
    required DateTime from,
    required DateTime to,
    String? currencyCode,
  }) async {
    final db = DatabaseHelper.instance;
    final contact = await db.getContactById(contactId);
    if (contact == null) {
      throw StateError('Contact with ID $contactId not found');
    }
    final business = await db.getFirstBusiness();
    final fallbackCurrency = business?.currencyCode ?? 'SDG';

    final allDocs = await db.getDocumentsByContact(contactId);
    final targetCurrency = currencyCode ?? fallbackCurrency;

    final invoiceIds = allDocs
        .where((d) => d.type == 'invoice' && d.id != null)
        .map((d) => d.id!)
        .toList();
    final receiptIds = allDocs
        .where((d) => d.type == 'payment_receipt' && d.id != null)
        .map((d) => d.id!)
        .toList();

    List<DocumentPayment> payments = const [];
    if (invoiceIds.isNotEmpty || receiptIds.isNotEmpty) {
      final dbExecutor = await db.database;
      final whereParts = <String>[];
      final args = <Object?>[];
      if (invoiceIds.isNotEmpty) {
        whereParts.add(
          'document_id IN (${List.filled(invoiceIds.length, '?').join(',')})',
        );
        args.addAll(invoiceIds);
      }
      if (receiptIds.isNotEmpty) {
        whereParts.add(
          'receipt_document_id IN (${List.filled(receiptIds.length, '?').join(',')})',
        );
        args.addAll(receiptIds);
      }
      final rows = await dbExecutor.query(
        'document_payments',
        where: whereParts.join(' OR '),
        whereArgs: args,
        orderBy: 'date ASC, id ASC',
      );
      payments = rows.map(DocumentPayment.fromMap).toList();
    }

    return generateStatement(
      contact: contact,
      documents: allDocs,
      payments: payments,
      from: from,
      to: to,
      currencyCode: targetCurrency,
      businessCurrencyCode: fallbackCurrency,
    );
  }

  /// Pure deterministic accounting statement generator.
  static CustomerStatement generateStatement({
    required Contact contact,
    required List<Document> documents,
    List<DocumentPayment>? payments,
    required DateTime from,
    required DateTime to,
    String? currencyCode,
    String businessCurrencyCode = 'SDG',
  }) {
    final targetCurrency = currencyCode?.trim().isNotEmpty == true
        ? currencyCode!
        : businessCurrencyCode;
    final currencySymbol = Currency.symbolForCode(targetCurrency);

    final byId = <int, Document>{
      for (final d in documents)
        if (d.id != null) d.id!: d,
    };

    // 1. Filter eligible invoices for this currency:
    // Non-draft, non-cancelled invoices with matching currency.
    final eligibleInvoices = <Document>[];
    for (final doc in documents) {
      if (doc.type != 'invoice') continue;
      if (doc.status == DocumentStatus.draft ||
          doc.status == DocumentStatus.cancelled) {
        continue;
      }
      final cCode = doc.currencyCode.trim().isNotEmpty
          ? doc.currencyCode
          : businessCurrencyCode;
      if (cCode == targetCurrency) {
        eligibleInvoices.add(doc);
      }
    }

    final eligibleInvoiceIds = {
      for (final inv in eligibleInvoices)
        if (inv.id != null) inv.id!,
    };

    final rawEntries = <StatementEntry>[];
    final warnings = <StatementWarning>[];
    final cancelledInvoiceReceipts = <CancelledInvoiceReceipt>[];

    final bool hasPaymentRows = payments != null && payments.isNotEmpty;
    final paymentsByDocId = <int, List<DocumentPayment>>{};
    if (payments != null) {
      for (final p in payments) {
        paymentsByDocId.putIfAbsent(p.documentId, () => []).add(p);
      }
    }

    if (hasPaymentRows) {
      // Modern path: use explicit document_payments allocation rows
      for (final inv in eligibleInvoices) {
        // 1. Emit invoice debit
        rawEntries.add(
          StatementEntry(
            date: inv.date,
            documentNumber: inv.documentNumber,
            description: inv.documentNumber,
            type: StatementEntryType.invoice,
            debit: inv.total,
            credit: 0.0,
            runningBalance: 0.0,
            documentId: inv.id,
          ),
        );

        final pRows = paymentsByDocId[inv.id] ?? const <DocumentPayment>[];
        if (pRows.isEmpty) {
          // Legacy invoice with no payment rows
          if (inv.paid > _eps) {
            rawEntries.add(
              StatementEntry(
                date: inv.date,
                documentNumber: inv.documentNumber,
                description: inv.documentNumber,
                type: StatementEntryType.initialPayment,
                debit: 0.0,
                credit: inv.paid,
                runningBalance: 0.0,
                documentId: inv.id,
              ),
            );
          }
        } else {
          // 2. Upfront payment rows
          final upfrontRows = pRows
              .where((p) =>
                  p.paymentOrigin == PaymentOrigin.upfront ||
                  (p.paymentOrigin == null && p.receiptDocumentId == null))
              .toList();
          for (final u in upfrontRows) {
            if (u.amount > _eps) {
              rawEntries.add(
                StatementEntry(
                  date: u.date,
                  documentNumber: inv.documentNumber,
                  description: inv.documentNumber,
                  type: StatementEntryType.initialPayment,
                  debit: 0.0,
                  credit: u.amount,
                  runningBalance: 0.0,
                  documentId: inv.id,
                ),
              );
            }
          }

          // 3. Receipt allocations
          final allocRows = pRows
              .where((p) =>
                  p.receiptDocumentId != null &&
                  p.paymentOrigin != PaymentOrigin.reversal &&
                  p.amount > _eps)
              .toList();

          for (final a in allocRows) {
            final voucher = byId[a.receiptDocumentId];
            final voucherNum = voucher?.documentNumber ?? '';
            rawEntries.add(
              StatementEntry(
                date: a.date,
                documentNumber:
                    voucherNum.isNotEmpty ? voucherNum : inv.documentNumber,
                description: inv.documentNumber,
                type: StatementEntryType.receipt,
                debit: 0.0,
                credit: a.amount,
                runningBalance: 0.0,
                documentId: a.receiptDocumentId,
                relatedDocumentId: inv.id,
              ),
            );
          }

          // 4. Reversals
          final revRows = pRows
              .where((p) =>
                  p.paymentOrigin == PaymentOrigin.reversal ||
                  p.amount < -_eps)
              .toList();

          for (final r in revRows) {
            final voucher =
                r.receiptDocumentId != null ? byId[r.receiptDocumentId] : null;
            final voucherNum = voucher?.documentNumber ?? '';
            rawEntries.add(
              StatementEntry(
                date: r.date,
                documentNumber:
                    voucherNum.isNotEmpty ? voucherNum : inv.documentNumber,
                description: inv.documentNumber,
                type: StatementEntryType.reconciliationAdjustment,
                debit: r.amount.abs(),
                credit: 0.0,
                runningBalance: 0.0,
                documentId: r.receiptDocumentId,
                relatedDocumentId: inv.id,
                isAdjustment: true,
              ),
            );
          }

          // 5. Fallback for untracked legacy upfront if any
          final trackedPaid =
              pRows.fold<double>(0.0, (sum, p) => sum + p.amount);
          final untracked = inv.paid - trackedPaid;
          if (untracked > _eps && upfrontRows.isEmpty) {
            rawEntries.add(
              StatementEntry(
                date: inv.date,
                documentNumber: inv.documentNumber,
                description: inv.documentNumber,
                type: StatementEntryType.initialPayment,
                debit: 0.0,
                credit: untracked,
                runningBalance: 0.0,
                documentId: inv.id,
              ),
            );
          }
        }
      }

      // 6. Include unallocated customer payment receipts (advance deposits)
      final coveredReceiptIds = <int>{};
      for (final pList in paymentsByDocId.values) {
        for (final p in pList) {
          if (p.receiptDocumentId != null) {
            coveredReceiptIds.add(p.receiptDocumentId!);
          }
        }
      }

      for (final doc in documents) {
        if (doc.type != 'payment_receipt') continue;
        if (doc.status == DocumentStatus.cancelled ||
            doc.status == DocumentStatus.draft) {
          continue;
        }
        if (doc.id != null && coveredReceiptIds.contains(doc.id!)) {
          continue;
        }
        final docCurrency = doc.currencyCode.trim().isNotEmpty
            ? doc.currencyCode
            : businessCurrencyCode;
        if (docCurrency != targetCurrency) continue;

        rawEntries.add(
          StatementEntry(
            date: doc.date,
            documentNumber: doc.documentNumber,
            description: doc.documentNumber,
            type: StatementEntryType.receipt,
            debit: 0.0,
            credit: doc.total,
            runningBalance: 0.0,
            documentId: doc.id,
          ),
        );
      }
    } else {
      // Legacy fallback path: classify payment receipts assuming single parent link
      final activeLinkedReceipts = <Document>[];

      for (final doc in documents) {
        if (doc.type != 'payment_receipt') continue;
        if (doc.status == DocumentStatus.cancelled ||
            doc.status == DocumentStatus.draft) {
          continue;
        }
        if (doc.relatedDocumentId == null) {
          final docCurrency = doc.currencyCode.trim().isNotEmpty
              ? doc.currencyCode
              : businessCurrencyCode;
          if (docCurrency == targetCurrency) {
            rawEntries.add(
              StatementEntry(
                date: doc.date,
                documentNumber: doc.documentNumber,
                description: doc.documentNumber,
                type: StatementEntryType.receipt,
                debit: 0.0,
                credit: doc.total,
                runningBalance: 0.0,
                documentId: doc.id,
              ),
            );
          }
          continue;
        }

        final parent = byId[doc.relatedDocumentId];
        if (parent == null || parent.type != 'invoice') continue;

        final parentCurrency = parent.currencyCode.trim().isNotEmpty
            ? parent.currencyCode
            : businessCurrencyCode;
        if (parentCurrency != targetCurrency) continue;

        if (eligibleInvoiceIds.contains(parent.id)) {
          activeLinkedReceipts.add(doc);
        } else if (parent.status == DocumentStatus.cancelled) {
          cancelledInvoiceReceipts.add(
            CancelledInvoiceReceipt(
              receiptId: doc.id ?? 0,
              receiptNumber: doc.documentNumber,
              date: doc.date,
              amount: doc.total,
              paymentMethod: doc.paymentMethod,
              cancelledInvoiceId: parent.id ?? 0,
              cancelledInvoiceNumber: parent.documentNumber,
            ),
          );
        }
      }

      final receiptsByInvoice = <int, List<Document>>{};
      for (final r in activeLinkedReceipts) {
        receiptsByInvoice.putIfAbsent(r.relatedDocumentId!, () => []).add(r);
      }

      for (final inv in eligibleInvoices) {
        final linkedReceipts = receiptsByInvoice[inv.id] ?? const <Document>[];
        final linkedTotal =
            linkedReceipts.fold<double>(0.0, (s, r) => s + r.total);
        final initialPaid = inv.paid - linkedTotal;

        rawEntries.add(
          StatementEntry(
            date: inv.date,
            documentNumber: inv.documentNumber,
            description: inv.documentNumber,
            type: StatementEntryType.invoice,
            debit: inv.total,
            credit: 0.0,
            runningBalance: 0.0,
            documentId: inv.id,
          ),
        );

        if (initialPaid >= -_eps) {
          if (initialPaid > _eps) {
            rawEntries.add(
              StatementEntry(
                date: inv.date,
                documentNumber: inv.documentNumber,
                description: inv.documentNumber,
                type: StatementEntryType.initialPayment,
                debit: 0.0,
                credit: initialPaid,
                runningBalance: 0.0,
                documentId: inv.id,
              ),
            );
          }
        } else {
          final discrepancy = initialPaid.abs();
          warnings.add(
            StatementWarning(
              invoiceNumber: inv.documentNumber,
              invoiceId: inv.id ?? 0,
              storedPaid: inv.paid,
              receiptsTotal: linkedTotal,
              discrepancy: discrepancy,
            ),
          );
          rawEntries.add(
            StatementEntry(
              date: inv.date,
              documentNumber: inv.documentNumber,
              description: inv.documentNumber,
              type: StatementEntryType.reconciliationAdjustment,
              debit: discrepancy,
              credit: 0.0,
              runningBalance: 0.0,
              documentId: inv.id,
              isAdjustment: true,
            ),
          );
        }
      }

      for (final r in activeLinkedReceipts) {
        final parent = byId[r.relatedDocumentId];
        final parentNum = parent?.documentNumber ?? '';
        rawEntries.add(
          StatementEntry(
            date: r.date,
            documentNumber: r.documentNumber,
            description: parentNum.isNotEmpty ? parentNum : r.documentNumber,
            type: StatementEntryType.receipt,
            debit: 0.0,
            credit: r.total,
            runningBalance: 0.0,
            documentId: r.id,
            relatedDocumentId: r.relatedDocumentId,
          ),
        );
      }
    }

    // 4. Deterministic sorting: date ASC, then debit before credit, then type, then docId
    rawEntries.sort((a, b) {
      final dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;

      // Debits (debit > 0) before Credits (credit > 0)
      final aIsDebit = a.debit > 0;
      final bIsDebit = b.debit > 0;
      if (aIsDebit != bIsDebit) {
        return aIsDebit ? -1 : 1;
      }

      final typeCmp = a.type.index.compareTo(b.type.index);
      if (typeCmp != 0) return typeCmp;

      final aId = a.documentId ?? 0;
      final bId = b.documentId ?? 0;
      return aId.compareTo(bId);
    });

    // 5. Partition by date range into Opening Balance & Period Transactions
    double openingBalance = 0.0;
    double currentBalance = 0.0;
    final periodEntries = <StatementEntry>[];
    double totalInvoiced = 0.0;
    double totalPaid = 0.0;
    double totalAdjustments = 0.0;

    for (final entry in rawEntries) {
      if (entry.date.isBefore(from)) {
        openingBalance += entry.debit - entry.credit;
      }
    }

    currentBalance = openingBalance;

    for (final entry in rawEntries) {
      if (!entry.date.isBefore(from) && !entry.date.isAfter(to)) {
        currentBalance += entry.debit - entry.credit;
        periodEntries.add(
          StatementEntry(
            date: entry.date,
            documentNumber: entry.documentNumber,
            description: entry.description,
            type: entry.type,
            debit: entry.debit,
            credit: entry.credit,
            runningBalance: currentBalance,
            documentId: entry.documentId,
            relatedDocumentId: entry.relatedDocumentId,
            isAdjustment: entry.isAdjustment,
          ),
        );
        if (entry.type == StatementEntryType.invoice) {
          totalInvoiced += entry.debit;
        } else if (entry.isAdjustment) {
          totalAdjustments += entry.debit;
        }
        if (entry.credit > 0) {
          totalPaid += entry.credit;
        }
      }
    }

    return CustomerStatement(
      contact: contact,
      currencyCode: targetCurrency,
      currencySymbol: currencySymbol,
      from: from,
      to: to,
      openingBalance: openingBalance,
      entries: periodEntries,
      totalInvoiced: totalInvoiced,
      totalPaid: totalPaid,
      totalAdjustments: totalAdjustments,
      closingBalance: currentBalance,
      warnings: warnings,
      cancelledInvoiceReceipts: cancelledInvoiceReceipts,
    );
  }
}

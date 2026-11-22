import '../../models/currency.dart';
import '../../models/document.dart';
import '../../models/document_item.dart';
import '../../models/document_payment.dart';
import '../../models/document_status.dart';
import '../../models/journal_entry_entity.dart';
import '../../models/product.dart';
import '../../utils/money_utils.dart';
import 'journal_draft.dart';
import 'ledger.dart';

/// Pure functional posting engine for Waraqatak.
/// Transforms domain business events into balanced, immutable [JournalEntryDraft] objects.
///
/// Posting rules correspond 1:1 with the reference specifications in
/// `docs/accounting_backbone_design.md` and `lib/services/accounting/ledger.dart`.
class PostingService {
  PostingService._();

  static const String sourceInvoice = 'invoice';
  static const String sourcePurchase = 'purchase';
  static const String sourcePayment = 'payment';
  static const String sourceReceipt = 'receipt';
  static const String sourceVoucher = 'voucher';
  static const String sourceCogs = 'cogs';
  static const String sourceAdjustment = 'stock_adjustment';
  static const String sourceStocktake = 'stocktake';
  static const String sourceOpeningStock = 'opening_stock';

  /// Generates journal entries for an issued document.
  /// Returns a list of balanced [JournalEntryDraft] objects (e.g. document entry,
  /// upfront settlement entry, and cost of goods sold entry).
  static List<JournalEntryDraft> postDocumentIssued({
    required Document doc,
    required List<DocumentItem> items,
    required Map<int, Product> products,
    required String Function(String prefix) nextEntryNo,
    DateTime? now,
    String origin = 'live',
    Document? parentDoc,
    bool isAllocated = false,
    double? upfrontPaid,
  }) {
    // Drafts and quotations post nothing
    if (doc.status == DocumentStatus.draft ||
        doc.status == DocumentStatus.cancelled ||
        doc.type == 'quotation') {
      return const [];
    }

    final timestamp = now ?? DateTime.now();
    final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
    final results = <JournalEntryDraft>[];

    switch (doc.type) {
      case 'invoice':
        _postInvoice(
          doc: doc,
          items: items,
          products: products,
          decimalDigits: decimalDigits,
          timestamp: timestamp,
          nextEntryNo: nextEntryNo,
          origin: origin,
          out: results,
          upfrontPaid: upfrontPaid,
        );
        break;

      case 'purchase':
        _postPurchase(
          doc: doc,
          items: items,
          products: products,
          decimalDigits: decimalDigits,
          timestamp: timestamp,
          nextEntryNo: nextEntryNo,
          origin: origin,
          out: results,
          upfrontPaid: upfrontPaid,
        );
        break;

      case 'payment_receipt':
        _postReceipt(
          doc: doc,
          decimalDigits: decimalDigits,
          timestamp: timestamp,
          nextEntryNo: nextEntryNo,
          origin: origin,
          out: results,
          parentDoc: parentDoc,
          isAllocated: isAllocated,
        );
        break;

      case 'expense_voucher':
        _postVoucher(
          doc: doc,
          decimalDigits: decimalDigits,
          timestamp: timestamp,
          nextEntryNo: nextEntryNo,
          origin: origin,
          out: results,
          parentDoc: parentDoc,
          isAllocated: isAllocated,
        );
        break;
    }

    return results;
  }

  static void _postInvoice({
    required Document doc,
    required List<DocumentItem> items,
    required Map<int, Product> products,
    required int decimalDigits,
    required DateTime timestamp,
    required String Function(String prefix) nextEntryNo,
    required String origin,
    required List<JournalEntryDraft> out,
    double? upfrontPaid,
  }) {
    final totalMinor = MoneyUtils.toMinorUnits(doc.total, decimalDigits);
    final taxMinor = MoneyUtils.toMinorUnits(doc.taxAmount, decimalDigits);
    final netMinor = totalMinor - taxMinor;

    if (totalMinor > 0) {
      final lines = <JournalLineDraft>[
        JournalLineDraft(
          accountCode: Accounts.receivables.code,
          debitMinor: totalMinor,
          contactId: doc.contactId,
        ),
        if (netMinor > 0)
          JournalLineDraft(
            accountCode: Accounts.salesRevenue.code,
            creditMinor: netMinor,
          ),
        if (taxMinor > 0)
          JournalLineDraft(
            accountCode: Accounts.vatOutput.code,
            creditMinor: taxMinor,
          ),
      ];

      if (lines.isNotEmpty) {
        out.add(
          JournalEntryDraft(
            entryNo: nextEntryNo('JE-INV'),
            effectiveDate: doc.date,
            postedAt: timestamp,
            sourceType: sourceInvoice,
            sourceId: doc.id,
            memo: 'Invoice ${doc.documentNumber}',
            origin: origin,
            lines: lines,
          ),
        );
      }

      // Upfront settlement recorded with invoice
      final effectiveUpfrontPaid = upfrontPaid ?? doc.paid;
      final paidMinor = MoneyUtils.toMinorUnits(effectiveUpfrontPaid, decimalDigits);
      if (paidMinor > 0) {
        final moneyAccount = Accounts.forPaymentMethod(doc.paymentMethod);
        out.add(
          JournalEntryDraft(
            entryNo: nextEntryNo('JE-PAY'),
            effectiveDate: doc.date,
            postedAt: timestamp,
            sourceType: sourcePayment,
            sourceId: doc.id,
            memo: 'Settlement for Invoice ${doc.documentNumber}',
            origin: origin,
            lines: [
              JournalLineDraft(
                accountCode: moneyAccount.code,
                debitMinor: paidMinor,
              ),
              JournalLineDraft(
                accountCode: Accounts.receivables.code,
                creditMinor: paidMinor,
                contactId: doc.contactId,
              ),
            ],
          ),
        );
      }
    }

    // Cost of Goods Sold for stocked items with known cost
    final cogsLines = <JournalLineDraft>[];
    for (final it in items) {
      final p = it.productId == null ? null : products[it.productId];
      final isStocked = p != null &&
          p.type == Product.typeProduct &&
          it.effectiveBaseQuantity > 0;
      if (!isStocked) continue;

      final unitCost = it.unitCost;
      if (unitCost != null && unitCost > 0.000000001) {
        final lineCost = it.effectiveBaseQuantity * unitCost;
        final costMinor = MoneyUtils.toMinorUnits(lineCost, decimalDigits);
        if (costMinor > 0) {
          cogsLines.add(
            JournalLineDraft(
              accountCode: Accounts.cogs.code,
              debitMinor: costMinor,
              productId: it.productId,
            ),
          );
          cogsLines.add(
            JournalLineDraft(
              accountCode: Accounts.inventory.code,
              creditMinor: costMinor,
              productId: it.productId,
            ),
          );
        }
      }
    }

    if (cogsLines.isNotEmpty) {
      out.add(
        JournalEntryDraft(
          entryNo: nextEntryNo('JE-COGS'),
          effectiveDate: doc.date,
          postedAt: timestamp,
          sourceType: sourceCogs,
          sourceId: doc.id,
          memo: 'COGS for Invoice ${doc.documentNumber}',
          origin: origin,
          lines: cogsLines,
        ),
      );
    }
  }

  static void _postPurchase({
    required Document doc,
    required List<DocumentItem> items,
    required Map<int, Product> products,
    required int decimalDigits,
    required DateTime timestamp,
    required String Function(String prefix) nextEntryNo,
    required String origin,
    required List<JournalEntryDraft> out,
    double? upfrontPaid,
  }) {
    final totalMinor = MoneyUtils.toMinorUnits(doc.total, decimalDigits);
    final taxMinor = MoneyUtils.toMinorUnits(doc.taxAmount, decimalDigits);
    final netMinor = totalMinor - taxMinor;

    if (totalMinor <= 0) return;

    final netAmount = doc.total - doc.taxAmount;

    double stockedNet = 0.0;
    for (final it in items) {
      final p = it.productId == null ? null : products[it.productId];
      final isStocked = p != null &&
          p.type == Product.typeProduct &&
          it.effectiveBaseQuantity > 0;
      if (isStocked) {
        if (doc.subtotal > 0.000000001) {
          stockedNet += (it.total / doc.subtotal) * netAmount;
        }
      }
    }

    final hasStocked = items.any((it) {
      final p = it.productId == null ? null : products[it.productId];
      return p != null &&
          p.type == Product.typeProduct &&
          it.effectiveBaseQuantity > 0;
    });
    final hasNonStocked = items.any((it) {
      final p = it.productId == null ? null : products[it.productId];
      return p == null ||
          p.type != Product.typeProduct ||
          it.effectiveBaseQuantity <= 0;
    });

    final int stockedMinor;
    final int expensedMinor;
    if (!hasStocked) {
      stockedMinor = 0;
      expensedMinor = netMinor;
    } else if (!hasNonStocked) {
      stockedMinor = netMinor;
      expensedMinor = 0;
    } else {
      final rawStockedMinor = MoneyUtils.toMinorUnits(stockedNet, decimalDigits);
      stockedMinor = rawStockedMinor.clamp(0, netMinor);
      expensedMinor = netMinor - stockedMinor;
    }

    final lines = <JournalLineDraft>[
      if (stockedMinor > 0)
        JournalLineDraft(
          accountCode: Accounts.inventory.code,
          debitMinor: stockedMinor,
        ),
      if (expensedMinor > 0)
        JournalLineDraft(
          accountCode: Accounts.operatingExpenses.code,
          debitMinor: expensedMinor,
        ),
      if (taxMinor > 0)
        JournalLineDraft(
          accountCode: Accounts.vatInput.code,
          debitMinor: taxMinor,
        ),
      JournalLineDraft(
        accountCode: Accounts.payables.code,
        creditMinor: totalMinor,
        contactId: doc.contactId,
      ),
    ];

    if (lines.isNotEmpty) {
      out.add(
        JournalEntryDraft(
          entryNo: nextEntryNo('JE-PUR'),
          effectiveDate: doc.date,
          postedAt: timestamp,
          sourceType: sourcePurchase,
          sourceId: doc.id,
          memo: 'Purchase ${doc.documentNumber}',
          origin: origin,
          lines: lines,
        ),
      );
    }

    // Upfront settlement recorded with purchase
    final effectiveUpfrontPaid = upfrontPaid ?? doc.paid;
    final paidMinor = MoneyUtils.toMinorUnits(effectiveUpfrontPaid, decimalDigits);
    if (paidMinor > 0) {
      final moneyAccount = Accounts.forPaymentMethod(doc.paymentMethod);
      out.add(
        JournalEntryDraft(
          entryNo: nextEntryNo('JE-PAY'),
          effectiveDate: doc.date,
          postedAt: timestamp,
          sourceType: sourcePayment,
          sourceId: doc.id,
          memo: 'Settlement for Purchase ${doc.documentNumber}',
          origin: origin,
          lines: [
            JournalLineDraft(
              accountCode: Accounts.payables.code,
              debitMinor: paidMinor,
              contactId: doc.contactId,
            ),
            JournalLineDraft(
              accountCode: moneyAccount.code,
              creditMinor: paidMinor,
            ),
          ],
        ),
      );
    }
  }

  static void _postReceipt({
    required Document doc,
    required int decimalDigits,
    required DateTime timestamp,
    required String Function(String prefix) nextEntryNo,
    required String origin,
    required List<JournalEntryDraft> out,
    Document? parentDoc,
    bool isAllocated = false,
  }) {
    final totalMinor = MoneyUtils.toMinorUnits(doc.total, decimalDigits);
    if (totalMinor <= 0) return;

    final moneyAccount = Accounts.forPaymentMethod(doc.paymentMethod);
    final String creditAccountCode;
    if (parentDoc != null) {
      if (parentDoc.status == DocumentStatus.cancelled ||
          parentDoc.status == DocumentStatus.draft) {
        creditAccountCode = Accounts.payables.code; // Customer advance liability
      } else {
        creditAccountCode = Accounts.receivables.code;
      }
    } else if (isAllocated) {
      creditAccountCode = Accounts.receivables.code;
    } else if (doc.contactId != null) {
      creditAccountCode = Accounts.payables.code; // Customer advance liability
    } else {
      creditAccountCode = Accounts.otherIncome.code;
    }

    out.add(
      JournalEntryDraft(
        entryNo: nextEntryNo('JE-REC'),
        effectiveDate: doc.date,
        postedAt: timestamp,
        sourceType: sourceReceipt,
        sourceId: doc.id,
        memo: 'Payment Receipt ${doc.documentNumber}',
        origin: origin,
        lines: [
          JournalLineDraft(
            accountCode: moneyAccount.code,
            debitMinor: totalMinor,
          ),
          JournalLineDraft(
            accountCode: creditAccountCode,
            creditMinor: totalMinor,
            contactId: doc.contactId,
          ),
        ],
      ),
    );
  }

  static void _postVoucher({
    required Document doc,
    required int decimalDigits,
    required DateTime timestamp,
    required String Function(String prefix) nextEntryNo,
    required String origin,
    required List<JournalEntryDraft> out,
    Document? parentDoc,
    bool isAllocated = false,
  }) {
    final totalMinor = MoneyUtils.toMinorUnits(doc.total, decimalDigits);
    if (totalMinor <= 0) return;

    final moneyAccount = Accounts.forPaymentMethod(doc.paymentMethod);
    final String debitAccountCode;
    if (parentDoc != null) {
      if (parentDoc.status == DocumentStatus.cancelled ||
          parentDoc.status == DocumentStatus.draft) {
        debitAccountCode = Accounts.receivables.code; // Supplier advance receivable
      } else {
        debitAccountCode = Accounts.payables.code;
      }
    } else if (isAllocated) {
      debitAccountCode = Accounts.payables.code;
    } else {
      debitAccountCode = Accounts.operatingExpenses.code;
    }

    out.add(
      JournalEntryDraft(
        entryNo: nextEntryNo('JE-VCH'),
        effectiveDate: doc.date,
        postedAt: timestamp,
        sourceType: sourceVoucher,
        sourceId: doc.id,
        memo: 'Expense Voucher ${doc.documentNumber}',
        origin: origin,
        lines: [
          JournalLineDraft(
            accountCode: debitAccountCode,
            debitMinor: totalMinor,
            contactId: doc.contactId,
          ),
          JournalLineDraft(
            accountCode: moneyAccount.code,
            creditMinor: totalMinor,
          ),
        ],
      ),
    );
  }

  /// Generates a journal entry for a subsequent payment recorded on an existing document.
  static JournalEntryDraft postPaymentRecorded({
    required DocumentPayment payment,
    required Document parentDoc,
    required String Function(String prefix) nextEntryNo,
    DateTime? now,
    String origin = 'live',
  }) {
    final timestamp = now ?? DateTime.now();
    final decimalDigits =
        Currency.decimalDigitsForCode(parentDoc.currencyCode);
    final amountMinor =
        MoneyUtils.toMinorUnits(payment.amount, decimalDigits);
    final moneyAccount = Accounts.forPaymentMethod(payment.paymentMethod);

    final isSale = parentDoc.type == 'invoice';
    return JournalEntryDraft(
      entryNo: nextEntryNo('JE-PAY'),
      effectiveDate: payment.date,
      postedAt: timestamp,
      sourceType: sourcePayment,
      sourceId: payment.id ?? parentDoc.id,
      memo: 'Payment on ${parentDoc.type} ${parentDoc.documentNumber}',
      origin: origin,
      lines: isSale
          ? [
              JournalLineDraft(
                accountCode: moneyAccount.code,
                debitMinor: amountMinor,
              ),
              JournalLineDraft(
                accountCode: Accounts.receivables.code,
                creditMinor: amountMinor,
                contactId: parentDoc.contactId,
              ),
            ]
          : [
              JournalLineDraft(
                accountCode: Accounts.payables.code,
                debitMinor: amountMinor,
                contactId: parentDoc.contactId,
              ),
              JournalLineDraft(
                accountCode: moneyAccount.code,
                creditMinor: amountMinor,
              ),
            ],
    );
  }

  /// Generates reversing entries for all live entries of a cancelled document.
  /// Reversals are dated at the original entry's effective date (D3).
  static List<JournalEntryDraft> postDocumentCancelled({
    required Document doc,
    required List<JournalEntryEntity> existingEntries,
    required String Function(String prefix) nextEntryNo,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final reversals = <JournalEntryDraft>[];

    // Find all non-reversed entries for this document
    final reversedIds = existingEntries
        .where((e) => e.reversesEntryId != null)
        .map((e) => e.reversesEntryId!)
        .toSet();

    for (final e in existingEntries) {
      if (reversedIds.contains(e.id)) continue; // already reversed
      if (e.reversesEntryId != null) continue; // this is itself a reversal

      final revLines = e.lines
          .map(
            (l) => JournalLineDraft(
              accountCode: l.accountCode,
              debitMinor: l.creditMinor,
              creditMinor: l.debitMinor,
              productId: l.productId,
              contactId: l.contactId,
            ),
          )
          .toList();

      reversals.add(
        JournalEntryDraft(
          entryNo: nextEntryNo('JE-REV'),
          effectiveDate: e.effectiveDate, // D3: dated at original date
          postedAt: timestamp,
          sourceType: e.sourceType,
          sourceId: e.sourceId,
          revision: e.revision + 1,
          memo: 'Reversal of entry ${e.entryNo} (Cancelled ${doc.documentNumber})',
          reversesEntryId: e.id,
          origin: 'live',
          lines: revLines,
        ),
      );
    }

    return reversals;
  }

  /// Generates journal entries for an inventory stock adjustment.
  static JournalEntryDraft? postStockAdjusted({
    required int productId,
    required double quantity,
    required double unitCost,
    required String reason,
    required int decimalDigits,
    required DateTime date,
    required String Function(String prefix) nextEntryNo,
    DateTime? now,
    String? memo,
    int? targetMovementId,
    String origin = 'live',
  }) {
    final timestamp = now ?? DateTime.now();
    final costAmount = quantity.abs() * unitCost;
    final costMinor = MoneyUtils.toMinorUnits(costAmount, decimalDigits);
    if (costMinor <= 0) return null;

    final isGain = quantity > 0;
    final List<JournalLineDraft> lines;

    switch (reason) {
      case 'opening_stock':
        lines = [
          JournalLineDraft(
            accountCode: Accounts.inventory.code,
            debitMinor: costMinor,
            productId: productId,
          ),
          JournalLineDraft(
            accountCode: Accounts.openingEquity.code,
            creditMinor: costMinor,
          ),
        ];
        break;

      case 'entry_correction':
        // Correction of prior movement: reverses against the offset account without hitting P&L
        lines = isGain
            ? [
                JournalLineDraft(
                  accountCode: Accounts.inventory.code,
                  debitMinor: costMinor,
                  productId: productId,
                ),
                JournalLineDraft(
                  accountCode: Accounts.openingEquity.code,
                  creditMinor: costMinor,
                ),
              ]
            : [
                JournalLineDraft(
                  accountCode: Accounts.openingEquity.code,
                  debitMinor: costMinor,
                ),
                JournalLineDraft(
                  accountCode: Accounts.inventory.code,
                  creditMinor: costMinor,
                  productId: productId,
                ),
              ];
        break;

      case 'count_gain':
        lines = [
          JournalLineDraft(
            accountCode: Accounts.inventory.code,
            debitMinor: costMinor,
            productId: productId,
          ),
          JournalLineDraft(
            accountCode: Accounts.inventoryAdjustments.code,
            creditMinor: costMinor,
          ),
        ];
        break;

      case 'count_loss':
      case 'damage_loss':
      case 'expiry_loss':
      case 'other':
      default:
        lines = isGain
            ? [
                JournalLineDraft(
                  accountCode: Accounts.inventory.code,
                  debitMinor: costMinor,
                  productId: productId,
                ),
                JournalLineDraft(
                  accountCode: Accounts.inventoryAdjustments.code,
                  creditMinor: costMinor,
                ),
              ]
            : [
                JournalLineDraft(
                  accountCode: Accounts.inventoryAdjustments.code,
                  debitMinor: costMinor,
                ),
                JournalLineDraft(
                  accountCode: Accounts.inventory.code,
                  creditMinor: costMinor,
                  productId: productId,
                ),
              ];
        break;
    }

    return JournalEntryDraft(
      entryNo: nextEntryNo('JE-ADJ'),
      effectiveDate: date,
      postedAt: timestamp,
      sourceType: sourceAdjustment,
      sourceId: targetMovementId ?? productId,
      memo: memo ?? 'Stock adjustment ($reason)',
      origin: origin,
      lines: lines,
    );
  }
}

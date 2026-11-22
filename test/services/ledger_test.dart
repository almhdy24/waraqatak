import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/customer_statement_service.dart';

Document doc(
  int id,
  String type,
  DateTime date, {
  double subtotal = 0,
  double discount = 0,
  double tax = 0,
  double? total,
  double paid = 0,
  String? method,
  int? related,
  String status = DocumentStatus.issued,
}) {
  final t = total ?? subtotal - discount + tax;
  return Document(
    id: id,
    type: type,
    documentNumber: '$type-$id',
    date: date,
    subtotal: subtotal,
    discount: discount,
    taxRate: 0,
    taxAmount: tax,
    total: t,
    paid: paid,
    remaining: t - paid,
    paymentMethod: method,
    relatedDocumentId: related,
    status: status,
  );
}

DocumentItem item(int docId, double qty, double price, {int? productId}) =>
    DocumentItem(
      documentId: docId,
      productId: productId,
      description: 'x',
      quantity: qty,
      price: price,
      total: qty * price,
    );

DateTime day(int d) => DateTime(2026, 1, d);

double balanceOf(List<JournalEntry> entries, Account a) =>
    AccountingReports.trialBalance(entries).rows
        .where((r) => r.account == a)
        .map((r) => r.balance)
        .fold(0.0, (s, v) => s + v);

void expectBalanced(List<JournalEntry> entries) {
  for (final e in entries) {
    expect(
      e.totalDebit,
      closeTo(e.totalCredit, 1e-6),
      reason: '${e.source} ${e.reference} is not balanced',
    );
  }
  expect(AccountingReports.trialBalance(entries).isBalanced, isTrue);
  expect(AccountingReports.balanceSheet(entries).isBalanced, isTrue);
}

void main() {
  const widget = Product(
    id: 1,
    name: 'Widget',
    salePrice: 20,
    purchasePrice: 8,
    stockQuantity: 9,
  );

  // Opening 5 @ 8, purchase 10 @ 11, sell 6 @ 20 + 15% VAT, part-paid
  // purchase by voucher, invoice paid by receipt.
  LedgerInput fullCycle() => LedgerInput(
    documents: [
      doc(10, 'purchase', day(2), subtotal: 110, paid: 50),
      doc(
        11,
        'expense_voucher',
        day(3),
        subtotal: 50,
        paid: 50,
        method: 'bank',
        related: 10,
      ),
      doc(
        20,
        'invoice',
        day(5),
        subtotal: 120,
        tax: 18,
        paid: 138,
        status: DocumentStatus.paid,
      ),
      doc(
        21,
        'payment_receipt',
        day(5),
        subtotal: 138,
        paid: 138,
        method: 'cash',
        related: 20,
      ),
    ],
    itemsByDocument: {
      10: [item(10, 10, 11, productId: 1)],
      20: [item(20, 6, 20, productId: 1)],
    },
    products: {1: widget},
    stockMovements: [
      StockMovement(
        productId: 1,
        type: StockMovement.typeOpening,
        quantity: 5,
        date: day(1),
      ),
    ],
    payments: [
      DocumentPayment(
        documentId: 10,
        amount: 50,
        date: day(3),
        receiptDocumentId: 11,
      ),
      DocumentPayment(
        documentId: 20,
        amount: 138,
        date: day(5),
        receiptDocumentId: 21,
      ),
    ],
  );

  group('full trading cycle', () {
    final entries = LedgerBuilder.build(fullCycle());

    test('every entry, the trial balance and the balance sheet balance', () {
      expectBalanced(entries);
    });

    test('account balances', () {
      expect(balanceOf(entries, Accounts.cash), closeTo(138, 1e-6));
      expect(balanceOf(entries, Accounts.bank), closeTo(-50, 1e-6));
      expect(balanceOf(entries, Accounts.receivables), closeTo(0, 1e-6));
      expect(balanceOf(entries, Accounts.payables), closeTo(60, 1e-6));
      expect(balanceOf(entries, Accounts.vatOutput), closeTo(18, 1e-6));
      expect(balanceOf(entries, Accounts.openingEquity), closeTo(40, 1e-6));
      expect(balanceOf(entries, Accounts.salesRevenue), closeTo(120, 1e-6));
    });

    test('cost of sales uses the weighted average (IAS 2)', () {
      // (5×8 + 10×11) / 15 = 10 per unit → 6 sold = 60, 9 left = 90.
      expect(balanceOf(entries, Accounts.cogs), closeTo(60, 1e-6));
      expect(balanceOf(entries, Accounts.inventory), closeTo(90, 1e-6));
    });

    test('income statement and balance sheet', () {
      final pl = AccountingReports.incomeStatement(entries);
      expect(pl.salesRevenue, closeTo(120, 1e-6));
      expect(pl.grossProfit, closeTo(60, 1e-6));
      expect(pl.netProfit, closeTo(60, 1e-6));

      final bs = AccountingReports.balanceSheet(entries);
      expect(bs.totalAssets, closeTo(178, 1e-6));
      expect(bs.totalLiabilities, closeTo(78, 1e-6));
      expect(bs.retainedEarnings, closeTo(60, 1e-6));
      expect(bs.totalEquity, closeTo(100, 1e-6));
    });

    test('entries are in date order', () {
      for (var i = 1; i < entries.length; i++) {
        expect(entries[i].date.isBefore(entries[i - 1].date), isFalse);
      }
    });

    test('balance sheet as of a date only sees earlier entries', () {
      final bs = AccountingReports.balanceSheet(entries, asOf: day(4));
      expect(bs.isBalanced, isTrue);
      expect(bs.retainedEarnings, closeTo(0, 1e-6));
      expect(bs.assets[Accounts.inventory], closeTo(150, 1e-6));
    });
  });

  test('drafts and cancelled documents post nothing', () {
    final entries = LedgerBuilder.build(
      LedgerInput(
        documents: [
          doc(
            1,
            'invoice',
            day(1),
            subtotal: 100,
            status: DocumentStatus.draft,
          ),
          doc(
            2,
            'invoice',
            day(1),
            subtotal: 100,
            status: DocumentStatus.cancelled,
          ),
          doc(
            3,
            'purchase',
            day(1),
            subtotal: 50,
            status: DocumentStatus.cancelled,
          ),
          doc(4, 'quotation', day(1), subtotal: 70),
        ],
        itemsByDocument: {
          1: [item(1, 1, 100, productId: 1)],
          2: [item(2, 1, 100, productId: 1)],
        },
        products: const {
          1: Product(id: 1, name: 'P', salePrice: 100, purchasePrice: 10),
        },
        stockMovements: const [],
      ),
    );
    expect(entries, isEmpty);
  });

  group('payments', () {
    test('row without receipt posts on its own date and method', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [doc(1, 'invoice', day(1), subtotal: 100, paid: 40)],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
          payments: [
            DocumentPayment(
              documentId: 1,
              amount: 40,
              paymentMethod: 'bank',
              date: day(9),
            ),
          ],
        ),
      );
      expectBalanced(entries);
      final pay = entries.singleWhere(
        (e) => e.source == EntrySource.invoicePayment,
      );
      expect(pay.date, day(9));
      expect(pay.lines.first.account, Accounts.bank);
      expect(balanceOf(entries, Accounts.receivables), closeTo(60, 1e-6));
    });

    test('paid amount without rows posts on the document date', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'purchase', day(2), subtotal: 80, paid: 80, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );
      expectBalanced(entries);
      final pay = entries.singleWhere(
        (e) => e.source == EntrySource.purchasePayment,
      );
      expect(pay.date, day(2));
      expect(balanceOf(entries, Accounts.cash), closeTo(-80, 1e-6));
      expect(balanceOf(entries, Accounts.payables), closeTo(0, 1e-6));
      expect(balanceOf(entries, Accounts.operatingExpenses), closeTo(80, 1e-6));
    });

    test('old unlinked rows are not counted twice next to a receipt', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 100, paid: 100),
            doc(
              2,
              'payment_receipt',
              day(2),
              subtotal: 100,
              paid: 100,
              method: 'cash',
              related: 1,
            ),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
          payments: [DocumentPayment(documentId: 1, amount: 100, date: day(2))],
        ),
      );
      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.cash), closeTo(100, 1e-6));
      expect(balanceOf(entries, Accounts.receivables), closeTo(0, 1e-6));
    });

    test('cancelled voucher: its payment row still settles the purchase', () {
      // Cancelling a voucher does not reduce the purchase's paid amount.
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'purchase', day(1), subtotal: 100, paid: 30),
            doc(
              2,
              'expense_voucher',
              day(2),
              subtotal: 30,
              paid: 30,
              related: 1,
              status: DocumentStatus.cancelled,
            ),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
          payments: [
            DocumentPayment(
              documentId: 1,
              amount: 30,
              paymentMethod: 'cash',
              date: day(2),
              receiptDocumentId: 2,
            ),
          ],
        ),
      );
      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.payables), closeTo(70, 1e-6));
      expect(balanceOf(entries, Accounts.cash), closeTo(-30, 1e-6));
    });

    test('unlinked receipt is other income; unlinked voucher an expense', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'payment_receipt', day(1), subtotal: 25, paid: 25),
            doc(2, 'expense_voucher', day(1), subtotal: 15, paid: 15),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );
      expectBalanced(entries);
      final pl = AccountingReports.incomeStatement(entries);
      expect(pl.otherIncome, closeTo(25, 1e-6));
      expect(pl.operatingExpenses, closeTo(15, 1e-6));
      expect(pl.netProfit, closeTo(10, 1e-6));
    });
  });

  test('purchase discount is allocated between stock and expenses', () {
    // Product 60 + service 40 = 100, discount 10 → net 90: stock 54, exp 36.
    final entries = LedgerBuilder.build(
      LedgerInput(
        documents: [
          doc(1, 'purchase', day(1), subtotal: 100, discount: 10, tax: 9),
        ],
        itemsByDocument: {
          1: [item(1, 6, 10, productId: 1), item(1, 1, 40, productId: 2)],
        },
        products: const {
          1: Product(id: 1, name: 'Stocked', salePrice: 20, stockQuantity: 6),
          2: Product(
            id: 2,
            name: 'Service',
            type: Product.typeService,
            salePrice: 40,
          ),
        },
        stockMovements: const [],
      ),
    );
    expectBalanced(entries);
    expect(balanceOf(entries, Accounts.inventory), closeTo(54, 1e-6));
    expect(balanceOf(entries, Accounts.operatingExpenses), closeTo(36, 1e-6));
    expect(balanceOf(entries, Accounts.vatInput), closeTo(9, 1e-6));
    expect(balanceOf(entries, Accounts.payables), closeTo(99, 1e-6));
  });

  test('stock adjustments move at the running average', () {
    final entries = LedgerBuilder.build(
      LedgerInput(
        documents: [doc(1, 'purchase', day(1), subtotal: 100)],
        itemsByDocument: {
          1: [item(1, 10, 10, productId: 1)],
        },
        products: const {
          1: Product(id: 1, name: 'P', salePrice: 20, stockQuantity: 8),
        },
        stockMovements: [
          StockMovement(
            productId: 1,
            type: StockMovement.typeAdjustment,
            quantity: -2,
            date: day(3),
          ),
        ],
      ),
    );
    expectBalanced(entries);
    expect(
      balanceOf(entries, Accounts.inventoryAdjustments),
      closeTo(20, 1e-6),
    );
    expect(balanceOf(entries, Accounts.inventory), closeTo(80, 1e-6));
  });

  group('stock without movements', () {
    const legacy = Product(
      id: 1,
      name: 'Old',
      salePrice: 10,
      purchasePrice: 5,
      stockQuantity: 4,
    );

    test('enters as opening stock before the first event', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [doc(1, 'invoice', day(10), subtotal: 20)],
          itemsByDocument: {
            1: [item(1, 2, 10, productId: 1)],
          },
          // 4 in stock now after selling 2 → 6 existed before tracking.
          products: const {1: legacy},
          stockMovements: const [],
        ),
      );
      expectBalanced(entries);
      final opening = entries.singleWhere(
        (e) => e.source == EntrySource.openingStock,
      );
      expect(opening.date.isBefore(day(10)), isTrue);
      expect(opening.totalDebit, closeTo(30, 1e-6));
      expect(balanceOf(entries, Accounts.cogs), closeTo(10, 1e-6));
      expect(balanceOf(entries, Accounts.inventory), closeTo(20, 1e-6));
    });

    test('is left out of books in another currency', () {
      final entries = LedgerBuilder.build(
        const LedgerInput(
          documents: [],
          itemsByDocument: {},
          products: {1: legacy},
          stockMovements: [],
          productPricesApply: false,
        ),
      );
      expect(entries, isEmpty);
    });
  });

  group('reports', () {
    final entries = LedgerBuilder.build(fullCycle());

    test('income statement for a period', () {
      final before = AccountingReports.incomeStatement(entries, to: day(4));
      expect(before.salesRevenue, 0);
      final period = AccountingReports.incomeStatement(
        entries,
        from: day(5),
        to: day(5),
      );
      expect(period.salesRevenue, closeTo(120, 1e-6));
    });

    test('general ledger opening balance and running balance', () {
      final gl = AccountingReports.generalLedger(
        entries,
        Accounts.inventory,
        from: day(3),
      );
      // Opening stock 40 + purchase 110 before day 3.
      expect(gl.openingBalance, closeTo(150, 1e-6));
      expect(gl.lines, hasLength(1));
      expect(gl.lines.single.credit, closeTo(60, 1e-6));
      expect(gl.closingBalance, closeTo(90, 1e-6));
    });

    test('account codes are unique and resolvable', () {
      final codes = Accounts.all.map((a) => a.code).toSet();
      expect(codes, hasLength(Accounts.all.length));
      for (final a in Accounts.all) {
        expect(Accounts.byCode(a.code), same(a));
      }
    });

    test(
      'missing COGS is not silently zeroed: income statement flags incomplete costs and untrusted profit',
      () {
        // Sale of product with purchasePrice=0 and no recorded movements/purchases
        final entries = LedgerBuilder.build(
          LedgerInput(
            documents: [doc(10, 'invoice', day(1), subtotal: 500)],
            itemsByDocument: {
              10: [item(10, 5, 100, productId: 99)],
            },
            products: const {
              99: Product(
                id: 99,
                name: 'مجهول',
                salePrice: 100,
                purchasePrice: 0,
              ),
            },
            stockMovements: const [],
          ),
        );

        // Trial balance and balance sheet remain balanced
        expectBalanced(entries);

        final stmt = AccountingReports.incomeStatement(entries);
        expect(stmt.salesRevenue, 500.0);
        expect(stmt.costOfSales, 0.0);
        expect(
          stmt.hasIncompleteCostOfSales,
          isTrue,
          reason:
              'Sale with missing COGS must flag income statement as incomplete',
        );
        expect(stmt.uncostedSalesCount, 1);
        expect(
          stmt.trustedGrossProfit,
          isNull,
          reason: 'Gross profit cannot be trusted when COGS is missing',
        );
        expect(
          stmt.trustedNetProfit,
          isNull,
          reason: 'Net profit cannot be trusted when COGS is missing',
        );
      },
    );

    test(
      'complete COGS presents trusted gross and net profit matching calculated values',
      () {
        final entries = LedgerBuilder.build(fullCycle());
        final stmt = AccountingReports.incomeStatement(entries);
        expect(stmt.hasIncompleteCostOfSales, isFalse);
        expect(stmt.uncostedSalesCount, 0);
        expect(stmt.trustedGrossProfit, stmt.grossProfit);
        expect(stmt.trustedNetProfit, stmt.netProfit);
      },
    );
  });

  group('Phase 3: Cancelled Invoices and Receipts Accounting Remediation', () {
    test('1. An unpaid invoice that is cancelled posts nothing to ledger', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, status: DocumentStatus.cancelled),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expect(entries, isEmpty);
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      expect(balanceOf(entries, Accounts.salesRevenue), 0.0);
      expect(balanceOf(entries, Accounts.cash), 0.0);
      expectBalanced(entries);
    });

    test('2. A fully paid invoice that is cancelled retains cash and credits customer advance in payables', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 1000, status: DocumentStatus.cancelled),
            doc(2, 'payment_receipt', day(1), subtotal: 1000, paid: 1000, related: 1, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      expect(entries.length, 1);
      final receiptEntry = entries.first;
      expect(receiptEntry.source, EntrySource.receipt);
      // Real cash was received
      expect(balanceOf(entries, Accounts.cash), 1000.0);
      // Accounts Receivable is NOT credited into negative
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      // No sales revenue recognized for cancelled invoice
      expect(balanceOf(entries, Accounts.salesRevenue), 0.0);
      // Funds held are classified as customer advance / refund liability in customerDeposits
      expect(balanceOf(entries, Accounts.customerDeposits), 1000.0);
    });

    test('3. A partially paid invoice that is cancelled keeps AR at zero and records paid amount as payables', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 400, status: DocumentStatus.cancelled),
            doc(2, 'payment_receipt', day(1), subtotal: 400, paid: 400, related: 1, method: 'bank'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.bank), 400.0);
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      expect(balanceOf(entries, Accounts.salesRevenue), 0.0);
      expect(balanceOf(entries, Accounts.customerDeposits), 400.0);
    });

    test('4. Multiple receipts against one invoice followed by cancellation record full cash and payables', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 600, status: DocumentStatus.cancelled),
            doc(2, 'payment_receipt', day(2), subtotal: 350, paid: 350, related: 1, method: 'cash'),
            doc(3, 'payment_receipt', day(3), subtotal: 250, paid: 250, related: 1, method: 'bank'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      expect(entries.length, 2);
      expect(balanceOf(entries, Accounts.cash), 350.0);
      expect(balanceOf(entries, Accounts.bank), 250.0);
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      expect(balanceOf(entries, Accounts.customerDeposits), 600.0);
    });

    test('5. Cancellation followed by receipt reversal clears customer advance and cash', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 400, status: DocumentStatus.cancelled),
            doc(2, 'payment_receipt', day(2), subtotal: 400, paid: 400, related: 1, method: 'cash', status: DocumentStatus.cancelled),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expect(entries, isEmpty);
      expect(balanceOf(entries, Accounts.cash), 0.0);
      expect(balanceOf(entries, Accounts.payables), 0.0);
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      expectBalanced(entries);
    });

    test('6. Customer statement versus general-ledger reconciliation', () {
      const customer = Contact(id: 1, name: 'Customer Test', type: 'customer');
      final docs = [
        // Invoice 1 (cancelled) with Receipt 2 (400)
        doc(1, 'invoice', day(1), subtotal: 1000, paid: 400, status: DocumentStatus.cancelled),
        doc(2, 'payment_receipt', day(2), subtotal: 400, paid: 400, related: 1, method: 'cash'),
        // Invoice 3 (active) with Receipt 4 (250)
        doc(3, 'invoice', day(3), subtotal: 750, paid: 250, status: DocumentStatus.issued),
        doc(4, 'payment_receipt', day(4), subtotal: 250, paid: 250, related: 3, method: 'bank'),
      ];

      // 1. Customer statement computation
      final statement = CustomerStatementService.generateStatement(
        contact: customer,
        documents: docs,
        from: day(1),
        to: day(30),
      );

      // Statement closing balance reflects open active receivables (750 - 250 = 500)
      expect(statement.closingBalance, 500.0);
      // Explanatory section discloses the 400 receipt on cancelled invoice
      expect(statement.hasCancelledInvoiceReceipts, isTrue);
      expect(statement.cancelledInvoiceReceipts.length, 1);
      expect(statement.cancelledInvoiceReceipts[0].amount, 400.0);

      // 2. General Ledger computation
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: docs,
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      // General ledger Accounts Receivable exactly matches Customer Statement closing balance!
      expect(balanceOf(entries, Accounts.receivables), statement.closingBalance);
      expect(balanceOf(entries, Accounts.receivables), 500.0);

      // Customer credit from cancelled invoice is held in customerDeposits (liability), matching explanatory section
      expect(balanceOf(entries, Accounts.customerDeposits), statement.cancelledInvoiceReceipts[0].amount);
      expect(balanceOf(entries, Accounts.customerDeposits), 400.0);

      // Cash and Bank reflect the actual funds received
      expect(balanceOf(entries, Accounts.cash), 400.0);
      expect(balanceOf(entries, Accounts.bank), 250.0);
      expect(balanceOf(entries, Accounts.salesRevenue), 750.0);
    });

    test('7. Accounts Receivable before and after cancellation', () {
      // Before cancellation: active invoice with partial receipt
      final beforeEntries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 400, status: DocumentStatus.issued),
            doc(2, 'payment_receipt', day(2), subtotal: 400, paid: 400, related: 1, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(beforeEntries);
      expect(balanceOf(beforeEntries, Accounts.receivables), 600.0);
      expect(balanceOf(beforeEntries, Accounts.salesRevenue), 1000.0);
      expect(balanceOf(beforeEntries, Accounts.cash), 400.0);
      expect(balanceOf(beforeEntries, Accounts.payables), 0.0);

      // After cancellation: invoice is cancelled, receipt remains active
      final afterEntries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 1000, paid: 400, status: DocumentStatus.cancelled),
            doc(2, 'payment_receipt', day(2), subtotal: 400, paid: 400, related: 1, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(afterEntries);
      // Receivables drops to 0.0 (no negative receivable!)
      expect(balanceOf(afterEntries, Accounts.receivables), 0.0);
      expect(balanceOf(afterEntries, Accounts.salesRevenue), 0.0);
      // Cash is retained
      expect(balanceOf(afterEntries, Accounts.cash), 400.0);
      // 400 is reclassified from receivable offset to customer advance in customerDeposits
      expect(balanceOf(afterEntries, Accounts.customerDeposits), 400.0);
    });

    test('8. Cancelled purchase with expense voucher debits refund receivable and credits cash', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'purchase', day(1), subtotal: 500, paid: 300, status: DocumentStatus.cancelled),
            doc(2, 'expense_voucher', day(2), subtotal: 300, paid: 300, related: 1, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      // Cash paid to supplier is recorded
      expect(balanceOf(entries, Accounts.cash), -300.0);
      // Since purchase was cancelled, the money paid is a refund receivable owed by supplier
      expect(balanceOf(entries, Accounts.receivables), 300.0);
      expect(balanceOf(entries, Accounts.payables), 0.0);
      expect(balanceOf(entries, Accounts.operatingExpenses), 0.0);
    });

    test('9. Normal non-cancelled invoice payment regression credits receivables as expected', () {
      final entries = LedgerBuilder.build(
        LedgerInput(
          documents: [
            doc(1, 'invoice', day(1), subtotal: 500, paid: 500, status: DocumentStatus.paid),
            doc(2, 'payment_receipt', day(2), subtotal: 500, paid: 500, related: 1, method: 'cash'),
          ],
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.receivables), 0.0);
      expect(balanceOf(entries, Accounts.salesRevenue), 500.0);
      expect(balanceOf(entries, Accounts.cash), 500.0);
      expect(balanceOf(entries, Accounts.payables), 0.0);
    });

    test('10. Multi-currency ledger isolation with cancelled documents', () {
      final docs = [
        // USD cancelled invoice with active USD receipt
        Document(
          id: 1,
          type: 'invoice',
          documentNumber: 'INV-USD-1',
          date: day(1),
          subtotal: 200,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 200,
          paid: 200,
          remaining: 0,
          status: DocumentStatus.cancelled,
          currencyCode: 'USD',
        ),
        Document(
          id: 2,
          type: 'payment_receipt',
          documentNumber: 'REC-USD-2',
          date: day(2),
          subtotal: 200,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 200,
          paid: 200,
          remaining: 0,
          paymentMethod: 'bank',
          relatedDocumentId: 1,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        // SDG active invoice with active SDG receipt
        Document(
          id: 3,
          type: 'invoice',
          documentNumber: 'INV-SDG-3',
          date: day(1),
          subtotal: 50000,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 50000,
          paid: 50000,
          remaining: 0,
          status: DocumentStatus.paid,
          currencyCode: 'SDG',
        ),
        Document(
          id: 4,
          type: 'payment_receipt',
          documentNumber: 'REC-SDG-4',
          date: day(2),
          subtotal: 50000,
          discount: 0,
          taxRate: 0,
          taxAmount: 0,
          total: 50000,
          paid: 50000,
          remaining: 0,
          paymentMethod: 'cash',
          relatedDocumentId: 3,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
      ];

      // Build USD book
      final usdDocs = docs.where((d) => d.currencyCode == 'USD').toList();
      final usdEntries = LedgerBuilder.build(
        LedgerInput(
          documents: usdDocs,
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(usdEntries);
      expect(balanceOf(usdEntries, Accounts.bank), 200.0);
      expect(balanceOf(usdEntries, Accounts.receivables), 0.0);
      expect(balanceOf(usdEntries, Accounts.customerDeposits), 200.0);

      // Build SDG book
      final sdgDocs = docs.where((d) => d.currencyCode == 'SDG').toList();
      final sdgEntries = LedgerBuilder.build(
        LedgerInput(
          documents: sdgDocs,
          itemsByDocument: const {},
          products: const {},
          stockMovements: const [],
        ),
      );

      expectBalanced(sdgEntries);
      expect(balanceOf(sdgEntries, Accounts.cash), 50000.0);
      expect(balanceOf(sdgEntries, Accounts.receivables), 0.0);
      expect(balanceOf(sdgEntries, Accounts.salesRevenue), 50000.0);
      expect(balanceOf(sdgEntries, Accounts.payables), 0.0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/accounting/ledger.dart';

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
    AccountingReports.trialBalance(entries)
        .rows
        .where((r) => r.account == a)
        .map((r) => r.balance)
        .fold(0.0, (s, v) => s + v);

void expectBalanced(List<JournalEntry> entries) {
  for (final e in entries) {
    expect(e.totalDebit, closeTo(e.totalCredit, 1e-6),
        reason: '${e.source} ${e.reference} is not balanced');
  }
  expect(AccountingReports.trialBalance(entries).isBalanced, isTrue);
  expect(AccountingReports.balanceSheet(entries).isBalanced, isTrue);
}

void main() {
  const widget = Product(
      id: 1, name: 'Widget', salePrice: 20, purchasePrice: 8, stockQuantity: 9);

  // Opening 5 @ 8, purchase 10 @ 11, sell 6 @ 20 + 15% VAT, part-paid
  // purchase by voucher, invoice paid by receipt.
  LedgerInput fullCycle() => LedgerInput(
        documents: [
          doc(10, 'purchase', day(2), subtotal: 110, paid: 50),
          doc(11, 'expense_voucher', day(3),
              subtotal: 50, paid: 50, method: 'bank', related: 10),
          doc(20, 'invoice', day(5),
              subtotal: 120, tax: 18, paid: 138, status: DocumentStatus.paid),
          doc(21, 'payment_receipt', day(5),
              subtotal: 138, paid: 138, method: 'cash', related: 20),
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
              date: day(1)),
        ],
        payments: [
          DocumentPayment(
              documentId: 10, amount: 50, date: day(3), receiptDocumentId: 11),
          DocumentPayment(
              documentId: 20, amount: 138, date: day(5), receiptDocumentId: 21),
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
    final entries = LedgerBuilder.build(LedgerInput(
      documents: [
        doc(1, 'invoice', day(1), subtotal: 100, status: DocumentStatus.draft),
        doc(2, 'invoice', day(1),
            subtotal: 100, status: DocumentStatus.cancelled),
        doc(3, 'purchase', day(1),
            subtotal: 50, status: DocumentStatus.cancelled),
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
    ));
    expect(entries, isEmpty);
  });

  group('payments', () {
    test('row without receipt posts on its own date and method', () {
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [doc(1, 'invoice', day(1), subtotal: 100, paid: 40)],
        itemsByDocument: const {},
        products: const {},
        stockMovements: const [],
        payments: [
          DocumentPayment(
              documentId: 1,
              amount: 40,
              paymentMethod: 'bank',
              date: day(9)),
        ],
      ));
      expectBalanced(entries);
      final pay = entries.singleWhere((e) => e.source == EntrySource.invoicePayment);
      expect(pay.date, day(9));
      expect(pay.lines.first.account, Accounts.bank);
      expect(balanceOf(entries, Accounts.receivables), closeTo(60, 1e-6));
    });

    test('paid amount without rows posts on the document date', () {
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [
          doc(1, 'purchase', day(2), subtotal: 80, paid: 80, method: 'cash'),
        ],
        itemsByDocument: const {},
        products: const {},
        stockMovements: const [],
      ));
      expectBalanced(entries);
      final pay =
          entries.singleWhere((e) => e.source == EntrySource.purchasePayment);
      expect(pay.date, day(2));
      expect(balanceOf(entries, Accounts.cash), closeTo(-80, 1e-6));
      expect(balanceOf(entries, Accounts.payables), closeTo(0, 1e-6));
      expect(balanceOf(entries, Accounts.operatingExpenses), closeTo(80, 1e-6));
    });

    test('old unlinked rows are not counted twice next to a receipt', () {
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [
          doc(1, 'invoice', day(1), subtotal: 100, paid: 100),
          doc(2, 'payment_receipt', day(2),
              subtotal: 100, paid: 100, method: 'cash', related: 1),
        ],
        itemsByDocument: const {},
        products: const {},
        stockMovements: const [],
        payments: [DocumentPayment(documentId: 1, amount: 100, date: day(2))],
      ));
      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.cash), closeTo(100, 1e-6));
      expect(balanceOf(entries, Accounts.receivables), closeTo(0, 1e-6));
    });

    test('cancelled voucher: its payment row still settles the purchase', () {
      // Cancelling a voucher does not reduce the purchase's paid amount.
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [
          doc(1, 'purchase', day(1), subtotal: 100, paid: 30),
          doc(2, 'expense_voucher', day(2),
              subtotal: 30,
              paid: 30,
              related: 1,
              status: DocumentStatus.cancelled),
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
              receiptDocumentId: 2),
        ],
      ));
      expectBalanced(entries);
      expect(balanceOf(entries, Accounts.payables), closeTo(70, 1e-6));
      expect(balanceOf(entries, Accounts.cash), closeTo(-30, 1e-6));
    });

    test('unlinked receipt is other income; unlinked voucher an expense', () {
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [
          doc(1, 'payment_receipt', day(1), subtotal: 25, paid: 25),
          doc(2, 'expense_voucher', day(1), subtotal: 15, paid: 15),
        ],
        itemsByDocument: const {},
        products: const {},
        stockMovements: const [],
      ));
      expectBalanced(entries);
      final pl = AccountingReports.incomeStatement(entries);
      expect(pl.otherIncome, closeTo(25, 1e-6));
      expect(pl.operatingExpenses, closeTo(15, 1e-6));
      expect(pl.netProfit, closeTo(10, 1e-6));
    });
  });

  test('purchase discount is allocated between stock and expenses', () {
    // Product 60 + service 40 = 100, discount 10 → net 90: stock 54, exp 36.
    final entries = LedgerBuilder.build(LedgerInput(
      documents: [
        doc(1, 'purchase', day(1), subtotal: 100, discount: 10, tax: 9),
      ],
      itemsByDocument: {
        1: [item(1, 6, 10, productId: 1), item(1, 1, 40, productId: 2)],
      },
      products: const {
        1: Product(id: 1, name: 'Stocked', salePrice: 20, stockQuantity: 6),
        2: Product(
            id: 2, name: 'Service', type: Product.typeService, salePrice: 40),
      },
      stockMovements: const [],
    ));
    expectBalanced(entries);
    expect(balanceOf(entries, Accounts.inventory), closeTo(54, 1e-6));
    expect(balanceOf(entries, Accounts.operatingExpenses), closeTo(36, 1e-6));
    expect(balanceOf(entries, Accounts.vatInput), closeTo(9, 1e-6));
    expect(balanceOf(entries, Accounts.payables), closeTo(99, 1e-6));
  });

  test('stock adjustments move at the running average', () {
    final entries = LedgerBuilder.build(LedgerInput(
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
            date: day(3)),
      ],
    ));
    expectBalanced(entries);
    expect(balanceOf(entries, Accounts.inventoryAdjustments), closeTo(20, 1e-6));
    expect(balanceOf(entries, Accounts.inventory), closeTo(80, 1e-6));
  });

  group('stock without movements', () {
    const legacy = Product(
        id: 1, name: 'Old', salePrice: 10, purchasePrice: 5, stockQuantity: 4);

    test('enters as opening stock before the first event', () {
      final entries = LedgerBuilder.build(LedgerInput(
        documents: [doc(1, 'invoice', day(10), subtotal: 20)],
        itemsByDocument: {
          1: [item(1, 2, 10, productId: 1)],
        },
        // 4 in stock now after selling 2 → 6 existed before tracking.
        products: const {1: legacy},
        stockMovements: const [],
      ));
      expectBalanced(entries);
      final opening =
          entries.singleWhere((e) => e.source == EntrySource.openingStock);
      expect(opening.date.isBefore(day(10)), isTrue);
      expect(opening.totalDebit, closeTo(30, 1e-6));
      expect(balanceOf(entries, Accounts.cogs), closeTo(10, 1e-6));
      expect(balanceOf(entries, Accounts.inventory), closeTo(20, 1e-6));
    });

    test('is left out of books in another currency', () {
      final entries = LedgerBuilder.build(const LedgerInput(
        documents: [],
        itemsByDocument: {},
        products: {1: legacy},
        stockMovements: [],
        productPricesApply: false,
      ));
      expect(entries, isEmpty);
    });
  });

  group('reports', () {
    final entries = LedgerBuilder.build(fullCycle());

    test('income statement for a period', () {
      final before = AccountingReports.incomeStatement(entries, to: day(4));
      expect(before.salesRevenue, 0);
      final period =
          AccountingReports.incomeStatement(entries, from: day(5), to: day(5));
      expect(period.salesRevenue, closeTo(120, 1e-6));
    });

    test('general ledger opening balance and running balance', () {
      final gl = AccountingReports.generalLedger(entries, Accounts.inventory,
          from: day(3));
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
  });
}

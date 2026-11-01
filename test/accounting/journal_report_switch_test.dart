import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_report_switch_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    await db.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await db.closeDatabase();
    if (tempDir.existsSync()) {
      for (final f in tempDir.listSync()) {
        if (f is File) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }

    await db.insertBusiness(
      const Business(
        name: 'Report Test Business',
        ownerName: 'Finance Manager',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
      ),
    );
  });

  test('1. Default setting: journal_reports_enabled is false and reports derive on the fly', () async {
    final enabled = await LedgerService.isJournalReportsEnabled();
    expect(enabled, isFalse);

    // Create a product and a sale
    final pId = await db.insertProduct(
      Product(
        name: 'سلعة أ',
        barcode: 'P1',
        salePrice: 100.0,
        purchasePrice: 60.0,
        averageCost: 60.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-RS-1',
      date: DateTime(2026, 3, 1),
      subtotal: 100.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 100.0,
      paid: 100.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'سلعة أ',
        quantity: 1.0,
        price: 100.0,
        total: 100.0,
      ),
    ]);

    final book = await LedgerService.load();
    expect(book.currencyCode, equals('SDG'));
    expect(book.entries, isNotEmpty);
    // Entry was derived via LedgerBuilder
    final tb = AccountingReports.trialBalance(book.entries);
    expect(tb.isBalanced, isTrue);
  });

  test('2. Toggling journal_reports_enabled switches report source with 100% financial parity', () async {
    // 1. Setup multi-transaction business scenario
    final pId = await db.insertProduct(
      Product(name: 'منتج تجريبي', barcode: 'PROD-1', salePrice: 150.0, purchasePrice: 80.0),
    );

    // Purchase stocked item
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-101',
      date: DateTime(2026, 3, 1),
      subtotal: 800.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 120.0,
      total: 920.0,
      paid: 920.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(pur, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'منتج تجريبي',
        quantity: 10.0,
        price: 80.0,
        total: 800.0,
      ),
    ]);

    // Sale invoice
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-201',
      date: DateTime(2026, 3, 2),
      subtotal: 450.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 67.5,
      total: 517.5,
      paid: 200.0,
      remaining: 317.5,
      paymentMethod: 'cash',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );
    final invId = await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'منتج تجريبي',
        quantity: 3.0,
        price: 150.0,
        total: 450.0,
      ),
    ]);

    // Subsequent payment on invoice with receipt
    await db.recordPaymentWithReceipt(
      documentId: invId,
      amount: 100.0,
      paymentMethod: 'bank_transfer',
      notes: 'تحصيل جزئي',
    );

    // Standalone expense voucher
    final vch = Document(
      type: 'expense_voucher',
      documentNumber: 'VCH-301',
      date: DateTime(2026, 3, 4),
      subtotal: 50.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 50.0,
      paid: 50.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(vch, [
      DocumentItem(
        documentId: 0,
        description: 'فاتورة كهرباء',
        quantity: 1.0,
        price: 50.0,
        total: 50.0,
      ),
    ]);

    // 2. Load reports with journal_reports_enabled = false (derived)
    expect(await LedgerService.isJournalReportsEnabled(), isFalse);
    final derivedBook = await LedgerService.load();
    final derivedTB = AccountingReports.trialBalance(derivedBook.entries);
    final derivedIS = AccountingReports.incomeStatement(derivedBook.entries);
    final derivedBS = AccountingReports.balanceSheet(derivedBook.entries);

    expect(derivedTB.isBalanced, isTrue);

    // 3. Switch flag to true
    await LedgerService.setJournalReportsEnabled(true);
    expect(await LedgerService.isJournalReportsEnabled(), isTrue);

    // 4. Load reports with journal_reports_enabled = true (persisted journal)
    final journalBook = await LedgerService.load();
    final journalTB = AccountingReports.trialBalance(journalBook.entries);
    final journalIS = AccountingReports.incomeStatement(journalBook.entries);
    final journalBS = AccountingReports.balanceSheet(journalBook.entries);

    expect(journalTB.isBalanced, isTrue);

    // 5. Verify exact parity between derived and journal reports
    // (a) Trial Balance exact balance match on all 13 accounts
    for (final acct in Accounts.all) {
      final dBal = derivedTB.rows
          .firstWhere((r) => r.account == acct, orElse: () => AccountBalance(acct, 0, 0))
          .balance;
      final jBal = journalTB.rows
          .firstWhere((r) => r.account == acct, orElse: () => AccountBalance(acct, 0, 0))
          .balance;
      expect(
        (jBal - dBal).abs(),
        lessThan(0.001),
        reason: 'Trial balance balance mismatch on account ${acct.code}',
      );
    }

    // (b) Income Statement match
    expect(journalIS.salesRevenue, closeTo(derivedIS.salesRevenue, 0.001));
    expect(journalIS.costOfSales, closeTo(derivedIS.costOfSales, 0.001));
    expect(journalIS.operatingExpenses, closeTo(derivedIS.operatingExpenses, 0.001));
    expect(journalIS.grossProfit, closeTo(derivedIS.grossProfit, 0.001));
    expect(journalIS.netProfit, closeTo(derivedIS.netProfit, 0.001));

    // (c) Balance Sheet match
    expect(journalBS.totalAssets, closeTo(derivedBS.totalAssets, 0.001));
    expect(journalBS.totalLiabilities, closeTo(derivedBS.totalLiabilities, 0.001));
    expect(journalBS.retainedEarnings, closeTo(derivedBS.retainedEarnings, 0.001));
    expect(journalBS.isBalanced, isTrue);

    // 6. Test forceDerived: true overrides the setting
    final forcedBook = await LedgerService.load(forceDerived: true);
    final forcedTB = AccountingReports.trialBalance(forcedBook.entries);
    expect(forcedTB.isBalanced, isTrue);

    // 7. Test Parity Status Diagnostic helper
    final status = await JournalBackfillService.checkParityStatus();
    expect(status.isParity, isTrue);
    expect(status.reportsFromJournal, isTrue);
    expect(status.entryCount, greaterThan(0));
    expect(status.mismatchReason, isNull);
  });
}

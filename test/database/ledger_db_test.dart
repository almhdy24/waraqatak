// Real SQLite (ffi) integration test: the derived ledger stays consistent
// with what the app records (documents, payments, stock).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/inventory_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Own directory: test files run in parallel and share the DB file name.
    final dir = Directory.systemTemp.createTempSync('ledger_db_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  test('ledger built from a real database balances and reconciles', () async {
    final db = DatabaseHelper.instance;
    await db.insertBusiness(const Business(
        name: 'متجر النور', ownerName: 'سارة', phone: '1', address: 'x', taxRate: 10));
    final business = (await db.getFirstBusiness())!;

    // 10 in stock @ 100 (opening), then buy 5 @ 130 → average 110.
    // Every record is stamped with the real time, in call order.
    final pid = await ProductService.createProduct(
        name: 'زيت', salePrice: 200, purchasePrice: 100, stockQuantity: 10);

    final purchase = await DocumentService.createDocument(
        type: 'purchase', business: business,
        items: [DocumentItemInput(description: 'زيت', quantity: 5, price: 130, productId: pid)]);
    await DocumentService.recordPayment(documentId: purchase, amount: 300, paymentMethod: 'cash');

    // Quick sale of 3, paid in full at once.
    await DocumentService.createDocument(
        type: 'invoice', business: business, payNowMethod: 'cash',
        items: [DocumentItemInput(description: 'زيت', quantity: 3, price: 200, productId: pid)]);
    // Credit sale of 2, part paid later by bank transfer.
    final credit = await DocumentService.createDocument(
        type: 'invoice', business: business,
        items: [DocumentItemInput(description: 'زيت', quantity: 2, price: 200, productId: pid)]);
    await DocumentService.recordPayment(
        documentId: credit, amount: 100, paymentMethod: 'bank');
    // A cancelled sale and a draft change nothing.
    final cancelled = await DocumentService.createDocument(
        type: 'invoice', business: business,
        items: [DocumentItemInput(description: 'زيت', quantity: 1, price: 200, productId: pid)]);
    await DocumentService.cancelDocument(cancelled);
    await DocumentService.createDocument(
        type: 'invoice', business: business, isDraft: true,
        items: [DocumentItemInput(description: 'زيت', quantity: 4, price: 200, productId: pid)]);
    // One unit damaged.
    await InventoryService.adjust(productId: pid, delta: -1, notes: 'تالف');

    final book = await LedgerService.load();
    final entries = book.entries;
    expect(book.currencyCode, business.currencyCode);
    for (final e in entries) {
      expect(e.totalDebit, closeTo(e.totalCredit, 1e-6), reason: '${e.source} ${e.reference}');
    }
    expect(AccountingReports.trialBalance(entries).isBalanced, isTrue);
    final bs = AccountingReports.balanceSheet(entries);
    expect(bs.isBalanced, isTrue);

    double bal(Account a) => AccountingReports.generalLedger(entries, a).closingBalance;

    // Stock: 10 + 5 − 3 − 2 − 1 = 9 left at the 110 average.
    expect((await db.getProductById(pid))!.stockQuantity, 9);
    expect(bal(Accounts.inventory), closeTo(990, 1e-6));
    expect(bal(Accounts.cogs), closeTo(550, 1e-6));
    expect(bal(Accounts.inventoryAdjustments), closeTo(110, 1e-6));

    // Receivables and payables equal what the documents still owe.
    final docs = await db.getAllDocuments();
    double owed(String type) => docs
        .where((d) => d.type == type && d.status != 'cancelled' && d.status != 'draft')
        .fold(0.0, (s, d) => s + d.remaining);
    expect(bal(Accounts.receivables), closeTo(owed('invoice'), 1e-6));
    expect(bal(Accounts.payables), closeTo(owed('purchase'), 1e-6));
    expect(bal(Accounts.bank), closeTo(100, 1e-6));

    // Revenue is net of VAT for the two posted sales (5 × 200).
    final pl = AccountingReports.incomeStatement(entries);
    expect(pl.salesRevenue, closeTo(1000, 1e-6));
    expect(pl.grossProfit, closeTo(450, 1e-6));
  });
}

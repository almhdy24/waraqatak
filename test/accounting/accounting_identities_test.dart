import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/customer_statement_service.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('accounting_identities_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'مؤسسة الهويات المحاسبية',
        ownerName: 'المدير المالي',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 15.0,
        taxesEnabled: true,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.closeDatabase();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('5 Accounting Identities hold under realistic mixed transaction lifecycle', () async {
    final db = DatabaseHelper.instance;
    final business = (await db.getFirstBusiness())!;

    // 1. Seed Contacts
    final customerId = await db.insertContact(
      const Contact(name: 'عميل رئيسي', phone: '0911111111', type: 'customer'),
    );
    final supplierId = await db.insertContact(
      const Contact(name: 'مورد معتمد', phone: '0922222222', type: 'supplier'),
    );
    final customer = (await db.getContactById(customerId))!;
    final supplier = (await db.getContactById(supplierId))!;

    // 2. Seed Products
    final p1Id = await db.insertProduct(
      const Product(
        name: 'منتج أ',
        salePrice: 200.0,
        purchasePrice: 120.0,
        stockQuantity: 50,
        isTaxable: true,
      ),
    );
    final p2Id = await db.insertProduct(
      const Product(
        name: 'منتج ب',
        salePrice: 150.0,
        purchasePrice: 90.0,
        stockQuantity: 40,
        isTaxable: true,
      ),
    );

    // Initial stock snapshot
    final p1InitialStock = 50.0;
    final p2InitialStock = 40.0;

    // 3. Seed 5 Purchases
    var p1Purchased = 0.0;
    var p2Purchased = 0.0;
    for (var i = 1; i <= 5; i++) {
      final docId = await DocumentService.createDocument(
        type: 'purchase',
        business: business,
        contact: supplier,
        items: [
          DocumentItemInput(description: 'منتج أ توريد', quantity: 10, price: 120.0, productId: p1Id),
          DocumentItemInput(description: 'منتج ب توريد', quantity: 5, price: 90.0, productId: p2Id),
        ],
        paid: (i % 2 == 0) ? 1000.0 : 0.0,
        date: DateTime(2026, 11, i),
      );
      expect(docId, isPositive);
      p1Purchased += 10;
      p2Purchased += 5;
    }

    // 4. Seed 10 Invoices with varying payments
    var p1Sold = 0.0;
    var p2Sold = 0.0;
    final invoiceIds = <int>[];
    for (var i = 1; i <= 10; i++) {
      final q1 = 2.0;
      final q2 = 1.0;
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        contact: customer,
        items: [
          DocumentItemInput(description: 'منتج أ بيع', quantity: q1, price: 200.0, productId: p1Id, taxable: true),
          DocumentItemInput(description: 'منتج ب بيع', quantity: q2, price: 150.0, productId: p2Id, taxable: true),
        ],
        discount: (i == 3 || i == 7) ? 50.0 : 0.0,
        paid: (i <= 5) ? 300.0 : 0.0,
        date: DateTime(2026, 11, 10 + i),
      );
      invoiceIds.add(docId);
      p1Sold += q1;
      p2Sold += q2;
    }

    // 5. Cancel 2 Invoices
    final invToCancel1 = invoiceIds[0];
    final invToCancel2 = invoiceIds[1];
    await db.cancelDocument(invToCancel1);
    await db.cancelDocument(invToCancel2);

    // Subtract cancelled sales from physical consumption tracking
    p1Sold -= 4.0;
    p2Sold -= 2.0;

    // 6. Record Stock Adjustments (+5 for p1, -3 for p2)
    await db.adjustStock(
      productId: p1Id,
      delta: 5.0,
      notes: 'جرد زيادة',
    );
    await db.adjustStock(
      productId: p2Id,
      delta: -3.0,
      notes: 'تالف مخزني',
    );

    // ─── IDENTITY 1: Stock Conservation Identity ───
    final p1ExpectedStock = p1InitialStock + p1Purchased - p1Sold + 5.0;
    final p2ExpectedStock = p2InitialStock + p2Purchased - p2Sold - 3.0;

    final p1Current = (await db.getProductById(p1Id))!;
    final p2Current = (await db.getProductById(p2Id))!;

    expect(p1Current.stockQuantity, p1ExpectedStock);
    expect(p2Current.stockQuantity, p2ExpectedStock);

    // ─── IDENTITY 2: Debits == Credits on Every Journal Entry & Trial Balance ───
    final book = await LedgerService.load(currencyCode: 'SDG');
    for (final entry in book.entries) {
      if (entry.isCostMissing) continue;
      final diff = (entry.totalDebit - entry.totalCredit).abs();
      expect(diff < 0.005, isTrue, reason: 'Entry ${entry.reference} is unbalanced: Dr=${entry.totalDebit}, Cr=${entry.totalCredit}');
    }

    final tb = AccountingReports.trialBalance(book.entries);
    expect(tb.isBalanced, isTrue);

    // ─── IDENTITY 3: Balance Sheet Identity (Assets == Liabilities + Equity) ───
    final bs = AccountingReports.balanceSheet(book.entries);
    expect(bs.isBalanced, isTrue);

    // ─── IDENTITY 4: Income Statement Identity (Gross Profit == Revenue - COGS) ───
    final inc = AccountingReports.incomeStatement(book.entries);
    expect(inc.grossProfit, closeTo(inc.salesRevenue - inc.costOfSales, 0.01));
    expect(inc.netProfit, closeTo(inc.grossProfit + inc.otherIncome - inc.inventoryAdjustments - inc.operatingExpenses, 0.01));

    // ─── IDENTITY 5: Customer Statement Running Balance Reconciles with Receivables ───
    final stmt = await CustomerStatementService.getStatementForContact(
      contactId: customerId,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      currencyCode: 'SDG',
    );

    final recGl = AccountingReports.generalLedger(book.entries, Accounts.receivables);
    expect(stmt.closingBalance, closeTo(recGl.closingBalance, 0.01));
  });
}

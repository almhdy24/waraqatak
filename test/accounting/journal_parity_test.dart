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
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/accounting/stock_ledger.dart';
import 'package:warqatek/utils/money_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_parity_test');
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
        name: 'مؤسسة الاختبار المحاسبي',
        ownerName: 'المدير المالي',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  Future<Map<String, ({int debitMinor, int creditMinor, int balanceMinor})>>
      loadJournalBalances() async {
    final rawDb = await db.database;
    final rows = await rawDb.rawQuery('''
      SELECT 
        l.account_code,
        COALESCE(SUM(l.debit_minor), 0) as debit_minor,
        COALESCE(SUM(l.credit_minor), 0) as credit_minor
      FROM journal_lines l
      JOIN journal_entries e ON l.entry_id = e.id
      GROUP BY l.account_code
    ''');

    final result =
        <String, ({int debitMinor, int creditMinor, int balanceMinor})>{};
    for (final r in rows) {
      final code = r['account_code'] as String;
      final dr = (r['debit_minor'] as num).toInt();
      final cr = (r['credit_minor'] as num).toInt();
      final acct = Accounts.byCode(code);
      final bal = acct.debitNormal ? (dr - cr) : (cr - dr);
      result[code] = (debitMinor: dr, creditMinor: cr, balanceMinor: bal);
    }
    return result;
  }

  Future<void> assertParityWithDerivedLedger({int decimalDigits = 2}) async {
    final book = await LedgerService.load(currencyCode: 'SDG');
    final derivedTB = AccountingReports.trialBalance(book.entries);
    final journalMap = await loadJournalBalances();

    // 1. Verify internal journal balance (Debits == Credits in minor units)
    var journalTotalDrMinor = 0;
    var journalTotalCrMinor = 0;
    for (final val in journalMap.values) {
      journalTotalDrMinor += val.debitMinor;
      journalTotalCrMinor += val.creditMinor;
    }

    final derivedTotalDrMinor =
        MoneyUtils.toMinorUnits(derivedTB.totalDebit, decimalDigits);
    final derivedTotalCrMinor =
        MoneyUtils.toMinorUnits(derivedTB.totalCredit, decimalDigits);

    expect(
      journalTotalDrMinor,
      equals(journalTotalCrMinor),
      reason: 'Persisted journal must be internally balanced in minor units',
    );
    expect(
      derivedTotalDrMinor,
      equals(derivedTotalCrMinor),
      reason: 'Derived ledger must be internally balanced',
    );

    // 2. Verify account by account equality with 0 tolerance on critical accounts (D8)
    final derivedBalanceByCode = <String, double>{};
    for (final row in derivedTB.rows) {
      derivedBalanceByCode[row.account.code] = row.balance;
    }

    var journalNetDebits = 0;
    var derivedNetDebits = 0;

    for (final acct in Accounts.all) {
      final dBal = derivedBalanceByCode[acct.code] ?? 0.0;
      final derivedBalMinor = MoneyUtils.toMinorUnits(dBal, decimalDigits);
      final journalBalMinor = journalMap[acct.code]?.balanceMinor ?? 0;

      expect(
        journalBalMinor,
        equals(derivedBalMinor),
        reason:
            'Parity failed on account ${acct.code}: journal=$journalBalMinor, derived=$derivedBalMinor',
      );

      if (acct.debitNormal && journalBalMinor > 0) {
        journalNetDebits += journalBalMinor;
      }
      if (acct.debitNormal && derivedBalMinor > 0) {
        derivedNetDebits += derivedBalMinor;
      }
    }

    expect(
      journalNetDebits,
      equals(derivedNetDebits),
      reason: 'Net trial balance debit total must match derived ledger exactly',
    );

    // 3. Verify Income Statement Parity
    final derivedIS = AccountingReports.incomeStatement(book.entries);
    final rawDb = await db.database;
    final isRows = await rawDb.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN l.account_code = '4100' THEN l.credit_minor - l.debit_minor ELSE 0 END), 0) as revenue,
        COALESCE(SUM(CASE WHEN l.account_code = '5100' THEN l.debit_minor - l.credit_minor ELSE 0 END), 0) as cogs,
        COALESCE(SUM(CASE WHEN l.account_code = '4900' THEN l.credit_minor - l.debit_minor ELSE 0 END), 0) as other_income,
        COALESCE(SUM(CASE WHEN l.account_code = '5200' THEN l.debit_minor - l.credit_minor ELSE 0 END), 0) as stock_adjustments,
        COALESCE(SUM(CASE WHEN l.account_code = '6100' THEN l.debit_minor - l.credit_minor ELSE 0 END), 0) as operating_expenses
      FROM journal_lines l
      JOIN journal_entries e ON l.entry_id = e.id
    ''');

    final r = isRows.first;
    final jRevenue = (r['revenue'] as num).toInt();
    final jCogs = (r['cogs'] as num).toInt();
    final jOtherIncome = (r['other_income'] as num).toInt();
    final jStockAdj = (r['stock_adjustments'] as num).toInt();
    final jExpenses = (r['operating_expenses'] as num).toInt();
    final jNetIncome = jRevenue - jCogs + jOtherIncome - jStockAdj - jExpenses;

    final dRevenue = MoneyUtils.toMinorUnits(derivedIS.salesRevenue, decimalDigits);
    final dCogs = MoneyUtils.toMinorUnits(derivedIS.costOfSales, decimalDigits);
    final dOtherIncome = MoneyUtils.toMinorUnits(derivedIS.otherIncome, decimalDigits);
    final dStockAdj = MoneyUtils.toMinorUnits(derivedIS.inventoryAdjustments, decimalDigits);
    final dExpenses = MoneyUtils.toMinorUnits(derivedIS.operatingExpenses, decimalDigits);
    final dNetIncome = MoneyUtils.toMinorUnits(derivedIS.netProfit, decimalDigits);

    expect(jRevenue, equals(dRevenue), reason: 'Revenue parity');
    expect(jCogs, equals(dCogs), reason: 'COGS parity');
    expect(jOtherIncome, equals(dOtherIncome), reason: 'Other income parity');
    expect(jStockAdj, equals(dStockAdj), reason: 'Stock adjustments parity');
    expect(jExpenses, equals(dExpenses), reason: 'Expenses parity');
    expect(jNetIncome, equals(dNetIncome), reason: 'Net income parity');
  }

  test('1. Simple Sales Invoice (issued, unpaid) -> exact trial balance parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'كتاب المحاسبة',
        salePrice: 100.0,
        purchasePrice: 60.0,
        averageCost: 60.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 50.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1001',
      date: DateTime(2026, 3, 1),
      subtotal: 200.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 30.0,
      total: 230.0,
      paid: 0.0,
      remaining: 230.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: '2 x كتاب المحاسبة',
        quantity: 2.0,
        price: 100.0,
        total: 200.0,
      ),
    ];

    await db.insertDocumentWithItems(invoice, items);
    await assertParityWithDerivedLedger();
  });

  test('2. Sales Invoice with Upfront Settlement -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'قلم جاف',
        salePrice: 50.0,
        purchasePrice: 20.0,
        averageCost: 20.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 100.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1002',
      date: DateTime(2026, 3, 2),
      subtotal: 100.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 100.0,
      paid: 60.0,
      remaining: 40.0,
      paymentMethod: 'cash',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: '2 x قلم جاف',
        quantity: 2.0,
        price: 50.0,
        total: 100.0,
      ),
    ];

    await db.insertDocumentWithItems(invoice, items);
    await assertParityWithDerivedLedger();
  });

  test('3. Quick POS Sale (payNowMethod) -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'دفتر ملاحظات',
        salePrice: 80.0,
        purchasePrice: 45.0,
        averageCost: 45.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 40.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1003',
      date: DateTime(2026, 3, 3),
      subtotal: 80.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 80.0,
      paid: 0.0,
      remaining: 80.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'دفتر',
        quantity: 1.0,
        price: 80.0,
        total: 80.0,
      ),
    ];

    await db.insertDocumentWithItems(invoice, items, payNowMethod: 'bank');
    await assertParityWithDerivedLedger();
  });

  test('4. Purchase with Stocked and Non-Stocked Items and VAT -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'طابعة ليزر',
        salePrice: 1500.0,
        purchasePrice: 1000.0,
        averageCost: 1000.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    final purchase = Document(
      type: 'purchase',
      documentNumber: 'PUR-2001',
      date: DateTime(2026, 3, 4),
      subtotal: 1200.0, // 1000 stocked + 200 service/expense
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 180.0,
      total: 1380.0,
      paid: 0.0,
      remaining: 1380.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'طابعة ليزر',
        quantity: 1.0,
        price: 1000.0,
        total: 1000.0,
      ),
      const DocumentItem(
        documentId: 0,
        productId: null, // Service / non-stocked operating expense
        description: 'رسوم توصيل وصيانة',
        quantity: 1.0,
        price: 200.0,
        total: 200.0,
      ),
    ];

    await db.insertDocumentWithItems(purchase, items);
    await assertParityWithDerivedLedger();
  });

  test('5. Subsequent Payment with Receipt on Invoice -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'شاشة حاسوب',
        salePrice: 500.0,
        purchasePrice: 350.0,
        averageCost: 350.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1005',
      date: DateTime(2026, 3, 5),
      subtotal: 500.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 500.0,
      paid: 0.0,
      remaining: 500.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'شاشة',
        quantity: 1.0,
        price: 500.0,
        total: 500.0,
      ),
    ];

    final docId = await db.insertDocumentWithItems(invoice, items);

    // Record partial payment with linked receipt
    await db.recordPaymentWithReceipt(
      documentId: docId,
      amount: 300.0,
      paymentMethod: 'cash',
      notes: 'الدفعة الأولى',
    );

    await assertParityWithDerivedLedger();
  });

  test('6. Standalone Payment Receipt and Standalone Expense Voucher -> exact parity', () async {
    // Standalone Receipt (Other income)
    final receipt = Document(
      type: 'payment_receipt',
      documentNumber: 'REC-3001',
      date: DateTime(2026, 3, 6),
      subtotal: 150.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 150.0,
      paid: 150.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(receipt, const []);

    // Standalone Voucher (Operating expense)
    final voucher = Document(
      type: 'expense_voucher',
      documentNumber: 'VCH-4001',
      date: DateTime(2026, 3, 6),
      subtotal: 90.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 90.0,
      paid: 90.0,
      remaining: 0.0,
      paymentMethod: 'bank',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(voucher, const []);

    await assertParityWithDerivedLedger();
  });

  test('7. Document Cancellation (Invoice & Receipt) -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'كرسي مكتبي',
        salePrice: 300.0,
        purchasePrice: 180.0,
        averageCost: 180.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 15.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1007',
      date: DateTime(2026, 3, 7),
      subtotal: 300.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 300.0,
      paid: 0.0,
      remaining: 300.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'كرسي',
        quantity: 1.0,
        price: 300.0,
        total: 300.0,
      ),
    ];

    final docId = await db.insertDocumentWithItems(invoice, items);
    final receiptId = await db.recordPaymentWithReceipt(
      documentId: docId,
      amount: 100.0,
      paymentMethod: 'cash',
    );

    // Cancel receipt first, then invoice
    await db.cancelDocument(receiptId);
    await db.cancelDocument(docId);

    await assertParityWithDerivedLedger();
  });

  test('8. Document Revision (Edit quantity, price, tax) -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'لوحة مفاتيح',
        salePrice: 100.0,
        purchasePrice: 50.0,
        averageCost: 50.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1008',
      date: DateTime(2026, 3, 8),
      subtotal: 100.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 100.0,
      paid: 0.0,
      remaining: 100.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'لوحة مفاتيح',
        quantity: 1.0,
        price: 100.0,
        total: 100.0,
      ),
    ];

    final docId = await db.insertDocumentWithItems(invoice, items);

    // Revise invoice: quantity 2, total 200
    final revisedInvoice = invoice.copyWith(
      id: docId,
      subtotal: 200.0,
      total: 200.0,
      remaining: 200.0,
    );
    final revisedItems = [
      DocumentItem(
        documentId: docId,
        productId: pId,
        description: 'لوحة مفاتيح',
        quantity: 2.0,
        price: 100.0,
        total: 200.0,
      ),
    ];

    await db.updateDocumentWithItems(revisedInvoice, revisedItems);
    await assertParityWithDerivedLedger();
  });

  test('9. Metadata-only Document Edit -> zero new entries or reversals', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'ماوس لاسلكي',
        salePrice: 40.0,
        purchasePrice: 20.0,
        averageCost: 20.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    final invoice = Document(
      type: 'invoice',
      documentNumber: 'INV-1009',
      date: DateTime(2026, 3, 9),
      subtotal: 40.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 40.0,
      paid: 0.0,
      remaining: 40.0,
      recipientName: 'عميل أولي',
      recipientPhone: '111111',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );

    final items = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'ماوس لاسلكي',
        quantity: 1.0,
        price: 40.0,
        total: 40.0,
      ),
    ];

    final docId = await db.insertDocumentWithItems(invoice, items);

    final rawDb = await db.database;
    final countBeforeRows = await rawDb.rawQuery(
      'SELECT COUNT(*) as count FROM journal_entries WHERE source_id = ?',
      [docId],
    );
    final countBefore = (countBeforeRows.first['count'] as num).toInt();

    // Metadata-only edit: recipient phone and notes only
    final metadataDoc = invoice.copyWith(
      id: docId,
      recipientPhone: '999999',
      notes: 'تم تحديث الملاحظات فقط',
    );

    await db.updateDocumentWithItems(metadataDoc, items);

    final countAfterRows = await rawDb.rawQuery(
      'SELECT COUNT(*) as count FROM journal_entries WHERE source_id = ?',
      [docId],
    );
    final countAfter = (countAfterRows.first['count'] as num).toInt();

    expect(countAfter, equals(countBefore), reason: 'Metadata-only edits post nothing');
    await assertParityWithDerivedLedger();
  });

  test('10. Standalone Stock Adjustments (Gain, Loss) -> exact parity', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'كابل شبكة',
        salePrice: 10.0,
        purchasePrice: 5.0,
        averageCost: 5.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    final rawDb = await db.database;

    // Stock Gain (+5)
    await rawDb.transaction((txn) async {
      await StockLedger.record(
        txn,
        productId: pId,
        deltaQuantity: 5.0,
        type: StockMovement.typeAdjustment,
        unitCost: 5.0,
        reason: 'count_gain',
      );
    });

    // Stock Loss (-3)
    await rawDb.transaction((txn) async {
      await StockLedger.record(
        txn,
        productId: pId,
        deltaQuantity: -3.0,
        type: StockMovement.typeAdjustment,
        unitCost: 5.0,
        reason: 'damage_loss',
      );
    });

    await assertParityWithDerivedLedger();
  });

  test('11. Comprehensive Multi-Transaction Lifecycle -> complete parity', () async {
    // Setup multiple products
    final p1 = await db.insertProduct(
      Product(
        name: 'منتج أ',
        salePrice: 200.0,
        purchasePrice: 120.0,
        averageCost: 120.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 50.0,
      ),
    );
    final p2 = await db.insertProduct(
      Product(
        name: 'منتج ب',
        salePrice: 150.0,
        purchasePrice: 80.0,
        averageCost: 80.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 30.0,
      ),
    );

    // 1. Purchase additional stock
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-COMP-1',
      date: DateTime(2026, 3, 10),
      subtotal: 1000.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 150.0,
      total: 1150.0,
      paid: 500.0,
      remaining: 650.0,
      paymentMethod: 'bank',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );
    final purItems = [
      DocumentItem(
        documentId: 0,
        productId: p1,
        description: 'منتج أ',
        quantity: 5.0,
        price: 120.0,
        total: 600.0,
      ),
      DocumentItem(
        documentId: 0,
        productId: p2,
        description: 'منتج ب',
        quantity: 5.0,
        price: 80.0,
        total: 400.0,
      ),
    ];
    await db.insertDocumentWithItems(pur, purItems);

    // 2. Sales Invoice 1 (Partially paid)
    final inv1 = Document(
      type: 'invoice',
      documentNumber: 'INV-COMP-1',
      date: DateTime(2026, 3, 11),
      subtotal: 700.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 105.0,
      total: 805.0,
      paid: 400.0,
      remaining: 405.0,
      paymentMethod: 'cash',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );
    final inv1Items = [
      DocumentItem(
        documentId: 0,
        productId: p1,
        description: 'منتج أ',
        quantity: 2.0,
        price: 200.0,
        total: 400.0,
        unitCost: 120.0,
        totalCost: 240.0,
      ),
      DocumentItem(
        documentId: 0,
        productId: p2,
        description: 'منتج ب',
        quantity: 2.0,
        price: 150.0,
        total: 300.0,
        unitCost: 80.0,
        totalCost: 160.0,
      ),
    ];
    final inv1Id = await db.insertDocumentWithItems(inv1, inv1Items);

    // 3. Sales Invoice 2 (Quick POS sale)
    final inv2 = Document(
      type: 'invoice',
      documentNumber: 'INV-COMP-2',
      date: DateTime(2026, 3, 12),
      subtotal: 200.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 200.0,
      paid: 0.0,
      remaining: 200.0,
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    final inv2Items = [
      DocumentItem(
        documentId: 0,
        productId: p1,
        description: 'منتج أ',
        quantity: 1.0,
        price: 200.0,
        total: 200.0,
        unitCost: 120.0,
        totalCost: 120.0,
      ),
    ];
    await db.insertDocumentWithItems(inv2, inv2Items, payNowMethod: 'bank');

    // 4. Record subsequent payment on inv1
    await db.recordPaymentWithReceipt(
      documentId: inv1Id,
      amount: 405.0,
      paymentMethod: 'cash',
    );

    // 5. Stock adjustment
    final rawDb = await db.database;
    await rawDb.transaction((txn) async {
      await StockLedger.record(
        txn,
        productId: p1,
        deltaQuantity: -1.0,
        type: StockMovement.typeAdjustment,
        unitCost: 120.0,
        reason: 'damage_loss',
      );
    });

    // 6. Standalone receipt and voucher
    final standaloneReceipt = Document(
      type: 'payment_receipt',
      documentNumber: 'REC-COMP-1',
      date: DateTime(2026, 3, 13),
      subtotal: 50.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 50.0,
      paid: 50.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(standaloneReceipt, const []);

    final standaloneVoucher = Document(
      type: 'expense_voucher',
      documentNumber: 'VCH-COMP-1',
      date: DateTime(2026, 3, 13),
      subtotal: 30.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 30.0,
      paid: 30.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.issued,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(standaloneVoucher, const []);

    // Full parity assertion across all accounts and reports
    await assertParityWithDerivedLedger();
  });
}

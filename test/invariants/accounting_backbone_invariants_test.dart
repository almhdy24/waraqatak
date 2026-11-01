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
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/accounting/journal_draft.dart';
import 'package:warqatek/services/accounting/journal_writer.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/stock_ledger.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('backbone_invariants_test');
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
        name: 'Invariants Audit Business',
        ownerName: 'Chief Auditor',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
      ),
    );
  });

  // =========================================================================
  // INV-14: Double-Entry Balance Invariance (Zero-Sum Invariant)
  // =========================================================================
  test('INV-14: Double-Entry Balance Invariance: writes enforce exact minor unit balance', () async {
    final rawDb = await db.database;

    // (a) Attempting to write an unbalanced entry draft MUST throw StateError prior to write
    final unbalancedDraft = JournalEntryDraft(
      entryNo: 'JE-INV14-UNBALANCED',
      effectiveDate: DateTime(2026, 3, 1),
      postedAt: DateTime.now(),
      sourceType: 'manual',
      sourceId: 1,
      lines: [
        JournalLineDraft(accountCode: Accounts.cash.code, debitMinor: 10000),
        JournalLineDraft(accountCode: Accounts.salesRevenue.code, creditMinor: 9999), // 1 minor unit off!
      ],
    );

    expect(
      JournalWriter.write(rawDb, unbalancedDraft),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('Unbalanced journal entry'),
      )),
    );

    // (b) Balanced draft writes cleanly and balances in database
    final balancedDraft = JournalEntryDraft(
      entryNo: 'JE-INV14-BALANCED',
      effectiveDate: DateTime(2026, 3, 1),
      postedAt: DateTime.now(),
      sourceType: 'manual',
      sourceId: 1,
      lines: [
        JournalLineDraft(accountCode: Accounts.cash.code, debitMinor: 10000),
        JournalLineDraft(accountCode: Accounts.salesRevenue.code, creditMinor: 10000),
      ],
    );

    await rawDb.transaction((txn) async {
      final entryId = await JournalWriter.write(txn, balancedDraft);
      expect(entryId, greaterThan(0));
    });

    final check = await rawDb.rawQuery('''
      SELECT SUM(debit_minor) as dr, SUM(credit_minor) as cr
      FROM journal_lines
    ''');
    expect(check.first['dr'], equals(check.first['cr']));
  });

  // =========================================================================
  // INV-15: Journal Immutability & Append-Only Corrections
  // =========================================================================
  test('INV-15: Journal Immutability: revisions and cancellations are strictly append-only', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'منتج غير قابل للتعديل المباشر',
        barcode: 'IMM-1',
        salePrice: 100.0,
        purchasePrice: 60.0,
        averageCost: 60.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    // 1. Issue invoice
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-IMM-1',
      date: DateTime(2026, 3, 1),
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
    final invId = await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'بند 1',
        quantity: 1.0,
        price: 100.0,
        total: 100.0,
      ),
    ]);

    final rawDb = await db.database;
    final originalEntries = await rawDb.query(
      'journal_entries',
      where: 'source_id = ? AND source_type IN (?, ?)',
      whereArgs: [invId, 'invoice', 'cogs'],
    );
    expect(originalEntries, hasLength(2)); // INV-JE and COGS-JE
    final origEntryId = originalEntries.first['id'] as int;

    // 2. Revise invoice (modify price to 150)
    await db.updateDocumentWithItems(
      inv.copyWith(id: invId, subtotal: 150.0, total: 150.0, remaining: 150.0),
      [
        DocumentItem(
          documentId: invId,
          productId: pId,
          description: 'بند 1 معدل',
          quantity: 1.0,
          price: 150.0,
          total: 150.0,
        ),
      ],
    );

    // Assert: original entry row is UNTOUCHED (not updated, not deleted)
    final origCheck = await rawDb.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [origEntryId],
    );
    expect(origCheck, hasLength(1));
    expect(origCheck.first['reverses_entry_id'], isNull);

    // Assert: an explicit reversal entry exists referencing the original entry
    final reversals = await rawDb.query(
      'journal_entries',
      where: 'reverses_entry_id = ?',
      whereArgs: [origEntryId],
    );
    expect(reversals, hasLength(1));

    // 3. Cancel the revised invoice
    await db.cancelDocument(invId);

    // Assert: all prior rows remain intact in the database for audit trail
    final allEntries = await rawDb.query(
      'journal_entries',
      where: 'source_id = ? AND source_type IN (?, ?)',
      whereArgs: [invId, 'invoice', 'cogs'],
    );
    expect(allEntries.length, greaterThanOrEqualTo(4)); // orig + rev-reversal + rev-post + cancel-reversal
  });

  // =========================================================================
  // INV-16: Single Stock Writer Authoritativeness
  // =========================================================================
  test('INV-16: Single Stock Writer: StockLedger.record is the authoritative gate for stock_movements', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'منتج بوابة المخزون',
        barcode: 'GATE-1',
        salePrice: 50.0,
        purchasePrice: 20.0,
        stockQuantity: 0.0,
      ),
    );

    final rawDb = await db.database;
    await rawDb.transaction((txn) async {
      final movId = await StockLedger.record(
        txn,
        productId: pId,
        deltaQuantity: 5.0,
        type: StockMovement.typePurchase,
        date: DateTime(2026, 3, 1),
        unitCost: 20.0,
        provenance: 'unit_test',
        reason: 'count_gain',
      );
      expect(movId, greaterThan(0));
    });

    final productRows = await rawDb.query('products', where: 'id = ?', whereArgs: [pId]);
    expect((productRows.first['stock_quantity'] as num).toDouble(), equals(5.0));

    final movRows = await rawDb.query('stock_movements', where: 'product_id = ?', whereArgs: [pId]);
    expect(movRows, hasLength(1));
    expect(movRows.first['reason'], equals('count_gain'));
  });

  // =========================================================================
  // INV-17: Accounting Period Lock Gate
  // =========================================================================
  test('INV-17: Accounting Period Lock: mutations on or before books_closed_through are strictly rejected', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'منتج قفل الدفاتر',
        barcode: 'LOCK-INV-1',
        salePrice: 100.0,
        purchasePrice: 50.0,
        stockQuantity: 20.0,
      ),
    );

    await db.setBooksClosedThrough(DateTime(2026, 3, 31));

    // Attempting to insert document dated 2026-03-31 (on cutoff) MUST fail
    final docOnCutoff = Document(
      type: 'invoice',
      documentNumber: 'INV-CUTOFF',
      date: DateTime(2026, 3, 31),
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

    expect(
      () => db.insertDocumentWithItems(docOnCutoff, [
        DocumentItem(
          documentId: 0,
          productId: pId,
          description: 'بند',
          quantity: 1.0,
          price: 100.0,
          total: 100.0,
        ),
      ]),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('Accounting period is closed through 2026-03-31'),
      )),
    );

    // Document dated after cutoff (2026-04-01) succeeds
    final docAfterCutoff = docOnCutoff.copyWith(
      documentNumber: 'INV-POST-CUTOFF',
      date: DateTime(2026, 4, 1),
    );
    final docId = await db.insertDocumentWithItems(docAfterCutoff, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'بند',
        quantity: 1.0,
        price: 100.0,
        total: 100.0,
      ),
    ]);
    expect(docId, greaterThan(0));
  });

  // =========================================================================
  // INV-18: Continuous Parity Invariance (Oracle Equivalence)
  // =========================================================================
  test('INV-18: Continuous Parity Invariance: persisted journal matches derived ledger with zero tolerance', () async {
    final pId = await db.insertProduct(
      Product(
        name: 'منتج المطابقة الكاملة',
        barcode: 'PAR-INV-1',
        salePrice: 200.0,
        purchasePrice: 100.0,
        averageCost: 100.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 50.0,
      ),
    );

    // 1. Purchase
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-INV18-1',
      date: DateTime(2026, 3, 1),
      subtotal: 500.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 75.0,
      total: 575.0,
      paid: 575.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(pur, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'منتج المطابقة',
        quantity: 5.0,
        price: 100.0,
        total: 500.0,
      ),
    ]);

    // 2. Sale
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-INV18-1',
      date: DateTime(2026, 3, 2),
      subtotal: 600.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 90.0,
      total: 690.0,
      paid: 300.0,
      remaining: 390.0,
      paymentMethod: 'cash',
      status: DocumentStatus.partiallyPaid,
      currencyCode: 'SDG',
    );
    final invId = await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'منتج المطابقة',
        quantity: 3.0,
        price: 200.0,
        total: 600.0,
      ),
    ]);

    // 3. Payment
    await db.recordPaymentWithReceipt(
      documentId: invId,
      amount: 150.0,
      paymentMethod: 'bank_transfer',
      notes: 'تحصيل إضافي',
    );

    // 4. Stock adjustment
    await db.adjustStock(
      productId: pId,
      delta: -1.0,
      reason: 'damage_loss',
      notes: 'تلف وحدة واحدة',
      date: DateTime(2026, 3, 3),
    );

    // 5. Parity Oracle Assertion
    await JournalBackfillService.verifyParity();
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/database_diagnostic.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/journal_backfill_service.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/backup_service.dart';
import 'package:warqatek/services/database_diagnostic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('journal_backfill_test');
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
        name: 'شركة الاستيراد والتصدير',
        ownerName: 'المدير العام',
        phone: '0912345678',
        address: 'الخرطوم',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  test('1. Clean database: backfillIfNeeded marks completed with 0 entries', () async {
    final rawDb = await db.database;
    // Clear any settings
    await rawDb.delete('app_settings');

    final count = await JournalBackfillService.backfillIfNeeded();
    expect(count, equals(0));

    final isDone = await JournalBackfillService.isBackfillCompleted();
    expect(isDone, isTrue);

    final entries = await rawDb.query('journal_entries');
    expect(entries.isEmpty, isTrue);
  });

  test('2. Historical legacy data: backfills journal with origin=legacy_backfill and exact parity', () async {
    // 1. Temporarily disable shadow writing and backfilled flag to simulate legacy data
    await db.setSetting('journal_shadow_write', 'false');
    final rawDb = await db.database;
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');
    await rawDb.delete('app_settings', where: 'key = ?', whereArgs: [JournalBackfillService.settingKeyBackfilledAt]);

    // 2. Insert historical product with stock and purchases
    final pId = await db.insertProduct(
      Product(
        name: 'سلعة تاريخية',
        salePrice: 150.0,
        purchasePrice: 100.0,
        averageCost: 100.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 40.0,
      ),
    );

    // 3. Insert historical purchase
    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-HIST-1',
      date: DateTime(2025, 1, 10),
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
        productId: pId,
        description: 'شراء تاريخي',
        quantity: 10.0,
        price: 100.0,
        total: 1000.0,
      ),
    ];
    await db.insertDocumentWithItems(pur, purItems);

    // 4. Insert historical invoice
    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-HIST-1',
      date: DateTime(2025, 1, 15),
      subtotal: 300.0,
      discount: 0.0,
      taxRate: 0.15,
      taxAmount: 45.0,
      total: 345.0,
      paid: 345.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    final invItems = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'بيع تاريخي',
        quantity: 2.0,
        price: 150.0,
        total: 300.0,
      ),
    ];
    await db.insertDocumentWithItems(inv, invItems);

    // Clear any journal rows that might have been written
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');

    final journalCountBefore = (await rawDb.query('journal_entries')).length;
    expect(journalCountBefore, equals(0), reason: 'Simulated pre-migration legacy database');

    // 5. Execute Backfill
    final backfilledCount = await JournalBackfillService.backfillIfNeeded();
    expect(backfilledCount, greaterThan(0));

    // 6. Verify origin flag
    final backfilledEntries = await rawDb.query('journal_entries');
    for (final e in backfilledEntries) {
      expect(e['origin'], equals('legacy_backfill'));
    }

    // 7. Verify parity
    await JournalBackfillService.verifyParity();
    expect(await JournalBackfillService.isBackfillCompleted(), isTrue);
  });

  test('3. Idempotent re-run: subsequent call does not duplicate entries', () async {
    final rawDb = await db.database;
    final count1 = (await rawDb.query('journal_entries')).length;

    final secondRun = await JournalBackfillService.backfillIfNeeded();
    expect(secondRun, equals(0));

    final count2 = (await rawDb.query('journal_entries')).length;
    expect(count2, equals(count1));
  });

  test('4. Legacy Backup Restore triggers automatic backfill with parity', () async {
    // 1. Create a product and document
    final pId = await db.insertProduct(
      Product(
        name: 'منتج النسخة الاحتياطية',
        salePrice: 200.0,
        purchasePrice: 120.0,
        averageCost: 120.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 20.0,
      ),
    );

    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-BK-1',
      date: DateTime(2026, 2, 1),
      subtotal: 200.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 200.0,
      paid: 200.0,
      remaining: 0.0,
      paymentMethod: 'cash',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'عنصر',
        quantity: 1.0,
        price: 200.0,
        total: 200.0,
      ),
    ]);

    // 2. Export database JSON for test
    final backupJson = await BackupService.buildBackupJsonForTest();

    // 3. Strip journal tables to create a simulated legacy backup
    final legacyMap = jsonDecode(backupJson) as Map<String, dynamic>;
    final dataMap = legacyMap['data'] as Map<String, dynamic>;
    dataMap.remove('journal_entries');
    dataMap.remove('journal_lines');
    dataMap.remove('app_settings');

    // 4. Restore the legacy backup
    final ok = await BackupService.restoreFromJsonMap(legacyMap);
    expect(ok, isTrue);

    // 5. Verify backfill was automatically executed
    final rawDb = await db.database;
    final backfillSetting = await rawDb.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [JournalBackfillService.settingKeyBackfilledAt],
    );
    expect(backfillSetting.isNotEmpty, isTrue, reason: 'Backfill executed after legacy restore');

    final backfilledRows = await rawDb.query(
      'journal_entries',
      where: "origin = 'legacy_backfill'",
    );
    expect(backfilledRows, isNotEmpty);

    // 6. Verify parity passes
    await JournalBackfillService.verifyParity();
  });

  test('5. Interrupted batch and exception cleanup: cleans up incomplete entries and resets cursor on failure', () async {
    final rawDb = await db.database;
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');
    await rawDb.delete('document_items');
    await rawDb.delete('documents');
    await rawDb.delete('app_settings');

    final pId = await db.insertProduct(
      Product(
        name: 'منتج دفعات',
        salePrice: 100.0,
        purchasePrice: 60.0,
        averageCost: 60.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 100.0,
      ),
    );

    // Insert 6 invoices
    for (int i = 1; i <= 6; i++) {
      final inv = Document(
        type: 'invoice',
        documentNumber: 'INV-RESUME-$i',
        date: DateTime(2025, 3, i),
        subtotal: 100.0,
        discount: 0.0,
        taxRate: 0.15,
        taxAmount: 15.0,
        total: 115.0,
        paid: 115.0,
        remaining: 0.0,
        paymentMethod: 'cash',
        status: DocumentStatus.paid,
        currencyCode: 'SDG',
      );
      await db.insertDocumentWithItems(inv, [
        DocumentItem(
          documentId: 0,
          productId: pId,
          description: 'بند',
          quantity: 1.0,
          price: 100.0,
          total: 100.0,
        ),
      ]);
    }

    // Clear journal entries to simulate unbackfilled DB
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');

    // Run backfill with batchSize: 2, simulating failure after first batch
    var batchCount = 0;
    try {
      await JournalBackfillService.runBackfill(
        rawDb,
        batchSize: 2,
        onProgress: (processed, total) {
          batchCount++;
          if (batchCount == 1) {
            // Simulate error or parity failure after batch 1
            throw Exception('Simulated failure during backfill');
          }
        },
      );
      fail('Should have thrown simulated failure');
    } catch (e) {
      expect(e.toString(), contains('Simulated failure'));
    }

    // On exception, catch block must clean up incomplete entries and reset cursor
    final cursorAfterCrash = await JournalBackfillService.getBackfillCursor();
    expect(cursorAfterCrash, equals(0), reason: 'Cursor must be reset on exception to prevent corrupted state');

    final entriesAfterCrash = await rawDb.query('journal_entries');
    expect(entriesAfterCrash, isEmpty, reason: 'Incomplete entries must be cleaned up on exception');

    // Not marked completed
    expect(await JournalBackfillService.isBackfillCompleted(), isFalse);

    // Resumability from checkpoint: simulate an interrupted process where cursor was checkpointed at 2
    // Run fresh backfill to completion
    final backfilledCount = await JournalBackfillService.runBackfill(
      rawDb,
      batchSize: 2,
    );
    expect(backfilledCount, greaterThan(0));

    // Cursor should now be cleared
    final cursorAfterDone = await JournalBackfillService.getBackfillCursor();
    expect(cursorAfterDone, equals(0), reason: 'Cursor must be cleared on completion');
    expect(await JournalBackfillService.isBackfillCompleted(), isTrue);

    // Assert zero duplicate entries
    final dupes = await rawDb.rawQuery('''
      SELECT entry_no, COUNT(*) as c
      FROM journal_entries
      GROUP BY entry_no
      HAVING c > 1
    ''');
    expect(dupes, isEmpty, reason: 'Backfill must produce zero duplicate entries');

    // Rigorous parity check
    await JournalBackfillService.verifyParity();
  });

  test('6. Concurrent backfills deduplication: shared Future prevents duplicate runs', () async {
    final rawDb = await db.database;
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');
    await rawDb.delete('document_items');
    await rawDb.delete('documents');
    await rawDb.delete('app_settings');

    final pId = await db.insertProduct(
      Product(
        name: 'منتج التزامن',
        salePrice: 50.0,
        purchasePrice: 30.0,
        averageCost: 30.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 10.0,
      ),
    );

    final inv = Document(
      type: 'invoice',
      documentNumber: 'INV-CONCUR-1',
      date: DateTime(2025, 4, 1),
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
    await db.insertDocumentWithItems(inv, [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'بند',
        quantity: 1.0,
        price: 50.0,
        total: 50.0,
      ),
    ]);

    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');

    // Launch two backfills simultaneously
    final results = await Future.wait([
      JournalBackfillService.backfillIfNeeded(batchSize: 2),
      JournalBackfillService.backfillIfNeeded(batchSize: 2),
    ]);

    expect(results[0], equals(results[1]));
    expect(await JournalBackfillService.isBackfillCompleted(), isTrue);

    // Zero duplicates
    final dupes = await rawDb.rawQuery('''
      SELECT entry_no, COUNT(*) as c
      FROM journal_entries
      GROUP BY entry_no
      HAVING c > 1
    ''');
    expect(dupes, isEmpty);
  });

  test('7. Journal rebuild routine fixes account doubling bug and restores 100% parity (35,000,000 minor units)', () async {
    final rawDb = await db.database;
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');
    await rawDb.delete('document_items');
    await rawDb.delete('documents');
    await rawDb.delete('stock_movements');
    await rawDb.delete('products');
    await rawDb.delete('app_settings');

    // 1. Create product and 350,000 SDG purchase (35,000,000 minor units)
    final pId = await db.insertProduct(
      const Product(
        name: 'بضاعة المخزن الكبرى',
        salePrice: 500000.0,
        purchasePrice: 350000.0,
        averageCost: 350000.0,
        costStatus: Product.costStatusKnown,
        stockQuantity: 0.0,
      ),
    );

    final pur = Document(
      type: 'purchase',
      documentNumber: 'PUR-35M-1',
      date: DateTime(2026, 1, 1),
      subtotal: 350000.0,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: 350000.0,
      paid: 350000.0,
      remaining: 0.0,
      paymentMethod: 'bank',
      status: DocumentStatus.paid,
      currencyCode: 'SDG',
    );
    final purItems = [
      DocumentItem(
        documentId: 0,
        productId: pId,
        description: 'شراء بضاعة بقيمة 350 ألف',
        quantity: 1.0,
        price: 350000.0,
        total: 350000.0,
      ),
    ];
    final docId = await db.insertDocumentWithItems(pur, purItems);

    // Clear auto-posted shadow entries to set up the exact 2x doubling state (70,000,000 vs 35,000,000)
    await rawDb.delete('journal_lines');
    await rawDb.delete('journal_entries');

    // 2. Simulate the bug: live entries existed in journal_entries and journal_lines
    final liveEntryId = await rawDb.insert('journal_entries', {
      'entry_no': 'JE-LIVE-1',
      'effective_date': '2026-01-01',
      'posted_at': DateTime.now().toIso8601String(),
      'source_type': 'purchase',
      'source_id': docId,
      'origin': 'live',
      'revision': 1,
    });
    // Inventory 1140 Dr 35,000,000 minor, Bank 1120 Cr 35,000,000 minor
    await rawDb.insert('journal_lines', {
      'entry_id': liveEntryId,
      'account_code': Accounts.inventory.code,
      'debit_minor': 35000000,
      'credit_minor': 0,
    });
    await rawDb.insert('journal_lines', {
      'entry_id': liveEntryId,
      'account_code': Accounts.bank.code,
      'debit_minor': 0,
      'credit_minor': 35000000,
    });

    // Also simulate duplicate legacy backfill entries co-existing (doubling account balances)
    final dupEntryId = await rawDb.insert('journal_entries', {
      'entry_no': 'JE-BACKFILL-1',
      'effective_date': '2026-01-01',
      'posted_at': DateTime.now().toIso8601String(),
      'source_type': 'purchase',
      'source_id': docId,
      'origin': 'legacy_backfill',
      'revision': 1,
    });
    await rawDb.insert('journal_lines', {
      'entry_id': dupEntryId,
      'account_code': Accounts.inventory.code,
      'debit_minor': 35000000,
      'credit_minor': 0,
    });
    await rawDb.insert('journal_lines', {
      'entry_id': dupEntryId,
      'account_code': Accounts.bank.code,
      'debit_minor': 0,
      'credit_minor': 35000000,
    });

    // Verify corrupted state before rebuild:
    // Journal has 70,000,000 minor (doubled) while derived is 35,000,000 minor
    try {
      await JournalBackfillService.verifyParity(executor: rawDb);
      fail('Expected parity mismatch due to doubled entries');
    } catch (e) {
      expect(e.toString(), contains('Parity mismatch on account 1120'));
      expect(e.toString(), contains('derived=-35000000'));
      expect(e.toString(), contains('journal=-70000000'));
    }

    // 3. Execute Immediate Data Repair / Rebuild routine
    final backfilledCount = await JournalBackfillService.rebuildJournal(dbOverride: rawDb);
    expect(backfilledCount, greaterThan(0));

    // 4. Assert that verifyParity succeeds with 100% match (35,000,000 = 35,000,000)
    await JournalBackfillService.verifyParity(executor: rawDb);

    final parityStatus = await JournalBackfillService.checkParityStatus(executor: rawDb);
    expect(parityStatus.isParity, isTrue);
    expect(parityStatus.isBackfilled, isTrue);
    expect(parityStatus.mismatchReason, isNull);

    // Verify exact account balances in journal_lines
    final invRows = await rawDb.rawQuery(
      'SELECT SUM(debit_minor) as dr, SUM(credit_minor) as cr FROM journal_lines WHERE account_code = ?',
      [Accounts.inventory.code],
    );
    final invBal = (invRows.first['dr'] as num).toInt() - (invRows.first['cr'] as num).toInt();
    expect(invBal, equals(35000000), reason: 'Inventory 1140 must be exactly 35,000,000 minor units');

    final bankRows = await rawDb.rawQuery(
      'SELECT SUM(debit_minor) as dr, SUM(credit_minor) as cr FROM journal_lines WHERE account_code = ?',
      [Accounts.bank.code],
    );
    final bankBal = (bankRows.first['dr'] as num).toInt() - (bankRows.first['cr'] as num).toInt();
    expect(bankBal, equals(-35000000), reason: 'Bank 1120 must be exactly -35,000,000 minor units');

    // 5. Verify DatabaseDiagnosticService returns zero errors and parity is fully restored
    final diagReport = await DatabaseDiagnosticService.runDiagnostics(db: rawDb);
    final errors = diagReport.findings.where((f) => f.severity == DiagnosticSeverity.error).toList();
    expect(errors, isEmpty, reason: 'Database diagnostics must return 0 errors after full journal rebuild');
  });
}

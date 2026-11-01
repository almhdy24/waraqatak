import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/inventory_service.dart';
import 'package:warqatek/utils/error_utils.dart';

void main() {
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('period_lock_reasons_test');
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
        name: 'Period Lock Test Business',
        ownerName: 'Finance Controller',
        phone: '0123456789',
        address: 'Khartoum',
        currencyCode: 'SDG',
        taxRate: 0.15,
        taxesEnabled: true,
        pricesIncludeTax: false,
      ),
    );
  });

  group('Reason-Coded Stock Adjustments (D5)', () {
    test('1. Adjustments record explicit reason codes and post to correct accounts', () async {
      final pId = await db.insertProduct(
        Product(
          name: 'بضاعة تجريبية',
          barcode: 'ADJ-1',
          salePrice: 100.0,
          purchasePrice: 50.0,
          averageCost: 50.0,
          costStatus: Product.costStatusKnown,
          stockQuantity: 100.0,
        ),
      );

      // (a) Damage loss adjustment (-5 units)
      await InventoryService.adjust(
        productId: pId,
        delta: -5.0,
        reason: 'damage_loss',
        notes: 'تلف بسبب الرطوبة',
      );

      // Verify movement reason
      final rawDb = await db.database;
      final damageMovements = await rawDb.query(
        'stock_movements',
        where: "reason = 'damage_loss'",
      );
      expect(damageMovements, hasLength(1));
      expect(damageMovements.first['quantity'], equals(-5.0));

      // Verify journal posting: Dr 5200 (Inventory Adjustments) / Cr 1140 (Inventory)
      final damageEntries = await rawDb.query(
        'journal_entries',
        where: "source_type = 'stock_adjustment' AND memo LIKE '%damage_loss%'",
      );
      expect(damageEntries, hasLength(1));
      final damageLines = await rawDb.query(
        'journal_lines',
        where: 'entry_id = ?',
        whereArgs: [damageEntries.first['id']],
      );
      expect(damageLines, hasLength(2));
      final drAdj = damageLines.firstWhere((l) => l['account_code'] == Accounts.inventoryAdjustments.code);
      final crInv = damageLines.firstWhere((l) => l['account_code'] == Accounts.inventory.code);
      expect(drAdj['debit_minor'], equals(25000)); // 5 * 50 = 250 SDG -> 25000 minor
      expect(crInv['credit_minor'], equals(25000));

      // (b) Entry correction adjustment (+2 units)
      await InventoryService.adjust(
        productId: pId,
        delta: 2.0,
        reason: 'entry_correction',
        notes: 'تصحيح إدخال سابق',
      );

      // Verify journal posting: Dr 1140 (Inventory) / Cr 3100 (Opening Equity) -> DOES NOT HIT 5200 P&L
      final correctionEntries = await rawDb.query(
        'journal_entries',
        where: "source_type = 'stock_adjustment' AND memo LIKE '%entry_correction%'",
      );
      expect(correctionEntries, hasLength(1));
      final correctionLines = await rawDb.query(
        'journal_lines',
        where: 'entry_id = ?',
        whereArgs: [correctionEntries.first['id']],
      );
      expect(correctionLines, hasLength(2));
      final drInv2 = correctionLines.firstWhere((l) => l['account_code'] == Accounts.inventory.code);
      final crEquity = correctionLines.firstWhere((l) => l['account_code'] == Accounts.openingEquity.code);
      expect(drInv2['debit_minor'], equals(10000)); // 2 * 50 = 100 SDG -> 10000 minor
      expect(crEquity['credit_minor'], equals(10000));
      // Verify NO line hits 5200
      expect(
        correctionLines.any((l) => l['account_code'] == Accounts.inventoryAdjustments.code),
        isFalse,
        reason: 'entry_correction must not hit P&L account 5200',
      );
    });
  });

  group('Period Lock (D6)', () {
    test('2. Books closed through date strictly blocks historical mutations and permits future ones', () async {
      final pId = await db.insertProduct(
        Product(
          name: 'منتج قفل الفترة',
          barcode: 'PL-1',
          salePrice: 200.0,
          purchasePrice: 100.0,
          averageCost: 100.0,
          costStatus: Product.costStatusKnown,
          stockQuantity: 50.0,
        ),
      );

      // Insert an invoice dated 2026-03-01 before locking
      final invBeforeLock = Document(
        type: 'invoice',
        documentNumber: 'INV-PL-1',
        date: DateTime(2026, 3, 1),
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
      final invId = await db.insertDocumentWithItems(invBeforeLock, [
        DocumentItem(
          documentId: 0,
          productId: pId,
          description: 'منتج قفل الفترة',
          quantity: 1.0,
          price: 200.0,
          total: 200.0,
        ),
      ]);

      // Set period lock cutoff through 2026-03-15
      final lockDate = DateTime(2026, 3, 15);
      await db.setBooksClosedThrough(lockDate);

      expect(await db.getBooksClosedThrough(), equals(lockDate));
      expect(await db.isPeriodClosed(DateTime(2026, 3, 1)), isTrue);
      expect(await db.isPeriodClosed(DateTime(2026, 3, 15)), isTrue);
      expect(await db.isPeriodClosed(DateTime(2026, 3, 16)), isFalse);

      // (a) Attempt to insert an invoice in closed period (2026-03-10) -> REJECTED
      final invClosed = Document(
        type: 'invoice',
        documentNumber: 'INV-PL-FAIL',
        date: DateTime(2026, 3, 10),
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
      expect(
        () => db.insertDocumentWithItems(invClosed, [
          DocumentItem(
            documentId: 0,
            productId: pId,
            description: 'منتج',
            quantity: 1.0,
            price: 200.0,
            total: 200.0,
          ),
        ]),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Accounting period is closed through 2026-03-15'),
        )),
      );

      // (b) Attempt to update existing document dated in closed period -> REJECTED
      expect(
        () => db.updateDocumentWithItems(
          invBeforeLock.copyWith(id: invId, subtotal: 250.0, total: 250.0),
          [
            DocumentItem(
              documentId: invId,
              productId: pId,
              description: 'منتج معدل',
              quantity: 1.0,
              price: 250.0,
              total: 250.0,
            ),
          ],
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Accounting period is closed through 2026-03-15'),
        )),
      );

      // (c) Attempt to cancel existing document dated in closed period -> REJECTED
      expect(
        () => db.cancelDocument(invId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Accounting period is closed through 2026-03-15'),
        )),
      );

      // (d) Attempt stock adjustment dated in closed period -> REJECTED
      expect(
        () => db.adjustStock(
          productId: pId,
          delta: 5.0,
          date: DateTime(2026, 3, 5),
          notes: 'تسوية قديمة',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Accounting period is closed through 2026-03-15'),
        )),
      );

      // (e) Operations dated AFTER cutoff (2026-03-16) -> SUCCEED
      final invOpen = Document(
        type: 'invoice',
        documentNumber: 'INV-PL-PASS',
        date: DateTime(2026, 3, 16),
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
      final openDocId = await db.insertDocumentWithItems(invOpen, [
        DocumentItem(
          documentId: 0,
          productId: pId,
          description: 'منتج مفتوح',
          quantity: 1.0,
          price: 200.0,
          total: 200.0,
        ),
      ]);
      expect(openDocId, greaterThan(0));

      // (f) ErrorUtils mapping verification
      try {
        await db.assertPeriodOpen(DateTime(2026, 3, 1));
        fail('Should have thrown StateError');
      } catch (e) {
        final l10nAr = AppLocalizations('ar');
        final l10nEn = AppLocalizations('en');
        final friendlyAr = ErrorUtils.toFriendlyMessage(e, l10nAr);
        final friendlyEn = ErrorUtils.toFriendlyMessage(e, l10nEn);
        expect(friendlyAr, equals(l10nAr.errorPeriodClosed));
        expect(friendlyEn, equals(l10nEn.errorPeriodClosed));
      }

      // (g) Clear period lock cutoff -> All historical operations become permitted again
      await db.setBooksClosedThrough(null);
      expect(await db.getBooksClosedThrough(), isNull);
      expect(await db.isPeriodClosed(DateTime(2026, 3, 1)), isFalse);

      // Now cancelling the document succeeds
      await db.cancelDocument(invId);
      final cancelledDoc = await db.getDocumentById(invId);
      expect(cancelledDoc?.status, equals(DocumentStatus.cancelled));
    });
  });
}

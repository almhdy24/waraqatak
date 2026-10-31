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
import 'package:warqatek/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('single_base_currency_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> resetDb({String currencyCode = 'SDG', String? currencyLockedAt}) async {
    final rawDb = await DatabaseHelper.instance.database;
    await rawDb.delete('document_payments');
    await rawDb.delete('document_items');
    await rawDb.delete('stock_movements');
    await rawDb.delete('documents');
    await rawDb.delete('contacts');
    await rawDb.delete('products');
    await rawDb.delete('businesses');

    await DatabaseHelper.instance.insertBusiness(
      Business(
        name: 'متجر اختبار العملة الواحدة',
        ownerName: 'المالك',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0,
        currencyCode: currencyCode,
        currencyLockedAt: currencyLockedAt,
      ),
    );
  }

  Document makeDoc({
    int? id,
    required String type,
    String documentNumber = '',
    required double total,
    double paid = 0.0,
    double remaining = 0.0,
    String status = DocumentStatus.issued,
    String currencyCode = 'SDG',
    String? notes,
  }) {
    return Document(
      id: id,
      type: type,
      documentNumber: documentNumber,
      date: DateTime.now(),
      subtotal: total,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: total,
      paid: paid,
      remaining: remaining > 0 ? remaining : total - paid,
      status: status,
      currencyCode: currencyCode,
      notes: notes,
    );
  }

  group('Single Base Currency Policy: Architecture & Safety Suite', () {
    test('1. Currency modification is allowed before any transactions or stock movements', () async {
      await resetDb(currencyCode: 'SDG');
      final db = DatabaseHelper.instance;

      expect(await db.isCurrencyLocked(), isFalse);

      final business = await db.getFirstBusiness();
      expect(business, isNotNull);
      expect(business!.currencyCode, 'SDG');
      expect(business.currencyLockedAt, isNull);

      // Updating currency before transactions must succeed
      await db.updateBusiness(business.copyWith(currencyCode: 'USD'));

      final updated = await db.getFirstBusiness();
      expect(updated!.currencyCode, 'USD');
      expect(await db.isCurrencyLocked(), isFalse);
    });

    test('2. Draft documents do not lock currency; finalization locks currency permanently', () async {
      await resetDb(currencyCode: 'SDG');
      final db = DatabaseHelper.instance;

      // Create a draft quotation
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'quotation',
          documentNumber: 'QUO-00001',
          total: 100.0,
          status: DocumentStatus.draft,
          currencyCode: 'SDG',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'عرض سعر مسودة',
            quantity: 1,
            price: 100.0,
            total: 100.0,
          ),
        ],
      );

      // Create a draft invoice
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-00001',
          total: 200.0,
          status: DocumentStatus.draft,
          currencyCode: 'SDG',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'فاتورة مسودة',
            quantity: 1,
            price: 200.0,
            total: 200.0,
          ),
        ],
      );

      // Drafts must NOT lock currency
      var business = await db.getFirstBusiness();
      expect(await db.isCurrencyLocked(), isFalse);
      expect(business!.currencyLockedAt, isNull);

      // Allowed to change currency while only drafts exist
      await db.updateBusiness(business.copyWith(currencyCode: 'SAR'));
      business = await db.getFirstBusiness();
      expect(business!.currencyCode, 'SAR');

      // Now issue a finalized invoice in SAR
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-00002',
          total: 300.0,
          status: DocumentStatus.issued,
          currencyCode: 'SAR',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'فاتورة معتمدة',
            quantity: 1,
            price: 300.0,
            total: 300.0,
          ),
        ],
      );

      // Finalized invoice must immediately and permanently lock currency
      business = await db.getFirstBusiness();
      expect(business!.currencyLockedAt, isNotNull);
      expect(await db.isCurrencyLocked(), isTrue);

      // Changing currency must now be rejected atomically
      expect(
        () => db.updateBusiness(business!.copyWith(currencyCode: 'USD')),
        throwsA(isA<StateError>()),
      );
    });

    test('3. Deleting the finalized document does not unlock currency (permanence guarantee)', () async {
      await resetDb(currencyCode: 'SAR');
      final db = DatabaseHelper.instance;

      final docId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-00010',
          total: 150.0,
          status: DocumentStatus.issued,
          currencyCode: 'SAR',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'بند قابل للحذف',
            quantity: 1,
            price: 150.0,
            total: 150.0,
          ),
        ],
      );

      var business = await db.getFirstBusiness();
      expect(business!.currencyLockedAt, isNotNull);

      // Delete the document
      await db.deleteDocument(docId);

      // Verify documents table is empty
      final allDocs = await db.getAllDocuments();
      expect(allDocs, isEmpty);

      // Currency MUST remain locked
      expect(await db.isCurrencyLocked(), isTrue);
      business = await db.getFirstBusiness();
      expect(business!.currencyLockedAt, isNotNull);

      expect(
        () => db.updateBusiness(business!.copyWith(currencyCode: 'EUR')),
        throwsA(isA<StateError>()),
      );
    });

    test('4. Product creation without stock does not lock currency; opening stock locks currency', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;

      // 4a. Product with stockQuantity = 0 must NOT lock currency
      final p1Id = await db.insertProduct(
        const Product(
          name: 'منتج بدون مخزون',
          type: Product.typeProduct,
          salePrice: 10.0,
          purchasePrice: 5.0,
          stockQuantity: 0.0,
        ),
      );
      expect(p1Id, isPositive);
      expect(await db.isCurrencyLocked(), isFalse);

      // 4b. Product with stockQuantity > 0 (opening stock) MUST lock currency
      final p2Id = await db.insertProduct(
        const Product(
          name: 'منتج بمخزون افتتاحي',
          type: Product.typeProduct,
          salePrice: 20.0,
          purchasePrice: 12.0,
          stockQuantity: 5.0,
        ),
      );
      expect(p2Id, isPositive);

      final business = await db.getFirstBusiness();
      expect(business!.currencyLockedAt, isNotNull);
      expect(await db.isCurrencyLocked(), isTrue);

      expect(
        () => db.updateBusiness(business.copyWith(currencyCode: 'SDG')),
        throwsA(isA<StateError>()),
      );
    });

    test('5. New document creation rejects foreign currencies', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;

      // Attempting to insert a document in SDG when business is USD must throw ArgumentError
      expect(
        () => db.insertDocumentWithItems(
          makeDoc(
            type: 'invoice',
            documentNumber: 'INV-999',
            total: 100.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG', // Mismatch
          ),
          [
            DocumentItem(
              documentId: 0,
              description: 'سلعة بالعملة القديمة',
              quantity: 1,
              price: 100.0,
              total: 100.0,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('6. Historical document editing preserves original currency and recomputes cleanly', () async {
      await resetDb(currencyCode: 'USD', currencyLockedAt: DateTime.now().toIso8601String());
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Seed a historical invoice in SDG via raw insert (simulating legacy data)
      final histDocId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-LEGACY-01',
        'date': '2025-01-01T10:00:00.000',
        'subtotal': 1000.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 1000.0,
        'paid': 0.0,
        'remaining': 1000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      await rawDb.insert('document_items', {
        'document_id': histDocId,
        'description': 'بند قديم',
        'quantity': 2.0,
        'price': 500.0,
        'total': 1000.0,
        'taxable': 0,
      });

      // Fetch the historical document
      final docMap = (await rawDb.query('documents', where: 'id = ?', whereArgs: [histDocId])).first;
      final histDoc = Document.fromMap(docMap);
      expect(histDoc.currencyCode, 'SDG');

      // Update the historical document via updateDocumentWithItems
      final updatedDoc = makeDoc(
        id: histDoc.id,
        type: histDoc.type,
        documentNumber: histDoc.documentNumber,
        total: 1500.0,
        remaining: 1500.0,
        status: histDoc.status,
        currencyCode: histDoc.currencyCode,
        notes: 'ملاحظة محدثة للمستند القديم',
      );

      await db.updateDocumentWithItems(
        updatedDoc,
        [
          DocumentItem(
            documentId: histDocId,
            description: 'بند قديم معدل',
            quantity: 3.0,
            price: 500.0,
            total: 1500.0,
          ),
        ],
      );

      // Verify the document preserved its SDG currency
      final reloadedMap = (await rawDb.query('documents', where: 'id = ?', whereArgs: [histDocId])).first;
      final reloadedDoc = Document.fromMap(reloadedMap);
      expect(reloadedDoc.currencyCode, 'SDG');
      expect(reloadedDoc.total, 1500.0);
      expect(reloadedDoc.notes, 'ملاحظة محدثة للمستند القديم');
    });

    test('7. Duplication guard: copyDocumentWithItems rejects legacy currency mismatch', () async {
      await resetDb(currencyCode: 'USD', currencyLockedAt: DateTime.now().toIso8601String());
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Seed a legacy SDG document
      final legacyDocId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-SDG-01',
        'date': '2025-01-01T10:00:00.000',
        'subtotal': 50000.0,
        'total': 50000.0,
        'paid': 0.0,
        'remaining': 50000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // Duplicating the legacy SDG document while business is USD must throw StateError
      expect(
        () => db.copyDocumentWithItems(legacyDocId),
        throwsA(isA<StateError>()),
      );

      // Seed a USD document
      final usdDocId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-USD-01',
          total: 50.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'خدمة بالدولار',
            quantity: 1,
            price: 50.0,
            total: 50.0,
          ),
        ],
      );

      // Duplicating matching USD document must succeed
      final copyId = await db.copyDocumentWithItems(usdDocId);
      expect(copyId, isPositive);

      final copyDoc = (await db.getAllDocuments()).firstWhere((d) => d.id == copyId);
      expect(copyDoc.currencyCode, 'USD');
      expect(copyDoc.total, 50.0);
      expect(copyDoc.status, DocumentStatus.draft);
    });

    test('8. Quotation conversion: convertQuotationToInvoice rejects legacy currency mismatch', () async {
      await resetDb(currencyCode: 'USD', currencyLockedAt: DateTime.now().toIso8601String());
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Seed legacy SDG quotation
      final legacyQuoId = await rawDb.insert('documents', {
        'type': 'quotation',
        'document_number': 'QUO-SDG-01',
        'date': '2025-01-01T10:00:00.000',
        'subtotal': 25000.0,
        'total': 25000.0,
        'paid': 0.0,
        'remaining': 25000.0,
        'status': DocumentStatus.issued,
        'currency_code': 'SDG',
      });

      // Converting legacy SDG quotation when business is USD must throw StateError
      expect(
        () => db.convertQuotationToInvoice(legacyQuoId),
        throwsA(isA<StateError>()),
      );

      // Seed matching USD quotation
      final usdQuoId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'quotation',
          documentNumber: 'QUO-USD-01',
          total: 120.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'عرض سعر دولار',
            quantity: 2,
            price: 60.0,
            total: 120.0,
          ),
        ],
      );

      // Converting matching USD quotation must succeed
      final invId = await db.convertQuotationToInvoice(usdQuoId);
      expect(invId, isPositive);

      final invDoc = (await db.getAllDocuments()).firstWhere((d) => d.id == invId);
      expect(invDoc.currencyCode, 'USD');
      expect(invDoc.total, 120.0);
      expect(invDoc.status, DocumentStatus.draft);
    });

    test('9. Inconsistent or unproven stock cost guard: quantity reconciliation alone cannot trust unknown cost', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // 9a. Product with unknown cost, stock = 0, but inconsistent movement total = -5 (oversold history)
      final badProdId = await rawDb.insert('products', {
        'name': 'منتج ذو تاريخ غير متسق',
        'type': 'product',
        'stock_quantity': 0.0,
        'average_cost': null,
        'cost_status': Product.costStatusUnknown,
      });

      await rawDb.insert('stock_movements', {
        'product_id': badProdId,
        'type': StockMovement.typeSale,
        'quantity': -5.0, // Inconsistent: total movements = -5, but current stock is 0
        'date': DateTime.now().toIso8601String(),
        'cost_status': StockMovement.costStatusUnknown,
      });

      // Incoming purchase into badProdId
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'purchase',
          documentNumber: 'PUR-01',
          total: 100.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            productId: badProdId,
            description: 'شراء جديد',
            quantity: 10,
            price: 10.0,
            total: 100.0,
          ),
        ],
      );

      // Cost status MUST remain unknown due to inconsistent ledger
      final badProd = await db.getProductById(badProdId);
      expect(badProd!.costStatus, Product.costStatusUnknown);

      // 9b. Product with unknown cost history: stock = 0, net quantity = 0, but unknown movement history
      final unknownHistProdId = await rawDb.insert('products', {
        'name': 'منتج ذو تاريخ غير معلوم التكلفة',
        'type': 'product',
        'stock_quantity': 0.0,
        'average_cost': null,
        'cost_status': Product.costStatusUnknown,
      });

      // Opening 5 with unknown cost, sale 5 => net quantity = 0
      await rawDb.insert('stock_movements', {
        'product_id': unknownHistProdId,
        'type': StockMovement.typeOpening,
        'quantity': 5.0,
        'date': DateTime.now().toIso8601String(),
        'cost_status': StockMovement.costStatusUnknown,
      });
      await rawDb.insert('stock_movements', {
        'product_id': unknownHistProdId,
        'type': StockMovement.typeSale,
        'quantity': -5.0,
        'date': DateTime.now().toIso8601String(),
        'cost_status': StockMovement.costStatusUnknown,
      });

      // Incoming purchase into unknownHistProdId
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'purchase',
          documentNumber: 'PUR-02',
          total: 150.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            productId: unknownHistProdId,
            description: 'شراء دفعة بعد تاريخ مجهول',
            quantity: 10,
            price: 15.0,
            total: 150.0,
          ),
        ],
      );

      // Quantity reconciliation ALONE must NOT make unknown inventory costs trusted
      final unknownHistProd = await db.getProductById(unknownHistProdId);
      expect(unknownHistProd!.costStatus, Product.costStatusUnknown);

      // 9c. Product with zero stock and completely clean provenance (no unknown movements)
      final cleanProdId = await rawDb.insert('products', {
        'name': 'منتج ذو تاريخ نظيف وموثوق',
        'type': 'product',
        'stock_quantity': 0.0,
        'average_cost': null,
        'cost_status': Product.costStatusUnknown,
      });

      // Opening 5 with known cost $10, sale 5 with known cost $10 => net qty = 0, no unknown movements
      await rawDb.insert('stock_movements', {
        'product_id': cleanProdId,
        'type': StockMovement.typeOpening,
        'quantity': 5.0,
        'unit_cost': 10.0,
        'total_cost': 50.0,
        'date': DateTime.now().toIso8601String(),
        'cost_status': StockMovement.costStatusKnown,
      });
      await rawDb.insert('stock_movements', {
        'product_id': cleanProdId,
        'type': StockMovement.typeSale,
        'quantity': -5.0,
        'unit_cost': 10.0,
        'total_cost': 50.0,
        'date': DateTime.now().toIso8601String(),
        'cost_status': StockMovement.costStatusKnown,
      });

      // Incoming purchase into cleanProdId
      await db.insertDocumentWithItems(
        makeDoc(
          type: 'purchase',
          documentNumber: 'PUR-03',
          total: 180.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            productId: cleanProdId,
            description: 'شراء دفعة جديدة بعد تاريخ نظيف',
            quantity: 10,
            price: 18.0,
            total: 180.0,
          ),
        ],
      );

      // Clean ledger and verified known history allows fresh batch to be known
      final cleanProd = await db.getProductById(cleanProdId);
      expect(cleanProd!.costStatus, Product.costStatusKnown);
      expect(cleanProd.averageCost, 18.0);
    });

    test('10. Backup restoration preserves original currency, cost status, and locks currency', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;

      // Simulate a JSON backup map from a legacy business operating in SDG
      final backupData = {
        'app': BackupService.appId,
        'backup_version': 1,
        'database_version': 20,
        'data': {
          'businesses': [
            {
              'id': 1,
              'name': 'متجر مسترجع من النسخة الاحتياطية',
              'owner_name': 'مالك النسخة',
              'phone': '0912345678',
              'address': 'أم درمان',
              'currency_code': 'SDG',
              'currency_locked_at': null, // Legacy backup without currency_locked_at
            }
          ],
          'contacts': <Map<String, dynamic>>[],
          'products': [
            {
              'id': 1,
              'name': 'منتج قديم بتكلفة غير موثوقة',
              'type': 'product',
              'stock_quantity': 10.0,
              'average_cost': 50.0,
              'cost_status': Product.costStatusUnknown, // Unknown cost status
            }
          ],
          'documents': [
            {
              'id': 1,
              'type': 'invoice',
              'document_number': 'INV-RESTORE-01',
              'date': '2025-06-01T12:00:00.000',
              'subtotal': 500.0,
              'total': 500.0,
              'paid': 500.0,
              'remaining': 0.0,
              'status': DocumentStatus.issued,
              'currency_code': 'SDG',
            }
          ],
          'document_items': [
            {
              'id': 1,
              'document_id': 1,
              'product_id': 1,
              'description': 'بند مسترجع',
              'quantity': 2.0,
              'price': 250.0,
              'total': 500.0,
            }
          ],
          'document_counters': [
            {'type': 'invoice', 'next_number': 2}
          ],
          'document_payments': [
            {
              'id': 1,
              'document_id': 1,
              'amount': 500.0,
              'date': '2025-06-01T12:00:00.000',
              'payment_method': 'cash',
            }
          ],
          'stock_movements': [
            {
              'id': 1,
              'product_id': 1,
              'type': StockMovement.typeSale,
              'quantity': -2.0,
              'reference_document_id': 1,
              'date': '2025-06-01T12:00:00.000',
              'cost_status': StockMovement.costStatusUnknown,
            }
          ],
        },
      };

      final restored = await BackupService.restoreFromJsonMap(
        backupData,
        createSafetyBackup: false,
      );
      expect(restored, isTrue);

      // Verify business currency is SDG and immediately locked
      final restoredBusiness = await db.getFirstBusiness();
      expect(restoredBusiness, isNotNull);
      expect(restoredBusiness!.currencyCode, 'SDG');
      expect(restoredBusiness.currencyLockedAt, isNotNull);
      expect(await db.isCurrencyLocked(), isTrue);

      // Changing currency must be rejected
      expect(
        () => db.updateBusiness(restoredBusiness.copyWith(currencyCode: 'USD')),
        throwsA(isA<StateError>()),
      );

      // Product cost_status must be preserved as unknown (NOT mutated to known)
      final restoredProduct = await db.getProductById(1);
      expect(restoredProduct, isNotNull);
      expect(restoredProduct!.costStatus, Product.costStatusUnknown);
    });

    test('11. issueDocument draft-to-finalized transitions lock currency and reject foreign currency', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // 11a. Service draft invoice in USD (no stock movements)
      final serviceDraftId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-SRV-01',
          total: 80.0,
          status: DocumentStatus.draft,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'استشارة فنية (خدمة بدون مخزون)',
            quantity: 1,
            price: 80.0,
            total: 80.0,
          ),
        ],
      );

      expect(await db.isCurrencyLocked(), isFalse);

      // Issuing the draft must lock currency atomically
      await db.issueDocument(serviceDraftId);

      expect(await db.isCurrencyLocked(), isTrue);
      final biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);

      // 11b. Draft invoice seeded in foreign currency (EUR)
      await resetDb(currencyCode: 'USD');
      final eurDraftId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-EUR-01',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 100.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 100.0,
        'paid': 0.0,
        'remaining': 100.0,
        'status': DocumentStatus.draft,
        'currency_code': 'EUR',
      });
      await rawDb.insert('document_items', {
        'document_id': eurDraftId,
        'description': 'خدمة باليورو',
        'quantity': 1.0,
        'price': 100.0,
        'total': 100.0,
      });

      // Issuing draft with mismatched legacy currency must be rejected
      expect(
        () => db.issueDocument(eurDraftId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('12. updateDocumentWithItems draft-to-finalized transition and currency immutability', () async {
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;

      // 12a. Create draft invoice in USD
      final draftId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-DRAFT-01',
          total: 200.0,
          status: DocumentStatus.draft,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'خدمة مسودة',
            quantity: 2,
            price: 100.0,
            total: 200.0,
          ),
        ],
      );

      expect(await db.isCurrencyLocked(), isFalse);

      // Finalize the draft via updateDocumentWithItems
      await db.updateDocumentWithItems(
        makeDoc(
          id: draftId,
          type: 'invoice',
          documentNumber: 'INV-DRAFT-01',
          total: 200.0,
          status: DocumentStatus.issued, // Finalized!
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: draftId,
            description: 'خدمة معتمدة',
            quantity: 2,
            price: 100.0,
            total: 200.0,
          ),
        ],
      );

      // Must be locked atomically
      expect(await db.isCurrencyLocked(), isTrue);
      final biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);

      // 12b. Attempting to change currency on finalized document must throw ArgumentError
      expect(
        () => db.updateDocumentWithItems(
          makeDoc(
            id: draftId,
            type: 'invoice',
            documentNumber: 'INV-DRAFT-01',
            total: 200.0,
            status: DocumentStatus.issued,
            currencyCode: 'EUR', // Mismatched change
          ),
          [
            DocumentItem(
              documentId: draftId,
              description: 'خدمة معتمدة',
              quantity: 2,
              price: 100.0,
              total: 200.0,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('13. Every payment insertion path locks currency atomically', () async {
      // 13a. Advance payment on draft invoice
      await resetDb(currencyCode: 'USD');
      final db = DatabaseHelper.instance;

      expect(await db.isCurrencyLocked(), isFalse);

      await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-ADV-01',
          total: 500.0,
          paid: 100.0, // Upfront advance payment on draft
          status: DocumentStatus.draft,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'دفعة مقدمة على مسودة',
            quantity: 1,
            price: 500.0,
            total: 500.0,
          ),
        ],
      );

      // Advance payment must lock currency even on draft
      expect(await db.isCurrencyLocked(), isTrue);
      var biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);

      // 13b. Updating draft to include upfront payment locks currency
      await resetDb(currencyCode: 'USD');
      expect(await db.isCurrencyLocked(), isFalse);

      final unpdDraftId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-UNPD-01',
          total: 400.0,
          paid: 0.0,
          status: DocumentStatus.draft,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'مسودة بدون دفع',
            quantity: 1,
            price: 400.0,
            total: 400.0,
          ),
        ],
      );
      expect(await db.isCurrencyLocked(), isFalse);

      // Update draft to add upfront payment
      await db.updateDocumentWithItems(
        makeDoc(
          id: unpdDraftId,
          type: 'invoice',
          documentNumber: 'INV-UNPD-01',
          total: 400.0,
          paid: 80.0, // Added upfront payment
          status: DocumentStatus.draft,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: unpdDraftId,
            description: 'مسودة بدون دفع',
            quantity: 1,
            price: 400.0,
            total: 400.0,
          ),
        ],
      );

      expect(await db.isCurrencyLocked(), isTrue);
      biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);

      // 13c. recordPayment locks currency atomically
      await resetDb(currencyCode: 'USD');
      final rawDb = await db.database;
      final invId = await db.insertDocumentWithItems(
        makeDoc(
          type: 'invoice',
          documentNumber: 'INV-REC-01',
          total: 300.0,
          status: DocumentStatus.issued,
          currencyCode: 'USD',
        ),
        [
          DocumentItem(
            documentId: 0,
            description: 'فاتورة للتحصيل',
            quantity: 1,
            price: 300.0,
            total: 300.0,
          ),
        ],
      );

      // Temporarily clear currency_locked_at to verify recordPayment locks it atomically
      await rawDb.update('businesses', {'currency_locked_at': null});
      await rawDb.delete('document_payments');

      // Record a payment via recordPayment
      await db.recordPayment(
        documentId: invId,
        amount: 50.0,
        paymentMethod: 'cash',
        notes: 'دفعة نقدية',
      );

      // Payment insertion MUST lock currency
      expect(await db.isCurrencyLocked(), isTrue);
      biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);
    });

    test('14. Migration v21 locks previously issued documents, including cancelled documents', () async {
      await resetDb(currencyCode: 'SAR');
      final db = DatabaseHelper.instance;
      final rawDb = await db.database;

      // Seed a cancelled document that was previously finalized
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-CANCELLED-01',
        'date': '2025-01-01T10:00:00.000',
        'subtotal': 500.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 500.0,
        'paid': 0.0,
        'remaining': 500.0,
        'status': DocumentStatus.cancelled, // Finalized then cancelled
        'currency_code': 'SAR',
      });

      // Ensure business.currency_locked_at is initially null
      await rawDb.update('businesses', {'currency_locked_at': null});
      var biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNull);

      // Run backfillCurrencyLockIfNeeded simulating migration v21
      await DatabaseHelper.backfillCurrencyLockIfNeeded(rawDb);

      // Must be locked!
      biz = await db.getFirstBusiness();
      expect(biz!.currencyLockedAt, isNotNull);
      expect(await db.isCurrencyLocked(), isTrue);

      // Business currency update must be rejected
      expect(
        () => db.updateBusiness(biz!.copyWith(currencyCode: 'USD')),
        throwsA(isA<StateError>()),
      );
    });
  });
}

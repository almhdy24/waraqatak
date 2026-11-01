import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('purchase_edit_integrity_test');
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
    final file = File('${tempDir.path}/warqatek.db');
    if (file.existsSync()) file.deleteSync();

    await db.insertBusiness(
      const Business(
        name: 'مؤسسة الاختبار',
        ownerName: 'المدير',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0.0,
        taxesEnabled: false,
        pricesIncludeTax: false,
        currencyCode: 'SDG',
      ),
    );
  });

  test('1. Editing an issued purchase to add a supplier preserves stock quantity and movements', () async {
    final business = (await db.getFirstBusiness())!;

    final prodId = await db.insertProduct(
      const Product(
        name: 'منتج تجريبي',
        purchasePrice: 50.0,
        salePrice: 75.0,
        stockQuantity: 0.0,
        type: Product.typeProduct,
      ),
    );

    final purchaseInput = DocumentItemInput(
      productId: prodId,
      description: 'شراء كمية أولية',
      quantity: 100.0,
      price: 50.0,
      taxable: false,
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [purchaseInput],
      isDraft: false,
    );

    var product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 100.0);
    expect(product.averageCost, 50.0);

    final supplierId = await db.insertContact(
      const Contact(name: 'المورد الأول', phone: '0912345678', type: 'supplier'),
    );
    final supplier = (await db.getContactById(supplierId))!;

    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [purchaseInput],
      isDraft: false,
    );

    product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 100.0);

    final sqliteDb = await db.database;
    final movements = await sqliteDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((movements.first['net_qty'] as num?)?.toDouble(), 100.0);
    expect(movements.first['cnt'], 1);
    expect(product.averageCost, 50.0);

    final book = await LedgerService.load(currencyCode: 'SDG');
    final tb = AccountingReports.trialBalance(book.entries);
    final invRow = tb.rows.where((r) => r.account == Accounts.inventory).firstOrNull;
    expect((invRow?.debit ?? 0.0) - (invRow?.credit ?? 0.0), 5000.0);

    final payRow = tb.rows.where((r) => r.account == Accounts.payables).firstOrNull;
    expect((payRow?.credit ?? 0.0) - (payRow?.debit ?? 0.0), 5000.0);

    final supplierDocs = await db.getDocumentsByContact(supplierId);
    expect(supplierDocs.any((d) => d.id == docId), isTrue);
  });

  test('2. Purchase metadata edit (notes, date, payment method) produces zero stock movements', () async {
    final business = (await db.getFirstBusiness())!;
    final prodId = await db.insertProduct(
      const Product(name: 'منتج م2', purchasePrice: 20.0, salePrice: 30.0, stockQuantity: 0.0),
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 50.0, price: 20.0)],
      isDraft: false,
    );

    final countBefore = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );
    expect(countBefore, 1);

    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 50.0, price: 20.0)],
      notes: 'ملاحظة محدثة',
      paymentMethod: 'bank_transfer',
      isDraft: false,
    );

    final countAfter = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );
    expect(countAfter, 1, reason: 'Metadata-only edit must produce zero new stock movements');

    final product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 50.0);
    expect(product.averageCost, 20.0);
  });

  test('3. Purchase edit: increasing quantity applies delta movement and updates moving average', () async {
    final business = (await db.getFirstBusiness())!;
    final prodId = await db.insertProduct(
      const Product(name: 'منتج م3', purchasePrice: 40.0, salePrice: 60.0, stockQuantity: 0.0),
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'أولي', quantity: 100.0, price: 40.0)],
      isDraft: false,
    );

    // Increase qty from 100 to 150 (incoming 50 at cost 50.0)
    // Old cost 4000, new cost 4000 + 2500 = 6500. New avg = 6500 / 150 = 43.3333
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(productId: prodId, description: 'أولي', quantity: 100.0, price: 40.0),
        DocumentItemInput(productId: prodId, description: 'إضافي', quantity: 50.0, price: 50.0),
      ],
      isDraft: false,
    );

    final product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 150.0);

    final sqliteDb = await db.database;
    final movements = await sqliteDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((movements.first['net_qty'] as num?)?.toDouble(), 150.0);
    expect(movements.first['cnt'], 2); // Initial (100) + Delta (50)
    expect(product.averageCost, closeTo(6500.0 / 150.0, 0.01));
  });

  test('4. Purchase edit: decreasing quantity applies delta cancellation movement', () async {
    final business = (await db.getFirstBusiness())!;
    final prodId = await db.insertProduct(
      const Product(name: 'منتج م4', purchasePrice: 30.0, salePrice: 45.0, stockQuantity: 0.0),
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 100.0, price: 30.0)],
      isDraft: false,
    );

    // Decrease from 100 to 70
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 70.0, price: 30.0)],
      isDraft: false,
    );

    final product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 70.0);

    final sqliteDb = await db.database;
    final movements = await sqliteDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((movements.first['net_qty'] as num?)?.toDouble(), 70.0);
    expect(movements.first['cnt'], 2); // Initial (100) + Cancellation (-30)
    expect(product.averageCost, 30.0);
  });

  test('5. Purchase edit: price change updates average cost without changing quantity or adding movements', () async {
    final business = (await db.getFirstBusiness())!;
    final prodId = await db.insertProduct(
      const Product(name: 'منتج م5', purchasePrice: 50.0, salePrice: 75.0, stockQuantity: 0.0),
    );

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 100.0, price: 50.0)],
      isDraft: false,
    );

    // Price changed from 50 to 60 for the 100 units
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: prodId, description: 'شراء', quantity: 100.0, price: 60.0)],
      isDraft: false,
    );

    final product = (await db.getProductById(prodId))!;
    expect(product.stockQuantity, 100.0);
    expect(product.averageCost, 60.0);

    final countAfter = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );
    expect(countAfter, 1, reason: 'Price-only edit must not add extraneous physical movements');
  });

  test('6. Purchase edit: adding and removing line items applies correct deltas', () async {
    final business = (await db.getFirstBusiness())!;
    final pA = await db.insertProduct(const Product(name: 'أ', purchasePrice: 10.0, salePrice: 15.0, stockQuantity: 0.0));
    final pB = await db.insertProduct(const Product(name: 'ب', purchasePrice: 20.0, salePrice: 30.0, stockQuantity: 0.0));
    final pC = await db.insertProduct(const Product(name: 'ج', purchasePrice: 30.0, salePrice: 45.0, stockQuantity: 0.0));

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(productId: pA, description: 'أ', quantity: 10.0, price: 10.0),
        DocumentItemInput(productId: pB, description: 'ب', quantity: 20.0, price: 20.0),
      ],
      isDraft: false,
    );

    // Remove B, keep A, add C (15 units)
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [
        DocumentItemInput(productId: pA, description: 'أ', quantity: 10.0, price: 10.0),
        DocumentItemInput(productId: pC, description: 'ج', quantity: 15.0, price: 30.0),
      ],
      isDraft: false,
    );

    expect((await db.getProductById(pA))!.stockQuantity, 10.0);
    expect((await db.getProductById(pB))!.stockQuantity, 0.0);
    expect((await db.getProductById(pC))!.stockQuantity, 15.0);
  });

  test('7. Purchase edit: draft to issued creates initial movements', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'مسودة', purchasePrice: 25.0, salePrice: 40.0, stockQuantity: 0.0));

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'مسودة شراء', quantity: 40.0, price: 25.0)],
      isDraft: true,
    );

    expect((await db.getProductById(pid))!.stockQuantity, 0.0);

    // Finalize draft via updateDocument
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'مسودة شراء', quantity: 40.0, price: 25.0)],
      isDraft: false,
    );

    expect((await db.getProductById(pid))!.stockQuantity, 40.0);
    final count = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );
    expect(count, 1);
  });

  test('8. Purchase edit: edit then cancel results in net zero movements', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'إلغاء', purchasePrice: 15.0, salePrice: 25.0, stockQuantity: 0.0));

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 50.0, price: 15.0)],
      isDraft: false,
    );

    // Edit: increase to 80
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 80.0, price: 15.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 80.0);

    // Cancel document
    await DocumentService.cancelDocument(docId);
    expect((await db.getProductById(pid))!.stockQuantity, 0.0);

    final netQty = (await (await db.database).rawQuery(
      'SELECT SUM(quantity) as net FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    )).first['net'] as num?;
    expect(netQty?.toDouble() ?? 0.0, 0.0, reason: 'Cancelled document must net to zero movements (INV-10)');
  });

  test('9. Purchase edit: editing twice with same payload is strictly idempotent', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'تكرار', purchasePrice: 10.0, salePrice: 20.0, stockQuantity: 0.0));

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 20.0, price: 10.0)],
      isDraft: false,
    );

    // Edit 1
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 25.0, price: 10.0)],
      isDraft: false,
    );
    final countAfterFirst = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );

    // Edit 2 (exact same payload)
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 25.0, price: 10.0)],
      isDraft: false,
    );
    final countAfterSecond = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );

    expect(countAfterSecond, countAfterFirst, reason: 'Idempotent edit must not append movements');
    expect((await db.getProductById(pid))!.stockQuantity, 25.0);
  });

  test('10. Purchase edit: fractional quantities handled accurately', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'كسور', purchasePrice: 100.0, salePrice: 150.0, stockQuantity: 0.0));

    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'كسر', quantity: 10.5, price: 100.0)],
      isDraft: false,
    );

    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'كسر', quantity: 12.25, price: 100.0)],
      isDraft: false,
    );

    final product = (await db.getProductById(pid))!;
    expect(product.stockQuantity, closeTo(12.25, 0.0001));
  });

  test('11. Purchase edit: cannot reduce purchase below already-consumed stock', () async {
    final business = (await db.getFirstBusiness())!;
    final custId = await db.insertContact(const Contact(name: 'زبون', phone: '0911', type: 'customer'));
    final customer = (await db.getContactById(custId))!;
    final pid = await db.insertProduct(const Product(name: 'حماية الاستهلاك', purchasePrice: 10.0, salePrice: 20.0, stockQuantity: 0.0));

    // Purchase 10 units
    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 10.0, price: 10.0)],
      isDraft: false,
    );

    // Sell 8 units (leaving 2 units in stock)
    await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      contact: customer,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 8.0, price: 20.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 2.0);

    // Attempt to reduce purchase from 10 to 1 (which would require removing 9 units when only 2 exist)
    expect(
      () => DocumentService.updateDocument(
        documentId: docId,
        type: 'purchase',
        business: business,
        items: [DocumentItemInput(productId: pid, description: 'شراء', quantity: 1.0, price: 10.0)],
        isDraft: false,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('12. Sales edit: metadata-only edit produces zero stock movements', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'بيع م', purchasePrice: 10.0, salePrice: 25.0, stockQuantity: 50.0));

    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 10.0, price: 25.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 40.0);

    final countBefore = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );

    // Metadata edit
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'invoice',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 10.0, price: 25.0)],
      notes: 'تحديث بيانات الفاتورة',
      isDraft: false,
    );

    final countAfter = Sqflite.firstIntValue(
      await (await db.database).rawQuery('SELECT COUNT(*) FROM stock_movements WHERE reference_document_id = ?', [docId]),
    );
    expect(countAfter, countBefore, reason: 'Sales metadata edit must not add stock movements');
    expect((await db.getProductById(pid))!.stockQuantity, 40.0);
  });

  test('13. Sales edit: increasing and decreasing quantity adjusts stock and movements accurately', () async {
    final business = (await db.getFirstBusiness())!;
    final pid = await db.insertProduct(const Product(name: 'كميات بيع', purchasePrice: 10.0, salePrice: 20.0, stockQuantity: 50.0));

    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 10.0, price: 20.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 40.0);

    // Increase sold qty from 10 to 15 (delta = +5, stock drops to 35)
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'invoice',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 15.0, price: 20.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 35.0);

    var netM = (await (await db.database).rawQuery(
      'SELECT SUM(quantity) as net FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    )).first['net'] as num?;
    expect(netM?.toDouble(), -15.0, reason: 'Net sale movements must match sold quantity (-15)');

    // Decrease sold qty from 15 to 8 (delta = -7, stock restored to 42)
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'invoice',
      business: business,
      items: [DocumentItemInput(productId: pid, description: 'بيع', quantity: 8.0, price: 20.0)],
      isDraft: false,
    );
    expect((await db.getProductById(pid))!.stockQuantity, 42.0);

    netM = (await (await db.database).rawQuery(
      'SELECT SUM(quantity) as net FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    )).first['net'] as num?;
    expect(netM?.toDouble(), -8.0, reason: 'Net sale movements must match updated sold quantity (-8)');
  });

  test('14. V4 End-to-end full scenario: issue purchase 100 without supplier, edit supplier, notes, date; assert stock, movements, ledger, idempotency', () async {
    final business = (await db.getFirstBusiness())!;
    final prodId = await db.insertProduct(
      const Product(name: 'منتج V4 الشامل', purchasePrice: 40.0, salePrice: 60.0, stockQuantity: 0.0),
    );

    final purchaseInput = DocumentItemInput(productId: prodId, description: 'شراء 100 وحدة', quantity: 100.0, price: 40.0);

    // 1. Issue purchase qty 100 without a supplier
    final docId = await DocumentService.createDocument(
      type: 'purchase',
      business: business,
      contact: null,
      items: [purchaseInput],
      isDraft: false,
    );

    expect((await db.getProductById(prodId))!.stockQuantity, 100.0);

    // 2. Edit to add a supplier
    final supplierId = await db.insertContact(
      const Contact(name: 'مورد V4 المعتمد', phone: '0900000000', type: 'supplier'),
    );
    final supplier = (await db.getContactById(supplierId))!;

    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [purchaseInput],
      isDraft: false,
    );

    // 3. Edit notes
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [purchaseInput],
      notes: 'ملاحظات التوريد المحدثة',
      isDraft: false,
    );

    // 4. Edit date
    final newDate = DateTime.now().add(const Duration(days: 2));
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [purchaseInput],
      notes: 'ملاحظات التوريد المحدثة',
      date: newDate,
      isDraft: false,
    );

    // 5. Assert stock stays 100
    expect((await db.getProductById(prodId))!.stockQuantity, 100.0);

    // 6. Assert net movements for document equal 100, no new movements
    final rawDb = await db.database;
    final movements = await rawDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect((movements.first['net_qty'] as num).toDouble(), 100.0);
    expect(movements.first['cnt'], 1, reason: 'Must have exactly 1 initial movement; metadata edits add no new movements');

    // 7. Assert product inventory value and document payables correct
    final prodAfter = (await db.getProductById(prodId))!;
    expect(prodAfter.stockQuantity * prodAfter.averageCost!, 4000.0);

    final docAfter = (await db.getDocumentById(docId))!;
    expect(docAfter.total, 4000.0);
    expect(docAfter.remaining, 4000.0);

    final supplierDocs = await db.getDocumentsByContact(supplierId);
    expect(supplierDocs.any((d) => d.id == docId), isTrue);
    expect(supplierDocs.firstWhere((d) => d.id == docId).remaining, 4000.0);

    // 8. Assert second identical edit is a no-op
    await DocumentService.updateDocument(
      documentId: docId,
      type: 'purchase',
      business: business,
      contact: supplier,
      items: [purchaseInput],
      notes: 'ملاحظات التوريد المحدثة',
      date: newDate,
      isDraft: false,
    );

    final movementsAfterSecond = await rawDb.rawQuery(
      'SELECT SUM(quantity) as net_qty, COUNT(*) as cnt FROM stock_movements WHERE reference_document_id = ?',
      [docId],
    );
    expect(movementsAfterSecond.first['cnt'], 1, reason: 'Identical edit must be strictly idempotent with zero new movements');
    expect((movementsAfterSecond.first['net_qty'] as num).toDouble(), 100.0);
  });
}

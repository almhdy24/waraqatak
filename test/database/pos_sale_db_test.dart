// Real SQLite (ffi) integration test for the quick-sale flow and payments.
// Runs on the host with the system libsqlite3.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Business business;
  late Product pen, repair;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getDatabasesPath();
    final f = File('$dir/warqatek_free.db');
    if (f.existsSync()) f.deleteSync();
    final db = DatabaseHelper.instance;
    await db.insertBusiness(const Business(
        name: 'متجر', ownerName: 'أحمد', phone: '1', address: 'x', taxRate: 10));
    business = (await db.getFirstBusiness())!;
    final penId = await ProductService.createProduct(name: 'قلم', salePrice: 500, stockQuantity: 5, barcode: '111');
    final repId = await ProductService.createProduct(name: 'صيانة', salePrice: 1500, type: Product.typeService, isTaxable: false);
    pen = (await db.getProductById(penId))!;
    repair = (await db.getProductById(repId))!;
  });

  test('quick sale: paid invoice + receipt + payment method + stock, atomically', () async {
    final db = DatabaseHelper.instance;
    final method = (await db.getEnabledPaymentMethods()).first.key;
    final cart = PosCart()..add(pen, quantity: 2)..add(repair);
    cart.discount = 500;
    final t = cart.totals(taxRate: business.taxRate, pricesIncludeTax: business.pricesIncludeTax);

    final id = await DocumentService.createDocument(
      type: 'invoice', business: business, items: cart.toItemInputs(),
      discount: cart.discount, date: DateTime.now(), payNowMethod: method);

    final inv = (await db.getDocumentById(id))!;
    expect(inv.status, DocumentStatus.paid);
    expect(inv.total, closeTo(t.total, 0.001));
    expect(inv.paid, closeTo(inv.total, 0.001));
    expect(inv.remaining, 0);
    final payments = await db.getDocumentPayments(id);
    expect(payments, hasLength(1));
    expect(payments.single.paymentMethod, method);
    expect(payments.single.amount, closeTo(inv.total, 0.001));
    final receipts = (await db.getDocumentsByType('payment_receipt')).where((r) => r.relatedDocumentId == id);
    expect(receipts, hasLength(1));
    expect(receipts.single.paymentMethod, method);
    expect((await db.getProductById(pen.id!))!.stockQuantity, 3);
    expect((await db.getStockMovements(pen.id!)).where((m) => m.referenceDocumentId == id), hasLength(1));
    expect((await db.getProductById(repair.id!))!.stockQuantity, 0, reason: 'services keep no stock');
    // ignore: avoid_print
    print('sale ${inv.documentNumber}: total=${inv.total} tax=${inv.taxAmount} status=${inv.status}');
  });

  test('insufficient stock rolls everything back', () async {
    final db = DatabaseHelper.instance;
    final before = (await db.getAllDocuments()).length;
    final freshPen = (await db.getProductById(pen.id!))!; // 3 left
    await expectLater(
      DocumentService.createDocument(
        type: 'invoice', business: business, date: DateTime.now(), payNowMethod: 'cash',
        items: [DocumentItemInput(description: 'قلم', quantity: 10, price: 500, productId: freshPen.id)]),
      throwsA(isA<StateError>()),
    );
    expect((await db.getAllDocuments()).length, before, reason: 'no invoice or receipt left behind');
    expect((await db.getProductById(pen.id!))!.stockQuantity, 3);
  });

  test('payNowMethod is rejected for drafts / partial payments', () async {
    final items = [const DocumentItemInput(description: 'x', quantity: 1, price: 10)];
    expect(() => DocumentService.createDocument(type: 'invoice', business: business, items: items, isDraft: true, payNowMethod: 'cash'), throwsArgumentError);
    expect(() => DocumentService.createDocument(type: 'invoice', business: business, items: items, paid: 5, payNowMethod: 'cash'), throwsArgumentError);
    expect(() => DocumentService.createDocument(type: 'quotation', business: business, items: items, payNowMethod: 'cash'), throwsArgumentError);
  });

  test('regular payment recording still works (refactor)', () async {
    final db = DatabaseHelper.instance;
    final id = await DocumentService.createDocument(
      type: 'invoice', business: business, date: DateTime.now(),
      items: [const DocumentItemInput(description: 'y', quantity: 1, price: 1000, taxable: false)]);
    await DocumentService.recordPayment(documentId: id, amount: 400, paymentMethod: 'cash');
    final inv = (await db.getDocumentById(id))!;
    expect(inv.paid, 400);
    expect(inv.status, DocumentStatus.partiallyPaid);
    await DocumentService.recordPayment(documentId: id, amount: 600, paymentMethod: 'cash');
    expect((await db.getDocumentById(id))!.status, DocumentStatus.paid);
    expect(await db.getDocumentPayments(id), hasLength(2));
  });
}

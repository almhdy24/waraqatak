// Real SQLite (ffi) integration test for the quick-sale flow and payments.
// Runs on the host with the system libsqlite3.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/screens/quick_sale_screen.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Business business;
  late Product pen, repair;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getDatabasesPath();
    final f = File('$dir/warqatek_free.db');
    if (f.existsSync()) f.deleteSync();
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر',
        ownerName: 'أحمد',
        phone: '1',
        address: 'x',
        taxRate: 10,
        taxesEnabled: true,
      ),
    );
    business = (await db.getFirstBusiness())!;
    final penId = await ProductService.createProduct(
      name: 'قلم',
      salePrice: 500,
      stockQuantity: 5,
      barcode: '111',
    );
    final repId = await ProductService.createProduct(
      name: 'صيانة',
      salePrice: 1500,
      type: Product.typeService,
      isTaxable: false,
    );
    pen = (await db.getProductById(penId))!;
    repair = (await db.getProductById(repId))!;
  });

  test(
    'quick sale: paid invoice + receipt + payment method + stock, atomically',
    () async {
      final db = DatabaseHelper.instance;
      final method = (await db.getEnabledPaymentMethods()).first.key;
      final cart = PosCart()
        ..add(pen, quantity: 2)
        ..add(repair);
      cart.setTaxConfiguration(
        taxesEnabled: business.taxesEnabled,
        businessTaxRate: business.effectiveTaxRate,
      );
      cart.discount = 500;
      final t = cart.totals(
        taxRate: business.effectiveTaxRate,
        pricesIncludeTax: business.pricesIncludeTax,
      );

      final id = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: cart.toItemInputs(businessTaxRate: business.effectiveTaxRate),
        discount: cart.discount,
        date: DateTime.now(),
        payNowMethod: method,
      );

      final inv = (await db.getDocumentById(id))!;
      expect(inv.status, DocumentStatus.paid);
      expect(inv.total, closeTo(t.total, 0.001));
      expect(inv.paid, closeTo(inv.total, 0.001));
      expect(inv.remaining, 0);
      final payments = await db.getDocumentPayments(id);
      expect(payments, hasLength(1));
      expect(payments.single.paymentMethod, method);
      expect(payments.single.amount, closeTo(inv.total, 0.001));
      final receipts = (await db.getDocumentsByType(
        'payment_receipt',
      )).where((r) => r.relatedDocumentId == id);
      expect(receipts, hasLength(1));
      expect(receipts.single.paymentMethod, method);
      expect((await db.getProductById(pen.id!))!.stockQuantity, 3);
      expect(
        (await db.getStockMovements(
          pen.id!,
        )).where((m) => m.referenceDocumentId == id),
        hasLength(1),
      );
      expect(
        (await db.getProductById(repair.id!))!.stockQuantity,
        0,
        reason: 'services keep no stock',
      );
      // ignore: avoid_print
      print(
        'sale ${inv.documentNumber}: total=${inv.total} tax=${inv.taxAmount} status=${inv.status}',
      );
    },
  );

  test('insufficient stock rolls everything back', () async {
    final db = DatabaseHelper.instance;
    final before = (await db.getAllDocuments()).length;
    final freshPen = (await db.getProductById(pen.id!))!; // 3 left
    await expectLater(
      DocumentService.createDocument(
        type: 'invoice',
        business: business,
        date: DateTime.now(),
        payNowMethod: 'cash',
        items: [
          DocumentItemInput(
            description: 'قلم',
            quantity: 10,
            price: 500,
            productId: freshPen.id,
          ),
        ],
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await db.getAllDocuments()).length,
      before,
      reason: 'no invoice or receipt left behind',
    );
    expect((await db.getProductById(pen.id!))!.stockQuantity, 3);
  });

  test('payNowMethod is rejected for drafts / partial payments', () async {
    final items = [
      const DocumentItemInput(description: 'x', quantity: 1, price: 10),
    ];
    expect(
      () => DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: items,
        isDraft: true,
        payNowMethod: 'cash',
      ),
      throwsArgumentError,
    );
    expect(
      () => DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: items,
        paid: 5,
        payNowMethod: 'cash',
      ),
      throwsArgumentError,
    );
    expect(
      () => DocumentService.createDocument(
        type: 'quotation',
        business: business,
        items: items,
        payNowMethod: 'cash',
      ),
      throwsArgumentError,
    );
  });

  test('regular payment recording still works (refactor)', () async {
    final db = DatabaseHelper.instance;
    final id = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      date: DateTime.now(),
      items: [
        const DocumentItemInput(
          description: 'y',
          quantity: 1,
          price: 1000,
          taxable: false,
        ),
      ],
    );
    await DocumentService.recordPayment(
      documentId: id,
      amount: 400,
      paymentMethod: 'cash',
    );
    final inv = (await db.getDocumentById(id))!;
    expect(inv.paid, 400);
    expect(inv.status, DocumentStatus.partiallyPaid);
    await DocumentService.recordPayment(
      documentId: id,
      amount: 600,
      paymentMethod: 'cash',
    );
    expect((await db.getDocumentById(id))!.status, DocumentStatus.paid);
    expect(await db.getDocumentPayments(id), hasLength(2));
  });

  test(
    'quick sale with fractional quantities updates stock and persists exactly',
    () async {
      final db = DatabaseHelper.instance;
      final method = (await db.getEnabledPaymentMethods()).first.key;
      // pen has 3 left in stock from previous test
      final cart = PosCart()..add(pen, quantity: 1.25);

      final id = await DocumentService.createDocument(
        type: 'invoice',
        business: business.copyWith(taxesEnabled: false),
        items: cart.toItemInputs(),
        date: DateTime.now(),
        payNowMethod: method,
      );

      final inv = (await db.getDocumentById(id))!;
      expect(inv.status, DocumentStatus.paid);
      expect(inv.total, closeTo(625.0, 0.001)); // 1.25 * 500 = 625

      final items = await db.getDocumentItems(id);
      expect(items.single.quantity, 1.25);

      // Remaining stock: 3.0 - 1.25 = 1.75
      final updatedPen = (await db.getProductById(pen.id!))!;
      expect(updatedPen.stockQuantity, closeTo(1.75, 0.0001));

      final movements = (await db.getStockMovements(
        pen.id!,
      )).where((m) => m.referenceDocumentId == id);
      expect(movements, hasLength(1));
      expect(movements.single.quantity, closeTo(-1.25, 0.0001));
    },
  );

  test(
    'credit sale: partial payment with customer records upfront payment and remaining balance',
    () async {
      final db = DatabaseHelper.instance;
      final contactId = await db.insertContact(
        const Contact(
          name: 'العميل محمد',
          phone: '0912345678',
          type: 'customer',
        ),
      );
      final customer = (await db.getContactById(contactId))!;

      final bookId = await ProductService.createProduct(
        name: 'دفتر 1',
        salePrice: 500,
        stockQuantity: 100,
      );
      final book = (await db.getProductById(bookId))!;

      final cart = PosCart()..add(book, quantity: 1); // 500
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business.copyWith(taxesEnabled: false),
        items: cart.toItemInputs(),
        discount: 0,
        paid: 200, // partial payment
        date: DateTime.now(),
        paymentMethod: 'cash',
        contact: customer,
      );

      final inv = (await db.getDocumentById(docId))!;
      expect(inv.status, DocumentStatus.partiallyPaid);
      expect(inv.total, 500);
      expect(inv.paid, 200);
      expect(inv.remaining, 300);
      expect(inv.contactId, contactId);

      final payments = await db.getDocumentPayments(docId);
      expect(payments, hasLength(1));
      expect(payments.single.amount, 200);
      expect(payments.single.paymentMethod, 'cash');

      // Customer outstanding balance should be 300
      final outstanding = await db.getContactOutstanding(contactId, 'invoice');
      expect(outstanding, 300);
    },
  );

  test(
    'credit sale: zero payment with customer creates unpaid invoice',
    () async {
      final db = DatabaseHelper.instance;
      final contactId = await db.insertContact(
        const Contact(
          name: 'العميل علي',
          phone: '0998877665',
          type: 'customer',
        ),
      );
      final customer = (await db.getContactById(contactId))!;

      final bookId = await ProductService.createProduct(
        name: 'دفتر 2',
        salePrice: 500,
        stockQuantity: 100,
      );
      final book = (await db.getProductById(bookId))!;

      final cart = PosCart()..add(book, quantity: 1); // 500
      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: business.copyWith(taxesEnabled: false),
        items: cart.toItemInputs(),
        discount: 0,
        paid: 0, // zero payment (on account)
        date: DateTime.now(),
        contact: customer,
      );

      final inv = (await db.getDocumentById(docId))!;
      expect(inv.status, DocumentStatus.issued);
      expect(inv.total, 500);
      expect(inv.paid, 0);
      expect(inv.remaining, 500);
      expect(inv.contactId, contactId);

      final payments = await db.getDocumentPayments(docId);
      expect(payments, isEmpty);

      // Customer outstanding balance should be 500
      final outstanding = await db.getContactOutstanding(contactId, 'invoice');
      expect(outstanding, 500);
    },
  );

  group('Smart cash suggestions', () {
    test('exact amount is always first suggestion', () {
      final suggestions = QuickSaleScreen.computeCashSuggestions(
        total: 1250,
        decimalDigits: 0,
      );
      expect(suggestions.first, 1250);
    });

    test(
      'rounded denominations 500, 1000, 5000, 10000 are produced in order',
      () {
        final suggestions = QuickSaleScreen.computeCashSuggestions(
          total: 1250,
          decimalDigits: 0,
        );
        expect(suggestions, equals([1250.0, 1500.0, 2000.0, 5000.0]));
      },
    );

    test('duplicates are eliminated', () {
      final suggestions = QuickSaleScreen.computeCashSuggestions(
        total: 7500,
        decimalDigits: 0,
      );
      // next multiple of 500 is 8000, next of 1000 is 8000 (duplicate eliminated)
      // next multiple of 5000 is 10000, next of 10000 is 10000 (duplicate eliminated)
      expect(suggestions, equals([7500.0, 8000.0, 10000.0]));
      expect(suggestions.toSet().length, equals(suggestions.length));
    });

    test(
      'small totals with decimal digits use natural currency denominations',
      () {
        final suggestions = QuickSaleScreen.computeCashSuggestions(
          total: 15.5,
          decimalDigits: 2,
        );
        expect(suggestions.first, 15.5);
        expect(suggestions, equals([15.5, 16.0, 20.0, 50.0]));
      },
    );

    test('displays up to four suggestions maximum', () {
      final suggestions = QuickSaleScreen.computeCashSuggestions(
        total: 250,
        decimalDigits: 0,
      );
      expect(suggestions.length, lessThanOrEqualTo(4));
    });

    test('returns empty suggestions for zero or negative total', () {
      expect(
        QuickSaleScreen.computeCashSuggestions(total: 0, decimalDigits: 2),
        isEmpty,
      );
      expect(
        QuickSaleScreen.computeCashSuggestions(total: -50, decimalDigits: 2),
        isEmpty,
      );
    });
  });
}

// Real SQLite (ffi) integration test: payment lifecycle and cancellation integrity.
// Verifies that upfront payments on invoices/purchases are strictly preserved
// when subsequent receipts/vouchers are cancelled or deleted, repeated
// cancellations are safely rejected, and ledger double-counting is prevented.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Business business;
  late int sampleProductId;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('payment_cancellation_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'مؤسسة النزاهة المحاسبية',
        ownerName: 'فاطمة',
        phone: '0912345678',
        address: 'الخرطوم',
        taxRate: 0,
        currencyCode: 'SDG',
      ),
    );
    business = (await db.getFirstBusiness())!;

    sampleProductId = await ProductService.createProduct(
      name: 'بضاعة عامة',
      salePrice: 100,
      purchasePrice: 60,
      stockQuantity: 100,
    );
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    '1. Upfront down-payment on invoice is preserved when subsequent receipt is cancelled',
    () async {
      final db = DatabaseHelper.instance;

      // Create an invoice with total = 1000 and upfront payment = 300
      final invoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 10,
            price: 100,
            productId: sampleProductId,
          ),
        ],
        paid: 300,
      );

      var inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.total, 1000.0);
      expect(inv.paid, 300.0);
      expect(inv.remaining, 700.0);
      expect(inv.status, DocumentStatus.partiallyPaid);

      // Record an additional payment of 400 with a payment receipt
      final receiptId = await DocumentService.recordPayment(
        documentId: invoiceId,
        amount: 400,
        paymentMethod: 'cash',
      );

      inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.paid, 700.0);
      expect(inv.remaining, 300.0);
      expect(inv.status, DocumentStatus.partiallyPaid);

      // Cancel the payment receipt: invoice paid must return to 300, NOT 0!
      await DocumentService.cancelDocument(receiptId);

      inv = (await db.getDocumentById(invoiceId))!;
      expect(
        inv.paid,
        300.0,
        reason:
            'Upfront payment of 300 must be preserved when receipt is cancelled',
      );
      expect(inv.remaining, 700.0);
      expect(inv.status, DocumentStatus.partiallyPaid);
    },
  );

  test(
    '2. Repeated cancellation of already-cancelled payment receipt is rejected and does not double-reverse',
    () async {
      final db = DatabaseHelper.instance;

      final invoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 5,
            price: 100,
            productId: sampleProductId,
          ),
        ],
        paid: 100,
      );

      final receiptId = await DocumentService.recordPayment(
        documentId: invoiceId,
        amount: 200,
        paymentMethod: 'bank',
      );

      var inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.paid, 300.0);

      // First cancellation succeeds
      await DocumentService.cancelDocument(receiptId);
      inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.paid, 100.0);

      // Second cancellation must throw StateError and leave paid at 100
      await expectLater(
        () => DocumentService.cancelDocument(receiptId),
        throwsA(isA<StateError>()),
      );

      inv = (await db.getDocumentById(invoiceId))!;
      expect(
        inv.paid,
        100.0,
        reason:
            'Repeated cancellation must not double-reverse invoice paid amount',
      );
    },
  );

  test(
    '3. Deleting an already-cancelled receipt does not double-reverse invoice paid amount',
    () async {
      final db = DatabaseHelper.instance;

      final invoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 5,
            price: 100,
            productId: sampleProductId,
          ),
        ],
        paid: 200,
      );

      final receiptId = await DocumentService.recordPayment(
        documentId: invoiceId,
        amount: 150,
        paymentMethod: 'cash',
      );

      // Cancel receipt: paid goes from 350 to 200
      await DocumentService.cancelDocument(receiptId);
      var inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.paid, 200.0);

      // Delete the cancelled receipt: paid must remain 200
      await db.deleteDocument(receiptId);

      inv = (await db.getDocumentById(invoiceId))!;
      expect(
        inv.paid,
        200.0,
        reason:
            'Deleting a cancelled receipt must not reverse invoice paid amount again',
      );
    },
  );

  test(
    '4. Deleting an active (non-cancelled) payment receipt reverses only receipt amount and preserves upfront payment',
    () async {
      final db = DatabaseHelper.instance;

      final invoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 4,
            price: 100,
            productId: sampleProductId,
          ),
        ],
        paid: 100,
      );

      final receiptId = await DocumentService.recordPayment(
        documentId: invoiceId,
        amount: 200,
        paymentMethod: 'cash',
      );

      var inv = (await db.getDocumentById(invoiceId))!;
      expect(inv.paid, 300.0);

      // Delete the active receipt directly
      await db.deleteDocument(receiptId);

      inv = (await db.getDocumentById(invoiceId))!;
      expect(
        inv.paid,
        100.0,
        reason:
            'Deleting active receipt must reverse its 200 and keep initial 100',
      );
      expect(inv.remaining, 300.0);
    },
  );

  test(
    '5. Upfront purchase payment is preserved when subsequent expense voucher is cancelled',
    () async {
      final db = DatabaseHelper.instance;

      // Create purchase with total = 600, paid = 200 upfront
      final purchaseId = await DocumentService.createDocument(
        type: 'purchase',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 10,
            price: 60,
            productId: sampleProductId,
          ),
        ],
        paid: 200,
      );

      var pur = (await db.getDocumentById(purchaseId))!;
      expect(pur.total, 600.0);
      expect(pur.paid, 200.0);
      expect(pur.remaining, 400.0);

      // Add additional payment of 300 via expense voucher
      final voucherId = await DocumentService.recordPayment(
        documentId: purchaseId,
        amount: 300,
        paymentMethod: 'bank',
      );

      pur = (await db.getDocumentById(purchaseId))!;
      expect(pur.paid, 500.0);
      expect(pur.remaining, 100.0);

      // Cancel expense voucher: paid must return to 200
      await DocumentService.cancelDocument(voucherId);

      pur = (await db.getDocumentById(purchaseId))!;
      expect(
        pur.paid,
        200.0,
        reason:
            'Upfront purchase payment must be preserved when voucher is cancelled',
      );
      expect(pur.remaining, 400.0);
    },
  );

  test(
    '6. Newly created invoice with upfront payment registers payment row without double-counting in ledger',
    () async {
      final db = DatabaseHelper.instance;

      final invoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'بضاعة عامة',
            quantity: 2,
            price: 100,
            productId: sampleProductId,
          ),
        ],
        paid: 150,
        paymentMethod: 'cash',
      );

      // Verify document_payments table has the initial payment recorded
      final payments = await db.getDocumentPayments(invoiceId);
      expect(payments, hasLength(1));
      expect(payments.first.amount, 150.0);
      expect(payments.first.receiptDocumentId, isNull);

      // Verify derived double-entry ledger is mathematically balanced and has correct receivables settlement
      final book = await LedgerService.load();
      final trial = AccountingReports.trialBalance(book.entries);
      expect(trial.isBalanced, isTrue);

      // Verify invoice payment journal entry posts exactly 150 (not 300)
      final paymentEntries = book.entries
          .where(
            (e) =>
                e.documentId == invoiceId && e.source.name == 'invoicePayment',
          )
          .toList();
      expect(paymentEntries, hasLength(1));
      expect(paymentEntries.first.totalDebit, 150.0);
    },
  );
}

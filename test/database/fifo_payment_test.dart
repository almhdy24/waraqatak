import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/payment_allocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('fifo_payment_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('FIFO Payment Allocation Database Integration Tests (Linux CI)', () {
    test(
      '1. FIFO payment across 3 invoices (100, 200, 300) with amount 250 -> 2 receipts (100, 150)',
      () async {
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.closeDatabase();
        final dbFile = File('${tempDir.path}/fifo_test_1.db');
        if (dbFile.existsSync()) dbFile.deleteSync();

        final biz = const Business(
          name: 'Test Business',
          ownerName: 'Owner',
          phone: '0123456789',
          address: 'Khartoum',
          currencyCode: 'SDG',
        );
        await dbHelper.insertBusiness(biz);

        final customerId = await dbHelper.insertContact(
          const Contact(name: 'Customer A', type: 'customer'),
        );

        // Create 3 invoices: 100, 200, 300
        final inv1Id = await dbHelper.insertDocumentWithItems(
          Document(
            type: 'invoice',
            documentNumber: 'INV-001',
            date: DateTime(2026, 1, 1),
            contactId: customerId,
            subtotal: 100.0,
            discount: 0.0,
            taxRate: 0.0,
            taxAmount: 0.0,
            total: 100.0,
            paid: 0.0,
            remaining: 100.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG',
          ),
          [
            const DocumentItem(
              documentId: 0,
              description: 'Item 1',
              quantity: 1,
              price: 100.0,
              total: 100.0,
            ),
          ],
        );

        final inv2Id = await dbHelper.insertDocumentWithItems(
          Document(
            type: 'invoice',
            documentNumber: 'INV-002',
            date: DateTime(2026, 1, 2),
            contactId: customerId,
            subtotal: 200.0,
            discount: 0.0,
            taxRate: 0.0,
            taxAmount: 0.0,
            total: 200.0,
            paid: 0.0,
            remaining: 200.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG',
          ),
          [
            const DocumentItem(
              documentId: 0,
              description: 'Item 2',
              quantity: 1,
              price: 200.0,
              total: 200.0,
            ),
          ],
        );

        final inv3Id = await dbHelper.insertDocumentWithItems(
          Document(
            type: 'invoice',
            documentNumber: 'INV-003',
            date: DateTime(2026, 1, 3),
            contactId: customerId,
            subtotal: 300.0,
            discount: 0.0,
            taxRate: 0.0,
            taxAmount: 0.0,
            total: 300.0,
            paid: 0.0,
            remaining: 300.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG',
          ),
          [
            const DocumentItem(
              documentId: 0,
              description: 'Item 3',
              quantity: 1,
              price: 300.0,
              total: 300.0,
            ),
          ],
        );

        // Record FIFO payment of 250
        final receiptIds = await dbHelper.recordFifoPayment(
          contactId: customerId,
          documentType: 'invoice',
          amount: 250.0,
          paymentMethod: 'cash',
        );

        expect(receiptIds.length, equals(2));

        // Check invoice 1 (fully paid)
        final inv1 = await dbHelper.getDocumentById(inv1Id);
        expect(inv1?.paid, equals(100.0));
        expect(inv1?.remaining, equals(0.0));
        expect(inv1?.status, equals(DocumentStatus.paid));

        // Check invoice 2 (partially paid 150/200)
        final inv2 = await dbHelper.getDocumentById(inv2Id);
        expect(inv2?.paid, equals(150.0));
        expect(inv2?.remaining, equals(50.0));
        expect(inv2?.status, equals(DocumentStatus.partiallyPaid));

        // Check invoice 3 (untouched)
        final inv3 = await dbHelper.getDocumentById(inv3Id);
        expect(inv3?.paid, equals(0.0));
        expect(inv3?.remaining, equals(300.0));
        expect(inv3?.status, equals(DocumentStatus.issued));

        // Check receipts
        final rec1 = await dbHelper.getDocumentById(receiptIds[0]);
        expect(rec1?.total, equals(100.0));
        expect(rec1?.relatedDocumentId, equals(inv1Id));

        final rec2 = await dbHelper.getDocumentById(receiptIds[1]);
        expect(rec2?.total, equals(150.0));
        expect(rec2?.relatedDocumentId, equals(inv2Id));
      },
    );

    test(
      '2. Overpayment rejection throws PaymentAllocationException',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final customerId = await dbHelper.insertContact(
          const Contact(name: 'Customer B', type: 'customer'),
        );

        await dbHelper.insertDocumentWithItems(
          Document(
            type: 'invoice',
            documentNumber: 'INV-B1',
            date: DateTime(2026, 1, 1),
            contactId: customerId,
            subtotal: 100.0,
            discount: 0.0,
            taxRate: 0.0,
            taxAmount: 0.0,
            total: 100.0,
            paid: 0.0,
            remaining: 100.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG',
          ),
          [
            const DocumentItem(
              documentId: 0,
              description: 'Item',
              quantity: 1,
              price: 100.0,
              total: 100.0,
            ),
          ],
        );

        expect(
          () => dbHelper.recordFifoPayment(
            contactId: customerId,
            documentType: 'invoice',
            amount: 101.0,
          ),
          throwsA(isA<PaymentAllocationException>()),
        );
      },
    );

    test('3. Supplier purchases FIFO allocation works identically', () async {
      final dbHelper = DatabaseHelper.instance;
      final supplierId = await dbHelper.insertContact(
        const Contact(name: 'Supplier A', type: 'supplier'),
      );

      final pur1Id = await dbHelper.insertDocumentWithItems(
        Document(
          type: 'purchase',
          documentNumber: 'PUR-001',
          date: DateTime(2026, 1, 1),
          contactId: supplierId,
          subtotal: 150.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 150.0,
          paid: 0.0,
          remaining: 150.0,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
        [
          const DocumentItem(
            documentId: 0,
            description: 'Item P1',
            quantity: 1,
            price: 150.0,
            total: 150.0,
          ),
        ],
      );

      final pur2Id = await dbHelper.insertDocumentWithItems(
        Document(
          type: 'purchase',
          documentNumber: 'PUR-002',
          date: DateTime(2026, 1, 2),
          contactId: supplierId,
          subtotal: 250.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 250.0,
          paid: 0.0,
          remaining: 250.0,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
        [
          const DocumentItem(
            documentId: 0,
            description: 'Item P2',
            quantity: 1,
            price: 250.0,
            total: 250.0,
          ),
        ],
      );

      final voucherIds = await dbHelper.recordFifoPayment(
        contactId: supplierId,
        documentType: 'purchase',
        amount: 200.0,
        paymentMethod: 'cash',
      );

      expect(voucherIds.length, equals(2));

      final pur1 = await dbHelper.getDocumentById(pur1Id);
      expect(pur1?.paid, equals(150.0));
      expect(pur1?.remaining, equals(0.0));
      expect(pur1?.status, equals(DocumentStatus.paid));

      final pur2 = await dbHelper.getDocumentById(pur2Id);
      expect(pur2?.paid, equals(50.0));
      expect(pur2?.remaining, equals(200.0));
      expect(pur2?.status, equals(DocumentStatus.partiallyPaid));
    });

    test(
      '4. Cancellation reversal reverts only that receipt allocation',
      () async {
        final dbHelper = DatabaseHelper.instance;
        final customerId = await dbHelper.insertContact(
          const Contact(name: 'Customer C', type: 'customer'),
        );

        final invId = await dbHelper.insertDocumentWithItems(
          Document(
            type: 'invoice',
            documentNumber: 'INV-C1',
            date: DateTime(2026, 1, 1),
            contactId: customerId,
            subtotal: 300.0,
            discount: 0.0,
            taxRate: 0.0,
            taxAmount: 0.0,
            total: 300.0,
            paid: 0.0,
            remaining: 300.0,
            status: DocumentStatus.issued,
            currencyCode: 'SDG',
          ),
          [
            const DocumentItem(
              documentId: 0,
              description: 'Item',
              quantity: 1,
              price: 300.0,
              total: 300.0,
            ),
          ],
        );

        final receiptIds = await dbHelper.recordFifoPayment(
          contactId: customerId,
          documentType: 'invoice',
          amount: 200.0,
        );
        expect(receiptIds.length, equals(1));

        var inv = await dbHelper.getDocumentById(invId);
        expect(inv?.paid, equals(200.0));
        expect(inv?.remaining, equals(100.0));

        // Cancel the receipt
        await dbHelper.cancelDocument(receiptIds.first);

        inv = await dbHelper.getDocumentById(invId);
        expect(inv?.paid, equals(0.0));
        expect(inv?.remaining, equals(300.0));
      },
    );

    test('5. Standalone vouchers without contact persist cleanly', () async {
      final dbHelper = DatabaseHelper.instance;
      final docId = await dbHelper.insertDocumentWithItems(
        Document(
          type: 'expense_voucher',
          documentNumber: 'EXP-RAW-001',
          date: DateTime(2026, 1, 1),
          contactId: null,
          subtotal: 50.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 50.0,
          paid: 50.0,
          remaining: 0.0,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
        const [],
      );

      final doc = await dbHelper.getDocumentById(docId);
      expect(doc, isNotNull);
      expect(doc?.contactId, isNull);
      expect(doc?.total, equals(50.0));
    });

    test('6. Closed period lock rejects payment recording', () async {
      final dbHelper = DatabaseHelper.instance;
      final customerId = await dbHelper.insertContact(
        const Contact(name: 'Customer D', type: 'customer'),
      );

      await dbHelper.insertDocumentWithItems(
        Document(
          type: 'invoice',
          documentNumber: 'INV-D1',
          date: DateTime(2026, 1, 1),
          contactId: customerId,
          subtotal: 100.0,
          discount: 0.0,
          taxRate: 0.0,
          taxAmount: 0.0,
          total: 100.0,
          paid: 0.0,
          remaining: 100.0,
          status: DocumentStatus.issued,
          currencyCode: 'SDG',
        ),
        [
          const DocumentItem(
            documentId: 0,
            description: 'Item',
            quantity: 1,
            price: 100.0,
            total: 100.0,
          ),
        ],
      );

      // Lock accounting period through the future
      await dbHelper.setBooksClosedThrough(DateTime(2030, 1, 1));

      expect(
        () => dbHelper.recordFifoPayment(
          contactId: customerId,
          documentType: 'invoice',
          amount: 50.0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

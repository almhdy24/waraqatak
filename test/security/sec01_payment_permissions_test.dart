import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_payment.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/access/access_admin_service.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/audit_service.dart';
import 'package:warqatek/services/access/auth_service.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/document_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Database db;
  late AppUser ownerUser;
  late AppUser authorizedUser;
  late AppUser unauthorizedUser;
  late Business testBusiness;
  late Contact testCustomer;
  late int openInvoiceId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('sec01_perm_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AuditService.instance.setTestingDeviceId('test-device-sec01');
    AuthService.useCompute = false;
    AuthService.testingIterations = 50;
    SessionManager.enableInactivityTimer = false;
  });

  tearDownAll(() async {
    SessionManager.enableInactivityTimer = true;
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    AuthService.resetDeviceThrottle();
    SessionManager.instance.resetForTesting();
    await DatabaseHelper.instance.closeDatabase();

    final runDir = Directory.systemTemp.createTempSync('sec01_run_');
    await databaseFactory.setDatabasesPath(runDir.path);
    db = await DatabaseHelper.instance.database;

    ownerUser = AppUser(
      id: AccessDao.ownerUserId,
      workspaceId: AccessDao.defaultWorkspaceId,
      username: 'owner',
      displayName: 'Owner User',
      roleId: AccessDao.ownerRoleId,
      isOwner: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create a role WITH paymentsRecord
    final authorizedRole = await AccessAdminService.instance.createRole(
      name: 'Authorized Role',
      permissions: {
        PermissionRegistry.salesView,
        PermissionRegistry.salesCreate,
        PermissionRegistry.paymentsRecord,
      },
      actor: ownerUser,
      db: db,
    );

    // Create a role WITHOUT paymentsRecord (sales/purchase/vouchers only)
    final unauthorizedRole = await AccessAdminService.instance.createRole(
      name: 'Unauthorized Role',
      permissions: {
        PermissionRegistry.salesView,
        PermissionRegistry.salesCreate,
        PermissionRegistry.purchasesView,
        PermissionRegistry.purchasesCreate,
        PermissionRegistry.vouchersCreate,
        PermissionRegistry.salesCancel,
      },
      actor: ownerUser,
      db: db,
    );

    authorizedUser = await AccessAdminService.instance.createUser(
      username: 'auth_user',
      displayName: 'Authorized User',
      roleId: authorizedRole.id,
      password: 'Password123!',
      actor: ownerUser,
      db: db,
    );

    unauthorizedUser = await AccessAdminService.instance.createUser(
      username: 'unauth_user',
      displayName: 'Unauthorized User',
      roleId: unauthorizedRole.id,
      password: 'Password123!',
      actor: ownerUser,
      db: db,
    );

    // Setup base business and contact as system
    await AccessGuard.runAsSystem(() async {
      await DatabaseHelper.instance.insertBusiness(
        const Business(
          name: 'Test Business',
          ownerName: 'Test Owner',
          phone: '123456789',
          address: 'Khartoum',
          currencyCode: 'SDG',
        ),
      );
      testBusiness = (await DatabaseHelper.instance.getFirstBusiness())!;

      final custId = await DatabaseHelper.instance.insertContact(
        const Contact(name: 'Test Customer', type: 'customer'),
      );
      testCustomer = (await DatabaseHelper.instance.getContactById(custId))!;

      // Create an issued invoice with balance 1000 SDG
      openInvoiceId = await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        contact: testCustomer,
        items: [
          DocumentItemInput(
            description: 'Item 1',
            quantity: 1,
            price: 1000,
            taxable: false,
          ),
        ],
        paid: 0,
        paymentMethod: 'cash',
      );
    });

    // Enable multi-user mode
    await db.rawInsert('''
      INSERT INTO app_settings (key, value) VALUES ('multi_user_enabled', '1')
      ON CONFLICT(key) DO UPDATE SET value = '1'
    ''');
    SessionManager.instance.resetForTesting();
    await SessionManager.instance.init();
  });

  tearDown(() async {
    SessionManager.instance.resetForTesting();
    await DatabaseHelper.instance.closeDatabase();
  });

  group('SEC-01: Payment Permission Enforcement', () {
    test(
      'Unauthorized user without paymentsRecord cannot record payment through exposed entry points',
      () async {
        // Set unauthorized user session
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
          PermissionRegistry.vouchersCreate,
          PermissionRegistry.salesCancel,
        });
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        // Snapshot initial state
        final initialPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments',
        );
        final initialPaymentCount = initialPayments.first['count'] as int;

        final docBefore = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(docBefore.paid, 0.0);
        expect(docBefore.remaining, 1000.0);

        // 1. DatabaseHelper.recordPayment
        expect(
          () => DatabaseHelper.instance.recordPayment(
            documentId: openInvoiceId,
            amount: 100,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 2. DatabaseHelper.recordPaymentWithReceipt
        expect(
          () => DatabaseHelper.instance.recordPaymentWithReceipt(
            documentId: openInvoiceId,
            amount: 100,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 3. DatabaseHelper.recordFifoPayment
        expect(
          () => DatabaseHelper.instance.recordFifoPayment(
            contactId: testCustomer.id!,
            documentType: 'invoice',
            amount: 100,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 4. DocumentService.recordPayment
        expect(
          () => DocumentService.recordPayment(
            documentId: openInvoiceId,
            amount: 100,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 5. DocumentService.recordFifoPayment
        expect(
          () => DocumentService.recordFifoPayment(
            contactId: testCustomer.id!,
            isCustomer: true,
            amount: 100,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Transactional consistency: database remains completely untouched
        final finalPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments',
        );
        expect(finalPayments.first['count'], initialPaymentCount);

        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(docAfter.paid, 0.0);
        expect(docAfter.remaining, 1000.0);
        expect(docAfter.status, DocumentStatus.issued);
      },
    );

    test(
      'Authorized user with paymentsRecord can record payments successfully',
      () async {
        SessionManager.instance.setSession(authorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.paymentsRecord,
        });
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isTrue);

        final receiptId = await DocumentService.recordPayment(
          documentId: openInvoiceId,
          amount: 250,
          paymentMethod: 'cash',
        );
        expect(receiptId, isPositive);

        final doc = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(doc.paid, 250.0);
        expect(doc.remaining, 750.0);
        expect(doc.status, DocumentStatus.partiallyPaid);
      },
    );

    test(
      'Existing upfront payment workflows remain functional for sales/purchase users',
      () async {
        // User with salesCreate but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
          PermissionRegistry.vouchersCreate,
          PermissionRegistry.salesCancel,
        });
        expect(AccessGuard.can(PermissionRegistry.salesCreate), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        // Invoice with upfront payment
        final invoiceId = await DocumentService.createDocument(
          type: 'invoice',
          business: testBusiness,
          contact: testCustomer,
          items: [
            DocumentItemInput(
              description: 'Item A',
              quantity: 1,
              price: 500,
              taxable: false,
            ),
          ],
          paid: 200,
          paymentMethod: 'cash',
        );
        expect(invoiceId, isPositive);

        final inv = (await DatabaseHelper.instance.getDocumentById(invoiceId))!;
        expect(inv.paid, 200.0);
        expect(inv.remaining, 300.0);

        // Purchase with upfront payment (has purchasesCreate, no paymentsRecord)
        expect(AccessGuard.can(PermissionRegistry.purchasesCreate), isTrue);
        final supplier = Contact(name: 'Supplier X', type: 'supplier');
        final purchaseId = await DocumentService.createDocument(
          type: 'purchase',
          business: testBusiness,
          contact: supplier,
          items: [
            DocumentItemInput(
              description: 'Raw Materials',
              quantity: 10,
              price: 50,
              taxable: false,
            ),
          ],
          paid: 500,
          paymentMethod: 'cash',
        );
        expect(purchaseId, isPositive);

        final pur = (await DatabaseHelper.instance.getDocumentById(
          purchaseId,
        ))!;
        expect(pur.paid, 500.0);
        expect(pur.remaining, 0.0);
        expect(pur.status, DocumentStatus.paid);
      },
    );

    test(
      'Unauthorized issuance of a draft invoice with an upfront payment is rejected',
      () async {
        // Create a draft invoice with upfront payment as system
        int draftInvoiceId = 0;
        await AccessGuard.runAsSystem(() async {
          draftInvoiceId = await DocumentService.createDocument(
            type: 'invoice',
            business: testBusiness,
            contact: testCustomer,
            items: [
              DocumentItemInput(
                description: 'Draft Item',
                quantity: 1,
                price: 1000,
                taxable: false,
              ),
            ],
            paid: 400,
            paymentMethod: 'cash',
            isDraft: true,
          );
        });

        // unauthorizedUser has salesCreate but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
          PermissionRegistry.vouchersCreate,
          PermissionRegistry.salesCancel,
        });
        expect(AccessGuard.can(PermissionRegistry.salesCreate), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        final initialPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments WHERE document_id = ?',
          [draftInvoiceId],
        );
        expect(initialPayments.first['count'], 0);

        // 1. DocumentService.issueDocument must throw PermissionDeniedException
        expect(
          () => DocumentService.issueDocument(draftInvoiceId),
          throwsA(isA<PermissionDeniedException>()),
        );

        // 2. Direct DatabaseHelper.instance.issueDocument must throw PermissionDeniedException
        expect(
          () => DatabaseHelper.instance.issueDocument(draftInvoiceId),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Verify no mutation: document is still draft, no payment rows created
        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          draftInvoiceId,
        ))!;
        expect(docAfter.status, DocumentStatus.draft);

        final finalPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments WHERE document_id = ?',
          [draftInvoiceId],
        );
        expect(finalPayments.first['count'], 0);
      },
    );

    test(
      'Unauthorized issuance of a draft purchase with an upfront payment is rejected',
      () async {
        int draftPurchaseId = 0;
        await AccessGuard.runAsSystem(() async {
          final supplier = Contact(name: 'Draft Supplier', type: 'supplier');
          draftPurchaseId = await DocumentService.createDocument(
            type: 'purchase',
            business: testBusiness,
            contact: supplier,
            items: [
              DocumentItemInput(
                description: 'Draft Purchase Item',
                quantity: 5,
                price: 100,
                taxable: false,
              ),
            ],
            paid: 250,
            paymentMethod: 'cash',
            isDraft: true,
          );
        });

        // unauthorizedUser has purchasesCreate but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.purchasesView,
          PermissionRegistry.purchasesCreate,
        });
        expect(AccessGuard.can(PermissionRegistry.purchasesCreate), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        // DocumentService.issueDocument must reject
        expect(
          () => DocumentService.issueDocument(draftPurchaseId),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Direct DatabaseHelper.instance.issueDocument must reject
        expect(
          () => DatabaseHelper.instance.issueDocument(draftPurchaseId),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Verify status remains draft
        final purchaseAfter = (await DatabaseHelper.instance.getDocumentById(
          draftPurchaseId,
        ))!;
        expect(purchaseAfter.status, DocumentStatus.draft);

        final finalPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments WHERE document_id = ?',
          [draftPurchaseId],
        );
        expect(finalPayments.first['count'], 0);
      },
    );

    test(
      'Authorized issuance of draft invoice with upfront payment succeeds',
      () async {
        int draftInvoiceId = 0;
        await AccessGuard.runAsSystem(() async {
          draftInvoiceId = await DocumentService.createDocument(
            type: 'invoice',
            business: testBusiness,
            contact: testCustomer,
            items: [
              DocumentItemInput(
                description: 'Authorized Item',
                quantity: 1,
                price: 800,
                taxable: false,
              ),
            ],
            paid: 300,
            paymentMethod: 'cash',
            isDraft: true,
          );
        });

        // authorizedUser has salesCreate AND paymentsRecord
        SessionManager.instance.setSession(authorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
          PermissionRegistry.paymentsRecord,
        });
        expect(AccessGuard.can(PermissionRegistry.salesCreate), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isTrue);

        await DocumentService.issueDocument(draftInvoiceId);

        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          draftInvoiceId,
        ))!;
        expect(docAfter.status, DocumentStatus.partiallyPaid);
        expect(docAfter.paid, 300.0);
        expect(docAfter.remaining, 500.0);

        final payments = await db.rawQuery(
          'SELECT * FROM document_payments WHERE document_id = ?',
          [draftInvoiceId],
        );
        expect(payments.length, 1);
        expect(payments.first['amount'], 300.0);
        expect(payments.first['payment_origin'], PaymentOrigin.upfront);
      },
    );

    test(
      'Issuing draft invoice without payment (paid == 0) succeeds for salesCreate user without paymentsRecord',
      () async {
        int zeroPaidDraftId = 0;
        await AccessGuard.runAsSystem(() async {
          zeroPaidDraftId = await DocumentService.createDocument(
            type: 'invoice',
            business: testBusiness,
            contact: testCustomer,
            items: [
              DocumentItemInput(
                description: 'Unpaid Item',
                quantity: 1,
                price: 600,
                taxable: false,
              ),
            ],
            paid: 0,
            isDraft: true,
          );
        });

        // unauthorizedUser has salesCreate but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesCreate,
        });

        await DocumentService.issueDocument(zeroPaidDraftId);

        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          zeroPaidDraftId,
        ))!;
        expect(docAfter.status, DocumentStatus.issued);
        expect(docAfter.paid, 0.0);
        expect(docAfter.remaining, 600.0);
      },
    );

    test(
      'Unauthorized change to doc.paid via updateDocumentWithItems is rejected while preserving payment state',
      () async {
        // User with salesView and salesEdit, but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesEdit,
        });
        expect(AccessGuard.can(PermissionRegistry.salesEdit), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        final docBefore = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        final itemsBefore = await DatabaseHelper.instance.getDocumentItems(
          openInvoiceId,
        );
        expect(docBefore.paid, 0.0);
        expect(docBefore.remaining, 1000.0);
        expect(docBefore.status, DocumentStatus.issued);

        final initialPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments WHERE document_id = ?',
          [openInvoiceId],
        );
        expect(initialPayments.first['count'], 0);

        // Attempt to alter paid amount from 0.0 to 300.0 without paymentsRecord
        final modifiedDoc = docBefore.copyWith(paid: 300.0, remaining: 700.0);

        expect(
          () => DatabaseHelper.instance.updateDocumentWithItems(
            modifiedDoc,
            itemsBefore,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Document values and payment rows MUST remain unchanged
        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(docAfter.paid, 0.0);
        expect(docAfter.remaining, 1000.0);
        expect(docAfter.status, DocumentStatus.issued);

        final finalPayments = await db.rawQuery(
          'SELECT COUNT(*) as count FROM document_payments WHERE document_id = ?',
          [openInvoiceId],
        );
        expect(finalPayments.first['count'], 0);
      },
    );

    test(
      'Editing item descriptions and prices without changing doc.paid succeeds under salesEdit without paymentsRecord',
      () async {
        // User with salesView and salesEdit, but NOT paymentsRecord
        SessionManager.instance.setSession(unauthorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesEdit,
        });
        expect(AccessGuard.can(PermissionRegistry.salesEdit), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isFalse);

        final docBefore = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        final itemsBefore = await DatabaseHelper.instance.getDocumentItems(
          openInvoiceId,
        );

        // Revise line item description and price; total changes from 1000 to 1200, but paid remains 0.0
        final oldItem = itemsBefore.first;
        final revisedItems = [
          DocumentItem(
            id: oldItem.id,
            documentId: oldItem.documentId,
            productId: oldItem.productId,
            description: 'Item 1 Revised Description',
            quantity: oldItem.quantity,
            price: 1200.0,
            total: 1200.0,
            taxable: oldItem.taxable,
          ),
        ];
        final revisedDoc = docBefore.copyWith(
          subtotal: 1200.0,
          total: 1200.0,
          remaining: 1200.0,
          paid: 0.0, // paid amount unchanged
        );

        await DatabaseHelper.instance.updateDocumentWithItems(
          revisedDoc,
          revisedItems,
        );

        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(docAfter.total, 1200.0);
        expect(docAfter.paid, 0.0);
        expect(docAfter.remaining, 1200.0);

        final itemsAfter = await DatabaseHelper.instance.getDocumentItems(
          openInvoiceId,
        );
        expect(itemsAfter.first.description, 'Item 1 Revised Description');
        expect(itemsAfter.first.price, 1200.0);
      },
    );

    test(
      'Authorized change to doc.paid succeeds for user with salesEdit AND paymentsRecord',
      () async {
        // User with salesView, salesEdit, AND paymentsRecord
        SessionManager.instance.setSession(authorizedUser, {
          PermissionRegistry.salesView,
          PermissionRegistry.salesEdit,
          PermissionRegistry.paymentsRecord,
        });
        expect(AccessGuard.can(PermissionRegistry.salesEdit), isTrue);
        expect(AccessGuard.can(PermissionRegistry.paymentsRecord), isTrue);

        final docBefore = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        final itemsBefore = await DatabaseHelper.instance.getDocumentItems(
          openInvoiceId,
        );

        final updatedDoc = docBefore.copyWith(
          paid: 400.0,
          remaining: docBefore.total - 400.0,
        );

        await DatabaseHelper.instance.updateDocumentWithItems(
          updatedDoc,
          itemsBefore,
        );

        final docAfter = (await DatabaseHelper.instance.getDocumentById(
          openInvoiceId,
        ))!;
        expect(docAfter.paid, 400.0);
        expect(docAfter.remaining, docBefore.total - 400.0);
        expect(docAfter.status, DocumentStatus.partiallyPaid);

        final payments = await db.rawQuery(
          'SELECT * FROM document_payments WHERE document_id = ?',
          [openInvoiceId],
        );
        expect(payments.isNotEmpty, isTrue);
        expect(payments.first['amount'], 400.0);
      },
    );
  });
}

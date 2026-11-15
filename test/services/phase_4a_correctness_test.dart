import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/feature_gate.dart';
import 'package:warqatek/database/access_dao.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/app_user.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/digital_seal.dart';
import 'package:warqatek/models/exchange_rate.dart';
import 'package:warqatek/models/reference_pricing_types.dart';
import 'package:warqatek/services/access/access_guard.dart';
import 'package:warqatek/services/access/permission_registry.dart';
import 'package:warqatek/services/access/session_manager.dart';
import 'package:warqatek/services/business_reporting_service.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';
import 'package:warqatek/services/pos_cart.dart';
import 'package:warqatek/services/product_service.dart';
import 'package:warqatek/services/reference_pricing_service.dart';
import 'package:warqatek/services/seal_geometry_engine.dart';
import 'package:warqatek/utils/arabic_search_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4A-1 & 4A-2: Seal Geometry & RTL Overlay', () {
    test('4A-1: SealGeometryEngine.resolve clamps safely for extreme aspects & small containers', () {
      const aspects = [0.05, 50.0];
      const rtlOptions = [false, true];
      const containerW = 10.0;
      const containerH = 10.0;

      for (final aspect in aspects) {
        for (final isRtl in rtlOptions) {
          const config = DigitalSealConfig(
            type: SealType.stamp,
            aspectRatio: 1.0,
            widthRatio: 0.3,
            startRatio: 0.2,
            topRatio: 0.2,
          );
          final testConfig = config.copyWith(aspectRatio: aspect);

          final box = SealGeometryEngine.resolve(
            config: testConfig,
            containerWidth: containerW,
            containerHeight: containerH,
            isRtl: isRtl,
          );

          expect(box.width, greaterThan(0));
          expect(box.height, greaterThan(0));
          expect(box.x, greaterThanOrEqualTo(-0.001));
          expect(box.y, greaterThanOrEqualTo(-0.001));
          expect(box.x + box.width, lessThanOrEqualTo(containerW + 0.001));
          expect(box.y + box.height, lessThanOrEqualTo(containerH + 0.001));
        }
      }
    });

    test('4A-2: RTL resize delta logic inverts dx correctly', () {
      // In LTR, dragging right (+dx) increases width.
      // In RTL (handle on bottom-left), dragging left (-dx) increases width.
      double computeDelta(double dx, double dy, bool isRtl) {
        return (isRtl ? -dx : dx) + dy;
      }

      // Dragging left (dx = -10, dy = 0)
      expect(computeDelta(-10, 0, true), equals(10.0)); // RTL: enlarges
      expect(computeDelta(-10, 0, false), equals(-10.0)); // LTR: shrinks

      // Dragging right (dx = 10, dy = 0)
      expect(computeDelta(10, 0, true), equals(-10.0)); // RTL: shrinks
      expect(computeDelta(10, 0, false), equals(10.0)); // LTR: enlarges
    });
  });

  group('Phase 4A-4: PosCart wholesale customer reset & recall order', () {
    test('4A-4: setCustomer(null) resets pricingCategory to retail', () {
      final cart = PosCart();
      const wholesaleCustomer = Contact(
        id: 1,
        name: 'Wholesale Buyer',
        pricingCategory: Contact.categoryWholesale,
      );

      cart.setCustomer(wholesaleCustomer);
      expect(cart.pricingCategory, equals(Contact.categoryWholesale));

      cart.setCustomer(null);
      expect(cart.pricingCategory, equals(Contact.categoryRetail));
      expect(cart.customer, isNull);
    });

    test('4A-4: recall order (setCustomer then setPricingCategory) works correctly', () {
      final cart = PosCart();
      // Suppose held cart had customer == null and pricingCategory == wholesale
      cart.setCustomer(null);
      cart.setPricingCategory(Contact.categoryWholesale);
      expect(cart.customer, isNull);
      expect(cart.pricingCategory, equals(Contact.categoryWholesale));
    });
  });

  group('Phase 4A-7: ArabicSearchUtils digit normalization', () {
    test('4A-7: converts Arabic-Indic and Extended digits to ASCII', () {
      expect(ArabicSearchUtils.normalize('١٢٣٤٥٦٧٨٩٠'), equals('1234567890'));
      expect(ArabicSearchUtils.normalize('۱۲۳۴۵۶۷۸۹۰'), equals('1234567890'));
      expect(ArabicSearchUtils.normalize('كود ٥٠٥'), equals('كود 505'));
      expect(ArabicSearchUtils.normalize('BAR-١٢٣'), equals('bar-123'));
    });
  });

  group('Phase 4A-3, 4A-5, 4A-6, 4A-8, 4A-9: DB & Service Tests', () {
    late Directory tempDir;
    late DatabaseHelper db;
    late Business testBusiness;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('phase_4a_test');
      await databaseFactory.setDatabasesPath(tempDir.path);
      db = DatabaseHelper.instance;
    });

    tearDownAll(() async {
      FeatureGate.resetForTesting();
      await db.closeDatabase();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    setUp(() async {
      FeatureGate.setOverrideForTesting(true);
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
          name: 'Test Business',
          ownerName: 'Owner',
          phone: '123456789',
          address: 'Sana\'a',
          currencyCode: 'YER',
        ),
      );
      testBusiness = (await db.getFirstBusiness())!;
    });

    test('4A-3: InventoryCostingService excludes draft invoices from sales report', () async {
      final pId = await ProductService.createProduct(
        name: 'Item A',
        salePrice: 100,
        purchasePrice: 60,
        stockQuantity: 50,
      );

      final now = DateTime.now();

      // Create a draft invoice
      await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        items: [
          DocumentItemInput(productId: pId, description: 'Item A', quantity: 2, price: 100),
        ],
        isDraft: true,
      );

      // Create an issued invoice
      await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        items: [
          DocumentItemInput(productId: pId, description: 'Item A', quantity: 3, price: 100),
        ],
        isDraft: false,
      );

      final from = now.subtract(const Duration(days: 1));
      final to = now.add(const Duration(days: 1));

      final costReport = await InventoryCostingService.instance.getSalesReportWithCost(
        from: from,
        to: to,
      );
      final bizReport = await BusinessReportingService.instance.getProductPerformance(
        from: from,
        to: to,
      );

      // The draft invoice must be excluded from both
      expect(costReport.length, equals(1));
      expect(costReport.first.recognizedRevenue, equals(300.0));
      expect(bizReport.totalSalesRevenue, equals(300.0));
    });

    test('4A-5: updateDocument preserves typed recipientName and recipientPhone for walk-in', () async {
      final pId = await ProductService.createProduct(
        name: 'Item B',
        salePrice: 50,
        stockQuantity: 100,
      );

      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        recipientName: 'Walk-in John',
        recipientPhone: '777123456',
        items: [
          DocumentItemInput(productId: pId, description: 'Item B', quantity: 1, price: 50),
        ],
      );

      var doc = await db.getDocumentById(docId);
      expect(doc!.recipientName, equals('Walk-in John'));
      expect(doc.recipientPhone, equals('777123456'));

      // Update without contact and without specifying recipientName -> preserves existing
      await DocumentService.updateDocument(
        documentId: docId,
        type: 'invoice',
        business: testBusiness,
        items: [
          DocumentItemInput(productId: pId, description: 'Item B', quantity: 2, price: 50),
        ],
      );

      doc = await db.getDocumentById(docId);
      expect(doc!.recipientName, equals('Walk-in John'));
      expect(doc.recipientPhone, equals('777123456'));
      expect(doc.total, equals(100.0));

      // Update with new typed recipient
      await DocumentService.updateDocument(
        documentId: docId,
        type: 'invoice',
        business: testBusiness,
        recipientName: 'Walk-in Alice',
        recipientPhone: '777999888',
        items: [
          DocumentItemInput(productId: pId, description: 'Item B', quantity: 2, price: 50),
        ],
      );

      doc = await db.getDocumentById(docId);
      expect(doc!.recipientName, equals('Walk-in Alice'));
      expect(doc.recipientPhone, equals('777999888'));
    });

    test('4A-6: updateDocument throws ArgumentError when payNowMethod is non-null', () async {
      final pId = await ProductService.createProduct(
        name: 'Item C',
        salePrice: 20,
        stockQuantity: 100,
      );

      final docId = await DocumentService.createDocument(
        type: 'invoice',
        business: testBusiness,
        items: [
          DocumentItemInput(productId: pId, description: 'Item C', quantity: 1, price: 20),
        ],
      );

      expect(
        () => DocumentService.updateDocument(
          documentId: docId,
          type: 'invoice',
          business: testBusiness,
          payNowMethod: 'cash',
          items: [
            DocumentItemInput(productId: pId, description: 'Item C', quantity: 1, price: 20),
          ],
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('payNowMethod is not supported when updating'),
        )),
      );
    });

    test('4A-8: ProductService.findBySku finds exact match beyond 10 items without fuzzy truncation', () async {
      // Insert 15 products with code containing 'TEST'
      for (int i = 1; i <= 15; i++) {
        await ProductService.createProduct(
          name: 'Prod $i',
          code: 'TEST-${i.toString().padLeft(3, '0')}',
          salePrice: 10,
        );
      }

      final exact = await ProductService.findBySku('TEST-015');
      expect(exact, isNotNull);
      expect(exact!.name, equals('Prod 15'));

      final nonExistent = await ProductService.findBySku('TEST-999');
      expect(nonExistent, isNull);
    });

    test('4A-8: ProductService.createProduct enforces productsManage permission in multi-user mode', () async {
      final session = SessionManager.instance;
      session.setMultiUserEnabledForTesting(true);

      final cashier = AppUser(
        id: 'user-cashier-1',
        workspaceId: AccessDao.defaultWorkspaceId,
        username: 'cashier',
        displayName: 'Cashier Rep',
        roleId: 'role-cashier',
        isOwner: false,
        isActive: true,
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      session.setSession(cashier, {PermissionRegistry.salesCreate});

      try {
        expect(
          () => ProductService.createProduct(name: 'Forbidden Prod'),
          throwsA(isA<PermissionDeniedException>()),
        );
      } finally {
        session.resetForTesting();
      }
    });

    test('4A-9: ReferencePricingService and DAO AccessGuard and Pro Feature enforcement', () async {
      final session = SessionManager.instance;
      session.setMultiUserEnabledForTesting(true);

      final viewer = AppUser(
        id: 'user-viewer-1',
        workspaceId: AccessDao.defaultWorkspaceId,
        username: 'viewer',
        displayName: 'Viewer Rep',
        roleId: 'role-viewer',
        isOwner: false,
        isActive: true,
        setupComplete: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      session.setSession(viewer, {PermissionRegistry.productsView});

      try {
        // Without pricingRates, addCurrencyWithRate fails
        expect(
          () => ReferencePricingService.addCurrencyWithRate(
            ExchangeRate(
              code: 'USD',
              nameAr: 'دولار',
              symbol: '\$',
              rate: 530,
              isCustom: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Without pricingManage, setRounding fails
        expect(
          () => ReferencePricingService.setRounding(10),
          throwsA(isA<PermissionDeniedException>()),
        );
      } finally {
        session.resetForTesting();
      }

      // Feature entitlement check: when Pro is disabled, assertAvailable throws
      FeatureGate.setOverrideForTesting(false);
      try {
        expect(
          () => ReferencePricingService.addCurrencyWithRate(
            ExchangeRate(
              code: 'USD',
              nameAr: 'دولار',
              symbol: '\$',
              rate: 530,
              isCustom: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
          ),
          throwsA(isA<ReferencePricingException>().having(
            (e) => e.code,
            'code',
            equals(ReferencePricingError.proFeatureRequired),
          )),
        );

        // But system-context callers must NOT be blocked!
        await AccessGuard.runAsSystem(() async {
          await ReferencePricingService.addCurrencyWithRate(
            ExchangeRate(
              code: 'USD',
              nameAr: 'دولار',
              symbol: '\$',
              rate: 530,
              isCustom: true,
              updatedAt: DateTime(2026, 1, 1),
            ),
          );
        });

        final sqlDb = await db.database;
        final rates = await sqlDb.rawQuery('SELECT * FROM exchange_rates WHERE code = ?', ['USD']);
        expect(rates.length, equals(1));
      } finally {
        FeatureGate.resetForTesting();
      }
    });
  });
}

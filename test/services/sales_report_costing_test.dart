import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document_status.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/inventory_costing_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Business business;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('sales_report_costing_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'متجر اختبار المبيعات',
        ownerName: 'المالك',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
      ),
    );
    business = (await db.getFirstBusiness())!;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'getSalesReportWithCost single-query aggregation matches reference calculation exactly',
    () async {
      // 1. Seed products: one with known cost, one with zero purchase price (unknown cost)
      final pKnown = await ProductService.createProduct(
        name: 'منتج بتكلفة معروفة',
        salePrice: 100.0,
        purchasePrice: 60.0,
        stockQuantity: 50.0,
      );
      final pUnknown = await ProductService.createProduct(
        name: 'منتج بتكلفة مجهولة',
        salePrice: 80.0,
        purchasePrice: 0.0,
        stockQuantity: 50.0,
      );

      final now = DateTime.now();

      // 2. Create invoice 1: Fully costed, discount = 10
      final inv1Id = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        discount: 10.0,
        items: [
          DocumentItemInput(
            description: 'منتج بتكلفة معروفة',
            quantity: 2,
            price: 100.0,
            productId: pKnown,
          ),
        ],
        strictStock: false,
      );

      // 3. Create invoice 2: Partially uncosted (has item with unknown cost)
      final inv2Id = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'منتج بتكلفة مجهولة',
            quantity: 1,
            price: 80.0,
            productId: pUnknown,
          ),
        ],
        strictStock: false,
      );

      // 4. Create invoice 3: Cancelled invoice
      final inv3Id = await DocumentService.createDocument(
        type: 'invoice',
        business: business,
        items: [
          DocumentItemInput(
            description: 'منتج ملغي',
            quantity: 1,
            price: 50.0,
            productId: pKnown,
          ),
        ],
        strictStock: false,
      );
      await DocumentService.cancelDocument(inv3Id);

      // Query via optimized getSalesReportWithCost
      final report = await InventoryCostingService.instance
          .getSalesReportWithCost(
            from: now.subtract(const Duration(days: 1)),
            to: now.add(const Duration(days: 1)),
            includeCancelled: true,
          );

      expect(report, hasLength(3));

      // Reference computation check for Invoice 1
      final s1 = report.firstWhere((s) => s.document.id == inv1Id);
      expect(s1.document.status, equals(DocumentStatus.issued));
      expect(s1.recognizedRevenue, equals(190.0)); // 200 - 10 discount
      expect(s1.cogs, equals(120.0)); // 2 * 60.0
      expect(s1.grossProfit, equals(70.0)); // 190 - 120
      expect(s1.isCostReliable, isTrue);

      // Reference computation check for Invoice 2 (unknown cost item)
      final s2 = report.firstWhere((s) => s.document.id == inv2Id);
      expect(s2.document.status, equals(DocumentStatus.issued));
      expect(s2.recognizedRevenue, equals(80.0));
      expect(s2.cogs, equals(0.0));
      expect(s2.isCostReliable, isFalse);

      // Reference computation check for Invoice 3 (cancelled)
      final s3 = report.firstWhere((s) => s.document.id == inv3Id);
      expect(s3.document.status, equals(DocumentStatus.cancelled));
      expect(s3.recognizedRevenue, equals(0.0));
      expect(s3.cogs, equals(0.0));
      expect(s3.grossProfit, equals(0.0));
      expect(s3.isCostReliable, isTrue);
    },
  );
}

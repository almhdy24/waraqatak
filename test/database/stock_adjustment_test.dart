import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/services/inventory_service.dart';
import 'package:warqatek/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Product testProduct;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('stock_adjustment_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    final db = DatabaseHelper.instance;
    await db.insertBusiness(const Business(
      name: 'متجر التعديلات',
      ownerName: 'سامي',
      phone: '0123456789',
      address: 'أم درمان',
      taxRate: 0,
    ));
    final pid = await ProductService.createProduct(
      name: 'أرز بسمتي',
      salePrice: 1500,
      stockQuantity: 20.0,
      unit: 'كجم',
    );
    testProduct = (await db.getProductById(pid))!;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Stock Adjustment Operations (Add & Remove)', () {
    test('Add Stock (+) increases stock and records adjustment movement', () async {
      final db = DatabaseHelper.instance;
      // Add +15.5 kg to 20.0 kg -> 35.5 kg
      await InventoryService.adjust(
        productId: testProduct.id!,
        delta: 15.5,
        reason: 'count_gain',
        notes: 'جرد إضافي',
      );

      final updated = (await db.getProductById(testProduct.id!))!;
      expect(updated.stockQuantity, 35.5);

      final movements = await db.getStockMovements(testProduct.id!);
      final latest = movements.first;
      expect(latest.type, StockMovement.typeAdjustment);
      expect(latest.quantity, 15.5);
      expect(latest.notes, 'جرد إضافي');
    });

    test('Remove Stock (−) decreases stock and records adjustment movement', () async {
      final db = DatabaseHelper.instance;
      // Remove -10.25 kg from 35.5 kg -> 25.25 kg
      await InventoryService.adjust(
        productId: testProduct.id!,
        delta: -10.25,
        reason: 'damage_loss',
        notes: 'تلف أثناء التخزين',
      );

      final updated = (await db.getProductById(testProduct.id!))!;
      expect(updated.stockQuantity, 25.25);

      final movements = await db.getStockMovements(testProduct.id!);
      final latest = movements.first;
      expect(latest.type, StockMovement.typeAdjustment);
      expect(latest.quantity, -10.25);
      expect(latest.notes, 'تلف أثناء التخزين');
    });

    test('Fractional / decimal adjustments with positive input applied internally', () async {
      final db = DatabaseHelper.instance;
      double computeEffectiveDelta(double input, bool isAdd) => isAdd ? input : -input;

      // Start at 25.25 kg.
      // User selects Add Stock (+), enters strictly positive "12.375"
      final effectiveAddDelta = computeEffectiveDelta(12.375, true);
      await InventoryService.adjust(
        productId: testProduct.id!,
        delta: effectiveAddDelta,
        reason: 'count_gain',
      );

      var prod = (await db.getProductById(testProduct.id!))!;
      expect(prod.stockQuantity, 37.625);

      // User selects Remove Stock (−), enters strictly positive "7.125"
      final effectiveRemoveDelta = computeEffectiveDelta(7.125, false);
      await InventoryService.adjust(
        productId: testProduct.id!,
        delta: effectiveRemoveDelta,
        reason: 'damage_loss',
      );

      prod = (await db.getProductById(testProduct.id!))!;
      expect(prod.stockQuantity, 30.5);

      // Verify movements ledger
      final movements = await db.getStockMovements(testProduct.id!);
      expect(movements.first.quantity, -7.125);
      expect(movements[1].quantity, 12.375);
    });

    test('Zero or negative quantity input is invalid and rejected before adjust call', () {
      // Simulate input validation performed by UI controller
      double? validateAndComputeDelta(String input, bool isAdd, double currentStock) {
        final parsed = double.tryParse(input.replaceAll(',', '.'));
        if (parsed == null || parsed <= 0) return null;
        final delta = isAdd ? parsed : -parsed;
        if (currentStock + delta < 0) return null;
        return delta;
      }

      // Invalid zero or negative inputs
      expect(validateAndComputeDelta('0', true, 30.5), isNull);
      expect(validateAndComputeDelta('-5', true, 30.5), isNull);
      expect(validateAndComputeDelta('abc', true, 30.5), isNull);

      // Input exceeding stock on Remove
      expect(validateAndComputeDelta('50', false, 30.5), isNull);

      // Valid Add & Remove
      expect(validateAndComputeDelta('10', true, 30.5), 10.0);
      expect(validateAndComputeDelta('10', false, 30.5), -10.0);
    });
  });
}

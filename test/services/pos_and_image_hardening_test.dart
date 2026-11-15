import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/services/image_storage_service.dart';
import 'package:warqatek/services/pos_cart.dart';

void main() {
  group('POS-02: PosCart Line & Pricing Overrides Preservation', () {
    const productA = Product(
      id: 101,
      name: 'Widget A',
      salePrice: 100.0,
      stockQuantity: 50,
    );
    const unitBox = ProductUnit(
      id: 1,
      productId: 101,
      unitName: 'Box',
      conversionFactor: 10.0,
      salePrice: 900.0,
    );

    test('preserves pricing category, price override, tax rate, and unit', () {
      final cart = PosCart();
      cart.setPricingCategory(Contact.categoryWholesale);
      cart.setWholesalePricingEnabled(true);

      cart.add(
        productA,
        quantity: 2,
        unit: unitBox,
        pricingCategory: Contact.categoryWholesale,
        priceOverride: 850.0,
        taxRate: 5.0,
        wholesalePricingEnabled: true,
      );

      expect(cart.lines.length, 1);
      final line = cart.lines.first;
      expect(line.product.id, 101);
      expect(line.quantity, 2);
      expect(line.unit?.unitName, 'Box');
      expect(line.unit?.conversionFactor, 10.0);
      expect(line.priceOverride, 850.0);
      expect(line.unitPrice, 850.0);
      expect(line.taxRate, 5.0);
      expect(line.pricingCategory, Contact.categoryWholesale);
      expect(line.wholesalePricingEnabled, isTrue);

      // Simulate clear cart and undo
      final savedLines = List<PosCartLine>.from(cart.lines);
      final savedCategory = cart.pricingCategory;
      final savedWholesaleEnabled = cart.wholesalePricingEnabled;

      cart.clear();
      expect(cart.lines, isEmpty);

      // Perform undo restoration
      cart.setPricingCategory(savedCategory);
      cart.setWholesalePricingEnabled(savedWholesaleEnabled);
      for (final l in savedLines) {
        cart.add(
          l.product,
          quantity: l.quantity,
          unit: l.unit,
          pricingCategory: l.pricingCategory,
          priceOverride: l.priceOverride,
          taxRate: l.taxRate,
          wholesalePricingEnabled: l.wholesalePricingEnabled,
        );
      }

      expect(cart.lines.length, 1);
      final restoredLine = cart.lines.first;
      expect(restoredLine.product.id, 101);
      expect(restoredLine.quantity, 2);
      expect(restoredLine.unit?.unitName, 'Box');
      expect(restoredLine.priceOverride, 850.0);
      expect(restoredLine.unitPrice, 850.0);
      expect(restoredLine.taxRate, 5.0);
      expect(restoredLine.pricingCategory, Contact.categoryWholesale);
      expect(restoredLine.wholesalePricingEnabled, isTrue);
    });
  });

  group('POS-01: Held Carts JSON Serialization & Resiliency', () {
    const productA = Product(
      id: 201,
      name: 'Item A',
      salePrice: 50.0,
      stockQuantity: 100,
    );
    const productB = Product(
      id: 202,
      name: 'Item B',
      salePrice: 80.0,
      stockQuantity: 100,
    );
    const unitPack = ProductUnit(
      id: 2,
      productId: 201,
      unitName: 'Pack',
      conversionFactor: 5.0,
      salePrice: 220.0,
    );

    test('serializes and deserializes held cart correctly', () {
      final originalJson = {
        'id': 'held_123',
        'heldAt': DateTime.now().toIso8601String(),
        'customer': {
          'id': 1,
          'name': 'Customer Test',
          'type': 'customer',
          'pricing_category': 'retail',
        },
        'pricingCategory': 'retail',
        'discount': 15.0,
        'lines': [
          {
            'productId': 201,
            'quantity': 3.0,
            'taxRate': 10.0,
            'pricingCategory': Contact.categoryWholesale,
            'priceOverride': 210.0,
            'wholesalePricingEnabled': true,
            'unit': unitPack.toMap(),
          },
          {
            'productId': 202,
            'quantity': 1.0,
            'taxRate': null,
            'pricingCategory': null,
            'priceOverride': 75.0,
            'wholesalePricingEnabled': false,
            'unit': null,
          },
        ],
      };

      final encoded = jsonEncode(originalJson);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      final productMap = {201: productA, 202: productB};
      final unitsMap = {
        201: [unitPack],
      };

      final lines = <PosCartLine>[];
      for (final rawLine in decoded['lines'] as List) {
        final rawMap = rawLine as Map<String, dynamic>;
        final pId = rawMap['productId'] as int;
        final product = productMap[pId]!;
        final unitRaw = rawMap['unit'];
        ProductUnit? unit;
        if (unitRaw is Map<String, dynamic>) {
          final parsed = ProductUnit.fromMap(unitRaw);
          unit = unitsMap[pId]?.firstWhere(
            (u) => u.id == parsed.id,
            orElse: () => parsed,
          ) ?? parsed;
        }

        lines.add(
          PosCartLine(
            product,
            (rawMap['quantity'] as num).toDouble(),
            unit: unit,
            taxRate: (rawMap['taxRate'] as num?)?.toDouble(),
            pricingCategory: rawMap['pricingCategory'] as String?,
            priceOverride: (rawMap['priceOverride'] as num?)?.toDouble(),
            wholesalePricingEnabled:
                rawMap['wholesalePricingEnabled'] as bool? ?? false,
          ),
        );
      }

      expect(lines.length, 2);
      expect(lines[0].product.name, 'Item A');
      expect(lines[0].priceOverride, 210.0);
      expect(lines[0].unit?.unitName, 'Pack');
      expect(lines[1].product.name, 'Item B');
      expect(lines[1].priceOverride, 75.0);
    });

    test('gracefully ignores deleted/missing products', () {
      final jsonWithDeletedProduct = {
        'id': 'held_999',
        'heldAt': DateTime.now().toIso8601String(),
        'customer': null,
        'pricingCategory': null,
        'discount': 0.0,
        'lines': [
          {
            'productId': 9999, // Deleted product id
            'quantity': 2.0,
          },
          {
            'productId': 201, // Existing product
            'quantity': 1.0,
          },
        ],
      };

      final productMap = {201: productA}; // 9999 not in catalog
      final rawLines = jsonWithDeletedProduct['lines'] as List;
      final lines = <PosCartLine>[];

      for (final rawLine in rawLines) {
        final rawMap = rawLine as Map<String, dynamic>;
        final pId = rawMap['productId'] as int?;
        if (pId == null) continue;
        final product = productMap[pId];
        if (product == null) continue; // skipped safely!

        lines.add(
          PosCartLine(
            product,
            (rawMap['quantity'] as num).toDouble(),
          ),
        );
      }

      expect(lines.length, 1);
      expect(lines.first.product.id, 201);
    });
  });

  group('IMG-01: Image Fallback Logic', () {
    test('ImageStorageService produces correct thumbnail path naming', () {
      final thumbName = ImageStorageService.thumbNameFor('product_42.jpg');
      expect(thumbName, 'product_42_t.jpg');
    });

    test('Target path selection logic checks existence before picking thumb', () {
      // Create temporary mock files to test path existence resolution
      final tempDir = Directory.systemTemp.createTempSync('img_fallback_test');
      try {
        final mainFile = File('${tempDir.path}/item.png');
        mainFile.writeAsStringSync('main');
        final thumbFile = File('${tempDir.path}/item_t.png');

        // Case 1: thumb does not exist on disk, main file exists
        String? targetPath;
        if (thumbFile.existsSync()) {
          targetPath = thumbFile.path;
        } else if (mainFile.existsSync()) {
          targetPath = mainFile.path;
        }
        expect(targetPath, mainFile.path, reason: 'Must fall back to main when thumb is absent');

        // Case 2: thumb is created and exists on disk
        thumbFile.writeAsStringSync('thumb');
        if (thumbFile.existsSync()) {
          targetPath = thumbFile.path;
        } else if (mainFile.existsSync()) {
          targetPath = mainFile.path;
        }
        expect(targetPath, thumbFile.path, reason: 'Must prefer thumb when thumb is present');

        // Case 3: neither exists
        mainFile.deleteSync();
        thumbFile.deleteSync();
        if (thumbFile.existsSync()) {
          targetPath = thumbFile.path;
        } else if (mainFile.existsSync()) {
          targetPath = mainFile.path;
        } else {
          targetPath = null;
        }
        expect(targetPath, isNull, reason: 'Must resolve to null (icon fallback) when neither exists');
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}

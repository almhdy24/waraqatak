import '../database/database_helper.dart';
import '../models/product.dart';

enum BulkPriceOpType {
  percentageIncrease,
  percentageDecrease,
  fixedIncrease,
  fixedDecrease,
  setDirect,
}

enum BulkPriceTarget {
  sellingPrice,
  purchasePrice,
  both,
}

enum BulkPriceRounding {
  none,
  nearestWhole,
  nearestTen,
  ceilWhole,
}

class BulkPricePreviewItem {
  final Product product;
  final double currentSalePrice;
  final double proposedSalePrice;
  final double? salePriceDelta;
  final double currentPurchasePrice;
  final double proposedPurchasePrice;
  final double? purchasePriceDelta;
  final bool isValid;
  final String? errorMessage;

  const BulkPricePreviewItem({
    required this.product,
    required this.currentSalePrice,
    required this.proposedSalePrice,
    this.salePriceDelta,
    required this.currentPurchasePrice,
    required this.proposedPurchasePrice,
    this.purchasePriceDelta,
    required this.isValid,
    this.errorMessage,
  });
}

class BulkPriceResult {
  final int affectedCount;
  final BulkPriceOpType opType;
  final double opValue;
  final BulkPriceTarget target;

  const BulkPriceResult({
    required this.affectedCount,
    required this.opType,
    required this.opValue,
    required this.target,
  });
}

class BulkPricingService {
  BulkPricingService._();
  static final BulkPricingService instance = BulkPricingService._();

  double _applyOperation(
    double currentPrice,
    BulkPriceOpType opType,
    double value,
    BulkPriceRounding rounding,
  ) {
    double result = currentPrice;
    switch (opType) {
      case BulkPriceOpType.percentageIncrease:
        result = currentPrice * (1.0 + (value / 100.0));
        break;
      case BulkPriceOpType.percentageDecrease:
        result = currentPrice * (1.0 - (value / 100.0));
        break;
      case BulkPriceOpType.fixedIncrease:
        result = currentPrice + value;
        break;
      case BulkPriceOpType.fixedDecrease:
        result = currentPrice - value;
        break;
      case BulkPriceOpType.setDirect:
        result = value;
        break;
    }

    switch (rounding) {
      case BulkPriceRounding.none:
        return double.parse(result.toStringAsFixed(2));
      case BulkPriceRounding.nearestWhole:
        return result.roundToDouble();
      case BulkPriceRounding.nearestTen:
        return (result / 10.0).roundToDouble() * 10.0;
      case BulkPriceRounding.ceilWhole:
        return result.ceilToDouble();
    }
  }

  List<BulkPricePreviewItem> preview({
    required List<Product> products,
    required BulkPriceOpType opType,
    required double opValue,
    required BulkPriceTarget target,
    BulkPriceRounding rounding = BulkPriceRounding.none,
  }) {
    final previewList = <BulkPricePreviewItem>[];

    for (final p in products) {
      double newSale = p.salePrice;
      double newPurchase = p.purchasePrice;

      if (target == BulkPriceTarget.sellingPrice || target == BulkPriceTarget.both) {
        newSale = _applyOperation(p.salePrice, opType, opValue, rounding);
      }

      if (target == BulkPriceTarget.purchasePrice || target == BulkPriceTarget.both) {
        newPurchase = _applyOperation(p.purchasePrice, opType, opValue, rounding);
      }

      bool valid = true;
      String? error;
      if (newSale < 0) {
        valid = false;
        error = 'سعر البيع لا يمكن أن يكون سالباً';
      } else if (newPurchase < 0) {
        valid = false;
        error = 'سعر الشراء لا يمكن أن يكون سالباً';
      }

      previewList.add(BulkPricePreviewItem(
        product: p,
        currentSalePrice: p.salePrice,
        proposedSalePrice: newSale,
        salePriceDelta: newSale - p.salePrice,
        currentPurchasePrice: p.purchasePrice,
        proposedPurchasePrice: newPurchase,
        purchasePriceDelta: newPurchase - p.purchasePrice,
        isValid: valid,
        errorMessage: error,
      ));
    }

    return previewList;
  }

  Future<BulkPriceResult> applyBatch({
    required List<BulkPricePreviewItem> items,
    required BulkPriceOpType opType,
    required double opValue,
    required BulkPriceTarget target,
  }) async {
    final validItems = items.where((it) => it.isValid).toList();
    if (validItems.isEmpty) {
      throw ArgumentError('No valid items to update');
    }

    final anyInvalid = items.any((it) => !it.isValid);
    if (anyInvalid) {
      throw StateError('Cannot apply batch with invalid negative price items');
    }

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      for (final item in validItems) {
        final updateValues = <String, dynamic>{
          'updated_at': now,
        };

        if (target == BulkPriceTarget.sellingPrice || target == BulkPriceTarget.both) {
          updateValues['sale_price'] = item.proposedSalePrice;
        }
        if (target == BulkPriceTarget.purchasePrice || target == BulkPriceTarget.both) {
          updateValues['purchase_price'] = item.proposedPurchasePrice;
        }

        // Strictly updates catalog prices only — never stock_quantity,
        // historical document items, stock_movements, or average_cost.
        await txn.update(
          'products',
          updateValues,
          where: 'id = ?',
          whereArgs: [item.product.id],
        );
      }

      // Record audit event
      await txn.insert('audit_log', {
        'action': 'bulk_pricing',
        'entity_type': 'products_batch',
        'entity_id': validItems.length,
        'details':
            'affected_count=${validItems.length} op=${opType.name} value=$opValue target=${target.name}',
        'timestamp': now,
      });
    });

    return BulkPriceResult(
      affectedCount: validItems.length,
      opType: opType,
      opValue: opValue,
      target: target,
    );
  }
}

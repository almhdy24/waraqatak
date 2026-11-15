import '../core/catalog_events.dart';
import '../database/database_helper.dart';
import '../database/reference_pricing_dao.dart';
import 'access/access_guard.dart';
import 'access/audit_service.dart';
import 'access/permission_registry.dart';
import '../models/product.dart';
import '../models/reference_pricing_types.dart';

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
  wholesalePrice,
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
  final double? currentWholesalePrice;
  final double? proposedWholesalePrice;
  final double? wholesalePriceDelta;
  final bool isValid;
  final String? errorMessage;
  final bool skipSale;
  final bool skipPurchase;
  final bool skipWholesale;
  final int skippedFields;

  const BulkPricePreviewItem({
    required this.product,
    required this.currentSalePrice,
    required this.proposedSalePrice,
    this.salePriceDelta,
    required this.currentPurchasePrice,
    required this.proposedPurchasePrice,
    this.purchasePriceDelta,
    this.currentWholesalePrice,
    this.proposedWholesalePrice,
    this.wholesalePriceDelta,
    required this.isValid,
    this.errorMessage,
    this.skipSale = false,
    this.skipPurchase = false,
    this.skipWholesale = false,
    this.skippedFields = 0,
  });
}

class BulkPriceResult {
  final int affectedCount;
  final BulkPriceOpType opType;
  final double opValue;
  final BulkPriceTarget target;
  final int skippedCount;

  const BulkPriceResult({
    required this.affectedCount,
    required this.opType,
    required this.opValue,
    required this.target,
    this.skippedCount = 0,
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
      double? newWholesale = p.wholesalePrice;

      bool skipSale = false;
      bool skipPurchase = false;
      bool skipWholesale = false;
      int skippedFields = 0;

      if (p.priceCurrency != null) {
        skipSale = true;
        skipPurchase = p.referencePurchasePrice != null;
        skipWholesale = p.referenceWholesalePrice != null;
      }

      if (target == BulkPriceTarget.sellingPrice || target == BulkPriceTarget.both) {
        if (skipSale) {
          skippedFields++;
          newSale = p.salePrice;
        } else {
          newSale = _applyOperation(p.salePrice, opType, opValue, rounding);
        }
      }

      if (target == BulkPriceTarget.purchasePrice || target == BulkPriceTarget.both) {
        if (skipPurchase) {
          skippedFields++;
          newPurchase = p.purchasePrice;
        } else {
          newPurchase = _applyOperation(p.purchasePrice, opType, opValue, rounding);
        }
      }

      if (target == BulkPriceTarget.wholesalePrice && p.wholesalePrice != null) {
        if (skipWholesale) {
          skippedFields++;
          newWholesale = p.wholesalePrice;
        } else {
          newWholesale = _applyOperation(p.wholesalePrice!, opType, opValue, rounding);
        }
      }

      bool valid = true;
      String? error;
      if (newSale < 0) {
        valid = false;
        error = 'سعر البيع لا يمكن أن يكون سالباً';
      } else if (newPurchase < 0) {
        valid = false;
        error = 'سعر الشراء لا يمكن أن يكون سالباً';
      } else if (newWholesale != null && newWholesale < 0) {
        valid = false;
        error = 'سعر الجملة لا يمكن أن يكون سالباً';
      }

      previewList.add(BulkPricePreviewItem(
        product: p,
        currentSalePrice: p.salePrice,
        proposedSalePrice: newSale,
        salePriceDelta: newSale - p.salePrice,
        currentPurchasePrice: p.purchasePrice,
        proposedPurchasePrice: newPurchase,
        purchasePriceDelta: newPurchase - p.purchasePrice,
        currentWholesalePrice: p.wholesalePrice,
        proposedWholesalePrice: newWholesale,
        wholesalePriceDelta: (newWholesale != null && p.wholesalePrice != null)
            ? (newWholesale - p.wholesalePrice!)
            : null,
        isValid: valid,
        errorMessage: error,
        skipSale: skipSale,
        skipPurchase: skipPurchase,
        skipWholesale: skipWholesale,
        skippedFields: skippedFields,
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
    AccessGuard.require(PermissionRegistry.pricingManage);
    final validItems = items.where((it) => it.isValid).toList();
    if (validItems.isEmpty) {
      throw ArgumentError('No valid items to update');
    }

    final anyInvalid = items.any((it) => !it.isValid);
    if (anyInvalid) {
      throw StateError('Cannot apply batch with invalid negative price items');
    }

    final db = await DatabaseHelper.instance.database;
    int affectedCount = 0;
    int totalSkippedCount = 0;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final productIds = validItems.map((it) => it.product.id!).toList();
      final flagsMap = await ReferencePricingDao.getReferenceDrivenFlags(
        txn,
        productIds,
      );

      for (final item in validItems) {
        final pId = item.product.id!;
        final flags = flagsMap[pId] ??
            const ReferenceDrivenFlags(
              sale: false,
              wholesale: false,
              purchase: false,
            );

        final updateValues = <String, dynamic>{};

        if (target == BulkPriceTarget.sellingPrice || target == BulkPriceTarget.both) {
          if (flags.sale) {
            totalSkippedCount++;
          } else {
            updateValues['sale_price'] = item.proposedSalePrice;
          }
        }

        if (target == BulkPriceTarget.purchasePrice || target == BulkPriceTarget.both) {
          if (flags.purchase) {
            totalSkippedCount++;
          } else {
            updateValues['purchase_price'] = item.proposedPurchasePrice;
          }
        }

        if (target == BulkPriceTarget.wholesalePrice && item.product.wholesalePrice != null) {
          if (flags.wholesale) {
            totalSkippedCount++;
          } else if (item.proposedWholesalePrice != null) {
            updateValues['wholesale_price'] = item.proposedWholesalePrice;
          }
        }

        if (updateValues.isNotEmpty) {
          updateValues['updated_at'] = now;
          await txn.update(
            'products',
            updateValues,
            where: 'id = ?',
            whereArgs: [pId],
          );
          affectedCount++;
        }
      }

      // Record audit event only if affectedCount > 0
      if (affectedCount > 0) {
        await AuditService.instance.logEvent(
          txn,
          'bulk_pricing',
          entityType: 'products_batch',
          entityId: affectedCount,
          details:
              'affected_count=$affectedCount op=${opType.name} value=$opValue target=${target.name}',
        );
      }
    });

    if (affectedCount > 0) {
      CatalogEvents.notifyPricesChanged();
    }

    return BulkPriceResult(
      affectedCount: affectedCount,
      opType: opType,
      opValue: opValue,
      target: target,
      skippedCount: totalSkippedCount,
    );
  }
}

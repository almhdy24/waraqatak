import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import 'access/access_guard.dart';
import 'access/permission_registry.dart';
import 'image_storage_service.dart';

/// Thrown when attempting to delete a product referenced in transactions or documents.
class ProductInUseException implements Exception {
  final int productId;
  final String? message;
  const ProductInUseException(this.productId, [this.message]);

  @override
  String toString() => 'ProductInUseException($productId, $message)';
}

class ProductService {
  static Future<int> createProduct({
    required String name,
    String type = Product.typeProduct,
    String? code,
    String? barcode,
    String? unit,
    double salePrice = 0,
    double? wholesalePrice,
    double? wholesaleMinQuantity,
    double purchasePrice = 0,
    double stockQuantity = 0,
    double minStock = 0,
    bool isTaxable = true,
    String? notes,
    String? category,
  }) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final now = DateTime.now();
    final product = Product(
      name: name,
      type: type,
      code: code,
      barcode: barcode,
      unit: unit,
      salePrice: salePrice,
      wholesalePrice: wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity,
      purchasePrice: purchasePrice,
      stockQuantity: stockQuantity,
      minStock: minStock,
      isTaxable: isTaxable,
      isActive: true,
      notes: notes,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
    return DatabaseHelper.instance.insertProduct(product);
  }

  static Future<void> updateProduct(Product product) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final updated = product.copyWith(updatedAt: DateTime.now());
    await DatabaseHelper.instance.updateProduct(updated);
  }

  /// Authoritative entry point for saving a product and its units,
  /// safely deleting any replaced image only after the save transaction commits.
  static Future<int> saveProductWithUnits({
    required Product product,
    List<ProductUnit> units = const [],
    String? oldImagePathToDelete,
    bool allowClearReferencePricing = false,
  }) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final id = await DatabaseHelper.instance.saveProductWithUnits(
      product,
      units,
      allowClearReferencePricing: allowClearReferencePricing,
    );

    // B6: Delete replaced old image only after the save succeeded
    if (oldImagePathToDelete != null &&
        oldImagePathToDelete.isNotEmpty &&
        oldImagePathToDelete != product.imagePath) {
      await ImageStorageService.deleteImage(oldImagePathToDelete);
    }

    return id;
  }

  static Future<void> deleteProduct(int id) async {
    AccessGuard.require(PermissionRegistry.productsDelete);
    final isReferenced = await DatabaseHelper.instance.isProductReferenced(id);
    if (isReferenced) {
      throw ProductInUseException(
        id,
        'Cannot delete product referenced in documents',
      );
    }
    final product = await DatabaseHelper.instance.getProductById(id);
    await DatabaseHelper.instance.deleteProduct(id);
    if (product?.imagePath != null) {
      await ImageStorageService.deleteImage(product!.imagePath);
    }
  }

  static Future<void> setActive(int id, {required bool active}) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    await DatabaseHelper.instance.setProductActive(id, active: active);
  }

  static Future<bool> isReferencedInDocuments(int id) async {
    return DatabaseHelper.instance.isProductReferenced(id);
  }

  static Future<List<Product>> getAllProducts({
    String? type,
    bool? activeOnly,
    String? category,
  }) async {
    return DatabaseHelper.instance.getAllProducts(
      type: type,
      activeOnly: activeOnly,
      category: category,
    );
  }

  static Future<List<String>> getCategories() async {
    return DatabaseHelper.instance.getProductCategories();
  }

  static Future<List<Product>> searchProducts(
    String query, {
    int? limit,
  }) async {
    return DatabaseHelper.instance.searchProducts(query, limit: limit);
  }

  static Future<List<Product>> searchActive(
    String query, {
    int limit = 10,
  }) async {
    return DatabaseHelper.instance.searchActiveProducts(query, limit: limit);
  }

  static Future<Product?> findByBarcode(String barcode) async {
    return DatabaseHelper.instance.getProductByBarcode(barcode);
  }

  static Future<Product?> findBySku(String sku) async {
    final trimmed = sku.trim();
    if (trimmed.isEmpty) return null;
    return DatabaseHelper.instance.getProductByCode(trimmed);
  }

  static Future<bool> isBarcodeUsed(String barcode, {int? excludeId}) async {
    return DatabaseHelper.instance.isBarcodeUsed(barcode, excludeId: excludeId);
  }
}

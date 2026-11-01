import '../database/database_helper.dart';
import '../models/product.dart';

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
    final updated = Product(
      id: product.id,
      name: product.name,
      type: product.type,
      code: product.code,
      barcode: product.barcode,
      unit: product.unit,
      salePrice: product.salePrice,
      wholesalePrice: product.wholesalePrice,
      wholesaleMinQuantity: product.wholesaleMinQuantity,
      purchasePrice: product.purchasePrice,
      stockQuantity: product.stockQuantity,
      minStock: product.minStock,
      isTaxable: product.isTaxable,
      isActive: product.isActive,
      notes: product.notes,
      category: product.category,
      taxProfileId: product.taxProfileId,
      createdAt: product.createdAt,
      updatedAt: DateTime.now(),
    );
    await DatabaseHelper.instance.updateProduct(updated);
  }

  static Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
  }

  static Future<void> setActive(int id, {required bool active}) async {
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

  static Future<List<Product>> searchProducts(String query, {int? limit}) async {
    return DatabaseHelper.instance.searchProducts(query, limit: limit);
  }

  static Future<List<Product>> searchActive(String query, {int limit = 10}) async {
    return DatabaseHelper.instance.searchActiveProducts(query, limit: limit);
  }

  static Future<Product?> findByBarcode(String barcode) async {
    return DatabaseHelper.instance.getProductByBarcode(barcode);
  }

  static Future<Product?> findBySku(String sku) async {
    final results = await DatabaseHelper.instance.searchActiveProducts(sku);
    return results.where((p) => p.code == sku).firstOrNull;
  }

  static Future<bool> isBarcodeUsed(String barcode, {int? excludeId}) async {
    return DatabaseHelper.instance.isBarcodeUsed(barcode, excludeId: excludeId);
  }
}

import '../database/database_helper.dart';
import '../models/product.dart';

class ProductService {
  static Future<int> createProduct({
    required String name,
    String? code,
    double salePrice = 0,
    double purchasePrice = 0,
    double stockQuantity = 0,
    double minStock = 0,
    bool isTaxable = true,
    String? notes,
  }) async {
    final product = Product(
      name: name,
      code: code,
      salePrice: salePrice,
      purchasePrice: purchasePrice,
      stockQuantity: stockQuantity,
      minStock: minStock,
      isTaxable: isTaxable,
      notes: notes,
    );
    return DatabaseHelper.instance.insertProduct(product);
  }

  static Future<void> updateProduct(Product product) async {
    await DatabaseHelper.instance.updateProduct(product);
  }

  static Future<void> deleteProduct(int id) async {
    await DatabaseHelper.instance.deleteProduct(id);
  }

  static Future<List<Product>> getAllProducts() async {
    return DatabaseHelper.instance.getAllProducts();
  }

  static Future<List<Product>> searchProducts(String query) async {
    return DatabaseHelper.instance.searchProducts(query);
  }
}
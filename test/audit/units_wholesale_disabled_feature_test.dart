import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/models/product_unit.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/pdf/pdf_document_builder.dart';
import 'package:warqatek/utils/pdf_settings.dart';
import 'package:warqatek/utils/print_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseHelper db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('units_disabled_feature_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    db = DatabaseHelper.instance;
  });

  tearDownAll(() async {
    try {
      await db.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Existing unit and wholesale documents remain fully operational when wholesale pricing is disabled', () async {
    await db.closeDatabase();
    final file = File('${tempDir.path}/warqatek.db');
    if (file.existsSync()) file.deleteSync();

    // 1. Setup business with wholesale pricing enabled initially
    await db.insertBusiness(
      const Business(
        name: 'متجر الاختبار',
        ownerName: 'المالك',
        phone: '0912345678',
        address: 'الخرطوم',
        currencyCode: 'SDG',
        wholesalePricingEnabled: true,
      ),
    );
    final business = (await db.getFirstBusiness())!;

    // 2. Setup product with custom unit
    final pid = await db.insertProduct(
      const Product(
        name: 'زيت طعام',
        unit: 'لتر',
        stockQuantity: 100.0,
        purchasePrice: 40.0,
        salePrice: 50.0,
        wholesalePrice: 45.0,
      ),
    );
    final product = (await db.getProductById(pid))!;

    await db.insertProductUnit(
      ProductUnit(
        productId: pid,
        unitName: 'كرتونة',
        conversionFactor: 12.0,
        salePrice: 580.0,
        wholesalePrice: 520.0,
      ),
    );
    final units = await db.getProductUnits(pid);

    // 3. Create document with wholesale line in custom unit
    final docId = await DocumentService.createDocument(
      type: 'invoice',
      business: business,
      items: [
        DocumentItemInput(
          description: 'زيت طعام كرتونة',
          quantity: 2.0,
          price: 520.0,
          productId: pid,
          saleUnit: 'كرتونة',
          unitConversionFactor: 12.0,
          baseQuantity: 24.0,
          pricingCategory: Contact.categoryWholesale,
        ),
      ],
      strictStock: true,
    );

    // Initial stock deducted: 100 - 24 = 76
    expect((await db.getProductById(pid))?.stockQuantity, 76.0);

    // 4. Disable wholesale pricing on business
    final disabledBusiness = business.copyWith(wholesalePricingEnabled: false);
    await db.updateBusiness(disabledBusiness);

    // 5. Code path test: resolveLinePrice with wholesalePricingEnabled: false returns retail unit price
    final resolvedRetail = DocumentService.resolveLinePrice(
      product: product,
      availableUnits: units,
      quantity: 1.0,
      saleUnit: 'كرتونة',
      unitConversionFactor: 12.0,
      pricingCategory: Contact.categoryRetail,
      targetCategory: Contact.categoryWholesale,
      wholesalePricingEnabled: false,
    );
    expect(resolvedRetail, 580.0, reason: 'When feature is disabled, resolves to unit retail price');

    // 6. Display / Read test: existing document items preserve wholesale snapshot & totals
    final doc = (await db.getDocumentById(docId))!;
    final items = await db.getDocumentItems(docId);
    expect(items.length, 1);
    expect(items.first.saleUnit, 'كرتونة');
    expect(items.first.unitConversionFactor, 12.0);
    expect(items.first.baseQuantity, 24.0);
    expect(items.first.price, 520.0);
    expect(items.first.pricingCategory, Contact.categoryWholesale);
    expect(doc.total, 1040.0);

    // 7. Print test: PdfDocumentBuilder generates valid PDF without throwing
    final pdfBytes = await PdfDocumentBuilder.build(
      doc: doc,
      items: items,
      business: disabledBusiness,
      style: PdfStyleSettings(),
      l10n: AppLocalizations('ar'),
      paperSize: PaperSize.a4,
    );
    expect(pdfBytes.isNotEmpty, isTrue);

    // 8. Edit test: update document (e.g. changing notes) preserves snapshot line fields
    final updatedDoc = Document.fromMap({
      ...doc.toMap(),
      'notes': 'ملاحظة بعد تعطيل التسعير بالجملة',
    });
    await db.updateDocumentWithItems(
      updatedDoc,
      items,
      strictStock: true,
    );
    final editedItems = await db.getDocumentItems(docId);
    expect(editedItems.first.price, 520.0);
    expect(editedItems.first.saleUnit, 'كرتونة');
    expect(editedItems.first.baseQuantity, 24.0);
    expect(editedItems.first.pricingCategory, Contact.categoryWholesale);
    expect((await db.getProductById(pid))?.stockQuantity, 76.0);

    // 9. Cancel test: cancelDocument restores exact original base units
    await db.cancelDocument(docId);
    expect((await db.getProductById(pid))?.stockQuantity, 100.0);
  });
}

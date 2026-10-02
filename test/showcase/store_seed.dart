// Realistic demo store used by the showcase screenshots
// (test/showcase/showcase_test.dart). Everything is created through the
// app's own services, so the data is exactly what a real user would have.
// Names, phone numbers and IDs are fictional.
import 'package:sqflite/sqflite.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/contact.dart';
import 'package:warqatek/models/product.dart';
import 'package:warqatek/services/document_service.dart';
import 'package:warqatek/services/inventory_service.dart';

class StoreSeed {
  final Business business;
  final Map<String, Contact> contacts;
  final Map<String, Product> products;
  final Map<String, int> documents;

  StoreSeed(this.business, this.contacts, this.products, this.documents);
}

DateTime _daysAgo(int d, {int hour = 11, int minute = 0}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - d, hour, minute);
}

Future<StoreSeed> seedStore({String lang = 'ar'}) async {
  final db = DatabaseHelper.instance;
  final ar = lang == 'ar';

  await db.insertBusiness(Business(
    name: ar ? 'البركة للإلكترونيات' : 'Al Baraka Electronics',
    ownerName: ar ? 'عثمان الأمين' : 'Osman Elamin',
    phone: '0912 345 678',
    address: ar
        ? 'أم درمان - السوق الكبير، شارع الموردة'
        : 'Omdurman, Grand Market, Al Mourada St.',
    email: 'sales@albaraka-electronics.example',
    currencyCode: 'SDG',
    taxesEnabled: true,
    taxRate: 17,
    legalName: ar ? 'مؤسسة البركة للإلكترونيات والاتصالات' : 'Al Baraka Electronics & Telecom',
    taxId: '300-418-275',
    commercialReg: '45871',
  ));
  final business = (await db.getFirstBusiness())!;
  await db.setPaymentMethodEnabled('bankak', enabled: true);

  // ── Contacts ──
  final contacts = <String, Contact>{};
  Future<void> contact(String key, String nameAr, String nameEn, String phone,
      {String type = 'customer', String? legal, String? taxId, String? address}) async {
    final c = Contact(
      name: ar ? nameAr : nameEn,
      phone: phone,
      type: type,
      legalName: legal,
      taxId: taxId,
      address: address,
      createdAt: _daysAgo(60),
    );
    final id = await db.insertContact(c);
    contacts[key] = (await db.getContactById(id))!;
  }

  await contact('nile', 'شركة النيل للحلول التقنية', 'Nile Tech Solutions', '0923 456 789',
      legal: ar ? 'شركة النيل للحلول التقنية المحدودة' : 'Nile Tech Solutions Ltd.',
      taxId: '300-552-910', address: ar ? 'الخرطوم - العمارات، شارع 15' : 'Khartoum, Amarat, St. 15');
  await contact('school', 'مدرسة المستقبل الخاصة', 'Future Private School', '0911 222 333',
      address: ar ? 'بحري - الصافية' : 'Bahri, Safiya');
  await contact('mohamed', 'محمد عثمان الطيب', 'Mohamed Osman', '0912 111 222');
  await contact('fatima', 'فاطمة عبد الرحيم', 'Fatima Abdelrahim', '0915 333 444');
  await contact('mustafa', 'مصطفى إبراهيم آدم', 'Mustafa Ibrahim', '0918 555 666');
  await contact('gulf', 'شركة الخليج لتجارة الإلكترونيات', 'Gulf Electronics Trading', '0922 777 888',
      type: 'supplier', taxId: '300-118-004');
  await contact('amin', 'مؤسسة الأمين للتوريدات', 'Al Amin Supplies', '0912 999 000',
      type: 'supplier');

  // ── Products & services (opening stock 45 days ago) ──
  final products = <String, Product>{};
  Future<void> product(String key, String nameAr, String nameEn, double sale,
      double cost, double stock,
      {String type = Product.typeProduct, double minStock = 3, String? barcode, String? unit}) async {
    final id = await db.insertProduct(Product(
      name: ar ? nameAr : nameEn,
      type: type,
      code: key.toUpperCase(),
      barcode: barcode,
      unit: unit,
      salePrice: sale,
      purchasePrice: cost,
      stockQuantity: type == Product.typeProduct ? stock : 0,
      minStock: type == Product.typeProduct ? minStock : 0,
      createdAt: _daysAgo(45),
      updatedAt: _daysAgo(45),
    ));
    products[key] = (await db.getProductById(id))!;
  }

  await product('chg', 'شاحن سريع 25 واط', '25W fast charger', 18000, 12500, 12, barcode: '6291041500011');
  await product('cbl', 'كابل شحن تايب-سي 1 م', 'USB-C cable 1 m', 5000, 3000, 40, minStock: 10, barcode: '6291041500028');
  await product('ear', 'سماعة بلوتوث لاسلكية', 'Wireless earbuds', 45000, 32000, 6, barcode: '6291041500035');
  await product('pwb', 'باور بانك 20000 مللي أمبير', 'Power bank 20000 mAh', 38000, 27000, 5, barcode: '6291041500042');
  await product('wch', 'ساعة ذكية رياضية', 'Smart sport watch', 65000, 48000, 6, barcode: '6291041500059');
  await product('cse', 'كفر حماية سيليكون', 'Silicone case', 6000, 2500, 30, minStock: 10, barcode: '6291041500066');
  await product('scr', 'شاشة حماية زجاجية', 'Tempered glass protector', 4000, 1500, 60, minStock: 15, barcode: '6291041500073');
  await product('mem', 'بطاقة ذاكرة 64 جيجا', 'Memory card 64 GB', 15000, 10500, 20, barcode: '6291041500080');
  await product('rtr', 'راوتر واي فاي محمول 4G', 'Portable 4G Wi-Fi router', 95000, 72000, 8, minStock: 4, barcode: '6291041500097');
  await product('spk', 'مكبر صوت بلوتوث', 'Bluetooth speaker', 55000, 39000, 3, minStock: 2, barcode: '6291041500103');
  await product('fix', 'صيانة شاشة (تبديل)', 'Screen replacement', 35000, 0, 0, type: Product.typeService);
  await product('sw', 'برمجة وتحديث هاتف', 'Phone software update', 10000, 0, 0, type: Product.typeService);
  await product('ins', 'تركيب شاشة حماية', 'Protector fitting', 2000, 0, 0, type: Product.typeService);

  DocumentItemInput line(String key, double qty, {double? price}) {
    final p = products[key]!;
    return DocumentItemInput(
      description: p.name,
      quantity: qty,
      price: price ?? p.salePrice,
      taxable: p.isTaxable,
      productId: p.id,
    );
  }

  DocumentItemInput buy(String key, double qty) =>
      line(key, qty, price: products[key]!.purchasePrice);

  final docs = <String, int>{};
  Future<int> create(String key, String type, int daysAgo,
      {String? contact,
      required List<DocumentItemInput> items,
      double discount = 0,
      String? payNow,
      bool draft = false,
      String? notes,
      int hour = 11}) async {
    final id = await DocumentService.createDocument(
      type: type,
      business: business,
      contact: contact == null ? null : contacts[contact],
      items: items,
      discount: discount,
      date: _daysAgo(daysAgo, hour: hour),
      validUntil: type == 'quotation' ? _daysAgo(daysAgo - 14) : null,
      payNowMethod: payNow,
      isDraft: draft,
      notes: notes,
    );
    docs[key] = id;
    return id;
  }

  Future<void> voucher(String type, int daysAgo, double amount, String method,
      {String? contact, required String reason}) async {
    await DocumentService.createDocument(
      type: type,
      business: business,
      contact: contact == null ? null : contacts[contact],
      items: const [],
      paid: amount,
      notes: reason,
      date: _daysAgo(daysAgo, hour: 9),
      paymentMethod: method,
    );
  }

  // ── Purchases (stock in) ──
  final p1 = await create('purchase1', 'purchase', 38, contact: 'gulf', items: [
    buy('chg', 20), buy('ear', 10), buy('pwb', 10), buy('wch', 4),
  ], notes: ar ? 'شحنة الشهر - دبي' : 'Monthly shipment - Dubai');
  await DocumentService.recordPayment(documentId: p1, amount: 400000, paymentMethod: 'bank');
  final p2 = await create('purchase2', 'purchase', 30, contact: 'amin', items: [
    buy('scr', 100), buy('cse', 50), buy('cbl', 60), buy('mem', 10),
  ]);
  await DocumentService.recordPayment(documentId: p2, amount: 150000, paymentMethod: 'cash');

  // ── Operating expenses ──
  await voucher('expense_voucher', 32, 150000, 'bank',
      reason: ar ? 'إيجار المحل - الشهر الحالي' : 'Shop rent - this month');
  await voucher('expense_voucher', 12, 45000, 'bankak',
      reason: ar ? 'فاتورة الكهرباء' : 'Electricity bill');
  await voucher('expense_voucher', 5, 30000, 'cash',
      reason: ar ? 'رصيد إنترنت ومكالمات' : 'Internet & phone credit');

  // ── Credit sales to companies ──
  final inv1 = await create('nileInvoice', 'invoice', 26, contact: 'nile', items: [
    line('rtr', 4), line('mem', 4), line('sw', 4),
  ], discount: 20000, notes: ar ? 'توريد أجهزة لفرع العمارات' : 'Devices for Amarat branch');
  await DocumentService.recordPayment(documentId: inv1, amount: 300000, paymentMethod: 'bank');
  final inv2 = await create('schoolInvoice', 'invoice', 18, contact: 'school', items: [
    line('pwb', 6), line('cbl', 20), line('chg', 6),
  ]);
  await DocumentService.recordPayment(documentId: inv2, amount: 150000, paymentMethod: 'bankak');
  await create('schoolQuote', 'quotation', 3, contact: 'school', items: [
    line('wch', 10), line('ear', 10),
  ], notes: ar ? 'عرض خاص لجوائز نهاية العام' : 'End-of-year prizes offer');
  await create('nileQuote', 'quotation', 1, contact: 'nile', items: [
    line('rtr', 6), line('sw', 6),
  ]);

  // ── Counter sales (quick sale), last two weeks ──
  final sales = <(int, int, List<DocumentItemInput>, String, String?)>[
    (14, 10, [line('scr', 2), line('ins', 2)], 'cash', null),
    (13, 17, [line('chg', 1), line('cbl', 1)], 'cash', 'mohamed'),
    (11, 12, [line('ear', 1)], 'bankak', 'fatima'),
    (10, 19, [line('fix', 1), line('scr', 1)], 'cash', 'mustafa'),
    (9, 13, [line('cse', 3), line('scr', 3), line('ins', 3)], 'cash', null),
    (7, 18, [line('wch', 1), line('cbl', 1)], 'bankak', null),
    (6, 11, [line('pwb', 1)], 'cash', 'mohamed'),
    (4, 16, [line('spk', 1)], 'bankak', 'fatima'),
    (3, 10, [line('mem', 2), line('cse', 2)], 'cash', null),
    (2, 20, [line('chg', 2), line('scr', 2), line('ins', 2)], 'cash', null),
    (1, 15, [line('ear', 1), line('cse', 1)], 'bank', 'mustafa'),
    (0, 10, [line('scr', 3), line('cse', 2), line('ins', 3)], 'cash', null),
    (0, 12, [line('chg', 1), line('cbl', 2)], 'bankak', 'mohamed'),
    (0, 13, [line('fix', 1)], 'cash', 'fatima'),
  ];
  var n = 0;
  for (final (days, hour, items, method, who) in sales) {
    await create('sale${n++}', 'invoice', days, hour: hour, contact: who, items: items, payNow: method);
  }

  // Unpaid invoice due, a draft and a cancelled one (statuses).
  await create('mustafaInvoice', 'invoice', 4, contact: 'mustafa', items: [line('wch', 1), line('sw', 1)]);
  await create('draftInvoice', 'invoice', 0, contact: 'nile', draft: true, items: [line('rtr', 2)]);
  final cancelled = await create('cancelled', 'invoice', 8, items: [line('spk', 1)]);
  await DocumentService.cancelDocument(cancelled);

  // One damaged speaker written off.
  await InventoryService.adjust(
      productId: products['spk']!.id!, delta: -1, notes: ar ? 'تالف أثناء النقل' : 'Damaged in transit');

  await _alignRecordDates();

  return StoreSeed(business, contacts, products, docs);
}

/// The app stamps receipts, payment rows and stock movements with "now".
/// For a back-dated demo, move them to their document's date so every
/// report tells the same story (fixture only; the app never does this).
Future<void> _alignRecordDates() async {
  final Database db = await DatabaseHelper.instance.database;
  await db.execute('''
    UPDATE documents SET date = (
      SELECT p.date FROM documents p WHERE p.id = documents.related_document_id)
    WHERE type IN ('payment_receipt', 'expense_voucher')
      AND related_document_id IS NOT NULL
      AND related_document_id IN (SELECT id FROM documents WHERE type IN ('invoice', 'purchase'))
  ''');
  await db.execute('''
    UPDATE document_payments SET date = (
      SELECT d.date FROM documents d WHERE d.id = document_payments.document_id)
  ''');
  await db.execute('''
    UPDATE stock_movements SET date = (
      SELECT d.date FROM documents d WHERE d.id = stock_movements.reference_document_id)
    WHERE reference_document_id IS NOT NULL
  ''');
}

import 'package:flutter/material.dart';

class LanguageProvider extends InheritedWidget {
  final String langCode;
  final Future<void> Function(String) onChangeLanguage;

  const LanguageProvider({
    super.key,
    required this.langCode,
    required this.onChangeLanguage,
    required super.child,
  });

  static LanguageProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageProvider>();

  @override
  bool updateShouldNotify(LanguageProvider oldWidget) =>
      langCode != oldWidget.langCode;
}

class AppLocalizations {
  final String langCode;

  AppLocalizations(this.langCode);

  static AppLocalizations of(BuildContext context) {
    final provider = LanguageProvider.of(context);
    return AppLocalizations(provider?.langCode ?? 'ar');
  }

  // ========== APP ==========
  String get appTitle => _t('ورقتك', 'Waraqatak');
  String get tagline => _t('ورقتك جاهزة', 'Your documents, ready');
  String get version => _t('الإصدار', 'Version');

  // ========== NAVIGATION ==========
  String get home => _t('الرئيسية', 'Home');
  String get documents => _t('المستندات', 'Documents');
  String get customers => _t('العملاء', 'Customers');
  String get products => _t('المنتجات', 'Products');
  String get settings => _t('الإعدادات', 'Settings');

  // ========== CREATE DOCUMENTS ==========
  String get createInvoice => _t('فاتورة جديدة', 'New Invoice');
  String get createQuotation => _t('عرض سعر جديد', 'New Quotation');
  String get createPaymentReceipt =>
      _t('إيصال دفع جديد', 'New Payment Receipt');
  String get createExpenseVoucher => _t('سند مصروف جديد', 'New Expense Voucher');
  String get createDocument => _t('إنشاء مستند', 'Create Document');
  String get otherDocument => _t('مستند آخر', 'Other Document');

  // ========== DOCUMENT TYPES ==========
  String get invoice => _t('فاتورة', 'Invoice');
  String get quotation => _t('عرض سعر', 'Quotation');
  String get paymentReceipt => _t('إيصال دفع', 'Payment Receipt');
  String get expenseVoucher => _t('سند مصروف', 'Expense Voucher');
  String get customDocument => _t('مستند مخصص', 'Custom Document');

  // ========== DASHBOARD ==========
  String get salesToday => _t('مبيعات اليوم', "Today's Sales");
  String get invoicesToday => _t('فواتير اليوم', "Today's Invoices");
  String get outstanding => _t('المبالغ المستحقة', 'Outstanding');
  String get recentDocuments => _t('أحدث المستندات', 'Recent Documents');

  // ========== EMPTY STATES ==========
  String get noDocuments => _t('لا توجد مستندات حتى الآن', 'No documents yet');
  String get noDocumentsDescription => _t(
        'أنشئ أول فاتورة أو عرض سعر وابدأ بتنظيم شغلك.',
        'Create your first invoice or quotation and start organizing your work.',
      );
  String get noCustomers => _t('لا يوجد عملاء حتى الآن', 'No customers yet');
  String get noCustomersDescription => _t(
        'أضف عملاءك لتبدأ في إنشاء الفواتير والمستندات.',
        'Add your customers to start creating invoices and documents.',
      );
  String get noProducts => _t('لا توجد منتجات حتى الآن', 'No products yet');
  String get noProductsDescription => _t(
        'أضف منتجاتك لتسهيل إنشاء الفواتير ومتابعة المخزون.',
        'Add your products to make invoices easier and track inventory.',
      );

  // ========== COMMON ACTIONS ==========
  String get search => _t('بحث', 'Search');
  String get all => _t('الكل', 'All');
  String get save => _t('حفظ', 'Save');
  String get cancel => _t('إلغاء', 'Cancel');
  String get delete => _t('حذف', 'Delete');
  String get edit => _t('تعديل', 'Edit');
  String get open => _t('فتح', 'Open');
  String get sharePdf => _t('مشاركة ملف PDF', 'Share PDF');
  String get print => _t('طباعة', 'Print');

  // ========== BUSINESS & SETTINGS ==========
  String get businessData =>
      _t('بيانات النشاط التجاري', 'Business Information');
  String get languageLabel => _t('اللغة', 'Language');
  String get arabic => _t('العربية', 'Arabic');
  String get english => _t('الإنجليزية', 'English');
  String get backup => _t('نسخ احتياطي', 'Backup');
  String get restore => _t('استعادة النسخة الاحتياطية', 'Restore Backup');
  String get about => _t('عن ورقتك', 'About Waraqatak');

  // ========== FINANCIAL ==========
  String get taxRate => _t('نسبة الضريبة', 'Tax Rate');
  String get currency => _t('العملة', 'Currency');
  String get amount => _t('المبلغ', 'Amount');
  String get reason => _t('السبب', 'Reason');

  // ========== PAYMENT ==========
  String get receivedFrom => _t('المستلم من', 'Received From');
  String get paidTo => _t('دُفع إلى', 'Paid To');
  String get paymentMethod => _t('طريقة الدفع', 'Payment Method');
  String get cash => _t('نقداً', 'Cash');
  String get bankTransfer => _t('تحويل بنكي', 'Bank Transfer');
  String get bankak => _t('بنكك', 'Bankak');
  String get okash => _t('أوكاش', 'O-Cash');

  // New payment methods
  String get mada => _t('مدى', 'Mada');
  String get creditCard => _t('بطاقة ائتمان', 'Credit Card');
  String get mobileWallet => _t('محفظة جوال', 'Mobile Wallet');
  String get fawry => _t('فوري', 'Fawry');
  String get paypal => _t('باي بال', 'PayPal');

  // ========== GENERAL ==========
  String get notes => _t('ملاحظات', 'Notes');
  String get customer => _t('العميل', 'Customer');
  String get supplier => _t('المورد', 'Supplier');

  // ========== PRODUCTS & INVENTORY ==========
  String get productName => _t('اسم المنتج', 'Product Name');
  String get productCode => _t('رمز المنتج', 'Product Code');
  String get unitPrice => _t('سعر البيع', 'Selling Price');
  String get purchasePrice => _t('سعر الشراء', 'Purchase Price');
  String get quantity => _t('الكمية', 'Quantity');
  String get price => _t('السعر', 'Price');
  String get total => _t('الإجمالي', 'Total');
  String get stock => _t('المخزون', 'Inventory');
  String get stockQuantity => _t('الكمية المتوفرة', 'Stock Quantity');
  String get lowStockThreshold => _t('حد التنبيه', 'Low Stock Threshold');
  String get lowStock => _t('المخزون منخفض', 'Low Stock');
  String get outOfStock => _t('نفد المخزون', 'Out of Stock');
  String get minStock => _t('الحد الأدنى للمخزون', 'Minimum Stock');

  // ========== TOTALS ==========
  String get subtotal => _t('المجموع الفرعي', 'Subtotal');
  String get discount => _t('الخصم', 'Discount');
  String get tax => _t('الضريبة', 'Tax');
  String get grandTotal => _t('الإجمالي النهائي', 'Grand Total');
  String get paid => _t('المدفوع', 'Paid');
  String get remaining => _t('المتبقي', 'Remaining');

  // ========== TAX ==========
  String get taxable => _t('خاضع للضريبة', 'Taxable');
  String get nonTaxable => _t('غير خاضع للضريبة', 'Non-Taxable');

  // ========== CUSTOMER ==========
  String get walkInCustomer => _t('عميل نقدي', 'Walk-in Customer');

  // ========== OPERATION MESSAGES ==========
  String get operationSuccessful =>
      _t('تمت العملية بنجاح', 'Operation completed successfully');
  String get operationFailed => _t(
        'حدث خطأ أثناء تنفيذ العملية',
        'An error occurred while performing the operation',
      );
  String get confirmDelete => _t('تأكيد الحذف', 'Confirm Deletion');
  String get deleteDocumentMessage =>
      _t('هل تريد حذف هذا المستند؟', 'Delete this document?');
  String get deleteCustomerMessage =>
      _t('هل تريد حذف هذا العميل؟', 'Delete this customer?');
  String get deleteProductMessage =>
      _t('هل تريد حذف هذا المنتج؟', 'Delete this product?');
  String get productUsedInDocuments => _t(
      'لا يمكن حذف منتج مستخدم في مستندات سابقة.',
      'A product used in existing documents cannot be deleted.');

  // ========== BUSINESS SETUP ==========
  String get setupBusiness =>
      _t('إعداد النشاط التجاري', 'Set Up Your Business');
  String get welcomeFirstTime => _t(
        'مرحباً بك في ورقتك. ابدأ بإعداد بيانات نشاطك التجاري.',
        'Welcome to Waraqatak. Start by setting up your business information.',
      );
  String get startNow => _t('ابدأ الآن', 'Get Started');
  String get businessName => _t('اسم النشاط التجاري', 'Business Name');
  String get ownerName => _t('اسم المالك', 'Owner Name');
  String get businessLogo => _t('شعار النشاط التجاري', 'Business Logo');
  String get changeLogo => _t('تغيير الشعار', 'Change Logo');
  String get removeLogo => _t('إزالة الشعار', 'Remove Logo');
  String get logoLoadFailed =>
      _t('تعذر تحميل الشعار', 'Could not load the logo');

  // ========== DOCUMENT FIELDS ==========
  String get type => _t('النوع', 'Type');
  String get itemDescription => _t('وصف البند', 'Item Description');
  String get itemQuantity => _t('الكمية', 'Quantity');
  String get itemPrice => _t('السعر', 'Price');
  String get date => _t('التاريخ', 'Date');
  String get validUntil => _t('صالح حتى', 'Valid Until');
  String get validityDays =>
      _t('مدة صلاحية العرض', 'Quotation Validity Period');
  String get title => _t('العنوان', 'Title');
  String get content => _t('المحتوى', 'Content');

  // ========== VALIDATION ==========
  String get required => _t('هذا الحقل مطلوب', 'This field is required');
  String get invalidQuantity => _t(
      'يجب أن تكون الكمية أكبر من صفر', 'Quantity must be greater than zero');
  String get invalidAmount => _t('أدخل مبلغاً صحيحاً', 'Enter a valid amount');

  // ========== CONTACT DETAILS ==========
  String get phone => _t('رقم الهاتف', 'Phone Number');
  String get address => _t('العنوان', 'Address');
  String get email => _t('البريد الإلكتروني', 'Email');

  // ========== BACKUP / RESTORE ==========
  String get backupDescription =>
      _t('إنشاء نسخة احتياطية من بياناتك', 'Create a backup of your data');
  String get saveBackupTo => _t('حفظ نسخة إلى...', 'Save Backup to...');
  String get backupSavedTo => _t(
        'تم حفظ النسخة في الموقع المحدد',
        'Backup saved to the selected location',
      );
  String get backupSaveFailed => _t('فشل حفظ النسخة', 'Failed to save backup');
  String get confirmRestore =>
      _t('استعادة النسخة الاحتياطية؟', 'Restore backup?');
  String get restoreWarning => _t(
        'سيتم استبدال البيانات الحالية بالبيانات الموجودة في النسخة الاحتياطية. لا يمكن التراجع عن هذا الإجراء.',
        'Your current data will be replaced with the data in the backup. This action cannot be undone.',
      );
  String get backupRestore =>
      _t('النسخ الاحتياطي والاستعادة', 'Backup & Restore');

  // ========== PDF ==========
  String get documentNumber => _t('رقم المستند', 'Document Number');
  String get customerOrParty => _t('العميل/الجهة', 'Customer/Party');
  String get item => _t('البند', 'Item');

  // ========== ABOUT / FREE ==========
  String get aboutDescription => _t(
        'ورقتك تطبيق محاسبة بسيط لإنشاء الفواتير وعروض الأسعار والإيصالات، مع متابعة المدفوعات وإدارة العملاء والمنتجات — يعمل بالكامل من هاتفك دون الحاجة لإنترنت.',
        'Waraqatak is a simple business document app for creating invoices, quotations, and receipts. Track payments, manage customers and products — all offline, directly on your phone.',
      );
  String get arabicEnglishSupport =>
      _t('العربية والإنجليزية', 'Arabic & English');
  String get offlineFirst =>
      _t('يعمل بدون إنترنت', 'Works fully offline');
  String get paymentTracking =>
      _t('متابعة المدفوعات والإيصالات', 'Payment & receipt tracking');
  String get documentStatusTracking =>
      _t('متابعة حالة المستندات', 'Document status tracking');

  // ========== CONTACT ==========
  String get contactWhatsApp => _t('واتساب', 'WhatsApp');
  String get contactEmail => _t('البريد الإلكتروني', 'Email');
  String get contactMessage => _t(
        'السلام عليكم، أريد التواصل بخصوص تطبيق ورقتك.',
        'Hello, I would like to get in touch about Waraqatak.',
      );
  String get contactEmailSubject =>
      _t('تواصل بخصوص ورقتك', 'Waraqatak Inquiry');

  // ========== PRIVACY ==========
  String get privacyPolicy => _t('سياسة الخصوصية', 'Privacy Policy');
  String get privacySettingsDescription => _t(
        'تعرف على كيفية تعامل ورقتك مع بياناتك وبيانات نشاطك التجاري.',
        'Learn how Waraqatak handles your data and business information.',
      );

  String get facebook => _t('فيسبوك', 'Facebook');
  String get fromYourPhone => _t('من هاتفك', 'From your phone');
  String get contact => _t('تواصل', 'Contact');

  // ========== DOCUMENT STATUS ==========
  String get statusDraft         => _t('مسودة',           'Draft');
  String get statusIssued        => _t('صادرة',           'Issued');
  String get statusPartiallyPaid => _t('مدفوعة جزئياً',  'Partially Paid');
  String get statusPaid          => _t('مدفوعة',          'Paid');
  String get statusCancelled     => _t('ملغاة',           'Cancelled');

  // ========== PAYMENT RECORDING ==========
  String get recordPayment      => _t('تسجيل دفعة',             'Record Payment');
  String get paymentRecorded    => _t('تم تسجيل الدفعة بنجاح',  'Payment recorded');
  String get paymentHistory     => _t('سجل الدفعات',            'Payment History');
  String get paymentAmountLabel => _t('مبلغ الدفعة',            'Payment Amount');
  String get noPaymentsYet      => _t('لا توجد دفعات بعد',      'No payments yet');

  // ========== CANCELLATION ==========
  String get cancelDocument        => _t('إلغاء المستند', 'Cancel Document');
  String get confirmCancel         => _t('تأكيد الإلغاء', 'Confirm Cancellation');
  String get cancelDocumentMessage => _t(
    'هل تريد إلغاء هذا المستند؟ لا يمكن التراجع عن هذا الإجراء.',
    'Cancel this document? This cannot be undone.',
  );
  String get cancelReceiptMessage => _t(
    'إلغاء هذا الإيصال سيعكس الدفعة المرتبطة به ويُحدّث حالة الفاتورة.',
    'Cancelling this receipt will reverse its payment and update the invoice.',
  );

  // ========== DRAFT / ISSUE ==========
  String get saveDraft    => _t('حفظ كمسودة',      'Save as Draft');
  String get issueDocument => _t('إصدار المستند',   'Issue Document');
  String get issueInvoice  => _t('إصدار الفاتورة',  'Issue Invoice');

  // ========== DOCUMENT CYCLE ==========
  String get convertToInvoice      => _t('تحويل إلى فاتورة',          'Convert to Invoice');
  String get convertConfirm        => _t('تحويل عرض السعر إلى فاتورة؟', 'Convert this quotation to an invoice?');
  String get convertConfirmBody    => _t(
    'سيتم إنشاء فاتورة مسودة بناءً على بيانات عرض السعر. يمكنك مراجعتها قبل الإصدار.',
    'A draft invoice will be created from this quotation. Review it before issuing.',
  );
  String get convertedToInvoice    => _t('تم تحويله إلى فاتورة',      'Converted to Invoice');
  String get openInvoice           => _t('فتح الفاتورة',               'Open Invoice');
  String get copyDocument          => _t('نسخ المستند',                'Copy Document');
  String get documentCopied        => _t('تم نسخ المستند',             'Document copied');
  String get relatedInvoice        => _t('عن فاتورة',                  'Related Invoice');
  String get relatedDocument       => _t('المستند المرتبط',            'Related Document');
  String get sourceQuotation       => _t('من عرض سعر',                 'From Quotation');
  String get paymentReversed       => _t('تم عكس الدفعة',              'Payment reversed');
  String get viewReceipt           => _t('عرض الإيصال',                'View Receipt');

  // ========== DOCUMENTS SCREEN EMPTY STATES ==========
  String get noDocumentsTitle    => _t('لا توجد مستندات بعد',      'No documents yet');
  String get noDocumentsHint     => _t('أنشئ أول فاتورة أو عرض سعر وابدأ.', 'Create your first invoice or quotation.');
  String get noSearchResults     => _t('لم نجد مستندات مطابقة',    'No matching documents');
  String get noSearchResultsHint => _t('جرّب رقم المستند أو اسم العميل.', 'Try a document number or customer name.');

  // ========== PAYMENT METHODS CONFIG ==========
  String get paymentMethods => _t('طرق الدفع', 'Payment Methods');
  String get configurePaymentMethods =>
      _t('اختر طرق الدفع المتاحة في تطبيقك', 'Choose which payment methods to show');

  // ========== MISC ==========
  String get retry => _t('إعادة المحاولة', 'Retry');
  String get items => _t('البنود', 'Items');

  // ========== PRODUCTS PHASE 3.1 ==========
  String get productType => _t('نوع المنتج', 'Product Type');
  String get productItem => _t('منتج', 'Product');
  String get serviceItem => _t('خدمة', 'Service');
  String get barcode => _t('الباركود', 'Barcode');
  String get sku => _t('رمز المخزون (SKU)', 'SKU');
  String get unit => _t('وحدة القياس', 'Unit');
  String get active => _t('نشط', 'Active');
  String get inactive => _t('غير نشط', 'Inactive');
  String get addItem    => _t('إضافة بند',   'Add Item');
  String get addProduct => _t('إضافة منتج', 'Add Product');
  String get addService => _t('إضافة خدمة', 'Add Service');
  String get editProduct => _t('تعديل المنتج', 'Edit Product');
  String get editService => _t('تعديل الخدمة', 'Edit Service');
  String get deactivateProduct => _t('تعطيل المنتج', 'Deactivate Product');
  String get activateProduct => _t('تفعيل المنتج', 'Activate Product');
  String get deactivateProductMessage => _t(
    'هذا المنتج مستخدم في مستندات سابقة. هل تريد تعطيله بدلاً من حذفه؟',
    'This product is used in existing documents. Deactivate it instead of deleting?',
  );
  String get productDeactivated => _t('تم تعطيل المنتج', 'Product deactivated');
  String get productActivated => _t('تم تفعيل المنتج', 'Product activated');
  String get scanBarcode => _t('مسح الباركود', 'Scan Barcode');
  String get barcodeScanner => _t('ماسح الباركود', 'Barcode Scanner');
  String get barcodeNotFound => _t('لم يُعثر على منتج بهذا الباركود', 'No product found for this barcode');
  String get duplicateBarcode => _t('هذا الباركود مستخدم لمنتج آخر', 'This barcode is already used by another product');
  String get createFromBarcode => _t('إنشاء منتج جديد', 'Create New Product');
  String get allTypes => _t('الكل', 'All');
  String get productsOnly => _t('المنتجات', 'Products');
  String get servicesOnly => _t('الخدمات', 'Services');

  // ========== DEVELOPER ==========
  String get developer => _t('المطور', 'Developer');
  String get madeBy => _t('تطوير', 'Made by');
  String get visitWebsite => _t('الموقع الإلكتروني', 'Website');
  String get viewOnGitHub => _t('GitHub', 'GitHub');
  String get waraqatakProductPage => _t('صفحة المنتج', 'Product Page');

  // ========== PHASE 3.2 — PURCHASES ==========
  String get purchase          => _t('أمر شراء',        'Purchase Order');
  String get purchases         => _t('أوامر الشراء',    'Purchase Orders');
  String get newPurchase       => _t('أمر شراء جديد',   'New Purchase Order');
  String get finalizePurchase  => _t('إصدار أمر الشراء', 'Finalize Purchase');
  String get purchaseDocument  => _t('مستند شراء',      'Purchase Document');
  String get purchasesOnly     => _t('الشراء',          'Purchases');

  // ========== PHASE 3.2 — SUPPLIERS ==========
  String get suppliers          => _t('الموردون',            'Suppliers');
  String get suppliersOnly      => _t('الموردون',            'Suppliers');
  String get noSuppliers        => _t('لا يوجد موردون بعد', 'No suppliers yet');
  String get supplierBalance    => _t('رصيد المورد',         'Supplier Balance');
  String get payable            => _t('مستحق الدفع',         'Payable');

  // ========== PHASE 3.2 — CUSTOMERS EXTENDED ==========
  String get customerBalance    => _t('رصيد العميل',         'Customer Balance');
  String get receivable         => _t('مستحق الاستلام',      'Receivable');
  String get deactivateContact         => _t('تعطيل جهة الاتصال', 'Deactivate Contact');
  String get activateContact           => _t('تفعيل جهة الاتصال',  'Activate Contact');
  String get deactivateContactMessage  => _t(
    'هذه الجهة مستخدمة في مستندات سابقة. هل تريد تعطيلها؟',
    'This contact is used in existing documents. Deactivate instead of deleting?',
  );
  String get contactDeactivated => _t('تم تعطيل جهة الاتصال', 'Contact deactivated');
  String get contactActivated   => _t('تم تفعيل جهة الاتصال',  'Contact activated');
  String get activeOnly         => _t('النشطة فقط',             'Active only');

  // ========== PHASE 3.2 — INVENTORY ==========
  String get inventory         => _t('المخزون',               'Inventory');
  String get stockMovements    => _t('حركات المخزون',         'Stock Movements');
  String get stockMovement     => _t('حركة مخزون',            'Stock Movement');
  String get openingStock      => _t('رصيد افتتاحي',          'Opening Stock');
  String get adjustStock       => _t('تعديل يدوي',            'Manual Adjustment');
  String get stockAdjustment   => _t('تعديل المخزون',         'Stock Adjustment');
  String get adjustmentDelta   => _t('كمية التعديل (+ أو -)', 'Adjustment Delta (+ or -)');
  String get noMovements       => _t('لا توجد حركات مخزون',  'No stock movements');
  String get lowStockAlert     => _t('تنبيه مخزون منخفض',    'Low Stock Alert');
  String get insufficientStockFor => _t('مخزون غير كافٍ لـ', 'Insufficient stock for');
  String insufficientStock(String name, double available, double required) =>
      langCode == 'ar'
          ? 'مخزون غير كافٍ لـ "$name": المتاح ${available.toStringAsFixed(2)}، المطلوب ${required.toStringAsFixed(2)}'
          : 'Insufficient stock for "$name": available ${available.toStringAsFixed(2)}, required ${required.toStringAsFixed(2)}';

  // ========== PHASE 3.3 — DASHBOARD DATE FILTERS ==========
  String get today         => _t('اليوم',          'Today');
  String get last7Days     => _t('آخر 7 أيام',    'Last 7 Days');
  String get thisMonth     => _t('هذا الشهر',     'This Month');
  String get customRange   => _t('فترة مخصصة',    'Custom Range');

  // ========== PHASE 3.3 — DASHBOARD CARDS ==========
  String get salesPeriod         => _t('المبيعات',           'Sales');
  String get purchasesPeriod     => _t('المشتريات',          'Purchases');
  String get paymentsIn          => _t('مدفوعات واردة',      'Payments In');
  String get paymentsOut         => _t('مدفوعات صادرة',      'Payments Out');
  String get allTimeBalance      => _t('الرصيد الكلي',       'All-time Balance');
  String get noDataForPeriod     => _t('لا توجد بيانات خلال هذه الفترة', 'No data for this period');
  String get inventorySummary    => _t('ملخص المخزون',       'Inventory Summary');
  String get trackedProducts     => _t('منتجات مسجّلة',      'Tracked Products');
  String get viewInventory       => _t('عرض المخزون',        'View Inventory');
  String get viewReports         => _t('التقارير',           'Reports');

  // ========== PHASE 3.3 — REPORTS HUB ==========
  String get reports          => _t('التقارير',            'Reports');
  String get salesReport      => _t('تقرير المبيعات',      'Sales Report');
  String get purchasesReport  => _t('تقرير المشتريات',     'Purchases Report');
  String get paymentsReport   => _t('تقرير المدفوعات',     'Payments Report');
  String get customerReport   => _t('تقرير العملاء',       'Customer Report');
  String get supplierReport   => _t('تقرير الموردين',      'Supplier Report');
  String get inventoryReport  => _t('تقرير المخزون',       'Inventory Report');
  String get productReport    => _t('تقرير المنتجات',      'Product Report');

  // ========== PHASE 3.3 — REPORT FIELDS ==========
  String get totalSales       => _t('إجمالي المبيعات',     'Total Sales');
  String get totalPurchasesAmt => _t('إجمالي المشتريات',   'Total Purchases');
  String get totalPaid        => _t('إجمالي المدفوع',      'Total Paid');
  String get totalOutstanding => _t('إجمالي المتبقي',      'Total Outstanding');
  String get invoiceCount     => _t('عدد الفواتير',         'Invoices');
  String get purchaseCount    => _t('عدد الطلبات',          'Orders');
  String get cancelledCount   => _t('ملغاة',                'Cancelled');
  String get finalized        => _t('مكتملة',               'Finalized');
  String get receivedPayments => _t('مدفوعات واردة',        'Received Payments');
  String get madePayments     => _t('مدفوعات صادرة',        'Made Payments');
  String get salesQty         => _t('كمية المبيعات',        'Sales Qty');
  String get salesValue       => _t('قيمة المبيعات',        'Sales Value');
  String get purchasedQty     => _t('كمية المشتريات',       'Purchased Qty');
  String get stockStatus      => _t('حالة المخزون',         'Stock Status');
  String get noReportData     => _t('لا توجد بيانات لهذا التقرير', 'No report data');
  String get relatedDoc       => _t('المستند المرجعي',      'Related Doc');

  // ========== PHASE 3.3 — PRINT SETTINGS ==========
  String get printSettings    => _t('إعدادات الطباعة',     'Print Settings');
  String get paperSize        => _t('حجم الورق',            'Paper Size');
  String get paperA4          => _t('A4',                   'A4');
  String get paperA5          => _t('A5',                   'A5');
  String get paperThermal80   => _t('حرارية 80مم',          'Thermal 80mm');
  String get defaultPaperSize => _t('حجم الورق الافتراضي', 'Default Paper Size');

  // ========== PHASE 3.4 — PAYMENT METHODS ==========
  String get addPaymentMethod    => _t('إضافة طريقة دفع',         'Add Payment Method');
  String get editPaymentMethod   => _t('تعديل طريقة الدفع',       'Edit Payment Method');
  String get methodName          => _t('اسم الطريقة',             'Method Name');
  String get predefinedMethods   => _t('الطرق المتاحة',           'Available Methods');
  String get customMethods       => _t('طرق مخصصة',               'Custom Methods');
  String get noCustomMethods     => _t('لا توجد طرق مخصصة بعد',  'No custom methods yet');
  String get confirmDeleteMethod => _t('حذف طريقة الدفع',         'Delete Payment Method');

  // ========== PHASE 3.6 — PAYMENT METHODS DB ==========
  String get defaultMethod          => _t('الافتراضي',                     'Default');
  String get setAsDefault           => _t('تعيين كافتراضي',                'Set as Default');
  String get cannotDeleteMethodInUse => _t('لا يمكن حذف طريقة مستخدمة في مستندات', 'Cannot delete: method used in documents');
  String get methodLabelAr          => _t('الاسم بالعربية',                'Arabic Name');
  String get methodLabelEn          => _t('الاسم بالإنجليزية',             'English Name');
  String get noPaymentMethodsEnabled => _t('لا توجد طرق دفع مفعّلة',     'No payment methods enabled');

  // ========== PHASE 3.4 — SCANNER ==========
  String get scannerHint       => _t('وجّه الكاميرا نحو الباركود',     'Point camera at barcode');
  String get scannerPermDenied => _t('يتطلب إذن الكاميرا',             'Camera permission required');
  String get scannerPermMsg    => _t('امنح إذن الكاميرا للمسح الضوئي', 'Grant camera permission to scan barcodes');
  String get manualEntry       => _t('إدخال يدوي',                     'Manual Entry');

  // ========== PHASE 3.4 — INVENTORY ==========
  String get newStockQuantity => _t('الكمية بعد التعديل', 'New Stock Quantity');
  String get adjustmentReason => _t('سبب التعديل',        'Adjustment Reason');
  String get inStock          => _t('متوفر',              'In Stock');
  String get scanToLocate     => _t('مسح للبحث',          'Scan to Locate');

  // ========== PHASE 3.4 — AUDIT ==========
  String get auditLog => _t('سجل الأحداث', 'Audit Log');

  // ========== PHASE 3.5 — FINANCIAL & LEGAL ==========
  String get financialSettings   => _t('الإعدادات المالية والقانونية', 'Financial & Legal Settings');
  String get financialSettingsDesc => _t('الضرائب والهوية القانونية وإعدادات المستندات', 'Taxes, legal identity & document settings');
  String get legalIdentity       => _t('الهوية القانونية',        'Legal Identity');
  String get legalName           => _t('الاسم القانوني',          'Legal / Registered Name');
  String get taxId               => _t('الرقم الضريبي',           'Tax ID');
  String get taxReg              => _t('رقم التسجيل الضريبي',     'Tax Registration No.');
  String get commercialReg       => _t('السجل التجاري',           'Commercial Reg. No.');
  String get branch              => _t('الفرع',                   'Branch');

  String get taxSettings         => _t('إعدادات الضريبة',         'Tax Settings');
  String get taxesEnabled        => _t('تفعيل الضريبة',           'Enable Taxes');
  String get taxesEnabledDesc    => _t('عرض الضريبة في الفواتير', 'Show tax on invoices');
  String get pricesIncludeTax    => _t('الأسعار شاملة الضريبة',  'Prices include tax (inclusive)');
  String get pricesIncludeTaxDesc => _t('سعر الوحدة يشمل الضريبة بالفعل', 'Unit price already includes tax');
  String get defaultTaxProfile   => _t('ملف ضريبي افتراضي',       'Default Tax Profile');
  String get noDefaultProfile    => _t('لا يوجد ملف افتراضي',     'No default profile');

  String get taxProfiles         => _t('ملفات الضريبة',           'Tax Profiles');
  String get taxProfilesDesc     => _t('إنشاء وإدارة معدلات الضريبة', 'Create and manage tax rates');
  String get addTaxProfile       => _t('إضافة ملف ضريبي',         'Add Tax Profile');
  String get editTaxProfile      => _t('تعديل الملف الضريبي',     'Edit Tax Profile');
  String get taxProfileName      => _t('اسم الملف الضريبي',       'Profile Name');
  String get taxProfileType      => _t('نوع الضريبة',             'Tax Type');
  String get taxProfileRate      => _t('نسبة الضريبة (%)',         'Tax Rate (%)');
  String get taxProfileDefault   => _t('افتراضي',                  'Default');
  String get taxProfileInclusive => _t('شامل (مضمّن في السعر)',   'Inclusive (in price)');
  String get taxProfileExclusive => _t('غير شامل (يضاف للسعر)',  'Exclusive (added on top)');
  String get calculationMode     => _t('طريقة الاحتساب',          'Calculation Mode');
  String get noTaxProfiles       => _t('لا توجد ملفات ضريبية بعد', 'No tax profiles yet');
  String get confirmDeleteProfile => _t('حذف الملف الضريبي؟',     'Delete Tax Profile?');
  String get taxTypeVat          => _t('ضريبة القيمة المضافة',    'VAT');
  String get taxTypeSalesTax     => _t('ضريبة المبيعات',          'Sales Tax');
  String get taxTypeServiceCharge => _t('رسوم خدمة',             'Service Charge');
  String get taxTypeOther        => _t('أخرى',                    'Other');

  String get documentSettings    => _t('إعدادات المستند',          'Document Settings');
  String get invoiceTitle        => _t('عنوان الفاتورة',           'Invoice Title');
  String get invoiceTitleDesc    => _t('يظهر في رأس الفاتورة بدلاً من "فاتورة"', 'Shown on invoice instead of "Invoice"');
  String get legalFooter         => _t('التذييل القانوني',          'Legal Footer');
  String get legalFooterDesc     => _t('نص يظهر في أسفل كل فاتورة', 'Text shown at the bottom of each invoice');

  String get contactLegalName    => _t('الاسم القانوني للجهة',     'Contact Legal Name');
  String get contactTaxId        => _t('الرقم الضريبي للجهة',      'Contact Tax ID');
  String get taxProfile          => _t('الملف الضريبي',            'Tax Profile');
  String get noTaxProfile        => _t('بدون ملف ضريبي',           'No Tax Profile');

  // ========== PHASE 3.8 — SUBSCRIPTION ==========
  String get subscription              => _t('الاشتراك',                               'Subscription');
  // Status labels
  String get trialActiveStatus         => _t('تجربة مجانية نشطة',                     'Free Trial Active');
  String get trialExpiredStatus        => _t('انتهت التجربة',                          'Trial Expired');
  String get licensedStatus            => _t('مرخّص',                                  'Licensed');
  String get licenseExpiredStatus      => _t('انتهى الترخيص',                         'License Expired');
  String get licenseRevokedStatus      => _t('تم إلغاء الترخيص',                      'License Revoked');
  String get orderPendingStatus        => _t('الطلب قيد المراجعة',                    'Order Pending');
  String get orderRejectedStatus       => _t('تم رفض الطلب',                          'Order Rejected');
  String get deviceLimitStatus         => _t('تجاوزت حد الأجهزة',                    'Device Limit Reached');
  // Trial
  String get daysLeftInTrial           => _t('يوم متبقٍ في التجربة',                  'day(s) left in trial');
  String get trialFreeDays             => _t('١٤ يوماً مجاناً — بدون قيود',          '14 days free — no limits');
  // Plans
  String get choosePlan                => _t('اختر خطتك',                             'Choose Your Plan');
  String get mostPopularBadge          => _t('الأكثر طلباً',                          'Most Popular');
  String get saveBadge                 => _t('وفّر',                                  'Save');
  String get perMonthSuffix            => _t('/ شهر',                                 '/ mo');
  String get equivalentMonthly         => _t('ما يعادل',                              'Equiv.');
  String get subscriptionRenewable     => _t('قابل للتجديد',                         'Renewable');
  String get limitedPromoOffer         => _t('عرض ترويجي محدود',                      'Limited Promotional Offer');
  // Actions
  String get subscribeNow              => _t('اشترك الآن',                            'Subscribe Now');
  String get renewNow                  => _t('جدّد الاشتراك',                         'Renew Now');
  String get renewEarly                => _t('تجديد مبكر للاشتراك',                   'Renew Subscription Early');
  String get licenseActiveDesc         => _t('اشتراكك نشط ومفعّل على هذا الجهاز.',   'Your subscription is active on this device.');
  String get checkOrderStatus          => _t('فحص حالة الطلب',                       'Check Order Status');
  String get submitOrder               => _t('إرسال الطلب',                           'Submit Order');
  String get tryAgain                  => _t('إعادة المحاولة',                        'Try Again');
  String get contactUs                 => _t('تواصل معنا',                            'Contact Us');
  String get cancelAndResubmit         => _t('إلغاء وإعادة الاشتراك',                'Cancel & Re-subscribe');
  String get continueUsingApp          => _t('الدخول إلى ورقاتك',                    'Enter Waraqatak');
  String get activating                => _t('جارٍ التفعيل…',                        'Activating…');
  // Paywall
  String get trialExpiredHeadline      => _t('انتهت التجربة المجانية',                'Free Trial Ended');
  String get trialExpiredBody          => _t('استمر في ورقاتك باشتراك يناسبك.',      'Continue with a plan that suits you.');
  String get licenseExpiredHeadline    => _t('انتهى اشتراكك',                         'Subscription Ended');
  String get licenseExpiredBody        => _t('جدّد اشتراكك للاستمرار.',              'Renew to continue using Waraqatak.');
  String get dataAlwaysSafe            => _t('بياناتك محفوظة دائماً — حتى بعد انتهاء الاشتراك.', 'Your data is always safe — even after subscription ends.');
  // Payment flow
  String get choosePaymentMethod       => _t('طريقة الدفع',                           'Payment Method');
  String get paymentInstructions       => _t('تعليمات الدفع',                         'Payment Instructions');
  String get buyerNameLabel            => _t('اسمك الكامل',                           'Your Full Name');
  String get buyerContactLabel         => _t('هاتف أو بريد إلكتروني',                'Phone or Email');
  String get attachProof               => _t('إرفاق إيصال الدفع (اختياري)',          'Attach Payment Proof (optional)');
  String get proofNoteLabel            => _t('ملاحظة (اختياري)',                      'Note (optional)');
  String get orderSubmittedTitle       => _t('تم إرسال طلبك',                        'Order Submitted');
  String get orderReferenceLabel       => _t('رقم الطلب',                             'Order Reference');
  String get orderPendingBody          => _t('طلبك قيد مراجعة الإدارة. يمكنك فحص الحالة لاحقاً.', 'Your order is under admin review. Check status later.');
  String get activationSuccessTitle    => _t('تم التفعيل!',                           'Activated!');
  String get activationSuccessBody     => _t('ورقاتك نشطة الآن. استمتع باستخدامها.', 'Waraqatak is now active. Enjoy!');
  String get licenseExpiresOn          => _t('ينتهي بتاريخ',                          'Expires on');
  String get rejectionReason           => _t('سبب الرفض',                             'Rejection Reason');
  String get noPaymentMethodsAvailable => _t('لا توجد طرق دفع متاحة حالياً',        'No payment methods available');
  String get networkError              => _t('تعذّر الاتصال بالخادم',                 'Could not connect to server');
  String get rateLimitError            => _t('الرجاء الانتظار قبل إعادة المحاولة',   'Please wait before retrying');

  // ── License key restore ────────────────────────────────────────────────────
  String get haveALicenseKey       => _t('هل لديك مفتاح ترخيص؟',                       'Have a license key?');
  String get restoreLicense        => _t('استعادة الترخيص',                             'Restore License');
  String get enterLicenseKey       => _t('أدخل مفتاح الترخيص',                          'Enter License Key');
  String get licenseKeyHint        => _t('مثال: XXXX-XXXX-XXXX',                        'e.g. XXXX-XXXX-XXXX');
  String get activate              => _t('تفعيل',                                        'Activate');
  String get formattedPhoneNote    => _t('إذا غيّرت هاتفك أو أعدت تنسيقه، أدخل مفتاح الترخيص الخاص بك لاستعادة وصولك فوراً.', 'If you formatted your phone, enter your license key to instantly restore access.');
  String get invalidLicenseKey     => _t('مفتاح الترخيص غير صحيح أو منتهي الصلاحية',  'Invalid or expired license key');

  // ── Payment form help ──────────────────────────────────────────────────────
  String get enterCorrectDataNote  => _t('أدخل بياناتك الصحيحة — سنتواصل معك إذا واجهنا أي مشكلة ونرسل لك مفتاح الترخيص.', 'Enter your correct details — we\'ll contact you if there\'s any issue and send your license key.');
  String get buyerNameHelper       => _t('اسمك الكامل كما هو، حتى نتعرف على دفعتك',    'Your full name, so we can identify your payment');
  String get buyerContactHelper    => _t('هاتفك أو بريدك — نتواصل بك إذا احتجنا لذلك',  'Your phone or email — we\'ll reach you if needed');

  String _t(String ar, String en) => langCode == 'ar' ? ar : en;
}

import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

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
  String get createExpenseVoucher =>
      _t('سند مصروف جديد', 'New Expense Voucher');
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
  String get confirm => _t('تأكيد', 'Confirm');
  String get delete => _t('حذف', 'Delete');
  String get edit => _t('تعديل', 'Edit');
  String get open => _t('فتح', 'Open');
  String get sharePdf => _t('مشاركة ملف PDF', 'Share PDF');
  String get print => _t('طباعة', 'Print');
  String get unsavedChangesTitle => _t('تغييرات غير محفوظة', 'Unsaved Changes');
  String get unsavedChangesMessage => _t(
    'لديك تعديلات لم يتم حفظها. هل تريد بالتأكيد الخروج وإلغاء التعديلات؟',
    'You have unsaved changes. Are you sure you want to discard them and leave?',
  );
  String get discardChanges => _t('تجاهل التعديلات', 'Discard Changes');
  String get confirmDeleteLine => _t('حذف هذا البند؟', 'Delete this item?');
  String get deleteLineWarning => _t(
    'هل تريد بالتأكيد إزالة هذا البند من المستند؟',
    'Are you sure you want to remove this item from the document?',
  );

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
  String get cheque => _t('شيك', 'Cheque');

  // New payment methods
  String get mada => _t('مدى', 'Mada');
  String get creditCard => _t('بطاقة ائتمان', 'Credit Card');
  String get mobileWallet => _t('محفظة جوال', 'Mobile Wallet');
  String get fawry => _t('فوري', 'Fawry');
  String get paypal => _t('باي بال', 'PayPal');

  // ========== GENERAL ==========
  String get notes => _t('ملاحظات', 'Notes');
  String get details => _t('التفاصيل', 'Details');
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
    'A product used in existing documents cannot be deleted.',
  );

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
    'يجب أن تكون الكمية أكبر من صفر',
    'Quantity must be greater than zero',
  );
  String get invalidAmount => _t('أدخل مبلغاً صحيحاً', 'Enter a valid amount');

  // ========== CONTACT DETAILS ==========
  String get phone => _t('رقم الهاتف', 'Phone Number');
  String get address => _t('العنوان', 'Address');
  String get email => _t('البريد الإلكتروني', 'Email');

  // ========== BACKUP / RESTORE ==========
  String get backupDescription =>
      _t('إنشاء نسخة احتياطية من بياناتك', 'Create a backup of your data');
  String get saveBackupTo => _t('حفظ نسخة إلى…', 'Save Backup to…');
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
  String get offlineFirst => _t('يعمل بدون إنترنت', 'Works fully offline');
  String get paymentTracking =>
      _t('متابعة المدفوعات والإيصالات', 'Payment & receipt tracking');
  String get documentStatusTracking =>
      _t('متابعة حالة المستندات', 'Document status tracking');

  // ========== CONTACT ==========
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
  String get termsOfUse => _t('شروط الاستخدام', 'Terms of Use');
  String get termsDescription => _t(
    'الشروط التي يحكم استخدامك لتطبيق ورقتك.',
    'The terms that govern your use of Waraqatak.',
  );
  String get deleteAccountData =>
      _t('حذف بيانات الحساب', 'Delete account data');
  String get deleteAccountDataDescription => _t(
    'إرشادات لحذف بياناتك من هذا الجهاز ومن خوادم المطور.',
    'How to delete your data from this device and from the developer servers.',
  );
  String get appLogoLabel => _t('شعار ورقتك', 'Waraqatak logo');

  // ========== DIAGNOSTICS & ERROR REPORTING ==========
  String get diagnosticSharingTitle =>
      _t('مشاركة تقارير الأعطال والتشخيص', 'Share Diagnostic & Crash Reports');
  String get diagnosticSharingDesc => _t(
    'إرسال تقارير تقنية منقحة عند حدوث أخطاء غير متوقعة للمساعدة في تحسين استقرار التطبيق.',
    'Send sanitized technical reports when unexpected errors occur to help improve app stability.',
  );
  String get diagnosticSharingModalTitle =>
      _t('حول تقارير التشخيص والخصوصية', 'About Diagnostics & Privacy');
  String get diagnosticSharingModalBody => _t(
    'نحن نحترم خصوصيتك وأمان بياناتك التجارية:\n\n'
        '• ما نجمعه: إصدار التطبيق، نظام التشغيل، نوع الخطأ التقني، واسم العملية البرمجية (مثل إنشاء PDF)، وسلسلة التتبع البرمجية المنقحة.\n\n'
        '• ما لا نجمعه إطلاقاً: محتوى الفواتير، أسماء وأرقام العملاء أو الموردين، المبالغ المالية، كلمات المرور، أو أي بيانات شخصية.\n\n'
        '• مدة الاحتفاظ: تُحذف التقارير تلقائياً بعد 30 يوماً من خوادمنا.\n\n'
        '• التحكم: يمكنك إيقاف هذه الميزة في أي وقت وحذف التقارير المعلقة فوراً من جهازك.',
    'We fully respect your privacy and business data security:\n\n'
        '• What we collect: App version, operating system version, technical exception type, safe operation name (such as invoice PDF generation), and sanitized stack trace.\n\n'
        '• What we NEVER collect: Invoice contents, customer/supplier names or numbers, monetary amounts, passwords, or personal data.\n\n'
        '• Retention period: Reports are automatically deleted after 30 days from our servers.\n\n'
        '• Control: You can disable this feature at any time and immediately purge any pending reports from your device.',
  );

  // ========== OPEN-SOURCE LICENSES ==========
  String get appName => _t('ورقتك', 'Waraqatak');
  String get openSourceLicenses =>
      _t('التراخيص المفتوحة المصدر', 'Open-source Licenses');
  String get openSourceLicensesDescription => _t(
    'استعرض تراخيص الحزم والخطوط المستخدمة في التطبيق.',
    'View licenses for the packages and fonts used in this app.',
  );
  String get openSourceLicensesLegalese => _t(
    'يستخدم هذا التطبيق مكتبات مفتوحة المصدر وخط Tajawal (رخصة SIL Open Font License 1.1).',
    'This app uses open-source libraries and the Tajawal font (SIL Open Font License 1.1).',
  );

  // ========== BACKUP WARNING & ENCRYPTION ==========
  String get backupUnencryptedTitle =>
      _t('نسخة احتياطية غير مشفرة', 'Unencrypted Backup');
  String get backupUnencryptedWarning => _t(
    'ملف النسخة الاحتياطية يحتوي على بياناتك بصيغة غير مشفرة. '
        'احفظه في مكان آمن ولا تشاركه مع أي شخص لا تثق به.',
    'The backup file contains your data in unencrypted form. '
        'Keep it in a safe place and do not share it with anyone you do not trust.',
  );
  String get backupEncryptionQuestion =>
      _t('هل تريد حماية النسخة بكلمة سر؟', 'Do you want to protect this backup with a password?');
  String get backupWithoutPassword =>
      _t('لا، بدون كلمة سر (غير مشفرة)', 'No, without password (unencrypted)');
  String get backupWithPassword =>
      _t('نعم، حماية بكلمة سر', 'Yes, protect with password');
  String get backupPassword => _t('كلمة المرور', 'Password');
  String get backupConfirmPassword =>
      _t('تأكيد كلمة المرور', 'Confirm password');
  String get backupPasswordRequired =>
      _t('يرجى إدخال كلمة المرور', 'Please enter a password');
  String get backupPasswordMinLength =>
      _t('كلمة المرور يجب أن لا تقل عن 8 أحرف', 'Password must be at least 8 characters');
  String get backupPasswordsDoNotMatch =>
      _t('كلمتا المرور غير متطابقتين', 'Passwords do not match');
  String get backupPasswordWarning => _t(
    'تحذير: إذا نسيت كلمة المرور فلن يستطيع أحد فتح هذه النسخة، لا أنت ولا نحن.',
    'If you forget the password, nobody can open this backup, neither you nor us.',
  );
  String get backupPasswordHint => _t(
    'تلميح: استخدام الأحرف والأرقام الإنجليزية يجنبك اختلاف لوحات المفاتيح.',
    'Tip: Using English letters and digits avoids keyboard differences.',
  );
  String get backupEncryptedTitle =>
      _t('نسخة احتياطية مشفرة', 'Encrypted Backup');
  String get backupEnterPasswordMessage => _t(
    'هذه النسخة محمية بكلمة سر. أدخل كلمة المرور لاستعادتها:',
    'This backup is password-protected. Enter the password to restore it:',
  );
  String get backupIncorrectPassword =>
      _t('كلمة المرور غير صحيحة أو الملف تالف', 'Incorrect password or corrupted backup file');
  String get backupUpdateRequired =>
      _t('حدّث التطبيق لفتح هذه النسخة', 'Update the app to open this backup');
  String get backupCorrupted =>
      _t('ملف النسخة الاحتياطية تالف أو غير صالح', 'Backup file is corrupted or invalid');
  String get backupDecrypting =>
      _t('جاري فك التشفير والتحقق من البيانات…', 'Decrypting and verifying data…');
  String get backupEncrypting =>
      _t('جاري تشفير النسخة الاحتياطية والتحقق…', 'Encrypting backup and verifying…');
  String get backupSlowNotice => _t(
    'قد تستغرق هذه العملية دقيقة على الهواتف القديمة',
    'This operation may take up to a minute on older phones',
  );
  String get continueAction => _t('متابعة', 'Continue');

  String get fromYourPhone => _t('من هاتفك', 'From your phone');
  String get contact => _t('تواصل', 'Contact');

  // ========== DOCUMENT STATUS ==========
  String get statusDraft => _t('مسودة', 'Draft');
  String get statusIssued => _t('صادر', 'Issued');
  String get statusPartiallyPaid => _t('مدفوع جزئياً', 'Partially Paid');
  String get statusPaid => _t('مدفوع', 'Paid');
  String get statusCancelled => _t('ملغي', 'Cancelled');

  // ========== PAYMENT RECORDING ==========
  String get recordPayment => _t('تسجيل دفعة', 'Record Payment');
  String get paymentRecorded => _t('تم تسجيل الدفعة بنجاح', 'Payment recorded');
  String get paymentHistory => _t('سجل الدفعات', 'Payment History');
  String get paymentAmountLabel => _t('مبلغ الدفعة', 'Payment Amount');
  String get noPaymentsYet => _t('لا توجد دفعات بعد', 'No payments yet');

  // ========== CANCELLATION ==========
  String get cancelDocument => _t('إلغاء المستند', 'Cancel Document');
  String get confirmCancel => _t('تأكيد الإلغاء', 'Confirm Cancellation');
  String get cancelDocumentMessage => _t(
    'هل تريد إلغاء هذا المستند؟ لا يمكن التراجع عن هذا الإجراء.',
    'Cancel this document? This cannot be undone.',
  );
  String get cancelReceiptMessage => _t(
    'إلغاء هذا الإيصال سيعكس الدفعة المرتبطة به ويُحدّث حالة الفاتورة.',
    'Cancelling this receipt will reverse its payment and update the invoice.',
  );
  String cannotCancelWithActiveVouchers(String voucherNumbers) => _t(
    'لا يمكن إلغاء المستند لوجود سندات قبض/صرف نشطة مرتبطة به ($voucherNumbers). يرجى إلغاء هذه السندات أولاً.',
    'Cannot cancel document with active payment receipts/vouchers ($voucherNumbers). Please cancel these vouchers first.',
  );
  String get cancelPaidDocumentTitle => _t('تأكيد إلغاء مستند مسدد', 'Confirm Cancellation of Paid Document');
  String cancelPaidRecordedAmount(String amount, String symbol) => _t(
    'المبلغ المسدد المسجل: $amount $symbol',
    'Recorded paid amount: $amount $symbol',
  );
  String get cancelPaidReportsWarning => _t(
    'إلغاء هذا المستند سيؤدي إلى استبعاده واستبعاد دفعاته بالكامل من تقارير المبيعات والمشتريات والدفعات والأرباح وكشوف الحسابات.',
    'Cancelling this document will completely exclude it and its payments from sales, purchases, payments, profits, and statements.',
  );
  String get cancelPaidCustomerReturnInstruction => _t(
    'يجب تسليم هذا المبلغ للعميل يدوياً خارج التطبيق.',
    'This money must be returned to the customer manually outside the app.',
  );
  String get cancelPaidSupplierReturnInstruction => _t(
    'يجب استرداد هذا المبلغ من المورد يدوياً خارج التطبيق.',
    'This money must be recovered from the supplier manually outside the app.',
  );
  String get cancelPaidDoubleCountWarning => _t(
    'تنبيه هام: لا تُسجّل سند صرف لهذا المبلغ؛ لأن الدفعة مستبعدة تلقائياً من تقارير الصندوق، وتسجيل سند صرف سيؤدي إلى خصم المبلغ مرتين.',
    'Important: Do not record an expense voucher for this refund; the payment is already excluded from cash reports, and recording a voucher will deduct it twice.',
  );
  String get cancelPaidDoubleCountWarningPurchase => _t(
    'تنبيه هام: لا تُسجّل سند قبض لهذا المبلغ؛ لأن الدفعة مستبعدة تلقائياً من تقارير الصندوق، وتسجيل سند قبض سيؤدي إلى إضافة المبلغ مرتين.',
    'Important: Do not record a payment receipt for this refund; the payment is already excluded from cash reports, and recording a receipt will add it twice.',
  );
  String get refundStatusLabel => _t('حالة رد المبلغ', 'Refund Status');
  String get refundStatusRequiredHint => _t(
    'يرجى تحديد حالة رد المبلغ لإتمام الإلغاء',
    'Please select the refund status to confirm cancellation',
  );
  String get refundStatusRefunded => _t('تم رد المبلغ', 'Refunded');
  String get refundStatusNotRefunded => _t('لم يُرد بعد', 'Not refunded yet');
  String get refundStatusNotRecorded => _t('لم تُسجَّل حالة الرد', 'Refund status not recorded');
  String get keepDocument => _t('تراجع (إبقاء المستند)', 'Go Back (Keep Document)');
  String get confirmAndCancel => _t('تأكيد وإلغاء المستند', 'Confirm & Cancel Document');
  String get updateRefundStatus => _t('تعديل حالة رد المبلغ', 'Update Refund Status');
  String get refundAuditCardDisclaimer => _t(
    'هذه الملاحظة للسجلات الإدارية فقط ولا تؤثر على التقارير أو الأرصدة الحسابية.',
    'This note is for record-keeping only and does not affect reports or balances.',
  );
  String get cancelledDocumentMoneyCardTitle => _t('حالة أموال المستند الملغى', 'Cancelled Document Money Status');
  String get changeStatus => _t('تعديل الحالة', 'Change Status');

  // ========== DRAFT / ISSUE ==========
  String get saveDraft => _t('حفظ كمسودة', 'Save as Draft');
  String get issueDocument => _t('إصدار المستند', 'Issue Document');
  String get issueInvoice => _t('إصدار الفاتورة', 'Issue Invoice');

  // ========== DOCUMENT CYCLE ==========
  String get convertToInvoice => _t('تحويل إلى فاتورة', 'Convert to Invoice');
  String get convertConfirm => _t(
    'تحويل عرض السعر إلى فاتورة؟',
    'Convert this quotation to an invoice?',
  );
  String get convertConfirmBody => _t(
    'سيتم إنشاء فاتورة مسودة بناءً على بيانات عرض السعر. يمكنك مراجعتها قبل الإصدار.',
    'A draft invoice will be created from this quotation. Review it before issuing.',
  );
  String get convertedToInvoice =>
      _t('تم تحويله إلى فاتورة', 'Converted to Invoice');
  String get openInvoice => _t('فتح الفاتورة', 'Open Invoice');
  String get copyDocument => _t('نسخ المستند', 'Copy Document');
  String get documentCopied => _t('تم نسخ المستند', 'Document copied');
  String get relatedInvoice => _t('عن فاتورة', 'Related Invoice');
  String get relatedDocument => _t('المستند المرتبط', 'Related Document');
  String get sourceQuotation => _t('من عرض سعر', 'From Quotation');
  String get paymentReversed => _t('تم عكس الدفعة', 'Payment reversed');
  String get viewReceipt => _t('عرض الإيصال', 'View Receipt');

  // ========== DOCUMENTS SCREEN EMPTY STATES ==========
  String get noDocumentsTitle => _t('لا توجد مستندات بعد', 'No documents yet');
  String get noDocumentsHint => _t(
    'أنشئ أول فاتورة أو عرض سعر وابدأ.',
    'Create your first invoice or quotation.',
  );
  String get noSearchResults =>
      _t('لم نجد مستندات مطابقة', 'No matching documents');
  String get noSearchResultsHint => _t(
    'جرّب رقم المستند أو اسم العميل.',
    'Try a document number or customer name.',
  );

  // ========== PAYMENT METHODS CONFIG ==========
  String get paymentMethods => _t('طرق الدفع', 'Payment Methods');
  String get configurePaymentMethods => _t(
    'اختر طرق الدفع المتاحة في تطبيقك',
    'Choose which payment methods to show',
  );

  // ========== MISC ==========
  String get retry => _t('إعادة المحاولة', 'Retry');
  String get items => _t('البنود', 'Items');

  // ========== PRODUCTS & CATALOG ==========
  String get productType => _t('نوع المنتج', 'Product Type');
  String get productItem => _t('منتج', 'Product');
  String get serviceItem => _t('خدمة', 'Service');
  String get barcode => _t('الباركود', 'Barcode');
  String get sku => _t('رمز المخزون (SKU)', 'SKU');
  String get unit => _t('وحدة القياس', 'Unit');
  String get active => _t('نشط', 'Active');
  String get inactive => _t('غير نشط', 'Inactive');
  String get addItem => _t('إضافة بند', 'Add Item');
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
  String get flashlight => _t('الفلاش', 'Flashlight');
  String get barcodeNotFound => _t(
    'لم يُعثر على منتج بهذا الباركود',
    'No product found for this barcode',
  );
  String get duplicateBarcode => _t(
    'هذا الباركود مستخدم لمنتج آخر',
    'This barcode is already used by another product',
  );
  String get createFromBarcode => _t('إنشاء منتج جديد', 'Create New Product');
  String get allTypes => _t('الكل', 'All');
  String get productsOnly => _t('المنتجات', 'Products');
  String get servicesOnly => _t('الخدمات', 'Services');
  String get cannotConvertStockedProductToService => _t(
    'لا يمكن تحويل منتج يحتوي على مخزون إلى خدمة. يرجى تصفير المخزون أولاً',
    'Cannot convert a product with stock to a service. Please adjust stock to 0 first',
  );
  String get stockCannotBeEditedDirectly => _t(
    'لا يمكن تعديل كمية المخزون مباشرة هنا. استخدم تسوية المخزون للتعديل',
    'Stock quantity cannot be edited directly here. Use stock adjustment to modify',
  );

  // ========== DEVELOPER ==========
  String get madeBy => _t('تطوير', 'Made by');

  // ========== PURCHASES & ORDERS ==========
  String get purchase => _t('أمر شراء', 'Purchase Order');
  String get purchases => _t('أوامر الشراء', 'Purchase Orders');
  String get newPurchase => _t('أمر شراء جديد', 'New Purchase Order');
  String get finalizePurchase => _t('إصدار أمر الشراء', 'Finalize Purchase');
  String get purchaseDocument => _t('مستند شراء', 'Purchase Document');
  String get purchasesOnly => _t('الشراء', 'Purchases');

  // ========== SUPPLIERS ==========
  String get suppliers => _t('الموردون', 'Suppliers');
  String get suppliersOnly => _t('الموردون', 'Suppliers');
  String get noSuppliers => _t('لا يوجد موردون بعد', 'No suppliers yet');
  String get supplierBalance => _t('رصيد المورد', 'Supplier Balance');
  String get payable => _t('مستحق الدفع', 'Payable');

  // ========== CUSTOMERS EXTENDED ==========
  String get customerBalance => _t('رصيد العميل', 'Customer Balance');
  String get receivable => _t('مستحق الاستلام', 'Receivable');
  String get deactivateContact => _t('تعطيل جهة الاتصال', 'Deactivate Contact');
  String get activateContact => _t('تفعيل جهة الاتصال', 'Activate Contact');
  String get deactivateContactMessage => _t(
    'هذه الجهة مستخدمة في مستندات سابقة. هل تريد تعطيلها؟',
    'This contact is used in existing documents. Deactivate instead of deleting?',
  );
  String get contactDeactivated =>
      _t('تم تعطيل جهة الاتصال', 'Contact deactivated');
  String get contactActivated =>
      _t('تم تفعيل جهة الاتصال', 'Contact activated');
  String get activeOnly => _t('النشطة فقط', 'Active only');

  // ========== INVENTORY & STOCK MOVEMENTS ==========
  String get inventory => _t('المخزون', 'Inventory');
  String get stockMovements => _t('حركات المخزون', 'Stock Movements');
  String get stockMovement => _t('حركة مخزون', 'Stock Movement');
  String get openingStock => _t('رصيد افتتاحي', 'Opening Stock');
  String get adjustStock => _t('تعديل يدوي', 'Manual Adjustment');
  String get stockAdjustment => _t('تعديل المخزون', 'Stock Adjustment');
  String get adjustmentDelta =>
      _t('كمية التعديل (+ أو -)', 'Adjustment Delta (+ or -)');
  String get noMovements => _t('لا توجد حركات مخزون', 'No stock movements');
  String get lowStockAlert => _t('تنبيه مخزون منخفض', 'Low Stock Alert');
  String get insufficientStockFor =>
      _t('مخزون غير كافٍ لـ', 'Insufficient stock for');
  String insufficientStock(String name, double available, double required) {
    final availStr = FormatUtils.formatQuantity(available);
    final reqStr = FormatUtils.formatQuantity(required);
    return _t(
      'مخزون غير كافٍ لـ "${_iso(name)}": المتاح ${_iso(availStr)}، المطلوب ${_iso(reqStr)}',
      'Insufficient stock for "$name": available $availStr, required $reqStr',
    );
  }

  String get category => _t('الفئة', 'Category');
  String get allCategories => _t('كل الفئات', 'All Categories');
  String get categoryHint => _t(
    'الفئة (مثال: مواد غذائية، أجهزة)',
    'Category (e.g. Groceries, Hardware)',
  );
  String get adjustmentReasonRequired =>
      _t('سبب التعديل مطلوب لتأكيد الحركة', 'Adjustment reason is required');
  String get stockCannotBeNegative => _t(
    'المخزون الناتج لا يمكن أن يكون سالباً',
    'Resulting stock cannot be negative',
  );
  String get allMovementsHistory =>
      _t('سجل حركات المخزون', 'Stock Movement History');
  String get healthyStock => _t('مخزون كافٍ', 'Healthy Stock');
  String get filterByMovementType => _t('نوع الحركة', 'Movement Type');
  String get viewFullHistory => _t('عرض السجل الكامل', 'View Full History');
  String get scanOrSearchProduct =>
      _t('مسح أو بحث عن منتج', 'Scan or search product');
  String get createProductWithBarcode =>
      _t('إنشاء منتج بهذا الباركود', 'Create product with this barcode');
  String get allProducts => _t('كل المنتجات', 'All Products');

  // ========== DASHBOARD DATE FILTERS ==========
  String get today => _t('اليوم', 'Today');
  String get last7Days => _t('آخر 7 أيام', 'Last 7 Days');
  String get thisMonth => _t('هذا الشهر', 'This Month');
  String get previousMonth => _t('الشهر السابق', 'Previous Month');
  String get customRange => _t('فترة مخصصة', 'Custom Range');

  // ========== DASHBOARD METRIC CARDS ==========
  String get salesPeriod => _t('المبيعات', 'Sales');
  String get purchasesPeriod => _t('المشتريات', 'Purchases');
  String get paymentsIn => _t('مدفوعات واردة', 'Payments In');
  String get paymentsOut => _t('مدفوعات صادرة', 'Payments Out');
  String get allTimeBalance => _t('الرصيد الكلي', 'All-time Balance');
  String get noDataForPeriod =>
      _t('لا توجد بيانات خلال هذه الفترة', 'No data for this period');
  String get inventorySummary => _t('ملخص المخزون', 'Inventory Summary');
  String get trackedProducts => _t('منتجات مسجّلة', 'Tracked Products');
  String get viewInventory => _t('عرض المخزون', 'View Inventory');
  String get viewReports => _t('التقارير', 'Reports');

  // ========== REPORTS HUB ==========
  String get reports => _t('التقارير', 'Reports');
  String get salesReport => _t('تقرير المبيعات', 'Sales Report');
  String get purchasesReport => _t('تقرير المشتريات', 'Purchases Report');
  String get paymentsReport => _t('تقرير المدفوعات', 'Payments Report');
  String get customerReport => _t('تقرير العملاء', 'Customer Report');
  String get supplierReport => _t('تقرير الموردين', 'Supplier Report');
  String get inventoryReport => _t('تقرير المخزون', 'Inventory Report');
  String get productReport => _t('تقرير المنتجات', 'Product Report');

  // ========== REPORT FIELDS & COLUMNS ==========
  String get totalSales => _t('إجمالي المبيعات', 'Total Sales');
  String get totalPurchasesAmt => _t('إجمالي المشتريات', 'Total Purchases');
  String get totalPaid => _t('إجمالي المدفوع', 'Total Paid');
  String get totalOutstanding => _t('إجمالي المتبقي', 'Total Outstanding');
  String get invoiceCount => _t('عدد الفواتير', 'Invoices');
  String get purchaseCount => _t('عدد الطلبات', 'Orders');
  String get cancelledCount => _t('ملغي', 'Cancelled');
  String get finalized => _t('مكتملة', 'Finalized');
  String get receivedPayments => _t('مدفوعات واردة', 'Received Payments');
  String get madePayments => _t('مدفوعات صادرة', 'Made Payments');
  String get salesQty => _t('كمية المبيعات', 'Sales Qty');
  String get salesValue => _t('قيمة المبيعات', 'Sales Value');
  String get purchasedQty => _t('كمية المشتريات', 'Purchased Qty');
  String get stockStatus => _t('حالة المخزون', 'Stock Status');
  String get noReportData =>
      _t('لا توجد بيانات لهذا التقرير', 'No report data');
  String get relatedDoc => _t('المستند المرجعي', 'Related Doc');

  // ========== PRINT & THERMAL SETTINGS ==========
  String get printSettings => _t('إعدادات الطباعة', 'Print Settings');
  String get paperSize => _t('حجم الورق', 'Paper Size');
  String get paperA4 => _t('A4', 'A4');
  String get paperA5 => _t('A5', 'A5');
  String get paperThermal80 => _t('حرارية 80مم', 'Thermal 80mm');
  String get defaultPaperSize =>
      _t('حجم الورق الافتراضي', 'Default Paper Size');

  // ========== PAYMENT METHODS CONFIGURATION ==========
  String get addPaymentMethod => _t('إضافة طريقة دفع', 'Add Payment Method');
  String get editPaymentMethod =>
      _t('تعديل طريقة الدفع', 'Edit Payment Method');
  String get methodName => _t('اسم الطريقة', 'Method Name');
  String get predefinedMethods => _t('الطرق المتاحة', 'Available Methods');
  String get customMethods => _t('طرق مخصصة', 'Custom Methods');
  String get noCustomMethods =>
      _t('لا توجد طرق مخصصة بعد', 'No custom methods yet');
  String get confirmDeleteMethod =>
      _t('حذف طريقة الدفع', 'Delete Payment Method');

  // ========== PAYMENT METHODS STORAGE ==========
  String get defaultMethod => _t('الافتراضي', 'Default');
  String get setAsDefault => _t('تعيين كافتراضي', 'Set as Default');
  String get cannotDeleteMethodInUse => _t(
    'لا يمكن حذف طريقة مستخدمة في مستندات',
    'Cannot delete: method used in documents',
  );
  String get methodLabelAr => _t('الاسم بالعربية', 'Arabic Name');
  String get methodLabelEn => _t('الاسم بالإنجليزية', 'English Name');
  String get noPaymentMethodsEnabled =>
      _t('لا توجد طرق دفع مفعّلة', 'No payment methods enabled');

  // ========== BARCODE SCANNER ==========
  String get scannerHint =>
      _t('وجّه الكاميرا نحو الباركود', 'Point camera at barcode');
  String get scannerPermDenied =>
      _t('يتطلب إذن الكاميرا', 'Camera permission required');
  String get scannerPermMsg => _t(
    'امنح إذن الكاميرا للمسح الضوئي',
    'Grant camera permission to scan barcodes',
  );
  String get manualEntry => _t('إدخال يدوي', 'Manual Entry');

  // ========== INVENTORY ADJUSTMENTS ==========
  String get newStockQuantity => _t('الكمية بعد التعديل', 'New Stock Quantity');
  String get adjustmentReason => _t('سبب التعديل', 'Adjustment Reason');
  String get inStock => _t('متوفر', 'In Stock');
  String get scanToLocate => _t('مسح للبحث', 'Scan to Locate');

  // ========== AUDIT TRAIL ==========
  String get auditLog => _t('سجل الأحداث', 'Audit Log');

  // ========== FINANCIAL & LEGAL COMPLIANCE ==========
  String get financialSettings =>
      _t('الإعدادات المالية والقانونية', 'Financial & Legal Settings');
  String get financialSettingsDesc => _t(
    'الضرائب والهوية القانونية وإعدادات المستندات',
    'Taxes, legal identity & document settings',
  );
  String get legalIdentity => _t('الهوية القانونية', 'Legal Identity');
  String get legalName => _t('الاسم القانوني', 'Legal / Registered Name');
  String get taxId => _t('الرقم الضريبي', 'Tax ID');
  String get taxReg => _t('رقم التسجيل الضريبي', 'Tax Registration No.');
  String get commercialReg => _t('السجل التجاري', 'Commercial Reg. No.');
  String get branch => _t('الفرع', 'Branch');

  String get taxSettings => _t('إعدادات الضريبة', 'Tax Settings');
  String get taxesEnabled => _t('تفعيل الضريبة', 'Enable Taxes');
  String get taxesEnabledDesc =>
      _t('عرض الضريبة في الفواتير', 'Show tax on invoices');
  String get pricesIncludeTax =>
      _t('الأسعار شاملة الضريبة', 'Prices include tax (inclusive)');
  String get pricesIncludeTaxDesc =>
      _t('سعر الوحدة يشمل الضريبة بالفعل', 'Unit price already includes tax');
  String get wholesalePricing =>
      _t('تسعير الجملة والتجزئة', 'Wholesale & Retail Pricing');
  String get wholesalePricingDesc => _t(
        'تفعيل أسعار الجملة والتجزئة للمنتجات والعملاء',
        'Enable wholesale and retail prices for products and customers',
      );
  String get wholesalePricingDisableWarning => _t(
        'عند تعطيل تسعير الجملة، ستعتمد الفواتير الجديدة سعر التجزئة الافتراضي.',
        'When wholesale pricing is disabled, new documents will use standard retail pricing.',
      );
  String get disableAction => _t('تعطيل', 'Disable');
  String get wholesalePrice => _t('سعر الجملة', 'Wholesale Price');
  String get wholesaleMinQuantity =>
      _t('الحد الأدنى للجملة', 'Wholesale Min Quantity');
  String get wholesaleMinQuantityHelp => _t(
        'أقل كمية لتطبيق سعر الجملة تلقائياً',
        'Minimum quantity to automatically apply wholesale price',
      );
  String get pricingCategory => _t('فئة التسعير', 'Pricing Category');
  String get retail => _t('تجزئة', 'Retail');
  String get wholesale => _t('جملة', 'Wholesale');
  String get pricingCategoryCustomerDesc =>
      _t('فئة السعر الافتراضية لهذا العميل', 'Default pricing tier for this customer');
  String get pricingTier => _t('فئة السعر', 'Pricing Tier');
  String get linePriceRetail => _t('تجزئة', 'Retail');
  String get linePriceWholesale => _t('جملة', 'Wholesale');
  String get linePriceManual => _t('مخصص', 'Custom');
  String get itemTierWholesaleBadge => _t('سعر جملة', 'Wholesale Tier');
  String get itemTierRetailBadge => _t('سعر تجزئة', 'Retail Tier');
  String get bulkPricingCustomUnitsWarning => _t(
        'تنبيه: التعديل الجماعي للأسعار ينطبق على الوحدة الأساسية فقط ولا يغير أسعار وحدات البيع الإضافية.',
        'Notice: Bulk price adjustment applies to base units only and does not change additional sales unit prices.',
      );
  String get duplicateUnitNameError =>
      _t('اسم الوحدة موجود بالفعل لهذا المنتج', 'Unit name already exists for this product');
  String get reset => _t('إعادة ضبط', 'Reset');
  String get additionalSalesUnits =>
      _t('وحدات البيع الإضافية', 'Additional Sales Units');
  String get addSalesUnit => _t('إضافة وحدة بيع', 'Add Sales Unit');
  String get editSalesUnit => _t('تعديل وحدة البيع', 'Edit Sales Unit');
  String get salesUnitName => _t('اسم الوحدة', 'Unit Name');
  String get conversionFactor => _t('معامل التحويل', 'Conversion Factor');
  String get conversionFactorHelp => _t(
        'عدد الوحدات الأساسية التي تعادل وحدة البيع هذه (مثال: 1 كرتونة = 10 قطع)',
        'How many base units equal 1 of this sales unit (e.g., 1 carton = 10 pieces)',
      );
  String get invalidConversionFactor => _t(
        'يجب أن يكون معامل التحويل أكبر من صفر',
        'Conversion factor must be greater than zero',
      );
  String get salesUnit => _t('وحدة البيع', 'Sales Unit');
  String get baseUnit => _t('الوحدة الأساسية', 'Base Unit');
  String get defaultSaleUnit =>
      _t('الوحدة الافتراضية للبيع', 'Default Sales Unit');
  String get optional => _t('اختياري', 'Optional');
  String get noUnits =>
      _t('لا توجد وحدات بيع إضافية', 'No additional units yet');
  String get defaultTaxProfile =>
      _t('ملف ضريبي افتراضي', 'Default Tax Profile');
  String get noDefaultProfile =>
      _t('لا يوجد ملف افتراضي', 'No default profile');

  String get taxProfiles => _t('ملفات الضريبة', 'Tax Profiles');
  String get taxProfilesDesc =>
      _t('إنشاء وإدارة معدلات الضريبة', 'Create and manage tax rates');
  String get addTaxProfile => _t('إضافة ملف ضريبي', 'Add Tax Profile');
  String get editTaxProfile => _t('تعديل الملف الضريبي', 'Edit Tax Profile');
  String get taxProfileName => _t('اسم الملف الضريبي', 'Profile Name');
  String get taxProfileType => _t('نوع الضريبة', 'Tax Type');
  String get taxProfileRate => _t('نسبة الضريبة (%)', 'Tax Rate (%)');
  String get taxProfileDefault => _t('افتراضي', 'Default');
  String get taxProfileInclusive =>
      _t('شامل (مضمّن في السعر)', 'Inclusive (in price)');
  String get taxProfileExclusive =>
      _t('غير شامل (يضاف للسعر)', 'Exclusive (added on top)');
  String get calculationMode => _t('طريقة الاحتساب', 'Calculation Mode');
  String get noTaxProfiles =>
      _t('لا توجد ملفات ضريبية بعد', 'No tax profiles yet');
  String get confirmDeleteProfile =>
      _t('حذف الملف الضريبي؟', 'Delete Tax Profile?');
  String get taxTypeVat => _t('ضريبة القيمة المضافة', 'VAT');
  String get taxTypeSalesTax => _t('ضريبة المبيعات', 'Sales Tax');
  String get taxTypeServiceCharge => _t('رسوم خدمة', 'Service Charge');
  String get taxTypeOther => _t('أخرى', 'Other');

  String get documentSettings => _t('إعدادات المستند', 'Document Settings');
  String get invoiceTitle => _t('عنوان الفاتورة', 'Invoice Title');
  String get invoiceTitleDesc => _t(
    'يظهر في رأس الفاتورة بدلاً من "فاتورة"',
    'Shown on invoice instead of "Invoice"',
  );
  String get legalFooter => _t('التذييل القانوني', 'Legal Footer');
  String get legalFooterDesc => _t(
    'نص يظهر في أسفل كل فاتورة',
    'Text shown at the bottom of each invoice',
  );

  String get contactLegalName =>
      _t('الاسم القانوني للجهة', 'Contact Legal Name');
  String get contactTaxId => _t('الرقم الضريبي للجهة', 'Contact Tax ID');
  String get taxProfile => _t('الملف الضريبي', 'Tax Profile');
  String get noTaxProfile => _t('بدون ملف ضريبي', 'No Tax Profile');
  String get taxIncluded => _t('الضريبة (مشمولة)', 'Tax (Included)');
  String get netTaxableBase =>
      _t('المبلغ الخاضع للضريبة (غير شامل)', 'Taxable Base (Excl. Tax)');
  String get subtotalInclusive =>
      _t('المجموع شامل الضريبة', 'Subtotal (Incl. Tax)');
  String get paymentMethodInUseCannotDelete => _t(
    'لا يمكن حذف طريقة الدفع هذه لأنها مستخدمة في معاملات سابقة. يمكنك تعطيلها بدلاً من ذلك لمنع استخدامها في المعاملات الجديدة.',
    'Cannot delete this payment method because it is referenced in past transactions. You can disable it instead to prevent new transactions while preserving your history.',
  );
  String get cannotDeletePaymentMethodTitle =>
      _t('تعذر حذف طريقة الدفع', 'Cannot Delete Payment Method');
  String get currencyScopeNote => _t(
    'العملة الافتراضية تنطبق على المستندات والمنتجات الجديدة. تحتفظ المعاملات السابقة بالعملة التي سُجلت بها.',
    'Default currency applies to new documents and products. Existing transactions retain their recorded currency.',
  );
  String get currencyLockedNote => _t(
    'العملة الأساسية مقفلة بشكل دائم لوجود معاملات مالية أو حركات مخزون مسجلة.',
    'Base currency is permanently locked because financial transactions or stock movements exist.',
  );
  String get currencyInitialWarningNote => _t(
    'تنبيه: تصبح هذه العملة دائمة ولا يمكن تغييرها بمجرد تسجيل أول فاتورة أو إيصال أو حركة مخزون.',
    'Notice: Currency becomes permanent and cannot be changed once the first transaction or stock movement is recorded.',
  );
  String get currencyConfirmTitle =>
      _t('تأكيد اختيار العملة الأساسية', 'Confirm Base Currency');
  String currencyConfirmMessage(String currency) => _t(
    'لقد اخترت عملة (${_iso(currency)}). بمجرد تسجيل أول فاتورة أو إيصال أو إضافة مخزون، ستصبح هذه العملة دائمة ولا يمكن تغييرها مطلقاً من الإعدادات. هل تريد المتابعة؟',
    'You have selected ($currency). Once your first invoice, receipt, or stock movement is recorded, this currency becomes permanent and cannot be changed. Do you want to proceed?',
  );
  String get taxLivePreview =>
      _t('معاينة توضيحية لاحتساب الضريبة', 'Tax Calculation Preview');
  String get taxLivePreviewDesc => _t(
    'مثال توضيحي لمنتج بقيمة 100 مع خصم 10%',
    'Example for an item of 100 with 10% discount',
  );
  String get disableMethodAction => _t('تعطيل الطريقة', 'Disable Method');
  String get taxSettingsManagedInFinancial => _t(
    'يتم ضبط خيارات الضريبة وملفات الأسعار من شاشة الإعدادات المالية.',
    'Tax options and rates are configured in Financial Settings.',
  );
  String get taxesStatus => _t('حالة نظام الضريبة', 'Tax System Status');
  String get taxesEnabledActive => _t('الضريبة مفعلة', 'Taxes Active');
  String get taxesDisabledInactive =>
      _t('الضريبة معطلة (0%)', 'Taxes Disabled (0%)');
  String get productTaxOverrideNote => _t(
    'يمكن تخصيص ملف ضريبي مختلف لكل منتج على حدة من شاشة تفاصيل المنتج (مثل: المنتجات المعفاة أو الخاضعة لنسبة صفرية).',
    'Individual products can override this default with their own tax profile (e.g. zero-rated or exempt items).',
  );
  String get taxExclusiveExplained => _t(
    'الأسعار المدخلة غير شاملة: تُضاف الضريبة كقيمة إضافية فوق سعر المنتج.',
    'Prices exclude tax: tax is added on top of the item price.',
  );
  String get taxInclusiveExplained => _t(
    'الأسعار المدخلة شاملة: يتم استخراج الضريبة من داخل سعر المنتج دون زيادة المجموع.',
    'Prices include tax: tax is extracted from the item price without increasing the total.',
  );
  String get taxSampleEnteredPrice =>
      _t('سعر الصنف المدخل', 'Entered Item Price');
  String get taxSampleNetBase =>
      _t('الأساس الخاضع للضريبة', 'Net Taxable Base');
  String get taxSampleTaxAmount => _t('مبلغ الضريبة', 'Tax Amount');
  String get taxSampleTotalPayable =>
      _t('الإجمالي النهائي المستحق', 'Total Payable');
  String get taxZeroRatedVsDisabled => _t(
    'الفرق بين تعطيل الضريبة والنسبة الصفرية: تعطيل الضريبة يلغي احتساب الضرائب نهائياً، بينما النسبة الصفرية (0%) تعامل المنتج كخاضع للضريبة رسمياً بنسبة 0%.',
    'Difference: Disabling tax turns off calculation entirely, while zero-rated (0%) records the item under tax regulations with 0% tax.',
  );
  String get basicInfo =>
      _t('البيانات الأساسية ومعلومات الاتصال', 'Basic Identity & Contact');
  String get visualBranding => _t('الشعار والمظهر', 'Logo & Visual Branding');
  String get financialDefaults =>
      _t('الإعدادات المالية الافتراضية', 'Financial Defaults');
  String get legalAndTaxInfo =>
      _t('البيانات القانونية والضريبية', 'Legal & Tax Details');
  String get notConfigured => _t('غير محدد', 'Not configured');
  String get configureInFinancial =>
      _t('تعديل في الإعدادات المالية', 'Configure in Financial Settings');
  String get activeMethods => _t('طرق الدفع المفعلة', 'Active Payment Methods');
  String get disabledMethods =>
      _t('طرق الدفع المعطلة', 'Disabled Payment Methods');
  String get methodStatusActive => _t('مفعلة', 'Active');
  String get methodStatusDisabled => _t('معطلة', 'Disabled');
  String get methodNameRequired =>
      _t('يرجى إدخال اسم طريقة الدفع', 'Please enter a payment method name');
  String get itemTaxable => _t('خاضع للضريبة', 'Taxable');
  String get itemNonTaxable => _t('غير خاضع', 'Non-taxable');
  String get lineTotal => _t('الإجمالي', 'Line Total');
  String get checkForUpdates => _t('التحقق من التحديثات', 'Check for Updates');
  String get checkForUpdatesSubtitle => _t(
    'التحقق من توفر إصدارات جديدة على Google Play',
    'Check for new versions on Google Play',
  );
  String get checkingForUpdates =>
      _t('جارٍ التحقق من التحديثات…', 'Checking for updates…');
  String get appUpToDate => _t(
    'أنت تستخدم أحدث إصدار من التطبيق',
    'You are using the latest version',
  );
  String get updateAvailable =>
      _t('يتوفر تحديث جديد', 'A new update is available');
  String get updateDownloadedRestart => _t(
    'تم تنزيل التحديث. يرجى إعادة تشغيل التطبيق لتثبيته.',
    'Update downloaded. Restart the app to apply it.',
  );
  String get restartNow => _t('إعادة التشغيل الآن', 'Restart Now');
  String get updateCheckFailed => _t(
    'تعذر التحقق من التحديثات حالياً',
    'Unable to check for updates at this time',
  );
  String get updateFailed =>
      _t('تعذر إكمال التحديث', 'Unable to complete update');

  // ========== ACTIVATION & ENTITLEMENT ==========
  // Pro features are unlocked only by an activation key obtained outside the
  // app. There is no in-app pricing, ordering, or payment.
  String get activation => _t('التفعيل', 'Activation');
  // Status labels
  String get trialActiveStatus => _t('تجربة مجانية نشطة', 'Free Trial Active');
  String get trialExpiredStatus => _t('انتهت التجربة', 'Trial Expired');
  String get activatedStatus => _t('مُفعَّل', 'Activated');
  String get licenseExpiredStatus => _t('انتهى التفعيل', 'Activation Expired');
  String get licenseRevokedStatus =>
      _t('تم إلغاء التفعيل', 'Activation Revoked');
  String get deviceLimitStatus =>
      _t('تجاوزت حد الأجهزة', 'Device Limit Reached');
  // Trial
  String get daysLeftInTrial =>
      _t('يوم متبقٍ في التجربة', 'day(s) left in trial');
  String get trialFreeDays =>
      _t('١٤ يوماً مجاناً — بدون قيود', '14 days free — no limits');
  // Actions
  String get tryAgain => _t('إعادة المحاولة', 'Try Again');
  String get continueUsingApp => _t('الدخول إلى ورقتك', 'Enter Waraqatak');
  String get activating => _t('جارٍ التفعيل…', 'Activating…');
  String get activationSuccessTitle => _t('تم التفعيل!', 'Activated!');
  String get activationSuccessBody => _t(
    'ورقتك نشطة الآن. استمتع باستخدامها.',
    'Waraqatak is now active. Enjoy!',
  );
  String get licenseExpiresOn => _t('ينتهي بتاريخ', 'Expires on');
  String get networkError =>
      _t('تعذّر الاتصال بالخادم', 'Could not connect to server');

  // ── Activation key entry ───────────────────────────────────────────────────
  String get enterActivationKey =>
      _t('أدخل مفتاح التفعيل', 'Enter activation key');
  String get activationKeyHint =>
      _t('XXXX-XXXX-XXXX أو مفتاح طويل', 'XXXX-XXXX-XXXX or long key');
  String get activate => _t('تفعيل', 'Activate');
  // Approved copy (mandated):
  String get proFeaturesActivation => _t(
    'تُفعَّل الميزات الاحترافية بمفتاح تفعيل.',
    'Pro features are unlocked with an activation key.',
  );
  String get getActivationKeyInfo => _t(
    'أدخل مفتاح التفعيل لإلغاء قفل الميزات الاحترافية.',
    'Enter your activation key to unlock Pro features.',
  );
  String get invalidOrExpiredKey => _t(
    'مفتاح تفعيل غير صالح أو منتهي الصلاحية.',
    'Invalid or expired activation key.',
  );
  String get activationTooManyAttempts => _t(
    'محاولات كثيرة. يرجى المحاولة لاحقاً.',
    'Too many attempts. Please try again later.',
  );
  String get activationServerUnreachable => _t(
    'تعذّر الاتصال بالخادم. يرجى المحاولة لاحقاً.',
    'Could not reach the server. Please try again later.',
  );
  String get activationDeviceUnavailable => _t(
    'تعذّر التحقق من هوية هذا الجهاز بشكل آمن.',
    'Could not verify device identity securely.',
  );
  String get activationTipDevice => _t(
    'تلميح: تأكد من تفعيل خدمات النظام أو تشغيل التطبيق على جهاز مدعوم.',
    'Tip: Ensure system services are active or run the app on a supported device.',
  );
  String get pasteKey => _t('لصق', 'Paste');
  String get deviceModelLabel => _t('موديل الجهاز', 'Device Model');
  String get deviceIdLabel => _t('معرّف الجهاز', 'Device Identifier');
  String get copyDeviceId => _t('نسخ معرّف الجهاز', 'Copy device identifier');
  String get deviceIdCopied =>
      _t('تم نسخ معرّف الجهاز إلى الحافظة', 'Device identifier copied to clipboard');
  String get supportFromAboutPage => _t(
    'إذا استمرت المشكلة، يمكنك طلب الدعم الفني من صفحة "حول التطبيق".',
    'If the problem continues, contact support from the About page.',
  );
  String get openAboutPage => _t('صفحة حول التطبيق', 'About page');
  String get copySupportInfo => _t('نسخ معلومات الدعم الفني', 'Copy support info');
  String get supportInfoCopied =>
      _t('تم نسخ معلومات الدعم الفني للحافظة', 'Support info copied to clipboard');
  String referenceIdLabel(String id) => _t('الرقم المرجعي: $id', 'Reference ID: $id');
  String get copiedToClipboard => _t('تم النسخ للحافظة', 'Copied to clipboard');
  String get transferNoticeTitle => _t('نقل الترخيص إلى جهاز آخر', 'License Transfer');
  String get transferNoticeBody => _t(
    'لترخيص جهاز جديد، يرجى إزالة المفتاح من هذا الجهاز أولاً عبر الزر أدناه لتتمكن من تفعيله على جهازك الآخر.',
    'To activate on another device, remove the key from this device first using the button below.',
  );
  String get documentNotFound => _t('المستند غير موجود', 'Document not found');
  String get documentNotFoundDesc => _t(
    'تعذّر العثور على المستند المطلوب في قاعدة البيانات، أو قد يكون تم حذفه.',
    'The requested document was not found in the database or may have been deleted.',
  );
  String get viewDocument => _t('عرض المستند', 'View Document');
  String get helpCenter => _t('مركز المساعدة', 'Help Center');
  String get helpCenterSubtitle =>
      _t('دليل الاستخدام والأسئلة الشائعة عبر الإنترنت', 'Online user guides & FAQs');
  String get openDestination => _t('فتح', 'Open');
  String get entityLabel => _t('الكيان', 'Entity');
  String get actionTypeLabel => _t('نوع الإجراء', 'Action Type');
  String get detailsLabel => _t('التفاصيل', 'Details');

  // ── License screen (Settings → License) ───────────────────────────────────
  String get licenseScreenTitle => _t('التفعيل والترخيص', 'License');
  String get licenseStatusLabel => _t('الحالة', 'Status');
  String get licenseTypeLabel => _t('النوع', 'Type');
  String get licenseExpiryLabel => _t('تاريخ الانتهاء', 'Expiry');
  String get licenseTypeTrial => _t('تجربة مجانية', 'Free trial');
  String get licenseTypeActivated =>
      _t('مُفعَّل بمفتاح', 'Activated with a key');
  String get licenseTypePerpetual =>
      _t('مُفعَّل (دائم)', 'Activated (Perpetual)');
  String get licenseTypeTimed => _t('مُفعَّل (مؤقت)', 'Activated (Timed)');
  String get licenseNoExpiryDate => _t('بدون تاريخ انتهاء', 'No expiry date');
  String get licenseOnExpiryTitle =>
      _t('ماذا يحدث عند انتهاء الصلاحية؟', 'What happens when it expires?');
  String get licenseOnExpiryBody => _t(
    'عند انتهاء التجربة أو التفعيل، تظل بياناتك ومستنداتك متاحة في الوضع المجاني، ويحتاج استخدام الميزات الاحترافية إلى مفتاح تفعيل جديد. ولا تمنح إزالة المفتاح فترة تجريبية جديدة.',
    'When your trial or activation ends, your data and documents remain available in Free mode. Pro features require a new activation key. Removing a key does not grant a new trial.',
  );
  String get enterOrChangeKey =>
      _t('إدخال أو تغيير مفتاح التفعيل', 'Enter or change activation key');
  String get removeKeyFromDevice =>
      _t('إزالة المفتاح من هذا الجهاز', 'Remove key from this device');
  String get removeKeyConfirmTitle => _t('إزالة المفتاح؟', 'Remove key?');
  String get removeKeyConfirmBody => _t(
    'ستتم إزالة مفتاح التفعيل من هذا الجهاز وإلغاء ربطه بالخادم. لن يُلغى المفتاح نهائياً ويمكنك إدخاله مجدداً، وإذا كانت التجربة المجانية لا تزال سارية فستعود إليها.',
    'The activation key will be unlinked and removed from this device only. The key is not cancelled and you can enter it again. If your free trial is still valid, you will return to it.',
  );
  String get removeKeyConfirmAction => _t('إزالة', 'Remove');
  String get keyRemovedSnack =>
      _t('تمت إزالة المفتاح من هذا الجهاز.', 'Key removed from this device.');

  // ── Transparency screen (free vs Pro) ─────────────────────────────────────
  String get transparencyTitle => _t(
    'ما المتاح مجاناً وما يتطلب التفعيل',
    'What is free and what requires activation',
  );
  String get transparencyIntro => _t(
    'كل ما يلي يعمل دون إنترنت ودون أي عملية شراء داخل التطبيق. تحتاج ميزات محددة إلى مفتاح تفعيل.',
    'Everything below works offline with no in-app purchase. A few specific features require an activation key.',
  );
  String get transparencyFreeHeader => _t('متاحة دائماً', 'Always available');
  String get transparencyProHeader =>
      _t('تتطلب مفتاح تفعيل', 'Require an activation key');
  String get seeFreeVsPro => _t('ما المتاح مجاناً؟', 'See what is free vs Pro');

  // Feature labels — reused by the transparency screen. Mapped from the
  // `Feature` enum in `lib/services/feature_access.dart`.
  String get featureInvoices => _t(
    'الفواتير وعروض الأسعار والمستندات',
    'Invoices, quotations, and documents',
  );
  String get featureQuotations => _t('عروض الأسعار', 'Quotations');
  String get featureVouchers =>
      _t('سندات القبض والصرف', 'Receipt and expense vouchers');
  String get featureCustomDocuments =>
      _t('المستندات المخصصة', 'Custom documents');
  String get featureCustomers =>
      _t('العملاء وأرصدتهم', 'Customers and balances');
  String get featureProducts => _t('المنتجات والأسعار', 'Products and prices');
  String get featureBarcode => _t('ماسح الباركود', 'Barcode scanner');
  String get featureBasicReports => _t('التقارير الأساسية', 'Basic reports');
  String get featureBackupRestore =>
      _t('النسخ الاحتياطي والاستعادة', 'Backup and restore');
  String get featurePurchases =>
      _t('أوامر الشراء والموردون', 'Purchase orders and suppliers');
  String get featureInventory =>
      _t('إدارة المخزون المتقدمة', 'Advanced inventory management');
  String get featureAdvancedReports =>
      _t('التقارير التفصيلية الكاملة', 'Full detailed reports');

  // ========== FREE / PRO GATING ==========
  String get proBadgeLabel => _t('احترافي', 'Pro');
  String get proFeatureTitle => _t('ميزة احترافية', 'Pro Feature');
  String get proIncludesPurchases =>
      _t('أوامر الشراء والموردون', 'Purchases & Suppliers');
  String get proIncludesInventory =>
      _t('إدارة المخزون المتقدمة', 'Advanced Inventory Management');
  String get proIncludesReports =>
      _t('التقارير التفصيلية الكاملة', 'Full Detailed Reports');
  String get proAdvancedReports =>
      _t('التقارير الاحترافية', 'Advanced Reports');
  String get enterActivationKeyAction =>
      _t('إدخال مفتاح التفعيل', 'Enter activation key');
  String get freeDataAlwaysAvailable => _t(
    'بياناتك ومستنداتك محفوظة دائماً حتى في الوضع المجاني.',
    'Your data and documents are always available, even in Free mode.',
  );
  String get freeModeBannerMsg => _t(
    'الوضع المجاني نشط — الفواتير والعملاء والمنتجات متاحة دائماً.',
    'Free mode active — invoices, customers, and products are always available.',
  );

  // ========== QUICK SALE (POS) ==========
  String get posQuickSale => _t('بيع سريع', 'Quick sale');
  String get posQuickSaleDesc => _t(
    'بيع بالمسح أو اللمس مع إيصال فوري',
    'Tap or scan to sell with an instant receipt',
  );
  String get posSearchHint =>
      _t('ابحث بالاسم أو الكود أو الباركود', 'Search by name, code or barcode');
  String get posViewCart => _t('السلة', 'Cart');
  String get posCartEmpty => _t(
    'السلة فارغة. اضغط على منتج لإضافته.',
    'Cart is empty. Tap a product to add it.',
  );
  String get posAmountReceived => _t('المبلغ المستلم', 'Amount received');
  String get posChange => _t('الباقي للعميل', 'Change');
  String get posCompleteSale => _t('إتمام البيع', 'Complete sale');
  String get posSaleCompleted => _t('تم البيع بنجاح', 'Sale completed');
  String get posPrintReceipt => _t('طباعة إيصال', 'Print receipt');
  String get posShare => _t('مشاركة', 'Share');
  String get posViewInvoice => _t('عرض الفاتورة', 'View invoice');
  String get posNewSale => _t('بيع جديد', 'New sale');
  String get posClearCart => _t('تفريغ السلة', 'Clear cart');
  String get posClearCartConfirm => _t(
    'هل تريد حذف كل المنتجات من السلة؟',
    'Remove all items from the cart?',
  );
  String get posProductNotFound =>
      _t('لم يتم العثور على منتج مطابق', 'No matching product');
  String get posService => _t('خدمة', 'Service');
  String get posReceivedLessThanTotal => _t(
    'المبلغ المستلم أقل من الإجمالي',
    'Amount received is less than the total',
  );
  String get posSetupBusinessFirst => _t(
    'أكمل بيانات النشاط التجاري أولاً من الإعدادات',
    'Complete your business profile in Settings first',
  );
  String posNotEnoughStock(String name) =>
      _t('الكمية المتوفرة من "${_iso(name)}" لا تكفي', 'Not enough stock for "$name"');
  String posItemsCount(String n) {
    final parsed = num.tryParse(n.replaceAll(',', '').trim());
    if (parsed == null) {
      return _t('$n بند', '$n items');
    }
    return _plural(
      parsed,
      zero: _t('لا توجد بنود', '0 items'),
      one: _t('بند واحد', '1 item'),
      two: _t('بندان', '2 items'),
      few: _t('$n بنود', '$n items'),
      many: _t('$n بنداً', '$n items'),
      other: _t('$n بند', '$n items'),
      enOne: '1 item',
      enOther: '$n items',
    );
  }
  String posInStock(String n) => _t('متوفر: ${_iso(n)}', 'In stock: $n');

  // ========== ABOUT & SUPPORT ==========
  String get supportAndContact => _t('الدعم والتواصل', 'Support & contact');
  String get whatsappSupport => _t('واتساب', 'WhatsApp');
  String get whatsappSupportDesc =>
      _t('للمساعدة الفنية والاستفسارات', 'Technical help and questions');
  String get supportWhatsAppGreeting => _t(
    'مرحباً، أحتاج مساعدة في تطبيق ورقتك',
    'Hello, I need help with Waraqatak',
  );
  String get facebookPage => _t('صفحتنا على فيسبوك', 'Our Facebook page');
  String get facebookPageDesc =>
      _t('الأخبار والتحديثات والنصائح', 'News, updates and tips');
  String get developerWebsite => _t('موقع المطوّر', 'Developer website');
  String get whatYouCanDo => _t('ماذا يمكنك أن تفعل', 'What you can do');
  String get legalAndPrivacy => _t('الخصوصية والشروط', 'Privacy & terms');
  String get rateApp => _t('قيّم التطبيق', 'Rate app');
  String get shareApp => _t('شارك التطبيق', 'Share app');
  String get getHelp => _t('مساعدة', 'Get help');
  String get shareAppMessage => _t(
    'جرّب تطبيق ورقتك لإنشاء الفواتير والمستندات بسهولة:',
    'Try Waraqatak to create invoices and business documents easily:',
  );

  // ========== SETTINGS SECTIONS & APPEARANCE ==========
  String get settingsSectionBusiness => _t('النشاط التجاري', 'Business');
  String get settingsSectionAppearance =>
      _t('المظهر واللغة', 'Appearance & language');
  String get settingsSectionData =>
      _t('البيانات والنسخ الاحتياطي', 'Data & backup');
  String get settingsSectionSupport => _t('الدعم والمعلومات', 'Support & info');
  String get themeModeLabel => _t('المظهر', 'Theme');
  String get themeLight => _t('فاتح', 'Light');
  String get themeDark => _t('داكن', 'Dark');
  String get themeSystem => _t('تلقائي', 'System');
  String get aboutSubtitle =>
      _t('الدعم والتواصل والإصدار', 'Support, contact and version');

  // ========== PDF CUSTOMIZATION ==========
  String get pdfSignature => _t('التوقيع', 'Signature');
  String get pdfStamp => _t('الختم', 'Stamp');
  String get pdfCustomize =>
      _t('تخصيص المستندات (PDF)', 'Document design (PDF)');
  String get pdfCustomizeDesc => _t(
    'الألوان والقالب والشعار والحقول',
    'Colors, template, logo and fields',
  );
  String get pdfPreview => _t('معاينة', 'Preview');
  String get pdfOptions => _t('الخيارات', 'Options');
  String get pdfTemplate => _t('القالب', 'Template');
  String get pdfTemplateClassic => _t('كلاسيكي', 'Classic');
  String get pdfTemplateModern => _t('عصري', 'Modern');
  String get pdfTemplateMinimal => _t('بسيط', 'Minimal');
  String get pdfAccentColor => _t('اللون الرئيسي', 'Accent color');
  String get pdfLogo => _t('الشعار', 'Logo');
  String get pdfLogoCircle => _t('دائري', 'Circle');
  String get pdfLogoRounded => _t('مربع', 'Square');
  String get pdfLogoHidden => _t('إخفاء', 'Hidden');
  String get pdfTextSize => _t('حجم الخط', 'Text size');
  String get pdfTextSmall => _t('صغير', 'Small');
  String get pdfTextNormal => _t('متوسط', 'Normal');
  String get pdfTextLarge => _t('كبير', 'Large');
  String get pdfFields => _t('محتوى المستند', 'Document content');
  String get pdfShowBusinessContact =>
      _t('بيانات التواصل للنشاط', 'Business contact details');
  String get pdfShowTaxId => _t('الرقم الضريبي', 'Tax ID');
  String get pdfShowCustomer => _t('بيانات العميل', 'Customer details');
  String get pdfShowNotes => _t('الملاحظات', 'Notes');
  String get pdfShowPaymentSummary =>
      _t('المدفوع والمتبقي (الفواتير)', 'Paid and remaining (invoices)');
  String get pdfShowSignature =>
      _t('خانة التوقيع والختم', 'Signature and stamp area');
  String get pdfShowPageNumbers => _t('أرقام الصفحات', 'Page numbers');
  String get pdfZebraRows =>
      _t('تظليل صفوف الجدول بالتناوب', 'Striped table rows');
  String get pdfFooterText => _t('نص التذييل', 'Footer text');
  String get pdfFooterTextHint =>
      _t('مثال: شكراً لتعاملكم معنا', 'e.g. Thank you for your business');
  String get pdfResetDefaults =>
      _t('استعادة الإعدادات الافتراضية', 'Reset to defaults');
  String get pdfSampleItem1 => _t('خدمة تصميم', 'Design service');
  String get pdfSampleItem2 => _t('منتج تجريبي', 'Sample product');
  String get pdfSampleCustomer => _t('عميل تجريبي', 'Sample customer');
  String get pdfSampleNotes =>
      _t('هذه معاينة للتصميم فقط.', 'This is a design preview only.');

  // ========== ACCOUNTING ==========
  String get accounting =>
      _t('المحاسبة والقوائم المالية', 'Accounting & statements');
  String get incomeStatement => _t('قائمة الدخل', 'Income statement');
  String get balanceSheet => _t('الميزانية العمومية', 'Balance sheet');
  String get trialBalance => _t('ميزان المراجعة', 'Trial balance');
  String get chartOfAccounts => _t('الحسابات', 'Accounts');
  String get accountStatement =>
      _t('كشف حساب (دفتر الأستاذ)', 'Account ledger');
  String get journalEntry => _t('قيد يومية', 'Journal entry');
  String get debit => _t('مدين', 'Debit');
  String get credit => _t('دائن', 'Credit');
  String get accountBalance => _t('الرصيد', 'Balance');
  String get accountCode => _t('الرمز', 'Code');
  String get accountColumn => _t('الحساب', 'Account');
  String get openingBalance => _t('الرصيد الافتتاحي', 'Opening balance');
  String get closingBalance => _t('الرصيد الختامي', 'Closing balance');
  String get revenueSection => _t('الإيرادات', 'Revenue');
  String get grossProfit => _t('مجمل الربح', 'Gross profit');
  String get expensesSection => _t('المصروفات', 'Expenses');
  String get netProfit => _t('صافي الربح', 'Net profit');
  String get netLoss => _t('صافي الخسارة', 'Net loss');
  String get assetsSection => _t('الأصول', 'Assets');
  String get liabilitiesSection => _t('الالتزامات', 'Liabilities');
  String get equitySection => _t('حقوق الملكية', 'Equity');
  String get retainedEarnings => _t('الأرباح المحتجزة', 'Retained earnings');
  String get totalAssets => _t('إجمالي الأصول', 'Total assets');
  String get totalLiabilitiesEquity =>
      _t('إجمالي الالتزامات وحقوق الملكية', 'Total liabilities & equity');
  String get balancedLabel => _t('متوازن', 'Balanced');
  String get notBalancedLabel => _t('غير متوازن', 'Not balanced');
  String get noEntriesYet => _t('لا توجد قيود بعد', 'No entries yet');
  String asOfDate(String d) => _t('كما في ${_iso(d)}', 'As of $d');
  String get accountingNote => _t(
    'تُنشأ القيود تلقائياً بنظام القيد المزدوج من مستنداتك، ولا تُرحَّل المسودات والمستندات الملغاة. يُقيَّم المخزون بطريقة المتوسط المرجح.',
    'Double-entry records are created automatically from your documents; drafts and cancelled documents are not posted. Stock is valued at weighted-average cost.',
  );
  String get entryInvoicePayment => _t('تحصيل فاتورة', 'Invoice payment');
  String get entryPurchasePayment =>
      _t('سداد أمر شراء', 'Purchase order payment');
  String get entryCostOfSales => _t('تكلفة المبيعات', 'Cost of sales');
  String get entryOpeningStock => _t('مخزون افتتاحي', 'Opening stock');
  String get entryStockAdjustment => _t('تسوية مخزون', 'Stock adjustment');

  String accountName(String code) => switch (code) {
    '1110' => _t('الصندوق (النقدية)', 'Cash on hand'),
    '1120' => _t('البنوك والمحافظ الإلكترونية', 'Bank & e-wallets'),
    '1130' => _t('العملاء (ذمم مدينة)', 'Accounts receivable'),
    '1140' => _t('المخزون', 'Inventory'),
    '1150' => _t('ضريبة مستردة (مدخلات)', 'Tax receivable (input)'),
    '2110' => _t('الموردون (ذمم دائنة)', 'Accounts payable'),
    '2120' => _t('ضريبة مستحقة (مخرجات)', 'Tax payable (output)'),
    '3100' => _t('رأس المال / أرصدة افتتاحية', 'Opening balance equity'),
    '4100' => _t('إيرادات المبيعات', 'Sales revenue'),
    '4900' => _t('إيرادات أخرى', 'Other income'),
    '5100' => _t('تكلفة البضاعة المباعة', 'Cost of goods sold'),
    '5200' => _t('عجز وتسويات المخزون', 'Inventory adjustments'),
    '6100' => _t('المصروفات التشغيلية', 'Operating expenses'),
    _ => code,
  };

  // ========== IN-APP NOTIFICATIONS & OPS ==========
  String get inboxTitle => _t('الإعلانات والتنبيهات', 'Announcements');
  String get noNotifications =>
      _t('لا توجد إعلانات حالياً', 'No announcements at this time');
  String get markAllRead => _t('تحديد الكل كمقروء', 'Mark all as read');
  String get announcementDetails =>
      _t('تفاصيل الإعلان', 'Announcement Details');
  String get openLink => _t('فتح الرابط المرفق', 'Open Link');
  String get unreadBadge => _t('جديد', 'New');
  String get categoryAnnouncement => _t('إعلان عام', 'Announcement');
  String get categoryUpdate => _t('تحديث جديد', 'Update');
  String get categoryCritical => _t('تنبيه هام', 'Important');
  String get categoryTips => _t('نصائح وإرشادات', 'Tips & Guides');
  String get undo => _t('تراجع', 'Undo');
  String get deleteAll => _t('حذف الكل', 'Delete all');
  String get confirmDeleteAll => _t('تأكيد حذف جميع التنبيهات؟', 'Delete all notifications?');
  String get confirmDeleteAllMessage => _t(
    'سيتم حذف جميع التنبيهات والإعلانات القابلة للحذف نهائياً. التنبيهات الهامة ستبقى محفوظة.',
    'All dismissible announcements will be permanently deleted. Critical notices will be preserved.',
  );
  String get notificationDeleted => _t('تم حذف التنبيه', 'Notification deleted');
  String get notificationsDeleted => _t('تم حذف التنبيهات المحددة', 'Selected notifications deleted');
  String get cannotDeleteCritical => _t('لا يمكن حذف التنبيهات الهامة أو الحرجة', 'Critical notifications cannot be deleted');
  String get selectedCount => _t('محدد', 'selected');

  // ========== CUSTOMER ACCOUNT STATEMENT ==========
  String get customerStatement => _t('كشف حساب عميل', 'Customer Statement');
  String get statementPeriod => _t('فترة الكشف', 'Statement Period');
  String get totalInvoiced => _t('إجمالي المبيعات', 'Total Invoiced');
  String get initialPayment => _t('دفعة أولية', 'Initial Payment');
  String get statementAdjustment =>
      _t('تسوية فروقات تعديل', 'Reconciliation Adjustment');
  String get statementWarningTitle => _t(
    'تنبيه: يتضمن هذا الكشف بنود تسوية لفروقات محاسبية',
    'Warning: Statement contains reconciliation adjustments',
  );
  String statementWarningDetail(String inv, String amount, String symbol) => _t(
    'الفاتورة #${_iso(inv)} تتضمن فارقاً محاسبياً بمقدار ${_iso(amount)} ${_iso(symbol)} ناتجاً عن تعديل يدوي سابق.',
    'Invoice #$inv has a discrepancy of $amount $symbol due to an earlier manual edit.',
  );
  String get cancelledReceiptsTitle => _t(
    'سندات قبض مرتبطة بفواتير ملغاة (مستبعدة من الرصيد)',
    'Receipts Linked to Cancelled Invoices (Excluded from Balance)',
  );
  String get cancelledReceiptsSubtitle => _t(
    'مبالغ تم استلامها بموجب سندات رسمية لفواتير تم إلغاؤها لاحقاً دون تسجيل حركة استرداد نقدي:',
    'Payments collected for invoices that were later cancelled without a recorded refund:',
  );
  String get cancelledInvoice => _t('الفاتورة الملغاة', 'Cancelled Invoice');
  String get transactionDetails => _t('رقم المستند والبيان', 'Doc # & Details');
  String get runningBalance => _t('الرصيد', 'Balance');
  String get authorizedSignature =>
      _t('توقيع المحاسب / الإدارة', 'Authorized Signature');
  String get customerSignature =>
      _t('توقيع العميل المستلم', 'Customer Signature');
  String get generatedAt => _t('تاريخ ووقت الطباعة', 'Generated At');
  String get page => _t('صفحة', 'Page');
  String get allTime => _t('كل المعاملات', 'All Transactions');
  String get selectCurrency => _t('اختر العملة', 'Select Currency');
  String get shareWhatsApp => _t('مشاركة واتساب', 'Share WhatsApp');
  String get previewPdf => _t('معاينة PDF', 'Preview PDF');
  String get noTransactionsInPeriod =>
      _t('لا توجد حركات في هذه الفترة', 'No transactions in this period');
  String whatsAppStatementCaption(
    String customer,
    String business,
    String from,
    String to,
    String balance,
    String symbol,
  ) => _t(
    'السلام عليكم يا ${_iso(customer)}،\nمرفق كشف حسابكم المالي الصادر من ${_iso(business)}.\nالفترة: من ${_iso(from)} إلى ${_iso(to)}\nالرصيد المستحق: ${_iso(balance)} ${_iso(symbol)}\nشاكرين ومقدرين حسن تعاملكم معنا.',
    'Hello $customer,\nAttached is your account statement from $business.\nPeriod: from $from to $to\nOutstanding balance: $balance $symbol\nThank you for your business.',
  );

  // ========== INVENTORY COSTING & PROFIT ==========
  String get inventoryValuationAtCost =>
      _t('قيمة المخزون بالتكلفة', 'Inventory Value at Cost');
  String get costStatus => _t('حالة التكلفة', 'Cost Status');
  String get costKnown => _t('محددة', 'Known');
  String get costUnknown => _t('غير محددة', 'Unknown');
  String get costReconstructed => _t('مسترجعة', 'Reconstructed');
  String get unresolvedCostProducts =>
      _t('منتجات بدون تكلفة', 'Unresolved Cost Products');
  String get averageCost => _t('متوسط التكلفة', 'Average Cost');
  String get cogs => _t('تكلفة المبيعات', 'Cost of Goods Sold');
  String get profitMargin => _t('هامش الربح', 'Profit Margin');
  String get costIncomplete => _t('تكلفة غير مكتملة', 'Incomplete Cost');
  String get costReliable => _t('تكلفة موثوقة', 'Reliable Cost');
  String get reconcileCost => _t('تسوية التكلفة', 'Reconcile Cost');
  String get enterCostBasis =>
      _t('أدخل أساس التكلفة للوحدة', 'Enter Unit Cost Basis');
  String get costBasisHint => _t('مثال: 1500', 'e.g. 1500');
  String get costReconciliationSuccess =>
      _t('تم تحديث أساس التكلفة بنجاح', 'Cost basis updated successfully');
  String get costReconciliationReason =>
      _t('سبب التسوية (اختياري)', 'Reconciliation Reason (Optional)');
  String get cannotEditPurchaseWithSubsequentSales => _t(
    'لا يمكن تعديل فاتورة الشراء لوجود مبيعات أو حركات مخزون لاحقة استهلكت هذا المخزون',
    'Cannot edit purchase document because subsequent sales or movements consumed this stock',
  );
  String get legacyCostSummaryTitle =>
      _t('ملخص تدقيق التكلفة التاريخية', 'Historical Cost Audit Summary');
  String get valuedStockCount => _t('منتجات مسعرة بالتكلفة', 'Valued Products');
  String get unvaluedStockQty =>
      _t('كمية المخزون غير المقيمة', 'Unvalued Stock Qty');
  String get close => _t('إغلاق', 'Close');
  String get currentStock => _t('المخزون الحالي', 'Current Stock');

  // ========== BUSINESS REPORTS & ANALYTICS ==========
  String get stockMovementsReport =>
      _t('تقرير حركات المخزون', 'Stock Movements Report');
  String get balanceBefore => _t('الرصيد قبل', 'Balance Before');
  String get balanceAfter => _t('الرصيد بعد', 'Balance After');
  String get lowStockReport =>
      _t('تقرير النواقص وإعادة الطلب', 'Low Stock & Replenishment Report');
  String get outOfStockReport =>
      _t('تقرير نفاد المخزون', 'Out of Stock Report');
  String get shortageQuantity => _t('الكمية المطلوبة', 'Shortage Qty');
  String get salesByProduct => _t('المبيعات حسب المنتج', 'Sales by Product');
  String get profitByProduct => _t('الأرباح حسب المنتج', 'Profit by Product');
  String get productPerformance => _t('أداء المنتجات', 'Product Performance');
  String get sortByRevenue => _t('حسب الإيراد', 'By Revenue');
  String get sortByQuantity => _t('حسب الكمية', 'By Quantity');
  String get sortByProfit => _t('حسب الربح', 'By Profit');
  String get allSuppliers => _t('كل الموردين', 'All Suppliers');
  String get paymentStatus => _t('حالة السداد', 'Payment Status');
  String get paidStatus => _t('مسدد بالكامل', 'Fully Paid');
  String get partialStatus => _t('مسدد جزئياً', 'Partially Paid');
  String get unpaidStatus => _t('غير مسدد', 'Unpaid');
  String get printOrShareReport =>
      _t('طباعة أو مشاركة التقرير', 'Print / Share Report');
  String get reportPeriod => _t('فترة التقرير', 'Report Period');
  String get reportGeneratedAt => _t('تاريخ وتوقيت التقرير', 'Generated At');
  String get unitsSummary =>
      _t('إجمالي الكميات حسب الوحدة', 'Quantities by Unit');
  String get grossProfitNotice => _t(
    'مجمل الربح = الإيراد الصافي - تكلفة البضاعة المباعة (لا يشمل المصروفات التشغيلية)',
    'Gross Profit = Net Revenue - COGS (Excludes operating expenses)',
  );
  String get unknownCostNotice => _t(
    'تنبيه: يحتوي هذا التقرير على مبيعات بتكلفة تاريخية غير محددة',
    'Notice: Report contains sales with unknown historical cost',
  );
  String get mixedCurrenciesNotice => _t(
    'تنبيه: تتضمن البيانات معاملات بعملات مختلفة دون تحويل إلى عملة موحدة',
    'Warning: Data includes multiple currencies without conversion to a single currency',
  );
  String get inventoryValuationReport =>
      _t('تقرير تقييم المخزون', 'Inventory Valuation Report');
  String get transactionCount => _t('عدد الفواتير', 'Invoices Count');
  String get currentInventoryReport =>
      _t('تقرير المخزون الحالي', 'Current Inventory Report');
  String get searchProductsHint =>
      _t('بحث بالاسم أو الباركود…', 'Search by name or barcode…');
  String get activeFilterAll => _t('الكل', 'All');
  String get noReplenishmentNeeded => _t(
    'لا توجد منتجات تحتاج لإعادة طلب حالياً',
    'No products need reordering currently',
  );
  String get product => _t('المنتج', 'Product');
  String get totalCost => _t('إجمالي التكلفة', 'Total Cost');
  String get status => _t('الحالة', 'Status');
  String get issued => _t('صادر', 'Issued');

  // ========== ADVANCED PRO FEATURES ==========
  String get featureStocktake =>
      _t('جرد وتسوية المخزون', 'Stocktake & Reconciliation');
  String get featureBulkPriceUpdate =>
      _t('تعديل الأسعار بالجملة', 'Bulk Price Editing');
  String get featureCsvImportExport =>
      _t('استيراد وتصدير CSV', 'CSV Import & Export');
  String get featureInventoryAudit =>
      _t('سجل تدقيق المخزون', 'Inventory Audit Log');

  String get stocktakeTitle => _t('جرد المخزون', 'Stocktake');
  String get startStocktake => _t('بدء جلسة جرد', 'Start Stocktake');
  String get sessionNumber => _t('رقم الجلسة', 'Session No.');
  String get systemQty => _t('كمية النظام', 'System Qty');
  String get countedQty => _t('الكمية الفعلية', 'Counted Qty');
  String get variance => _t('الفارق', 'Variance');
  String get uncounted => _t('غير مجرود', 'Uncounted');
  String get reviewAndFinalize =>
      _t('مراجعة وتأكيد الجرد', 'Review & Finalize');
  String get confirmFinalizeStocktake =>
      _t('تأكيد تسوية المخزون', 'Confirm Stock Reconciliation');
  String get stocktakeDiscrepancyWarning => _t(
    'سيتم تعديل كميات المخزون في النظام لتطابق الجرد الفعلي بدقة مع تسجيل حركات التسوية',
    'System stock quantities will be updated to match physical counts with audit adjustments recorded',
  );
  String get interimMovementWarning => _t(
    'تنبيه: حدثت حركات مخزون بعد بدء الجلسة؛ سيتم حساب التسوية بالنسبة للرصيد الحالي بدقة',
    'Notice: Stock movements occurred after session start; reconciliation will adjust against current stock accurately',
  );
  String get stocktakeFinalizedSuccess =>
      _t('تمت تسوية الجرد بنجاح', 'Stocktake finalized successfully');
  String get noStocktakeSessions =>
      _t('لا توجد جلسات جرد سابقة', 'No stocktake sessions yet');
  String get sessionStatusInProgress => _t('قيد الجرد', 'In Progress');
  String get sessionStatusCompleted => _t('مكتمل', 'Completed');
  String get sessionStatusCancelled => _t('ملغي', 'Cancelled');
  String get cancelStocktakeSession => _t('إلغاء جلسة الجرد', 'Cancel Session');
  String get confirmCancelSession => _t(
    'هل أنت متأكد من إلغاء جلسة الجرد دون تسوية؟',
    'Are you sure you want to cancel this stocktake session without reconciliation?',
  );

  String get bulkPricingTitle =>
      _t('تعديل الأسعار بالجملة', 'Bulk Price Editing');
  String get selectProducts => _t('تحديد المنتجات', 'Select Products');
  String get selectAll => _t('تحديد الكل', 'Select All');
  String get deselectAll => _t('إلغاء تحديد الكل', 'Deselect All');
  String get operationType => _t('نوع العملية', 'Operation Type');
  String get percentageIncrease =>
      _t('زيادة بنسبة مئوية (%)', 'Percentage Increase (%)');
  String get percentageDecrease =>
      _t('تخفيض بنسبة مئوية (%)', 'Percentage Decrease (%)');
  String get fixedIncrease => _t('زيادة بمبلغ ثابت', 'Fixed Amount Increase');
  String get fixedDecrease => _t('تخفيض بمبلغ ثابت', 'Fixed Amount Decrease');
  String get setNewPrice =>
      _t('تحديد سعر جديد مباشر', 'Set New Price Directly');
  String get targetPrice => _t('السعر المستهدف', 'Target Price');
  String get sellingPrice => _t('سعر البيع', 'Selling Price');
  String get bothPrices => _t('سعري البيع والشراء', 'Both Sale & Purchase');
  String get roundingRule => _t('قاعدة التقريب', 'Rounding Rule');
  String get roundNone => _t('بدون تقريب', 'No Rounding');
  String get roundNearestWhole => _t('لأقرب عدد صحيح', 'Nearest Whole');
  String get roundNearestTen => _t('لأقرب عشرة', 'Nearest Ten');
  String get roundUp => _t('تقريب لأعلى', 'Round Up');
  String get applyChanges => _t('تطبيق التعديلات', 'Apply Changes');
  String get previewChanges => _t('معاينة التعديلات', 'Preview Changes');
  String get currentPrice => _t('السعر الحالي', 'Current Price');
  String get proposedPrice => _t('السعر المقترح', 'Proposed Price');
  String get priceDifference => _t('الفرق', 'Difference');
  String get confirmPriceUpdate => _t(
    'تأكيد تعديل أسعار المنتجات المحددة؟',
    'Confirm price update for selected products?',
  );
  String get invalidPriceWarning => _t(
    'تحذير: توجد أسعار مقترحة سالبة أو غير صالحة',
    'Warning: Negative or invalid proposed prices detected',
  );
  String get pricesUpdatedSuccess =>
      _t('تم تعديل الأسعار بنجاح', 'Prices updated successfully');

  String get csvImportExportTitle =>
      _t('استيراد وتصدير CSV', 'CSV Import & Export');
  String get exportProductsCsv =>
      _t('تصدير المنتجات إلى CSV', 'Export Products to CSV');
  String get downloadTemplate => _t('تحميل نموذج CSV', 'Download CSV Template');
  String get importProductsCsv =>
      _t('استيراد منتجات من CSV', 'Import Products from CSV');
  String get selectCsvFile => _t('اختر ملف CSV', 'Select CSV File');
  String get duplicateHandling =>
      _t('طريقة التعامل مع المنتجات المكررة', 'Duplicate Handling Strategy');
  String get skipDuplicates => _t('تخطي المنتجات الموجودة', 'Skip Existing');
  String get updateExisting =>
      _t('تحديث بيانات المنتجات الموجودة', 'Update Existing Data');
  String get previewImport => _t('معاينة الاستيراد', 'Preview Import');
  String get validRows => _t('الصفوف الصالحة', 'Valid Rows');
  String get invalidRows => _t('صفوف بها أخطاء', 'Rows with Errors');
  String get confirmImport => _t('تأكيد الاستيراد', 'Confirm Import');
  String get importSummary => _t('ملخص الاستيراد', 'Import Summary');
  String get importedCount => _t('تم استيرادها', 'Imported');
  String get updatedCount => _t('تم تحديثها', 'Updated');
  String get skippedCount => _t('تم تخطيها', 'Skipped');
  String get csvStockInfoNotice => _t(
    'ملاحظة: كميات المخزون لا يتم تعديلها عبر ملف CSV للحفاظ على سلامة القيود المخزنية',
    'Note: Stock quantities are not modified via CSV to preserve inventory integrity',
  );

  String get advancedInventoryAnalytics =>
      _t('تحليلات المخزون المتقدمة', 'Advanced Inventory Analytics');
  String get inventoryTurnover =>
      _t('معدل دوران المخزون', 'Inventory Turnover');
  String get salesVelocity =>
      _t('سرعة المبيعات (وحدة/يوم)', 'Sales Velocity (units/day)');
  String get estimatedDaysRemaining =>
      _t('الأيام المتبقية التقريبية', 'Est. Days Remaining');
  String get slowMovingStock =>
      _t('مخزون بطيء الحركة / راكد', 'Slow-Moving Stock');
  String get tiedUpCapital => _t('رأس المال الراكد', 'Dormant Capital');
  String get reorderRecommendations =>
      _t('توصيات إعادة الطلب', 'Reorder Recommendations');
  String get negativeMarginAlert =>
      _t('تنبيه: هامش ربح سالب', 'Negative Margin Alert');
  String get sellingBelowCost =>
      _t('البيع بسعر أقل من التكلفة', 'Selling Below Cost');
  String get categoryValuationShare =>
      _t('توزيع قيمة المخزون حسب الفئة', 'Stock Value by Category');

  String get auditHistoryTitle =>
      _t('سجل التدقيق والمراجعة', 'Audit Log & Review');
  String get eventType => _t('نوع الحدث', 'Event Type');
  String get allEvents => _t('كل الأحداث', 'All Events');
  String get eventStocktake => _t('تسوية جرد', 'Stocktake');
  String get eventBulkPricing => _t('تعديل أسعار جماعي', 'Bulk Pricing');
  String get eventCsvImport => _t('استيراد CSV', 'CSV Import');
  String get eventStockAdjustment => _t('تعديل يدوي', 'Manual Adjustment');
  String get eventCostReconciled => _t('تسوية تكلفة', 'Cost Reconciled');
  String get noMatchingProduct =>
      _t('لم يتم العثور على منتج مطابق', 'No matching product');
  String get statusMatched => _t('مطابق', 'Matched');

  // ========== UI/UX QUALITY ENHANCEMENTS & ACTIONS ==========
  String get saveInvoice => _t('حفظ الفاتورة', 'Save Invoice');
  String get savePurchase => _t('حفظ أمر الشراء', 'Save Purchase Order');
  String get saveProduct => _t('حفظ المنتج', 'Save Product');
  String get saveService => _t('حفظ الخدمة', 'Save Service');
  String get saveCustomer => _t('حفظ العميل', 'Save Customer');
  String get saveSupplier => _t('حفظ المورد', 'Save Supplier');
  String get saveChanges => _t('حفظ التعديلات', 'Save Changes');
  String get addCustomer => _t('إضافة عميل', 'Add Customer');
  String get addSupplier => _t('إضافة مورد', 'Add Supplier');
  String get editCustomer => _t('تعديل بيانات العميل', 'Edit Customer');
  String get editSupplier => _t('تعديل بيانات المورد', 'Edit Supplier');
  String get addCustomerNew => _t('إضافة عميل جديد', 'Add New Customer');
  String get addSupplierNew => _t('إضافة مورد جديد', 'Add New Supplier');
  String get confirmStockAdjustment =>
      _t('تأكيد تسوية المخزون', 'Confirm Stock Adjustment');
  String get enterAdjustmentDelta => _t(
    'يرجى تحديد كمية التعديل (قيمة غير صفرية)',
    'Please enter an adjustment quantity (non-zero)',
  );
  String get openingStockHelp => _t(
    'الكمية الابتدائية المتوفرة في المخزون لبدء متابعة حركة المنتج بدقة.',
    'Initial physical quantity on hand to begin inventory tracking.',
  );
  String get purchasePriceCostHelp => _t(
    'سعر التكلفة للوحدة، يُعتمد في تقييم المخزون واحتساب أرباح المبيعات بدقة.',
    'Unit purchase cost used for stock valuation and profit calculations.',
  );
  String get pleaseAddItems => _t(
    'يرجى إضافة بند واحد على الأقل للمستند',
    'Please add at least one item to the document',
  );
  String get supplierStatement => _t('كشف حساب مورد', 'Supplier Statement');
  String get totalStockIn => _t('إجمالي الوارد', 'Total In');
  String get totalStockOut => _t('إجمالي المنصرف', 'Total Out');
  String get value => _t('القيمة', 'Value');
  String get movementStockIn => _t('وارد', 'Stock In');
  String get movementStockOut => _t('منصرف', 'Stock Out');
  String get reportCatFinancial =>
      _t('التقارير المالية والأرباح', 'Financial & Profit Reports');
  String get reportCatSalesPurchases =>
      _t('المبيعات والمشتريات والمدفوعات', 'Sales, Purchases & Payments');
  String get reportCatInventory =>
      _t('المخزون وحركة المواد', 'Inventory & Stock Analytics');
  String get reportCatAudit =>
      _t('سجلات التدقيق والمراجعة', 'Audit & Activity Logs');
  String get reportSubtitleSales => _t(
    'ملخص الفواتير، تكلفة البضاعة المباعة ومجمل الربح',
    'Invoices, COGS and gross profit summary',
  );
  String get reportSubtitlePurchases => _t(
    'أوامر الشراء المسجلة ومستحقات الموردين',
    'Purchase orders and supplier payables',
  );
  String get reportSubtitlePayments => _t(
    'حركة المقبوضات والمدفوعات النقدية والبنكية',
    'Inbound & outbound cash and bank receipts',
  );
  String get reportSubtitleAccounting => _t(
    'قائمة الدخل، الميزانية العمومية ودفتر الأستاذ العام',
    'Income statement, balance sheet & general ledger',
  );
  String get reportSubtitleCustomers => _t(
    'أرصدة العملاء، مبيعاتهم وحالة التحصيل',
    'Customer balances, revenue & receivables',
  );
  String get reportSubtitleSuppliers => _t(
    'أرصدة الموردين، مشترياتهم وحالة السداد',
    'Supplier balances, purchases & payables',
  );
  String get reportSubtitleInventory => _t(
    'تقييم المخزون الحالي بالتكلفة وحالة توفر المواد',
    'Stock valuation at cost and availability',
  );
  String get reportSubtitleLowStock => _t(
    'قائمة النواقص وحساب الكميات المطلوبة لإعادة الطلب',
    'Shortages and replenishment calculations',
  );
  String get reportSubtitleMovements => _t(
    'سجل حركات المخزون الواردة والمنصرفة مع الأرصدة',
    'Inbound and outbound movements with balances',
  );
  String get reportSubtitleProducts => _t(
    'تحليل أداء المنتجات حسب المبيعات والكميات والأرباح',
    'Product performance by sales, qty and profit',
  );
  String get reportSubtitleAdvancedAnalytics => _t(
    'معدل دوران المخزون، المنتجات الراكدة وهامش الربح',
    'Inventory turnover, slow stock & margin alerts',
  );
  String get reportSubtitleAudit => _t(
    'سجل الأنشطة والتعديلات والتسويات المخزنية',
    'Activity log, price changes & adjustments',
  );

  // ========== ACTIVATION SUPPORT & GUIDANCE ==========
  String get activationTroubleTitle =>
      _t('واجهت مشكلة في التفعيل؟', 'Having trouble with activation?');
  String get activationTroubleBody => _t(
    'يمكنك التواصل مع الدعم عبر واتساب أو البريد الإلكتروني للمساعدة في حل المشكلة.',
    'You can contact support via WhatsApp or email for assistance with resolving activation issues.',
  );
  String get activationSupportWhatsApp =>
      _t('تواصل عبر واتساب', 'Contact via WhatsApp');
  String get activationSupportEmail =>
      _t('مراسلة عبر البريد', 'Contact via Email');
  String get activationWhatsAppGreeting => _t(
    'مرحباً، أواجه صعوبة في تفعيل مفتاح الترخيص في تطبيق ورقتك وأحتاج مساعدة.',
    'Hello, I am having trouble activating my license key in Waraqatak and need help.',
  );
  String get activationEmailSubject => _t(
    'طلب مساعدة في تفعيل تطبيق ورقتك',
    'Assistance with Waraqatak License Activation',
  );
  String get activationTipKeyFormat => _t(
    'تلميح: تأكد من نسخ المفتاح كاملاً دون مسافات إضافية في البداية أو النهاية.',
    'Tip: Ensure the key is copied in full without leading or trailing spaces.',
  );
  String get activationTipServer => _t(
    'تلميح: تأكد من تفعيل اتصال الإنترنت بالهاتف ثم أعد الضغط على زر التفعيل.',
    'Tip: Make sure mobile data or Wi-Fi is active, then press Activate again.',
  );
  String get activationTipAttempts => _t(
    'تلميح: انتظر بضع دقائق قبل المحاولة مجدداً لتجنب الإيقاف المؤقت.',
    'Tip: Wait a few minutes before trying again to avoid temporary rate limits.',
  );

  // ========== DATABASE DIAGNOSTICS ==========
  String get databaseDiagnosticsTitle =>
      _t('فحص سلامة البيانات', 'Data Health & Diagnostics');
  String get databaseDiagnosticsSubtitle => _t(
    'تقرير قراءة فقط للتحقق من تكامل الأرصدة والقيود والمخزون',
    'Read-only report on ledger, balance, and inventory integrity',
  );
  String get diagnosticsScanning =>
      _t('جارٍ فحص قاعدة البيانات…', 'Scanning database…');
  String get diagnosticsSummaryErrors => _t('أخطاء تكامل', 'Integrity Errors');
  String get diagnosticsSummaryWarnings =>
      _t('تنبيهات تدقيق', 'Audit Warnings');
  String get diagnosticsSummaryInfo => _t('ملاحظات', 'Info');
  String get diagnosticsCleanTitle =>
      _t('قاعدة البيانات سليمة', 'Database is Clean');
  String get diagnosticsCleanDesc => _t(
    'تم فحص القيود والأرصدة والمخزون ولم يتم العثور على أي مشاكل أو تعارضات.',
    'Verified records, balances, and inventory with zero discrepancies found.',
  );
  String get diagnosticsTotalChecks =>
      _t('إجمالي الفحوصات المنفذة', 'Total checks executed');
  String get diagnosticsLastScan => _t('وقت الفحص', 'Scan time');
  String get diagnosticsCategoryAll => _t('الكل', 'All');
  String get diagnosticsCategoryOrphaned =>
      _t('سجلات يتيمة', 'Orphaned Records');
  String get diagnosticsCategoryBalances =>
      _t('تطابق أرصدة المستندات', 'Document Balances');
  String get diagnosticsCategoryStatuses =>
      _t('حالات المستندات', 'Document Statuses');
  String get diagnosticsCategoryPayments =>
      _t('اختلاف بين المبلغ المسدد وسجل المدفوعات', 'Payment Discrepancies');
  String get diagnosticsCategoryStock =>
      _t('اختلاف بين رصيد المخزون وسجل الحركات', 'Stock Discrepancy');
  String get diagnosticsCategoryMissingOpeningStock =>
      _t('رصيد افتتاحي مفقود', 'Missing Opening Stock');
  String get diagnosticsCategoryNegativeStock =>
      _t('رصيد مخزون سالب', 'Negative Physical Stock');
  String get diagnosticsCategoryCosting =>
      _t('تكلفة المخزون', 'Inventory Costing');
  String get diagnosticsCategoryDuplicates =>
      _t('أرقام مستندات مكررة', 'Duplicate Document Numbers');
  String get diagnosticsAffectedIds => _t('المعرفات المتأثرة', 'Affected IDs');
  String get diagnosticsMoreIds => _t('إضافية', 'more');
  String get diagnosticsManualReviewRequired =>
      _t('تتطلب مراجعة يدوية', 'Requires manual review');
  String get diagnosticsDisclaimer => _t(
    'هذا التقرير للمعاينة فقط (قراءة فقط). لا يتم إجراء أي تعديل أو حذف تلقائي للبيانات حفاظاً على السجلات المالية.',
    'This report is read-only. No automatic data modification or deletion occurs to preserve financial records.',
  );
  String get diagnosticsRefresh => _t('إعادة الفحص', 'Scan Again');
  String get diagnosticsNoFindingsForFilter =>
      _t('لا توجد ملاحظات في هذا التصنيف', 'No findings in this category');
  String get diagnosticsExecutionFailed => _t(
    'تعذر إكمال فحص قاعدة البيانات',
    'Failed to complete database diagnostics',
  );
  String get diagnosticsViewAffectedRecords =>
      _t('عرض السجلات المتأثرة', 'View Affected Records');
  String get diagnosticsAffectedRecordsTitle =>
      _t('السجلات المتأثرة', 'Affected Records');
  String get diagnosticsOpenRecord => _t('فتح السجل', 'Open Record');
  String get diagnosticsRecordUnavailable =>
      _t('السجل غير متاح', 'Record Unavailable');
  String get diagnosticsRecordUnavailableDesc => _t(
    'لم يتم العثور على هذا السجل في قاعدة البيانات أو قد تم حذفه مسبقاً.',
    'This record was not found in the database or has already been deleted.',
  );
  String get diagnosticsRecordOrphanedDesc => _t(
    'هذا القيد يتيم ولا يرتبط بأي مستند رئيسي نشط.',
    'This entry is orphaned and does not link to any active parent document.',
  );
  String get parentDocument => _t('المستند الأصلي', 'Parent Document');

  String diagnosticEntityType(String entityType) {
    if (!isArabic) {
      return switch (entityType) {
        'document_items' => 'document items',
        'products' => 'products',
        'stock_movements' => 'stock movements',
        'documents' => 'documents',
        'document_payments' => 'payment rows',
        'stocktake_items' => 'stocktake items',
        'stocktake_sessions' => 'stocktake sessions',
        'database' => 'database',
        _ => entityType,
      };
    }
    return switch (entityType) {
      'document_items' => 'بنود المستندات',
      'products' => 'أصناف المخزون',
      'stock_movements' => 'حركات المخزون',
      'documents' => 'مستندات',
      'document_payments' => 'سجلات المدفوعات',
      'stocktake_items' => 'بنود الجرد',
      'stocktake_sessions' => 'جلسات الجرد',
      'database' => 'قاعدة البيانات',
      _ => entityType,
    };
  }

  String diagnosticSeverity(String severityName) {
    if (!isArabic) {
      return switch (severityName.toLowerCase()) {
        'error' => 'Integrity Error',
        'warning' => 'Audit Warning',
        'info' => 'Information',
        _ => severityName,
      };
    }
    return switch (severityName.toLowerCase()) {
      'error' => 'خطأ تكامل',
      'warning' => 'تنبيه تدقيق',
      'info' => 'ملاحظة',
      _ => severityName,
    };
  }

  // ========== GOOGLE DRIVE BACKUP ==========
  String get googleDriveTitle =>
      _t('النسخ السحابي (Google Drive)', 'Cloud Backup (Google Drive)');
  String get googleDriveSubtitle => _t(
    'نسخ واسترجاع قاعدة البيانات بأمان في مجلد التطبيق الخاص',
    'Backup & restore securely in private app data folder',
  );
  String get googleDriveConnect =>
      _t('ربط حساب Google', 'Connect Google Account');
  String get googleDriveDisconnect =>
      _t('قطع اتصال الحساب', 'Disconnect Account');
  String get googleDriveUploadNow =>
      _t('رفع نسخة احتياطية الآن', 'Upload Backup Now');
  String get googleDriveRestoreFromCloud =>
      _t('استرجاع من Google Drive', 'Restore from Google Drive');
  String get googleDriveNoBackups => _t(
    'لا توجد نسخ احتياطية في Google Drive',
    'No backups found in Google Drive',
  );
  String get googleDriveUploading => _t(
    'جارٍ رفع النسخة إلى Google Drive…',
    'Uploading backup to Google Drive…',
  );
  String get googleDriveDownloading => _t(
    'جارٍ تنزيل النسخة والتحقق منها…',
    'Downloading and verifying backup…',
  );
  String get googleDriveUploadSuccess => _t(
    'تم رفع النسخة الاحتياطية بنجاح إلى Google Drive',
    'Backup uploaded successfully to Google Drive',
  );
  String get googleDriveSelectBackup =>
      _t('اختر نسخة احتياطية للاسترجاع', 'Select a backup to restore');
  String get googleDriveConfirmRestoreTitle =>
      _t('تأكيد استرجاع النسخة السحابية', 'Confirm Cloud Restore');
  String get googleDriveConfirmRestoreBody => _t(
    'سيتم استبدال البيانات الحالية بالنسخة المحددة. سيتم إنشاء نسخة أمان محلية تلقائياً قبل البدء.',
    'Current data will be replaced by the selected backup. A local safety backup is created automatically first.',
  );
  String get googleDriveSignInRequired => _t(
    'يرجى تسجيل الدخول بحساب Google أولاً',
    'Please sign in with a Google account first',
  );
  String get googleDriveErrorGeneric => _t(
    'حدث خطأ أثناء الاتصال بـ Google Drive. يرجى التحقق من اتصال الإنترنت.',
    'An error occurred communicating with Google Drive. Please check your internet connection.',
  );
  String get googleDriveErrorAuthExpired => _t(
    'انتهت صلاحية جلسة تسجيل الدخول، يرجى إعادة الاتصال بحساب Google.',
    'Session expired. Please reconnect your Google account.',
  );
  String get googleDriveErrorRestoreCorrupt => _t(
    'فشل الاسترجاع: ملف النسخة الاحتياطية غير صالح أو تالف.',
    'Restore failed: Backup file is invalid or corrupted.',
  );
  String get googleDriveSignInCancelled => _t(
    'تم إلغاء تسجيل الدخول أو لم يتم إكمال التحقق.',
    'Sign-in was cancelled or verification was not completed.',
  );
  String get googleDriveErrorConfig => _t(
    'فشل إعداد المصادقة، يرجى التحقق من إعدادات Google Cloud وتطابق بصمة التطبيق.',
    'Authentication configuration failed. Please verify Google Cloud settings and app certificate.',
  );
  String get googleDriveDeleteBackup => _t('حذف النسخة', 'Delete Backup');
  String get googleDriveConfirmDeleteTitle =>
      _t('تأكيد حذف النسخة السحابية', 'Confirm Cloud Backup Deletion');
  String get googleDriveConfirmDeleteBody => _t(
    'هل أنت متأكد من حذف هذه النسخة الاحتياطية من Google Drive؟ لا يمكن التراجع عن هذا الإجراء.',
    'Are you sure you want to delete this backup from Google Drive? This action cannot be undone.',
  );
  String get googleDriveDeleting => _t(
    'جارٍ حذف النسخة الاحتياطية…',
    'Deleting backup from Google Drive…',
  );
  String get googleDriveDeleteSuccess => _t(
    'تم حذف النسخة الاحتياطية من Google Drive بنجاح',
    'Backup deleted from Google Drive successfully',
  );
  String get googleDriveRefresh => _t('تحديث القائمة', 'Refresh List');
  String get googleDriveAccountConnected => _t('متصل', 'Connected');
  String get googleDriveAccountDisconnected => _t('غير متصل', 'Disconnected');
  String get googleDriveBackupListHeader =>
      _t('النسخ السحابية المتاحة', 'Available Cloud Backups');
  String get googleDriveEmptySubtitle => _t(
    'لم يتم رفع أي نسخ احتياطية إلى Google Drive بعد.',
    'No backups have been uploaded to Google Drive yet.',
  );

  // ========== ADVANCED REPAIR SYSTEM ==========
  String get repairSystemTitle =>
      _t('نظام الإصلاح المتقدم', 'Advanced Repair System');
  String get repairSystemSubtitle => _t(
    'فحص وتصحيح المشكلات المحاسبية والعلائقية بأمان داخل معاملات موثقة',
    'Inspect and safely repair accounting and relational issues in verified transactions',
  );
  String get repairActionFixAll =>
      _t('إصلاح جميع المشكلات الآمنة', 'Fix All Safe Issues');
  String get repairActionFix => _t('إصلاح المشكلة', 'Fix Issue');
  String get repairActionReview => _t('مراجعة السجلات', 'Review Records');
  String get repairActionExport =>
      _t('تصدير التقرير التشخيصي', 'Export Diagnostic Report');
  String get repairSafetyBackupCreated => _t(
    'تم إنشاء نسخة أمان محلية تلقائياً: ',
    'Local safety backup created automatically: ',
  );
  String get repairConfirmTitle =>
      _t('تأكيد عملية الإصلاح', 'Confirm Repair Action');
  String get repairConfirmFixAllTitle =>
      _t('إصلاح جميع المشكلات الآمنة تلقائياً', 'Auto-Repair All Safe Issues');
  String get repairConfirmFixAllBody => _t(
    'سيتم تنفيذ كافة الإصلاحات الحتمية والآمنة داخل معاملة قاعدة بيانات متكاملة مع إنشاء نسخة أمان محلية تلقائياً قبل البدء. لن يتم المساس بالسجلات المالية التي تتطلب قراراً يدوياً.',
    'All safe and deterministic repairs will be executed inside an SQLite transaction with an automatic local safety backup before starting. Financial records requiring human judgment will not be modified.',
  );
  String get repairSuccess => _t(
    'تم تنفيذ الإصلاح بنجاح والتحقق من سلامة البيانات',
    'Repair executed successfully and data integrity verified',
  );
  String get repairPartial => _t(
    'اكتملت بعض الإصلاحات، يرجى مراجعة المشكلات المتبقية',
    'Some repairs completed, please review remaining issues',
  );
  String get repairFailed => _t(
    'فشل الإصلاح وتم التراجع عن المعاملة بالكامل للحفاظ على البيانات',
    'Repair failed and transaction was fully rolled back to protect data',
  );
  String get repairTabAll => _t('الكل', 'All');
  String get repairTabAuto => _t('قابل للإصلاح التلقائي', 'Auto-Repairable');
  String get repairTabReview => _t('يتطلب المراجعة', 'Requires Review');
  String get repairRecordsCount =>
      _t('عدد السجلات المتأثرة', 'Affected Records');
  String get repairPlannedChange =>
      _t('الإجراء المخطط تنفيذه', 'Planned Action');
  String get repairRecommendedAction =>
      _t('الإجراء الموصى به', 'Recommended Action');
  String get repairReversible => _t('قابل للتراجع', 'Reversible');
  String get repairPermanent => _t('تعديل مباشر', 'Direct Update');
  String get repairReviewDialogTitle =>
      _t('تفاصيل المراجعة اليدوية', 'Manual Review Details');
  String get repairReviewGuidance =>
      _t('إرشادات المعالجة اليدوية', 'Recommended Next Steps');
  String get repairReportCopied => _t(
    'تم نسخ التقرير التشخيصي إلى الحافظة بنجاح',
    'Diagnostic report copied to clipboard successfully',
  );
  String get repairNoIssues => _t(
    'قاعدة البيانات سليمة وخالية من المشكلات',
    'Database is clean and healthy',
  );
  String get repairExecuting => _t(
    'جارٍ تنفيذ الإصلاح والتحقق من السلامة…',
    'Executing repair and verifying integrity…',
  );
  String get repairFixPreviewTitle =>
      _t('معاينة تفاصيل الإصلاح', 'Repair Preview');
  String get repairMovementPreviewTitle =>
      _t('معاينة إصلاح حركة المخزون', 'Stock Movement Repair Preview');
  String get repairMovementAction =>
      _t('معاينة وإصلاح الحركات', 'Preview & Repair Movements');
  String get repairOptionNeutralize => _t(
    'الخيار (ب): تحييد الحركة المكررة (موصى به - لا خسارة في الأرباح)',
    'Option B: Neutralize Duplicate (Recommended - No P&L Loss)',
  );
  String get repairOptionCompensate => _t(
    'الخيار (أ): قيد تسوية عكسي (يسجل خسارة في الأرباح والخسائر)',
    'Option A: Compensating Entry (Incurs P&L Loss)',
  );
  String get repairConfirmMovementBody => _t(
    'سيتم إنشاء نسخة أمان محلية تلقائياً قبل تطبيق تعديل حركات المخزون. هل ترغب في الاستمرار؟',
    'A local safety backup will be created automatically before modifying stock movements. Do you want to proceed?',
  );
  String get repairAffectedMovementsCount =>
      _t('حركات المخزون المتأثرة:', 'Affected Stock Movements:');
  String get repairExpectedMovement =>
      _t('الحركة المتوقعة من المستند:', 'Expected Movement:');
  String get repairActualMovement =>
      _t('إجمالي الحركات الفعلية:', 'Actual Movements:');
  String get repairSurplusMovement =>
      _t('الفائض المراد معالجته:', 'Surplus to Reconcile:');
  String get repairSafeBadge => _t('إصلاح آمن وتلقائي', 'Safe Auto-Repair');
  String get repairReviewBadge =>
      _t('يتطلب مراجعة يدوية', 'Requires Manual Review');

  // ========== FINANCIAL SUMMARY ENHANCEMENTS ==========
  String get paymentDetails => _t('تفاصيل الدفع', 'Payment Details');
  String get remainingBalanceHelper => _t(
    'يُحسب الرصيد المتبقي تلقائياً بناءً على المبلغ المدفوع',
    'Remaining balance is calculated automatically from the paid amount',
  );
  String get financialOverview => _t('الملخص المالي', 'Financial Overview');

  // ========== LOCALIZATION EXTENSIONS ==========
  String get eventStocktakeStarted =>
      _t('جرد المخزون (بدء)', 'Stocktake (Started)');
  String get eventStocktakeFinalized =>
      _t('جرد المخزون (تسوية)', 'Stocktake (Reconciled)');
  String get eventStocktakeCancelled =>
      _t('جرد المخزون (إلغاء)', 'Stocktake (Cancelled)');

  String get paymentMethodHintAr =>
      _t('مثال: بنكك، محفظة إلكترونية', 'e.g., Bankak, E-Wallet');
  String get paymentMethodHintEn =>
      _t('مثال: تحويل بنكي، محفظة إلكترونية', 'e.g., Bank Transfer, E-Wallet');

  String get selectedFileEmpty =>
      _t('الملف المحدد فارغ', 'Selected file is empty');
  String get invalidRow => _t('(صف غير صالح)', '(Invalid row)');
  String get existingProductTag => _t('منتج موجود', 'Existing product');
  String get newProductTag => _t('منتج جديد', 'New product');

  String get perDaySuffix => _t('/يوم', '/day');
  String daysRemainingCount(int days) {
    return _plural(
      days,
      zero: _t('أقل من يوم', 'Less than a day'),
      one: _t('~يوم واحد', '~1 day'),
      two: _t('~يومان', '~2 days'),
      few: _t('~$days أيام', '~$days days'),
      many: _t('~$days يوماً', '~$days days'),
      other: _t('~$days يوم', '~$days days'),
      enOne: '~1 day',
      enOther: '~$days days',
    );
  }
  String reorderSuggestionTag(String qty) => _t('طلب: ${_iso(qty)}', 'Order: $qty');
  String get noProductsBelowCost => _t(
    'ممتاز! لا توجد منتجات تباع بأقل من متوسط التكلفة',
    'Great! No products sold below average cost',
  );
  String lossAmount(String amount) => _t('خسارة: -${_iso(amount)}', 'Loss: -$amount');
  String unvaluedSalesNotice(int count) {
    return _plural(
      count,
      zero: _t('(لا توجد مبيعات)', '(0 sales)'),
      one: _t('(عملية بيع واحدة)', '(1 sale)'),
      two: _t('(عمليتا بيع)', '(2 sales)'),
      few: _t('($count عمليات بيع)', '($count sales)'),
      many: _t('($count عملية بيع)', '($count sales)'),
      other: _t('($count عملية بيع)', '($count sales)'),
      enOne: '(1 sale)',
      enOther: '($count sales)',
    );
  }

  String get financialSummaryCardTitle =>
      _t('الملخص المالي والحسابات', 'Financial Summary & Balance');

  String get errorDuplicateSku => _t(
    'رمز المنتج (SKU) مسجل مسبقاً لمنتج آخر',
    'Product SKU is already in use by another product',
  );
  String get errorDuplicateRecord => _t(
    'هذا السجل مسجل مسبقاً في النظام، يرجى التحقق من عدم التكرار',
    'This record already exists in the system',
  );
  String get errorForeignKeyConstraint => _t(
    'لا يمكن إتمام العملية لوجود مستندات أو سجلات مرتبطة بهذا العنصر',
    'Cannot complete operation because this item is referenced by existing records',
  );
  String get errorInsufficientStockGeneral => _t(
    'الكمية المتوفرة في المخزون غير كافية لإتمام العملية',
    'Insufficient stock to complete this transaction',
  );
  String get errorNetworkConnectivity => _t(
    'تعذّر الاتصال بالإنترنت، يرجى التحقق من الشبكة ثم إعادة المحاولة',
    'Could not connect to the network. Please check your internet connection',
  );
  String get errorOperationTimeout => _t(
    'استغرقت العملية وقتاً أطول من المتوقع، يرجى إعادة المحاولة',
    'The operation timed out. Please try again',
  );
  String get errorInvalidNumberFormat => _t(
    'يرجى التأكد من كتابة الأرقام والمبالغ بشكل صحيح',
    'Please enter valid numbers',
  );

  String get pdfTaxIdLabel => _t('الرقم الضريبي:', 'Tax ID:');
  String get pdfTaxRegLabel => _t('رقم التسجيل الضريبي:', 'Tax Reg:');
  String get pdfCommercialRegLabel => _t('السجل التجاري:', 'CR:');
  String get pdfBranchLabel => _t('الفرع:', 'Branch:');

  bool get isArabic => langCode == 'ar';

  String _t(String ar, String en) => langCode == 'ar' ? ar : en;

  /// Private Bidi First Strong Isolate (U+2068 .. U+2069) helper.
  /// Applied exclusively to dynamic presentation tokens displayed in Flutter widgets
  /// and WhatsApp/share messages to prevent RTL/LTR layout reversals.
  static String _iso(Object? s) => '\u2068$s\u2069';

  /// Arabic plural category according to CLDR rules
  static String _arabicPluralCategory(num count) {
    final int n = count.abs().toInt();
    if (n == 0) return 'zero';
    if (n == 1) return 'one';
    if (n == 2) return 'two';
    final int rem100 = n % 100;
    if (rem100 >= 3 && rem100 <= 10) return 'few';
    if (rem100 >= 11 && rem100 <= 99) return 'many';
    return 'other';
  }

  /// Zero-dependency plural helper for Arabic and English.
  String _plural(
    num count, {
    required String zero,
    required String one,
    String? two,
    required String few,
    String? many,
    required String other,
    String? enOne,
    String? enOther,
  }) {
    if (langCode == 'ar') {
      final cat = _arabicPluralCategory(count);
      switch (cat) {
        case 'zero':
          return zero;
        case 'one':
          return one;
        case 'two':
          return two ?? few;
        case 'few':
          return few;
        case 'many':
          return many ?? other;
        case 'other':
        default:
          return other;
      }
    } else {
      if (count == 1) {
        return enOne ?? other;
      }
      return enOther ?? other;
    }
  }
}

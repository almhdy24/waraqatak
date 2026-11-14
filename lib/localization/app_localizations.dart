// ignore_for_file: non_constant_identifier_names

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
    'لديك تعديلات لم تُحفظ. هل تريد الخروج وتجاهلها؟',
    'You have unsaved changes. Are you sure you want to discard them and leave?',
  );
  String get discardChanges => _t('تجاهل التعديلات', 'Discard Changes');
  String get confirmDeleteLine => _t('حذف هذا البند؟', 'Delete this item?');
  String get deleteLineWarning => _t(
    'سيُحذف هذا البند من المستند.',
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
  String get receivedFrom => _t('استلمنا من', 'Received From');
  String get paidTo => _t('دفعنا إلى', 'Paid To');
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
  String get customerHasDocumentsTitle =>
      _t('للعميل معاملات مسجلة', 'Customer has transactions');
  String get customerHasDocumentsMessage => _t(
    'لهذا العميل مستندات مسجلة، والحذف سيمحو سجل حسابه وأرصدته. أرشف العميل بدلاً من ذلك: يختفي من المستندات الجديدة وتبقى كل السجلات سليمة.',
    'This customer has recorded documents. Deleting would erase their account history and balances. Archive the customer instead: they stop appearing for new documents, and all records stay intact.',
  );
  String get archiveCustomer => _t('أرشفة العميل', 'Archive customer');
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
  String get title => _t('عنوان المستند', 'Title');
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
    'ستُستبدل بياناتك الحالية بما في النسخة الاحتياطية، ولا يمكن التراجع عن ذلك.',
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
  String get backupEncryptionQuestion => _t(
    'هل تريد حماية النسخة بكلمة مرور؟',
    'Do you want to protect this backup with a password?',
  );
  String get backupWithoutPassword => _t(
    'لا، بدون كلمة مرور (غير مشفرة)',
    'No, without password (unencrypted)',
  );
  String get backupWithPassword =>
      _t('نعم، حماية بكلمة مرور', 'Yes, protect with password');
  String get backupPassword => _t('كلمة المرور', 'Password');
  String get backupConfirmPassword =>
      _t('تأكيد كلمة المرور', 'Confirm password');
  String get backupPasswordRequired =>
      _t('أدخل كلمة المرور', 'Please enter a password');
  String get backupPasswordMinLength => _t(
    'كلمة المرور يجب أن لا تقل عن 8 أحرف',
    'Password must be at least 8 characters',
  );
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
    'هذه النسخة محمية بكلمة مرور. أدخل كلمة المرور لاستعادتها:',
    'This backup is password-protected. Enter the password to restore it:',
  );
  String get backupIncorrectPassword => _t(
    'كلمة المرور غير صحيحة أو الملف تالف',
    'Incorrect password or corrupted backup file',
  );
  String get backupUpdateRequired =>
      _t('حدّث التطبيق لفتح هذه النسخة', 'Update the app to open this backup');
  String get backupCorrupted => _t(
    'ملف النسخة الاحتياطية تالف أو غير صالح',
    'Backup file is corrupted or invalid',
  );
  String get backupDecrypting => _t(
    'جاري فك التشفير والتحقق من البيانات…',
    'Decrypting and verifying data…',
  );
  String get backupEncrypting => _t(
    'جاري تشفير النسخة الاحتياطية والتحقق…',
    'Encrypting backup and verifying…',
  );
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
    'لا يمكن إلغاء المستند لوجود سندات قبض/صرف نشطة مرتبطة به (${_iso(voucherNumbers)}). ألغِ هذه السندات أولاً.',
    'Cannot cancel document with active payment receipts/vouchers ($voucherNumbers). Please cancel these vouchers first.',
  );
  String get cancelPaidDocumentTitle =>
      _t('تأكيد إلغاء مستند مسدد', 'Confirm Cancellation of Paid Document');
  String cancelPaidRecordedAmount(String amount, String symbol) => _t(
    'المبلغ المسدد المسجل: ${_iso('$amount $symbol')}',
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

  String voucherOutstandingCustomer(String amount) => _t(
    'المستحق على العميل: ${_iso(amount)}',
    'Customer owes: ${_iso(amount)}',
  );
  String voucherOutstandingSupplier(String amount) => _t(
    'المستحق للمورد: ${_iso(amount)}',
    'Owed to supplier: ${_iso(amount)}',
  );
  String get voucherAllocationHintCustomer => _t(
    'يُسدَّد المبلغ على فواتير العميل المفتوحة من الأقدم إلى الأحدث.',
    'The amount settles the customer open invoices from oldest to newest.',
  );
  String get voucherAllocationHintSupplier => _t(
    'يُسدَّد المبلغ على فواتير شراء المورد المفتوحة من الأقدم إلى الأحدث.',
    'The amount settles the supplier open purchases from oldest to newest.',
  );
  String voucherAmountExceedsOutstanding(String amount) => _t(
    'المبلغ أكبر من المستحق (${_iso(amount)}).',
    'The amount is more than the outstanding balance (${_iso(amount)}).',
  );
  String get voucherNoOpenDocuments => _t(
    'لا توجد مستندات مفتوحة لهذا الطرف. اترك الحقل فارغاً لتسجيل المبلغ كإيراد أو مصروف آخر.',
    'There are no open documents for this contact. Leave the contact empty to record the amount as other income or expense.',
  );
  String voucherAllocatedSnack(String count) => _t(
    'تم توزيع المبلغ على عدة مستندات (${_iso(count)})، وأُنشئ سند لكل مستند.',
    'The amount was split across several documents (${_iso(count)}); a receipt was created for each.',
  );
  String get errorPaymentExceedsOutstanding => _t(
    'المبلغ أكبر من المستحق على الطرف.',
    'The amount is more than the outstanding balance.',
  );
  String get errorDocumentAlreadyCancelled =>
      _t('المستند ملغى بالفعل.', 'Document is already cancelled.');
  String get errorCannotReduceTotalBelowPayments => _t(
    'لا يمكن تقليل الإجمالي إلى أقل من المدفوعات المسجلة.',
    'Cannot reduce total below recorded payments.',
  );
  String get errorInsufficientStockToCancelPurchase => _t(
    'لا يمكن إلغاء فاتورة الشراء لعدم توفر مخزون كافٍ.',
    'Cannot cancel purchase due to insufficient stock.',
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
    'حدّد حالة رد المبلغ لإتمام الإلغاء',
    'Please select the refund status to confirm cancellation',
  );
  String get refundStatusRefunded => _t('تم رد المبلغ', 'Refunded');
  String get refundStatusNotRefunded => _t('لم يُرد بعد', 'Not refunded yet');
  String get refundStatusNotRecorded =>
      _t('لم تُسجَّل حالة الرد', 'Refund status not recorded');
  String get keepDocument =>
      _t('تراجع (إبقاء المستند)', 'Go Back (Keep Document)');
  String get confirmAndCancel =>
      _t('تأكيد وإلغاء المستند', 'Confirm & Cancel Document');
  String get updateRefundStatus =>
      _t('تعديل حالة رد المبلغ', 'Update Refund Status');
  String get refundAuditCardDisclaimer => _t(
    'هذه الملاحظة للسجلات الإدارية فقط ولا تؤثر على التقارير أو الأرصدة الحسابية.',
    'This note is for record-keeping only and does not affect reports or balances.',
  );
  String get cancelledDocumentMoneyCardTitle =>
      _t('حالة أموال المستند الملغى', 'Cancelled Document Money Status');
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
  String get sku => _t('رمز المنتج (SKU)', 'SKU');
  String get unit => _t('وحدة القياس', 'Unit');
  String get active => _t('نشط', 'Active');
  String get inactive => _t('غير نشط', 'Inactive');
  String get addItem => _t('إضافة بند', 'Add Item');
  String get addProduct => _t('إضافة منتج', 'Add Product');
  String get addService => _t('إضافة خدمة', 'Add Service');
  String get editProduct => _t('تعديل المنتج', 'Edit Product');
  String get editService => _t('تعديل الخدمة', 'Edit Service');

  // Product image strings
  String get addPhoto => _t('إضافة صورة', 'Add Photo');
  String get changePhoto => _t('تغيير الصورة', 'Change Photo');
  String get removePhoto => _t('حذف الصورة', 'Remove Photo');
  String get takePicture => _t('التقاط صورة', 'Take Picture');
  String get chooseFromGallery => _t('اختر من المعرض', 'Choose from Gallery');
  String get imageLoadError => _t('تعذر تحميل الصورة', 'Failed to load image');
  String get imagePickFailed => _t('تعذر اختيار الصورة أو حفظها', 'Failed to select or save image');
  String get deactivateProduct => _t('تعطيل المنتج', 'Deactivate Product');
  String get activateProduct => _t('تفعيل المنتج', 'Activate Product');
  String get deactivateProductMessage => _t(
    'هذا المنتج له مستندات أو حركات مخزون سابقة. هل تريد تعطيله بدلاً من حذفه؟',
    'This product has documents or stock history. Deactivate it instead of deleting it?',
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
    'لا يمكن تحويل منتج له مخزون إلى خدمة. صفّر المخزون أولاً.',
    'Cannot convert a product with stock to a service. Please adjust stock to 0 first',
  );
  String get stockCannotBeEditedDirectly => _t(
    'لا يمكن تعديل كمية المخزون مباشرة هنا. استخدم «تعديل المخزون».',
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
  String get payable => _t('مستحق عليك', 'Payable');

  // ========== CUSTOMERS EXTENDED ==========
  String get customerBalance => _t('رصيد العميل', 'Customer Balance');
  String get receivable => _t('مستحق لك', 'Receivable');
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
  String get addStock => _t('إضافة مخزون (+)', 'Add Stock (+)');
  String get removeStock => _t('خصم مخزون (−)', 'Remove Stock (−)');
  String get adjustmentQuantity => _t('كمية التعديل', 'Adjustment Quantity');
  String get confirmAddStock =>
      _t('تأكيد إضافة المخزون', 'Confirm Stock Addition');
  String get confirmRemoveStock =>
      _t('تأكيد خصم المخزون', 'Confirm Stock Removal');
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
    'لا يمكن أن يصبح المخزون أقل من صفر',
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

  // ========== DASHBOARD & REPORT DATE FILTERS ==========
  String get today => _t('اليوم', 'Today');
  String get yesterday => _t('أمس', 'Yesterday');
  String get thisWeek => _t('هذا الأسبوع', 'This Week');
  String get last7Days => _t('آخر 7 أيام', 'Last 7 Days');
  String get thisMonth => _t('هذا الشهر', 'This Month');
  String get previousMonth => _t('الشهر السابق', 'Previous Month');
  String get lastMonth => _t('الشهر الماضي', 'Last Month');
  String get thisYear => _t('هذا العام', 'This Year');
  String get customRange => _t('فترة مخصصة', 'Custom Range');
  String get fromDate => _t('من', 'From');
  String get toDate => _t('إلى', 'To');
  String get dateRange => _t('الفترة الزمنية', 'Date Range');
  String get selectDate => _t('اختر التاريخ', 'Select Date');
  String get invalidDate =>
      _t('تاريخ غير صحيح (سنة/شهر/يوم)', 'Invalid date (YYYY/MM/DD)');
  String get dateOutOfRange =>
      _t('التاريخ خارج النطاق المسموح', 'Date is out of allowed range');
  String get dateFromMustBeBeforeTo => _t(
    'تاريخ البداية يجب أن يسبق أو يطابق تاريخ النهاية',
    'Start date must be before or equal to end date',
  );

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
  String get paperThermal80 => _t('ورق حراري 80 مم', 'Thermal 80mm');
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
  String get pricingCategoryCustomerDesc => _t(
    'فئة السعر الافتراضية لهذا العميل',
    'Default pricing tier for this customer',
  );
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
  String get duplicateUnitNameError => _t(
    'اسم الوحدة موجود بالفعل لهذا المنتج',
    'Unit name already exists for this product',
  );
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
      _t('نسبة ضريبة افتراضية', 'Default Tax Profile');
  String get noDefaultProfile =>
      _t('لا توجد نسبة افتراضية', 'No default profile');

  String get taxProfiles => _t('نسب الضريبة', 'Tax Profiles');
  String get taxProfilesDesc =>
      _t('إنشاء وإدارة معدلات الضريبة', 'Create and manage tax rates');
  String get addTaxProfile => _t('إضافة نسبة ضريبة', 'Add Tax Profile');
  String get editTaxProfile => _t('تعديل نسبة الضريبة', 'Edit Tax Profile');
  String get taxProfileName => _t('اسم النسبة', 'Profile Name');
  String get taxProfileType => _t('نوع الضريبة', 'Tax Type');
  String get taxProfileRate => _t('نسبة الضريبة (%)', 'Tax Rate (%)');
  String get taxProfileDefault => _t('افتراضي', 'Default');
  String get taxProfileInclusive =>
      _t('شامل (مضمّن في السعر)', 'Inclusive (in price)');
  String get taxProfileExclusive =>
      _t('غير شامل (يضاف للسعر)', 'Exclusive (added on top)');
  String get calculationMode => _t('طريقة الاحتساب', 'Calculation Mode');
  String get noTaxProfiles =>
      _t('لا توجد نسب ضريبة بعد', 'No tax profiles yet');
  String get confirmDeleteProfile =>
      _t('حذف نسبة الضريبة؟', 'Delete Tax Profile?');
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
  String get taxProfile => _t('نسبة الضريبة', 'Tax Profile');
  String get noTaxProfile => _t('بدون نسبة ضريبة', 'No Tax Profile');
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
    'تُضبط خيارات الضريبة ونسبها من شاشة الإعدادات المالية.',
    'Tax options and rates are configured in Financial Settings.',
  );
  String get taxesStatus => _t('حالة نظام الضريبة', 'Tax System Status');
  String get taxesEnabledActive => _t('الضريبة مفعلة', 'Taxes Active');
  String get taxesDisabledInactive =>
      _t('الضريبة معطلة (0%)', 'Taxes Disabled (0%)');
  String get productTaxOverrideNote => _t(
    'يمكنك تحديد نسبة ضريبة مختلفة لكل منتج من شاشة تفاصيل المنتج (مثل: المنتجات المعفاة أو ذات النسبة الصفرية).',
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
      _t('سعر المنتج المدخل', 'Entered Item Price');
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
      _t('أدخل اسم طريقة الدفع', 'Please enter a payment method name');
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
    'اكتمل تنزيل التحديث. أعد تشغيل التطبيق لتثبيته.',
    'Update downloaded. Restart the app to apply it.',
  );
  String get restartNow => _t('إعادة التشغيل الآن', 'Restart Now');
  String get updateCheckFailed => _t(
    'تعذر التحقق من التحديثات حالياً',
    'Unable to check for updates at this time',
  );
  String get updateFailed =>
      _t('تعذر إكمال التحديث', 'Unable to complete update');
  String get updateNonPlayInstall => _t(
    'التحديثات التلقائية متوفرة فقط للتطبيقات المثبتة عبر متجر Google Play',
    'In-app updates are only available for apps installed from Google Play',
  );
  String get updateNotAllowed => _t(
    'يتوفر تحديث ولكن لا يمكن تثبيته حالياً من داخل التطبيق',
    'An update is available but cannot be installed from within the app',
  );

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
      _t('14 يوماً مجاناً — بدون قيود', '14 days free — no limits');
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
    'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
    'Too many attempts. Please try again later.',
  );
  String get activationServerUnreachable => _t(
    'تعذّر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مجدداً.',
    'Could not reach the server. Please try again later.',
  );
  String get activationDeviceUnavailable => _t(
    'تعذّر التحقق من هذا الجهاز. أعد المحاولة، وإن تكرر الخطأ تواصل مع الدعم.',
    'Could not verify device identity securely.',
  );
  String get activationStorageFailed => _t(
    'تعذّر حفظ الترخيص على هذا الجهاز. حاول مرة أخرى، وإن تكرر الخطأ تواصل مع الدعم.',
    "Couldn't save the license on this device. Please try again. If it keeps happening, contact support.",
  );
  String get licenseStorageFault => _t(
    'تعذّرت قراءة الترخيص المحفوظ على هذا الجهاز. أعد إدخال مفتاح التفعيل.',
    'The saved license could not be read on this device. Please re-enter your activation key.',
  );
  String get activationTipDevice => _t(
    'تلميح: أعد تشغيل الهاتف وجرّب مرة أخرى. إن استمرت المشكلة تواصل مع الدعم.',
    'Tip: Ensure system services are active or run the app on a supported device.',
  );
  String get pasteKey => _t('لصق', 'Paste');
  String get deviceModelLabel => _t('موديل الجهاز', 'Device Model');
  String get deviceIdLabel => _t('معرّف الجهاز', 'Device Identifier');
  String get copyDeviceId => _t('نسخ معرّف الجهاز', 'Copy device identifier');
  String get deviceIdCopied => _t(
    'تم نسخ معرّف الجهاز إلى الحافظة',
    'Device identifier copied to clipboard',
  );
  String get supportFromAboutPage => _t(
    'إذا استمرت المشكلة، يمكنك طلب الدعم الفني من صفحة "حول التطبيق".',
    'If the problem continues, contact support from the About page.',
  );
  String get openAboutPage => _t('صفحة حول التطبيق', 'About page');
  String get copySupportInfo =>
      _t('نسخ معلومات الدعم الفني', 'Copy support info');
  String get supportInfoCopied => _t(
    'تم نسخ معلومات الدعم الفني للحافظة',
    'Support info copied to clipboard',
  );
  String referenceIdLabel(String id) =>
      _t('الرقم المرجعي: ${_iso(id)}', 'Reference ID: $id');
  String get copiedToClipboard => _t('تم النسخ للحافظة', 'Copied to clipboard');
  String get transferNoticeTitle =>
      _t('نقل الترخيص إلى جهاز آخر', 'License Transfer');
  String get transferNoticeBody => _t(
    'لتفعيل المفتاح على جهاز جديد، أزله من هذا الجهاز أولاً بالزر أدناه.',
    'To activate on another device, remove the key from this device first using the button below.',
  );
  String get documentNotFound => _t('المستند غير موجود', 'Document not found');
  String get documentNotFoundDesc => _t(
    'تعذّر العثور على هذا المستند. ربما حُذف.',
    'The requested document was not found in the database or may have been deleted.',
  );
  String get viewDocument => _t('عرض المستند', 'View Document');
  String get helpCenter => _t('مركز المساعدة', 'Help Center');
  String get helpCenterSubtitle => _t(
    'دليل الاستخدام والأسئلة الشائعة عبر الإنترنت',
    'Online user guides & FAQs',
  );
  String get openDestination => _t('فتح', 'Open');
  String get entityLabel => _t('الكيان', 'Entity');
  String get actionTypeLabel => _t('نوع الإجراء', 'Action Type');
  String get detailsLabel => _t('التفاصيل', 'Details');

  // ── License screen (Settings → License) ───────────────────────────────────
  String get licenseScreenRedesignTitle =>
      _t('تفعيل ورقتك Pro', 'Activate Waraqatak Pro');
  String trialActiveStatusWithDays(int days) => _t(
    'عندك تجربة مجانية لمدة 14 يوماً لكامل مميزات ورقتك Pro. متبقي $days يوم.',
    'You have a 14-day free trial for all Waraqatak Pro features. $days day(s) remaining.',
  );
  String get trialExpiredStatusMessage => _t(
    'انتهت التجربة المجانية. يمكنك إدخال مفتاح التفعيل للاستمرار في استخدام مميزات Pro.',
    'The free trial has expired. You can enter an activation key to continue using Pro features.',
  );
  String get whatsappNotInstalled => _t(
    'واتساب غير مثبت على جهازك',
    'WhatsApp is not installed on your device',
  );
  String get freeVsProIntroText => _t(
    'تحميل ورقتك مجاني. تجربة Pro كاملة 14 يوماً بدون دفع، وبعدها تحتاج مفتاح تفعيل.',
    'Downloading Waraqatak is free. Full Pro trial for 14 days without payment, afterwards an activation key is needed.',
  );
  String get freeTierHeader => _t('المجاني', 'Free');
  String get proTierHeader => _t('Pro (مع المفتاح)', 'Pro (with key)');
  String get alreadyHaveKeyTitle => _t('عندك مفتاح؟', 'Already have a key?');
  String get enterKeyHintText => _t(
    'الصق المفتاح هنا ثم اضغط "تفعيل".',
    'Paste the key here and tap "Activate".',
  );
  String get activationKeyHelperText => _t(
    'هذه الصفحة مخصصة لمن يملك مفتاح تفعيل مسبقاً. الصق المفتاح واضغط تفعيل، والتطبيق يعمل بشكل كامل بدون مفتاح.',
    'This screen is for users who already have an activation key. Paste the key and tap Activate; the app functions fully without one.',
  );
  String get supportCardTitle => _t('الدعم والمساعدة', 'Help & Support');
  String get supportCardSubtitle => _t(
    'هل تحتاج لمساعدة في التطبيق أو التفعيل؟ فريق الدعم متاح لمساعدتك.',
    'Need help with the app or activation? Our support team is here to assist you.',
  );
  String get contactEmailAction => _t('البريد الإلكتروني', 'Email');
  String get whatsappSupportAction => _t('واتساب', 'WhatsApp');
  String get supportEmailSubject =>
      _t('طلب دعم فني — تطبيق ورقتك', 'Support Request — Waraqatak App');
  String emailLaunchFailedWithAddress(String email) => _t(
    'تعذر فتح تطبيق البريد. يمكنك مراسلتنا على: $email',
    'Could not open email app. You can reach us at: $email',
  );
  String get copyEmailAddress => _t('نسخ البريد', 'Copy Email');
  String get emailAddressCopied =>
      _t('تم نسخ عنوان البريد الإلكتروني', 'Email address copied to clipboard');
  String get licenseLoadError => _t(
    'تعذر تحميل بيانات الترخيص. يرجى إعادة المحاولة.',
    'Could not load license data. Please try again.',
  );
  String get licenseDetailsTitle =>
      _t('تفاصيل الترخيص والجهاز', 'License & Device Details');
  String get licenseDetailsSubtitle => _t(
    'معرّف الجهاز، شروط النقل، وملاحظات الصلاحية',
    'Device ID, transfer terms, and expiry notes',
  );
  String get freeVsProComparisonTitle =>
      _t('مقارنة مميزات المجاني و Pro', 'Free vs Pro Features Comparison');
  String get activationTipStorage => _t(
    'تلميح: تأكد من توفر مساحة تخزين كافية وصلاحيات التخزين الآمن بالجهاز.',
    'Tip: Ensure device storage and secure storage are accessible.',
  );
  String get activationUnexpectedError => _t(
    'حدث خطأ غير متوقع أثناء التفعيل. يرجى المحاولة لاحقاً.',
    'An unexpected error occurred during activation. Please try again later.',
  );
  String activateCooldown(int seconds) =>
      _t('تفعيل ($seconds ث)', 'Activate (${seconds}s)');
  String get verifyingKey => _t('جارٍ التحقق من المفتاح…', 'Verifying key…');
  String get keyPastedFeedback => _t('تم لصق المفتاح', 'Key pasted');
  String get clearKeyTooltip => _t('مسح', 'Clear');
  String get validKeyFormat => _t('صيغة المفتاح صحيحة', 'Valid key format');
  String get proUnlockedPurchases =>
      _t('إدارة المشتريات وفواتير الموردين', 'Purchases & supplier invoices');
  String get proUnlockedInventory =>
      _t('المخزون وحركات الجرد المتعدد', 'Inventory & stocktake operations');
  String get proUnlockedReports => _t(
    'التقارير المالية المتقدمة والأرباح',
    'Advanced financial reports & profit',
  );
  String get proUnlockedWholesale =>
      _t('أسعار الجملة والوحدات المتعددة', 'Wholesale pricing & multi-units');
  String get whatProUnlockedTitle =>
      _t('المميزات المتاحة مع Pro:', 'Features available with Pro:');
  String get helpAndSupport => _t('المساعدة والدعم', 'Help & Support');
  String get activationSuccessDone => _t(
    'تم التفعيل بنجاح، مميزات Pro صارت متاحة لك.',
    'Activated successfully! Pro features are now available to you.',
  );
  String get activationFailureGuidance => _t(
    'تعذّر التفعيل. تأكد أن المفتاح منسوخ كاملاً بدون مسافات وأن الإنترنت شغال. إذا استمرت المشكلة، يمكنك طلب الدعم الفني.',
    'Activation failed. Ensure the key is copied in full without spaces and that internet is working. If the problem persists, request technical support.',
  );

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
    'سيُزال مفتاح التفعيل من هذا الجهاز ويُفكّ ارتباطه بالخادم. المفتاح نفسه لا يُلغى ويمكنك إدخاله مجدداً. وإن كانت التجربة المجانية لا تزال سارية فستعود إليها.',
    'The activation key will be unlinked and removed from this device only. The key is not cancelled and you can enter it again. If your free trial is still valid, you will return to it.',
  );
  String get removeKeyConfirmAction => _t('إزالة', 'Remove');
  String get keyRemovedSnack =>
      _t('تمت إزالة المفتاح من هذا الجهاز.', 'Key removed from this device.');
  String get keyRemovedServerNotReleased => _t(
    'أُزيل المفتاح من هذا الجهاز، لكن تعذّر تحرير الجهاز على الخادم. أعد إدخال المفتاح وأزله مجدداً عند توفر الإنترنت، أو تواصل مع الدعم.',
    'The key was removed from this device, but the device could not be released on the server. Re-enter the key and remove it again when you are online, or contact support.',
  );

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
  String posNotEnoughStock(String name) => _t(
    'الكمية المتوفرة من "${_iso(name)}" لا تكفي',
    'Not enough stock for "$name"',
  );
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
  String get pdfSealsSection =>
      _t('الختم والتوقيع الرقمي', 'Digital Stamp & Signature');
  String get pdfSealStamp => _t('الختم الرقمي', 'Digital Stamp');
  String get pdfSealSignature => _t('التوقيع الرقمي', 'Digital Signature');
  String get pdfUploadSeal => _t('رفع صورة', 'Upload image');
  String get pdfReplaceSeal => _t('استبدال', 'Replace');
  String get pdfRemoveSeal => _t('إزالة', 'Remove');
  String get pdfSealOpacity => _t('درجة الشفافية', 'Opacity');
  String get pdfSealPagePlacement =>
      _t('موضع الصفحات', 'Page placement');
  String get pdfSealPageLast => _t('الصفحة الأخيرة', 'Last page');
  String get pdfSealPageFirst => _t('الصفحة الأولى', 'First page');
  String get pdfSealPageAll => _t('جميع الصفحات', 'All pages');
  String get pdfSealVisualEditor =>
      _t('محرر الموضع والحجم', 'Position & size editor');
  String get pdfSealResetPosition =>
      _t('إعادة ضبط الموضع', 'Reset position');
  String get pdfSealEditorHint =>
      _t('اسحب للتحريك أو اسحب من الزوايا لتغيير الحجم',
          'Drag to move or drag corners to resize');
  String get pdfSealInvalidFormat => _t(
      'صيغة غير مدعومة. يرجى اختيار صورة PNG أو JPG',
      'Unsupported format. Please select a PNG or JPG image');
  String get pdfSealOversized => _t(
      'حجم الصورة كبير جداً (الحد الأقصى 10 ميغابايت)',
      'Image file is too large (max 10MB)');
  String get pdfSealUploadFailed =>
      _t('فشل في تحميل الصورة', 'Failed to upload image');
  String get pdfSealActive => _t('مفعل', 'Enabled');
  String get pdfSealInactive => _t('معطل', 'Disabled');
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
  String get entryCostOfSales => _t('تكلفة البضاعة المباعة', 'Cost of sales');
  String get entryOpeningStock => _t('مخزون افتتاحي', 'Opening stock');
  String get entryStockAdjustment => _t('تعديل مخزون', 'Stock adjustment');

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
  String get confirmDeleteAll =>
      _t('تأكيد حذف جميع التنبيهات؟', 'Delete all notifications?');
  String get confirmDeleteAllMessage => _t(
    'ستُحذف جميع التنبيهات والإعلانات القابلة للحذف نهائياً. التنبيهات الهامة تبقى محفوظة.',
    'All dismissible announcements will be permanently deleted. Critical notices will be preserved.',
  );
  String get notificationDeleted =>
      _t('تم حذف التنبيه', 'Notification deleted');
  String get notificationsDeleted =>
      _t('تم حذف التنبيهات المحددة', 'Selected notifications deleted');
  String get cannotDeleteCritical => _t(
    'لا يمكن حذف التنبيهات الهامة أو الحرجة',
    'Critical notifications cannot be deleted',
  );
  String get selectedCount => _t('محدد', 'selected');

  // ========== CUSTOMER ACCOUNT STATEMENT ==========
  String get customerStatement => _t('كشف حساب عميل', 'Customer Statement');
  String get statementPeriod => _t('فترة الكشف', 'Statement Period');
  String get totalInvoiced => _t('إجمالي المبيعات', 'Total Invoiced');
  String get initialPayment => _t('دفعة أولية', 'Initial Payment');
  String get statementAdjustment =>
      _t('فرق ناتج عن تعديل سابق', 'Reconciliation Adjustment');
  String get statementWarningTitle => _t(
    'تنبيه: يتضمن هذا الكشف بنوداً لفروق ناتجة عن تعديلات سابقة',
    'Warning: Statement contains reconciliation adjustments',
  );
  String statementWarningDetail(String inv, String amount, String symbol) => _t(
    'الفاتورة #${_iso(inv)} تتضمن فرقاً بمقدار ${_iso('$amount $symbol')} ناتجاً عن تعديل سابق.',
    'Invoice #$inv has a discrepancy of $amount $symbol due to an earlier manual edit.',
  );
  String get cancelledReceiptsTitle => _t(
    'سندات قبض مرتبطة بفواتير ملغاة (مستبعدة من الرصيد)',
    'Receipts Linked to Cancelled Invoices (Excluded from Balance)',
  );
  String get cancelledReceiptsSubtitle => _t(
    'مبالغ استلمتها بسندات قبض لفواتير ألغيتها لاحقاً دون تسجيل استرداد نقدي:',
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
  String get cogs => _t('تكلفة البضاعة المباعة', 'Cost of Goods Sold');
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
      _t('تعديل الأسعار دفعة واحدة', 'Bulk Price Editing');
  String get featureCsvImportExport =>
      _t('استيراد وتصدير CSV', 'CSV Import & Export');
  String get featureInventoryAudit =>
      _t('سجل تدقيق المخزون', 'Inventory Audit Log');
  String get featureReferenceCurrency =>
      _t('أسعار الصرف والعملة المرجعية', 'Exchange Rates & Reference Currency');
  String get featureWholesalePricing =>
      _t('أسعار الجملة والتجزئة', 'Wholesale & Retail Pricing');

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
    'ستُعدَّل كميات المخزون لتطابق الجرد الفعلي، وستُسجَّل حركات التسوية.',
    'System stock quantities will be updated to match physical counts with audit adjustments recorded',
  );
  String get interimMovementWarning => _t(
    'تنبيه: حدثت حركات مخزون بعد بدء الجلسة. ستُحسب التسوية على الرصيد الحالي.',
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
    'هل تريد إلغاء جلسة الجرد دون تسوية؟',
    'Are you sure you want to cancel this stocktake session without reconciliation?',
  );

  String get bulkPricingTitle =>
      _t('تعديل الأسعار دفعة واحدة', 'Bulk Price Editing');
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
  String get roundingRule =>
      _t('تقريب الأسعار المحوّلة', 'Round converted prices');
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
    'ملاحظة: لا تُعدَّل كميات المخزون عبر ملف CSV، حفاظاً على دقة سجل الحركات.',
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
    'أدخل كمية التعديل (لا تساوي صفراً)',
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
    'أضف بنداً واحداً على الأقل',
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
      _t('المخزون وحركته', 'Inventory & Stock Analytics');
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
    'تقييم المخزون الحالي بالتكلفة وحالة توفره',
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
    'تلميح: تأكد من اتصال الهاتف بالإنترنت ثم اضغط «تفعيل» مرة أخرى.',
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
    'ستُستبدل بياناتك الحالية بالنسخة المحددة. تُحفظ نسخة أمان على هاتفك تلقائياً قبل البدء.',
    'Current data will be replaced by the selected backup. A local safety backup is created automatically first.',
  );
  String get googleDriveSignInRequired => _t(
    'يرجى تسجيل الدخول بحساب Google أولاً',
    'Please sign in with a Google account first',
  );
  String get googleDriveErrorGeneric => _t(
    'تعذّر الاتصال بـ Google Drive. تأكد من الإنترنت ثم حاول مجدداً.',
    'An error occurred communicating with Google Drive. Please check your internet connection.',
  );
  String get googleDriveErrorAuthExpired => _t(
    'انتهت جلسة تسجيل الدخول. أعد ربط حساب Google.',
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
    'تعذّر ربط حساب Google على هذا الجهاز. يُرجى التحقق من إعدادات Google Cloud وشهادة التطبيق، ثم المحاولة مجدداً.',
    'Authentication configuration failed. Please verify Google Cloud settings and app certificate.',
  );
  String get googleDriveDeleteBackup => _t('حذف النسخة', 'Delete Backup');
  String get googleDriveConfirmDeleteTitle =>
      _t('تأكيد حذف النسخة السحابية', 'Confirm Cloud Backup Deletion');
  String get googleDriveConfirmDeleteBody => _t(
    'ستُحذف هذه النسخة من Google Drive نهائياً ولا يمكن استرجاعها.',
    'Are you sure you want to delete this backup from Google Drive? This action cannot be undone.',
  );
  String get googleDriveDeleting =>
      _t('جارٍ حذف النسخة الاحتياطية…', 'Deleting backup from Google Drive…');
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

  String reorderSuggestionTag(String qty) =>
      _t('طلب: ${_iso(qty)}', 'Order: $qty');
  String get noProductsBelowCost => _t(
    'ممتاز! لا توجد منتجات تباع بأقل من متوسط التكلفة',
    'Great! No products sold below average cost',
  );
  String lossAmount(String amount) =>
      _t('خسارة: -${_iso(amount)}', 'Loss: -$amount');
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
    'رمز المنتج مستخدم لمنتج آخر',
    'Product SKU is already in use by another product',
  );
  String get errorDuplicateRecord => _t(
    'هذا السجل موجود مسبقاً. تأكد أنك لا تكرر إدخاله.',
    'This record already exists in the system',
  );
  String get errorForeignKeyConstraint => _t(
    'لا يمكن إتمام العملية لأن هذا العنصر مرتبط بمستندات أو سجلات أخرى.',
    'Cannot complete operation because this item is referenced by existing records',
  );
  String get errorInsufficientStockGeneral => _t(
    'الكمية المتوفرة في المخزون غير كافية لإتمام العملية',
    'Insufficient stock to complete this transaction',
  );
  String get errorNetworkConnectivity => _t(
    'تعذّر الاتصال بالإنترنت. تأكد من الشبكة ثم حاول مجدداً.',
    'Could not connect to the network. Please check your internet connection',
  );
  String get errorOperationTimeout => _t(
    'استغرقت العملية وقتاً أطول من المتوقع. حاول مرة أخرى.',
    'The operation timed out. Please try again',
  );
  String get errorInvalidNumberFormat => _t(
    'تأكد من كتابة الأرقام والمبالغ بشكل صحيح.',
    'Please enter valid numbers',
  );
  String get errorDeleteProductHasHistory => _t(
    'لا يمكن حذف منتج مرتبط بفواتير أو حركات شراء سابقة',
    'Cannot delete a product with existing invoice or purchase history',
  );
  String get errorDiscountExceedsSubtotal => _t(
    'قيمة الخصم لا يمكن أن تتجاوز المجموع الفرعي',
    'Discount cannot exceed subtotal',
  );
  String get errorPaidExceedsTotal => _t(
    'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي',
    'Paid amount cannot exceed total',
  );
  String get errorNegativeAmount => _t(
    'لا يمكن إدخال مبلغ أو سعر سالب',
    'Amount or price cannot be negative',
  );
  String get errorValidUntilBeforeDate => _t(
    'تاريخ انتهاء العرض يجب أن يكون بعد تاريخ الإصدار',
    'Valid-until date must be on or after issue date',
  );

  String get pdfTaxIdLabel => _t('الرقم الضريبي:', 'Tax ID:');
  String get pdfTaxRegLabel => _t('رقم التسجيل الضريبي:', 'Tax Reg:');
  String get pdfCommercialRegLabel => _t('السجل التجاري:', 'CR:');
  String get pdfBranchLabel => _t('الفرع:', 'Branch:');

  // ========== ACCOUNTING BACKBONE & DIAGNOSTICS ==========
  String get accountingBooksSection =>
      _t('الدفاتر المحاسبية', 'Accounting Books');
  String get accountingBooksSectionDesc => _t(
    'حالة مطابقة دفتر اليومية المزدوج ومصدر تقارير القوائم المالية',
    'Double-entry journal parity status and financial report source',
  );
  String get journalParityVerified => _t(
    'مطابقة تامة (100%) مع الدفتر المشتق',
    'Exact 100% parity with derived ledger',
  );
  String get journalParityMismatch => _t(
    'يوجد عدم تطابق بين الدفتر واليومية',
    'Parity mismatch between ledger and journal',
  );
  String get journalReportSource =>
      _t('مصدر التقارير المالية', 'Financial Reports Source');
  String get journalSourceDerived =>
      _t('الدفتر المشتق (افتراضي)', 'Derived Ledger (Default)');
  String get journalSourcePersisted =>
      _t('دفتر اليومية الدائم (مُفعل)', 'Persisted Journal (Active)');
  String get triggerJournalBackfill =>
      _t('إعادة إنشاء دفتر اليومية', 'Rebuild Journal (Backfill)');
  String get journalBackfillSuccess => _t(
    'تمت إعادة إنشاء القيود بنجاح ومطابقة الأرصدة',
    'Journal entries rebuilt successfully with verified parity',
  );
  String get switchJournalReportsTitle =>
      _t('تبديل مصدر التقارير المالية', 'Switch Financial Reports Source');
  String get switchJournalReportsConfirm => _t(
    'هل تريد تغيير مصدر التقارير المالية؟ سيتم احتساب القوائم مباشرة من دفتر اليومية الدائم بدلاً من إنشائها لحظياً.',
    'Do you want to switch the financial reports source? Statements will be generated directly from the persisted double-entry journal.',
  );

  // ========== STOCK ADJUSTMENT REASONS & PERIOD LOCK ==========
  String get adjustmentReasonCountGain =>
      _t('تسوية جرد (زيادة مخزون)', 'Stock Count (Gain)');
  String get adjustmentReasonCountLoss =>
      _t('تسوية جرد (عجز مخزون)', 'Stock Count (Loss)');
  String get adjustmentReasonDamageLoss => _t('تلف مخزون', 'Damaged Goods');
  String get adjustmentReasonExpiryLoss =>
      _t('انتهاء الصلاحية', 'Expired Stock');
  String get adjustmentReasonOpeningStock =>
      _t('بضاعة أول المدة', 'Opening Stock');
  String get adjustmentReasonCorrection =>
      _t('تصحيح خطأ سابق', 'Entry Correction');
  String get adjustmentReasonOther =>
      _t('أخرى (يتطلب ملاحظة)', 'Other (Note required)');

  String get periodLockSection =>
      _t('إقفال الفترة المحاسبية', 'Accounting Period Lock');
  String get periodLockSectionDesc => _t(
    'منع التعديل أو الحذف أو الإضافة في الفترات المحاسبية المغلقة',
    'Prevent adding, modifying, or cancelling transactions in closed periods',
  );
  String get periodLockClosedThrough =>
      _t('الدفاتر مقفلة حتى', 'Books closed through');
  String get periodLockOpen =>
      _t('الفترة مفتوحة بالكامل (لا يوجد إقفال)', 'All periods open (No lock)');
  String get setPeriodLock => _t('تحديد تاريخ الإقفال', 'Set Lock Date');
  String get clearPeriodLock =>
      _t('فتح الفترة (إلغاء الإقفال)', 'Clear Period Lock');
  String get confirmSetPeriodLockTitle =>
      _t('تأكيد إقفال الفترة المحاسبية', 'Confirm Period Lock');
  String get confirmSetPeriodLockMessage => _t(
    'إقفال الفترة حتى هذا التاريخ سيمنع إنشاء أو تعديل أو إلغاء أي فواتير أو مدفوعات أو تسويات مخزون مؤرخة في هذا التاريخ أو قبله. هل تريد المتابعة؟',
    'Closing books through this date will prevent posting, modifying, or cancelling any transactions dated on or before this date. Do you want to proceed?',
  );
  String get confirmClearPeriodLockTitle =>
      _t('فتح الفترة المحاسبية', 'Unlock Accounting Period');
  String get confirmClearPeriodLockMessage => _t(
    'إلغاء القفل يسمح بإضافة المستندات وتعديلها في الفترات السابقة. هل تريد المتابعة؟',
    'Are you sure you want to clear the period lock? Transactions in prior periods will become editable again.',
  );
  String get errorPeriodClosed => _t(
    'الفترة المحاسبية مقفلة حتى هذا التاريخ. لا يمكن إضافة أو تعديل أو إلغاء المعاملات.',
    'Accounting period is closed through this date. Transactions cannot be posted, revised, or cancelled.',
  );

  // ========== REFERENCE PRICING ==========
  String get exchangeRates => _t('أسعار الصرف', 'Exchange rates');
  String get exchangeRatesDesc => _t(
    'سعّر منتجاتك بعملة أخرى وحدّث سعر الصرف يدوياً',
    'Price products in another currency and update the rate manually',
  );
  String get pricingCurrency => _t('عملة التسعير', 'Pricing currency');
  String get exchangeRate => _t('سعر الصرف', 'Exchange rate');
  String get addCurrency => _t('إضافة عملة', 'Add currency');
  String get customCurrency => _t('عملة مخصصة', 'Custom currency');
  String get currencyCode => _t('رمز العملة', 'Currency code');
  String get currencySymbol => _t('الرمز المختصر', 'Symbol');
  String get roundingNone => _t('بدون تقريب', 'No rounding');
  String get roundingChangedRecalculatePrompt => _t(
    'تغيّر التقريب. هل تريد إعادة حساب الأسعار الآن؟',
    'Rounding changed. Recalculate prices now?',
  );
  String get rateMissingForCurrency => _t(
    'لا يوجد سعر صرف لهذه العملة. أضف سعر الصرف أولاً.',
    'No exchange rate for this currency. Add the rate first.',
  );
  String get repriceConfirmTitle => _t('تحديث الأسعار', 'Update prices');
  String repriceConfirmBody(Object products, Object units) => _t(
    'سيتم تحديث أسعار ${_iso(products)} منتج و${_iso(units)} وحدة.',
    'Prices of $products products and $units units will be updated.',
  );
  String repriceDone(Object products, Object units) => _t(
    'تم تحديث ${_iso(products)} منتج و${_iso(units)} وحدة.',
    'Updated $products products and $units units.',
  );
  String get recalculateAll =>
      _t('إعادة حساب كل الأسعار', 'Recalculate all prices');
  String get currencyInUse => _t(
    'لا يمكن حذف عملة مستخدمة في منتجات. يمكنك أرشفتها.',
    'A currency used by products cannot be deleted. You can archive it.',
  );
  String get archiveCurrency => _t('أرشفة', 'Archive');
  String get unarchiveCurrency => _t('إلغاء الأرشفة', 'Unarchive');
  String get switchToBaseConfirm => _t(
    'سيتحول المنتج إلى العملة الأساسية وتبقى أسعاره الحالية كما هي.',
    'The product will switch to the base currency and keep its current prices.',
  );
  String keepsCurrentBasePrice(Object value) => _t(
    'إن تُرك فارغاً يبقى السعر الحالي بالعملة الأساسية: ${_iso(value)}',
    'If left empty, the current base-currency price stays: $value',
  );
  String get unitReferencePricesCleared => _t(
    'تم مسح الأسعار المرجعية للوحدات. أدخلها بالعملة الجديدة.',
    'Unit reference prices were cleared. Enter them in the new currency.',
  );
  String bulkSkippedReference(Object count) => _t(
    'تم تخطي ${_iso(count)} سعر مرتبط بعملة أخرى.',
    'Skipped $count prices linked to another currency.',
  );
  String csvSkippedReference(Object count) => _t(
    'لم يتم تغيير ${_iso(count)} سعر مرتبط بعملة أخرى.',
    '$count prices linked to another currency were not changed.',
  );
  String get catalogUpdatedCartKept => _t(
    'تم تحديث الكتالوج. المنتجات الموجودة في السلة تحتفظ بأسعارها السابقة.',
    'The catalog was updated. Items already in the cart keep their previous prices.',
  );
  String get currencyChangeBlockedByRates => _t(
    'لا يمكن تغيير العملة الأساسية بعد إضافة أسعار صرف.',
    'The base currency cannot be changed after exchange rates are added.',
  );
  String get setupBusinessFirst =>
      _t('أكمل بيانات النشاط أولاً.', 'Complete the business details first.');
  String get chooseCurrency => _t('اختر العملة', 'Choose currency');
  String get currencyCodeField =>
      _t('رمز العملة (مثال: EUR)', 'Currency code (e.g. EUR)');
  String get currencyNameArField =>
      _t('اسم العملة بالعربية', 'Currency name in Arabic');
  String get currencyNameEnField => _t(
    'اسم العملة بالإنجليزية (اختياري)',
    'Currency name in English (optional)',
  );
  String get currencySymbolField =>
      _t('رمز العرض (اختياري، مثل: €)', 'Display symbol (optional, e.g. €)');
  String get currencyRateField => _t('سعر الصرف', 'Exchange rate');
  String get currencyRateHelper => _t(
    'كم وحدة من عملتك الأساسية تساوي 1 من هذه العملة',
    'How many units of your base currency equal 1 of this currency',
  );
  String get updateExchangeRate =>
      _t('تحديث سعر الصرف', 'Update exchange rate');
  String get recalculatePrices =>
      _t('إعادة تسعير المنتجات الآن', 'Recalculate product prices now');
  String get recalculateAllConfirm => _t(
    'سيُعاد حساب أسعار الأساس لكل المنتجات المرتبطة بعملات صرف بسعر الصرف الحالي لكل عملة. متابعة؟',
    'Base prices of all products linked to an exchange rate will be recalculated. Continue?',
  );
  String get repricePreviewTitle =>
      _t('معاينة إعادة التسعير', 'Reprice preview');
  String repricePreviewDesc(Object productCount, Object unitCount) => _t(
    'سيتم تحديث ${_iso(productCount)} منتج و${_iso(unitCount)} وحدة تسعير.',
    '$productCount products and $unitCount units will be updated.',
  );
  String repriceSuccess(Object count) => _t(
    'تم تحديث أسعار ${_iso(count)} منتج بنجاح',
    'Successfully updated prices for $count products',
  );
  String get archiveCurrencyConfirm => _t(
    'لن تظهر هذه العملة عند إنشاء أو تعديل منتجات جديدة. المنتجات الحالية تبقى مرتبطة بها.',
    'This currency will not appear when pricing new products. Existing products keep their pricing.',
  );
  String get deleteCurrencyConfirm => _t(
    'حذف هذه العملة المخصصة نهائياً؟',
    'Permanently delete this custom currency?',
  );
  String roundingNearest(Object step) =>
      _t('لأقرب ${_iso(step)} وحدة', 'To nearest $step units');

  String get refErrInvalidRate => _t(
    'سعر الصرف يجب أن يكون رقماً أكبر من الصفر وبما لا يتجاوز 6 خانات عشرية.',
    'Exchange rate must be > 0 with up to 6 decimal places.',
  );
  String get refErrInvalidPrice => _t(
    'السعر المرجعي يجب أن يكون رقماً موجباً وبما لا يتجاوز 4 خانات عشرية.',
    'Reference price must be positive with up to 4 decimal places.',
  );
  String get refErrPriceOutOfRange => _t(
    'السعر المحوّل يتجاوز الحد المسموح.',
    'Converted price exceeds the allowed range.',
  );
  String get refErrReferencePriceRequired => _t(
    'السعر المرجعي الأساسي مطلوب للمنتجات المسعّرة بعملة أخرى.',
    'Primary reference price is required when pricing in another currency.',
  );
  String get refErrRepricingBusy => _t(
    'هناك عملية إعادة تسعير جارية حالياً. يرجى الانتظار.',
    'Repricing already in progress. Please wait.',
  );
  String get refErrCurrencyExists =>
      _t('رمز العملة مسجل مسبقاً.', 'Currency code already exists.');
  String get refErrCurrencyIsBase => _t(
    'لا يمكن إضافة العملة الأساسية كعملة صرف.',
    'Cannot add base currency as an exchange rate.',
  );
  String get refErrCurrencyArchived => _t(
    'العملة المختارة مؤرشفة حالياً. تم استرجاع الإعداد السابق.',
    'Selected currency is archived. Previous selection restored.',
  );
  String get refErrGeneric =>
      _t('حدث خطأ في التسعير المرجعي.', 'A reference pricing error occurred.');

  // Multi-user & Permissions
  String get usersAndPermissions =>
      _t('المستخدمون والصلاحيات', 'Users & Permissions');
  String get usersAndPermissionsDesc => _t(
    'إدارة المستخدمين، الأدوار وسجل التدقيق',
    'Manage users, roles and audit trail',
  );
  String get multiUserTitle => _t('تعدد المستخدمين', 'Multi-User');
  String get multiUserEnabledLabel =>
      _t('تفعيل نظام تعدد المستخدمين', 'Enable Multi-User System');
  String get multiUserDisabledDesc => _t(
    'عند التفعيل، سيتطلب الوصول إلى النظام إدخال رمز المرور (PIN) وتحديد صلاحيات لكل مستخدم.',
    'When enabled, access requires a PIN and specific permissions per user.',
  );
  String get setupOwnerCredentials =>
      _t('إعداد بيانات المالك', 'Setup Owner Credentials');
  String get ownerPasswordLabel => _t('كلمة مرور المالك', 'Owner Password');
  String get ownerPinLabel =>
      _t('رمز PIN للمالك (4-6 أرقام)', 'Owner PIN (4-6 digits)');
  String get confirmPasswordLabel =>
      _t('تأكيد كلمة المرور', 'Confirm Password');
  String get recoveryCodeTitle => _t('رمز الاسترداد', 'Recovery Code');
  String get recoveryCodeWarning => _t(
    'احفظ هذا الرمز في مكان آمن وخارجي تماماً. هذا هو الرمز الوحيد الذي يمكنك استخدامه لإعادة تعيين كلمة مرور المالك في حال نسيانها.',
    'Save this code securely. It is the only way to recover Owner access if forgotten.',
  );
  String get recoveryCodeSavedConfirm => _t(
    'لقد قمت بحفظ رمز الاسترداد في مكان آمن',
    'I have saved the recovery code in a safe place',
  );
  String get enableMultiUserButton =>
      _t('تفعيل تعدد المستخدمين', 'Enable Multi-User');
  String get disableMultiUserButton =>
      _t('تعطيل تعدد المستخدمين', 'Disable Multi-User');
  String get disableMultiUserConfirm => _t(
    'هل تريد تعطيل تعدد المستخدمين؟ سيعود النظام لوضع المستخدم الفردي المباشر.',
    'Are you sure you want to disable multi-user mode? The system will revert to direct single-user mode.',
  );
  String get enterPin => _t('أدخل رمز PIN', 'Enter PIN');
  String get unlock => _t('فتح القفل', 'Unlock');
  String get invalidPin => _t('رمز PIN غير صحيح', 'Incorrect PIN');
  String get switchUser => _t('تبديل المستخدم', 'Switch User');
  String get loginWithPassword =>
      _t('تسجيل الدخول بكلمة المرور', 'Login with password');
  String get password => _t('كلمة المرور', 'Password');
  String get invalidCredentials => _t(
    'اسم المستخدم أو كلمة المرور غير صحيحة',
    'Invalid username or password',
  );
  String get forgotPassword => _t('نسيت كلمة المرور؟', 'Forgot password?');
  String get recoverOwnerAccess =>
      _t('استرداد حساب المالك', 'Recover Owner Access');
  String get recoveryCodeInputLabel =>
      _t('رمز الاسترداد المكون من 16 حرفاً', '16-character Recovery Code');
  String get newOwnerPassword =>
      _t('كلمة مرور المالك الجديدة', 'New Owner Password');
  String get newOwnerPin => _t('رمز PIN الجديد', 'New PIN');
  String get recoverySuccess => _t(
    'تم استرداد الحساب بنجاح وتم إنشاء رمز استرداد جديد',
    'Account recovered successfully. A new recovery code has been generated.',
  );
  String get invalidRecoveryCode =>
      _t('رمز الاسترداد غير صحيح', 'Invalid recovery code');
  String get users => _t('المستخدمون', 'Users');
  String get addUser => _t('إضافة مستخدم', 'Add User');
  String get editUser => _t('تعديل المستخدم', 'Edit User');
  String get username => _t('اسم المستخدم', 'Username');
  String get displayName => _t('الاسم الظاهر', 'Display Name');
  String get role => _t('الدور', 'Role');
  String get userActive => _t('نشط', 'Active');
  String get userInactive => _t('معطل', 'Inactive');
  String get pinCode => _t('رمز PIN (4-6 أرقام)', 'PIN Code (4-6 digits)');
  String get changePasswordOptional =>
      _t('تغيير كلمة المرور (اختياري)', 'Change Password (Optional)');
  String get cannotDeactivateOwner => _t(
    'لا يمكن تعطيل أو تعديل دور حساب المالك',
    'Cannot deactivate or change the role of the Owner account',
  );
  String get cannotDeleteOwner =>
      _t('لا يمكن حذف حساب المالك', 'Cannot delete the Owner account');
  String get rolesAndPermissions =>
      _t('الأدوار والصلاحيات', 'Roles & Permissions');
  String get addRole => _t('إضافة دور جديد', 'Add Role');
  String get editRole => _t('تعديل الدور', 'Edit Role');
  String get roleName => _t('اسم الدور', 'Role Name');
  String get roleDescription => _t('وصف الدور', 'Role Description');
  String get isSystemRole => _t(
    'دور نظام قياسي (غير قابل للتعديل)',
    'Built-in system role (read-only)',
  );
  String get customRole => _t('دور مخصص', 'Custom Role');
  String get permissionOverrides =>
      _t('استثناءات الصلاحيات للمستخدم', 'User Permission Overrides');
  String get auditTrail => _t('سجل التدقيق والنشاطات', 'Audit Trail');
  String get verifyAuditIntegrity =>
      _t('التحقق من سلامة السجل', 'Verify Log Integrity');
  String get auditIntegrityValid => _t(
    'سجل التدقيق سليم وغير معدّل (سلسلة التجزئة صالحة)',
    'Audit log is intact and tamper-free (hash chain is valid)',
  );
  String get auditIntegrityTampered => _t(
    'تحذير: تم الكشف عن تلاعب أو انقطاع في سجل التدقيق!',
    'Warning: Tampering or corruption detected in audit log!',
  );
  String get autoLockSetting =>
      _t('القفل التلقائي عند عدم النشاط', 'Auto-Lock Inactivity Timeout');
  String autoLockMinutesDesc(int m) => m == 0
      ? _t('معطل', 'Disabled')
      : _t('${_iso(m)} دقائق', '${_iso(m)} minutes');
  String get currentActiveUser => _t('المستخدم الحالي', 'Current User');
  String get lockNow => _t('قفل التطبيق الآن', 'Lock App Now');
  String get logout => _t('تسجيل الخروج', 'Logout');
  String get logoutConfirmTitle => _t('تسجيل الخروج', 'Logout');
  String get logoutConfirmMessage => _t(
    'هل تريد تسجيل الخروج؟ سيتم قفل الجلسة وفقدان أي تعديلات غير محفوظة في النماذج المفتوحة والعودة لشاشة الدخول.',
    'Are you sure you want to log out? Any unsaved changes in open forms will be lost and you will return to the lock screen.',
  );
  String get reauthenticateRequired => _t(
    'يرجى إدخال كلمة المرور للمتابعة',
    'Please enter your password to proceed',
  );
  String get confirmAction => _t('تأكيد الإجراء', 'Confirm Action');
  String get savedSuccessfully => _t('تم الحفظ بنجاح', 'Saved successfully');
  String get deletedSuccessfully =>
      _t('تم الحذف بنجاح', 'Deleted successfully');
  String get copy => _t('نسخ', 'Copy');
  String get invalidPasswordLength => _t(
    'كلمة المرور يجب أن لا تقل عن 6 أحرف',
    'Password must be at least 6 characters',
  );

  // ========== ANALYTICS & TELEMETRY ==========
  String get analyticsConsentTitle =>
      _t('إحصائيات الاستخدام المجهولة', 'Anonymous usage statistics');
  String get analyticsConsentDesc => _t(
    'مساعدة في تحسين التطبيق عبر بيانات تشغيلية مجهولة، بدون مبالغ أو أسماء أو فواتير',
    'Help improve the app via anonymous telemetry, excluding amounts, names, and invoices',
  );
  String get errorReportsConsentTitle =>
      _t('تقارير الأخطاء والأعطال', 'Error reports');
  String get errorReportsConsentDesc => _t(
    'إرسال تقارير تشخيصية مجهولة ومجردة من أي بيانات عند حدوث أخطاء للمساعدة في إصلاحها',
    'Send anonymous, sanitized crash and error diagnostics to help fix bugs',
  );
  String get analyticsNoticeTitle => _t(
    'بيانات الاستخدام وتقارير الأخطاء',
    'Usage Statistics & Error Reports',
  );
  String get analyticsNoticeBody => _t(
    'يساعد جمع إحصائيات الاستخدام المجهولة وتقارير الأعطال في تحسين موثوقية وأداء ورقتك. لا يتم جمع أي بيانات شخصية أو تجارية على الإطلاق، ويمكنك إيقاف أي منهما في أي وقت من الإعدادات.',
    'Anonymous usage statistics and error reports help improve the app\'s stability. No personal or business data is ever collected. You can turn them off anytime from Settings.',
  );
  String get analyticsNoticeSettings => _t('الإعدادات', 'Settings');
  String get analyticsNoticeOk => _t('حسناً', 'OK');
  String get anonymousAnalyticsTitle =>
      _t('إحصائيات الاستخدام المجهولة', 'Anonymous Telemetry');
  String get anonymousAnalyticsSubtitle => _t(
    'بيانات مجهولة لتحسين الأداء بدون مبالغ أو أسماء',
    'Anonymous metrics to improve performance, zero amounts or names',
  );
  String get anonymousAnalyticsExplainer => _t(
    'يجمع التطبيق إحصائيات مجهولة حول الميزات المستخدمة (مثل إنشاء الفواتير والنسخ الاحتياطي) لتحسين الاستقرار. لا يتم إرسال أي مبالغ، أسعار، تكاليف، أرقام هواتف، أسماء عملاء أو موردين، أو معلومات شخصية إطلاقاً. يمكنك إيقاف هذا الخيار في أي وقت من الإعدادات.',
    'The app collects anonymous statistics on feature usage (such as document creation and backup) to improve reliability. No amounts, prices, costs, phone numbers, contact names, or personal data are ever collected. You can disable this anytime in Settings.',
  );


  // ========== PERMISSION GROUPS ==========
  String get permGroup_sales_label => _t('المبيعات', 'Sales');
  String get permGroup_purchases_label => _t('المشتريات', 'Purchases');
  String get permGroup_payments_label => _t('المدفوعات والسندات', 'Payments & Vouchers');
  String get permGroup_stock_label => _t('المخزون والجرد', 'Stock & Inventory');
  String get permGroup_products_label => _t('المنتجات والتسعير', 'Products & Pricing');
  String get permGroup_contacts_label => _t('العملاء والموردين', 'Customers & Suppliers');
  String get permGroup_dashboard_label => _t('لوحة المعلومات', 'Dashboard');
  String get permGroup_reports_label => _t('التقارير والمؤشرات', 'Reports');
  String get permGroup_data_label => _t('الاستيراد والتصدير', 'Data Import & Export');
  String get permGroup_system_label => _t('إدارة النظام والنسخ', 'System & Backup');
  String get permGroup_settings_label => _t('إعدادات العمل والضرائب', 'Settings');
  String get permGroup_access_label => _t('المستخدمون والصلاحيات', 'Users & Roles');

  String permissionGroupLabelByName(String name) {
    switch (name) {
      case 'sales':
        return permGroup_sales_label;
      case 'purchases':
        return permGroup_purchases_label;
      case 'payments':
        return permGroup_payments_label;
      case 'stock':
        return permGroup_stock_label;
      case 'products':
        return permGroup_products_label;
      case 'contacts':
        return permGroup_contacts_label;
      case 'dashboard':
        return permGroup_dashboard_label;
      case 'reports':
        return permGroup_reports_label;
      case 'data':
        return permGroup_data_label;
      case 'system':
        return permGroup_system_label;
      case 'settings':
        return permGroup_settings_label;
      case 'access':
        return permGroup_access_label;
      default:
        return name;
    }
  }
  String get perm_sales_view_name => _t('عرض المبيعات والفواتير', 'View sales and invoices');
  String get perm_sales_view_desc => _t('عرض قائمة فواتير المبيعات وتفاصيلها', 'View list of sales invoices and details');
  String get perm_sales_create_name => _t('إنشاء فواتير المبيعات', 'Create sales invoices');
  String get perm_sales_create_desc => _t('إصدار فواتير بيع جديدة وعروض أسعار', 'Issue new sales invoices and quotations');
  String get perm_sales_edit_name => _t('تعديل فواتير المبيعات', 'Edit sales invoices');
  String get perm_sales_edit_desc => _t('تعديل فواتير المبيعات القائمة', 'Edit existing sales invoices');
  String get perm_sales_edit_price_name => _t('تعديل سعر البيع يدوياً', 'Manual price override');
  String get perm_sales_edit_price_desc => _t('تغيير سعر بيع الصنف أثناء إنشاء الفاتورة', 'Change item unit price on the invoice');
  String get perm_sales_edit_discount_name => _t('إضافة وتعديل الخصومات', 'Apply and edit discounts');
  String get perm_sales_edit_discount_desc => _t('تطبيق تخفيض على الفاتورة أو البنود', 'Apply discounts to documents or line items');
  String get perm_sales_cancel_name => _t('إلغاء فواتير المبيعات', 'Cancel sales invoices');
  String get perm_sales_cancel_desc => _t('إلغاء فواتير البيع واسترجاع كميات المخزون', 'Cancel invoices and restore inventory stock');
  String get perm_sales_delete_name => _t('حذف مسودات المبيعات', 'Delete draft invoices');
  String get perm_sales_delete_desc => _t('حذف فواتير المبيعات غير الصادرة نهائياً', 'Permanently delete draft sales documents');
  String get perm_sales_refund_name => _t('إدارة استرجاع المبالغ (Refund)', 'Manage document refunds');
  String get perm_sales_refund_desc => _t('تحديث حالة استرجاع المبالغ للفواتير الملغاة', 'Update refund status on cancelled invoices');
  String get perm_purchases_view_name => _t('عرض فواتير المشتريات', 'View purchase invoices');
  String get perm_purchases_view_desc => _t('عرض مشتريات البضائع وفواتير الموردين', 'View purchase invoices from suppliers');
  String get perm_purchases_create_name => _t('إنشاء فواتير المشتريات', 'Create purchase invoices');
  String get perm_purchases_create_desc => _t('تسجيل شراء بضاعة وتحديث تكلفة المخزون', 'Record incoming stock and update cost');
  String get perm_purchases_edit_name => _t('تعديل فواتير المشتريات', 'Edit purchase invoices');
  String get perm_purchases_edit_desc => _t('تعديل بنود وأسعار فواتير الشراء القائمة', 'Edit items and costs on purchase invoices');
  String get perm_purchases_cancel_name => _t('إلغاء فواتير المشتريات', 'Cancel purchase invoices');
  String get perm_purchases_cancel_desc => _t('إلغاء فاتورة شراء واسترجاع كميات المخزون', 'Cancel purchase invoice and reverse stock');
  String get perm_purchases_delete_name => _t('حذف مسودات المشتريات', 'Delete draft purchases');
  String get perm_purchases_delete_desc => _t('حذف فواتير الشراء غير الصادرة', 'Delete unissued purchase drafts');
  String get perm_payments_record_name => _t('تسجيل الدفعات والتحصيل', 'Record payments and collections');
  String get perm_payments_record_desc => _t('تسجيل دفعات نقدية أو بنكية على الفواتير', 'Record cash or bank payments on invoices');
  String get perm_vouchers_create_name => _t('إنشاء سندات القبض والصرف', 'Create payment receipts and expense vouchers');
  String get perm_vouchers_create_desc => _t('إصدار سندات مالية مستقلة للمصروفات والقبض', 'Issue financial receipt and payment vouchers');
  String get perm_expenses_view_name => _t('عرض سندات المصروفات', 'View expense vouchers');
  String get perm_expenses_view_desc => _t('الاطلاع على سجل المصروفات وسندات الصرف', 'View operating expenses and expense vouchers');
  String get perm_stock_adjust_name => _t('تسوية المخزون اليدوية', 'Manual stock adjustment');
  String get perm_stock_adjust_desc => _t('تعديل كميات المخزون بالزيادة أو النقص يدوياً', 'Manually add or reduce product stock levels');
  String get perm_stock_view_cost_name => _t('الاطلاع على تكلفة المخزون', 'View stock movement costs');
  String get perm_stock_view_cost_desc => _t('عرض أسعار وتكلفة حركات المخزون الداخلة والخارجة', 'View unit and total cost of stock movements');
  String get perm_stocktake_manage_name => _t('بدء وإدارة جلسات الجرد', 'Start and manage stocktake');
  String get perm_stocktake_manage_desc => _t('فتح جلسات الجرد الدوري وتسجيل الكميات المعدودة', 'Open stocktake sessions and enter counted stock');
  String get perm_stocktake_finalize_name => _t('اعتماد تسويات الجرد', 'Finalize stocktake reconciliation');
  String get perm_stocktake_finalize_desc => _t('ترحيل فروقات الجرد وتحديث المخزون محاسبياً', 'Post stocktake variances to inventory ledger');
  String get perm_products_view_name => _t('عرض قائمة المنتجات', 'View products catalog');
  String get perm_products_view_desc => _t('تصفح قائمة الأصناف والباركود وسعر البيع', 'Browse product catalog, barcodes, and sale prices');
  String get perm_products_manage_name => _t('إضافة وتعديل المنتجات والوحدات', 'Create and edit products & units');
  String get perm_products_manage_desc => _t('إنشاء أصناف جديدة وتعديل الأسعار والوحدات', 'Add products and manage pricing and units');
  String get perm_products_delete_name => _t('حذف المنتجات', 'Delete products');
  String get perm_products_delete_desc => _t('حذف أو تعطيل الأصناف غير المستخدمة', 'Delete or deactivate unused products');
  String get perm_products_view_cost_name => _t('الاطلاع على سعر الشراء وتكلفة المنتج', 'View purchase price and average cost');
  String get perm_products_view_cost_desc => _t('إظهار سعر التكلفة وسعر الشراء في شاشات الأصناف', 'Show purchase price and average cost on product views');
  String get perm_products_view_wholesale_name => _t('الاطلاع على أسعار الجملة', 'View wholesale prices');
  String get perm_products_view_wholesale_desc => _t('عرض سعر الجملة والحد الأدنى لكمية الجملة', 'View wholesale tier prices and minimum quantities');
  String get perm_pricing_manage_name => _t('إدارة التسعير الشامل (Bulk Pricing)', 'Bulk pricing management');
  String get perm_pricing_manage_desc => _t('تطبيق زيادات أو تخفيضات جماعية على أسعار الأصناف', 'Apply bulk price adjustments across catalog');
  String get perm_pricing_rates_name => _t('إدارة العملات وأسعار الصرف المرجعية', 'Manage exchange rates & reference currency');
  String get perm_pricing_rates_desc => _t('تعديل أسعار صرف العملات المرجعية في النظام', 'Update reference currency exchange rates');
  String get perm_contacts_view_name => _t('عرض العملاء والموردين', 'View contacts list');
  String get perm_contacts_view_desc => _t('تصفح سجل العملاء والموردين وأرقام هواتفهم', 'Browse customers and suppliers list and contact info');
  String get perm_contacts_manage_name => _t('إضافة وتعديل العملاء والموردين', 'Create and edit contacts');
  String get perm_contacts_manage_desc => _t('تسجيل عميل أو مورد جديد وتعديل بيانات الاتصال', 'Add customer/supplier and update details');
  String get perm_contacts_delete_name => _t('حذف العملاء والموردين', 'Delete contacts');
  String get perm_contacts_delete_desc => _t('حذف جهات الاتصال غير المرتبطة بمعاملات', 'Delete contacts not referenced in documents');
  String get perm_contacts_view_balances_name => _t('الاطلاع على مديونيات وحسابات العملاء والموردين', 'View balances, debts, and account statements');
  String get perm_contacts_view_balances_desc => _t('عرض إجمالي ديون العملاء ومستحقات الموردين وكشف الحساب', 'View receivables, payables, and account statements');
  String get perm_dashboard_view_totals_name => _t('عرض إجماليات المبيعات والأرباح بالرئيسية', 'View dashboard totals and revenue metrics');
  String get perm_dashboard_view_totals_desc => _t('إظهار بطاقات إجمالي مبيعات اليوم والديون بالرئيسية', 'Show sales revenue cards and summary metrics on home');
  String get perm_reports_view_sales_name => _t('تقرير المبيعات وحركة الفواتير', 'Sales report');
  String get perm_reports_view_sales_desc => _t('عرض تقرير المبيعات التفصيلي مع المجموع', 'View detailed sales and invoice reports');
  String get perm_reports_view_purchases_name => _t('تقرير المشتريات والمصروفات', 'Purchases report');
  String get perm_reports_view_purchases_desc => _t('عرض إجماليات المشتريات ومصروفات العمليات', 'View purchases spending and supplier orders');
  String get perm_reports_view_receivables_name => _t('تقرير الديون والمستحقات', 'Receivables and payables report');
  String get perm_reports_view_receivables_desc => _t('تقرير أرصدة ومطالبات العملاء والموردين', 'View aging debts and supplier balances');
  String get perm_reports_view_inventory_cost_name => _t('تقرير تقييم المخزون وأرباح الأصناف', 'Inventory valuation and profit reports');
  String get perm_reports_view_inventory_cost_desc => _t('عرض قيمة المخزون بسعر الشراء وصافي أرباح المنتجات', 'View inventory cost valuation and product gross profits');
  String get perm_reports_view_financials_name => _t('التقارير المالية (قائمة الدخل والميزانية)', 'Financial statements (Income Statement & Balance Sheet)');
  String get perm_reports_view_financials_desc => _t('الاطلاع على قائمة الدخل، الميزانية العمومية، وميزان المراجعة', 'View Income Statement, Balance Sheet, and Trial Balance');
  String get perm_reports_export_pdf_name => _t('تصدير وطباعة تقارير PDF', 'Export and print PDF reports');
  String get perm_reports_export_pdf_desc => _t('طباعة أو مشاركة تقارير الأعمال كملفات PDF', 'Print or share business reports as PDF documents');
  String get perm_data_export_csv_name => _t('تصدير البيانات إلى ملفات CSV / Excel', 'Export data to CSV / Excel');
  String get perm_data_export_csv_desc => _t('تصدير قائمة الأصناف والبيانات إلى ملفات خارجية', 'Export catalog and records to external spreadsheets');
  String get perm_data_import_csv_name => _t('استيراد البيانات من ملفات CSV', 'Import data from CSV');
  String get perm_data_import_csv_desc => _t('إدخال أصناف وقوائم أسعار من ملفات CSV خارجية', 'Batch import products and prices from CSV');
  String get perm_backup_create_name => _t('إنشاء نسخة احتياطية (.waraq)', 'Create database backup (.waraq)');
  String get perm_backup_create_desc => _t('تصدير نسخة احتياطية محلية أو إلى Google Drive', 'Generate encrypted or local backup archives');
  String get perm_backup_restore_name => _t('استعادة النسخة الاحتياطية (حساس)', 'Restore database backup (Sensitive)');
  String get perm_backup_restore_desc => _t('استرجاع قاعدة البيانات ومسح البيانات الحالية', 'Restore database from backup file, replacing local data');
  String get perm_system_repair_name => _t('أدوات الفحص والإصلاح وتشخيص القاعدة', 'Diagnostics and database repair tools');
  String get perm_system_repair_desc => _t('تشغيل إصلاحات جدولية وتصدير سجل التشخيص', 'Run database health diagnostics and repair scripts');
  String get perm_accounting_period_lock_name => _t('إقفال الفترات المحاسبية (Period Lock)', 'Accounting period closing and lock');
  String get perm_accounting_period_lock_desc => _t('تحديد تاريخ إقفال الحسابات لمنع التعديل السابق', 'Set books closed date preventing past mutations');
  String get perm_settings_manage_name => _t('تعديل بيانات المنشأة والإعدادات العامة', 'Business profile and general settings');
  String get perm_settings_manage_desc => _t('تغيير اسم المنشأة، الشعار، والخيارات العامة', 'Update store profile, branding, and global settings');
  String get perm_payment_methods_manage_name => _t('إدارة طرق الدفع والحسابات', 'Manage payment methods');
  String get perm_payment_methods_manage_desc => _t('تفعيل وإضافة طرق دفع نقدية أو بنكية مخصصة', 'Configure payment methods and bank options');
  String get perm_tax_profiles_manage_name => _t('إدارة الملفات الضريبية ونسب الضريبة', 'Manage tax profiles');
  String get perm_tax_profiles_manage_desc => _t('إنشاء وتعديل ملفات ونسب ضريبة القيمة المضافة', 'Configure tax profiles and VAT rates');
  String get perm_audit_view_name => _t('الاطلاع على سجل النشاط والرقابة (Audit Trail)', 'View activity and audit trail');
  String get perm_audit_view_desc => _t('تصفح سجل العمليات وسلسلة التحقق الرقمية', 'Review system activity log and tamper-evident chain');
  String get perm_users_manage_name => _t('إدارة المستخدمين وكلمات المرور', 'Manage users and credentials');
  String get perm_users_manage_desc => _t('إضافة موظفين، تعيين الأدوار، وإعادة ضبط كلمات المرور', 'Create users, assign roles, and reset credentials');
  String get perm_roles_manage_name => _t('إدارة الأدوار ومصفوفة الصلاحيات', 'Manage roles and permission matrix');
  String get perm_roles_manage_desc => _t('إنشاء أدوار مخصصة وتعديل صلاحيات الأدوار', 'Create custom roles and customize permissions');
  String get perm_license_manage_name => _t('إدارة الترخيص والتفعيل (Pro Activation)', 'License and Pro subscription management');
  String get perm_license_manage_desc => _t('إدخال مفاتيح التفعيل وإدارة ترخيص التطبيق', 'Activate license keys and manage subscription');

  String permissionName(String key) {
    switch (key) {
      case 'sales.view':
        return perm_sales_view_name;
      case 'sales.create':
        return perm_sales_create_name;
      case 'sales.edit':
        return perm_sales_edit_name;
      case 'sales.edit_price':
        return perm_sales_edit_price_name;
      case 'sales.edit_discount':
        return perm_sales_edit_discount_name;
      case 'sales.cancel':
        return perm_sales_cancel_name;
      case 'sales.delete':
        return perm_sales_delete_name;
      case 'sales.refund':
        return perm_sales_refund_name;
      case 'purchases.view':
        return perm_purchases_view_name;
      case 'purchases.create':
        return perm_purchases_create_name;
      case 'purchases.edit':
        return perm_purchases_edit_name;
      case 'purchases.cancel':
        return perm_purchases_cancel_name;
      case 'purchases.delete':
        return perm_purchases_delete_name;
      case 'payments.record':
        return perm_payments_record_name;
      case 'vouchers.create':
        return perm_vouchers_create_name;
      case 'expenses.view':
        return perm_expenses_view_name;
      case 'stock.adjust':
        return perm_stock_adjust_name;
      case 'stock.view_cost':
        return perm_stock_view_cost_name;
      case 'stocktake.manage':
        return perm_stocktake_manage_name;
      case 'stocktake.finalize':
        return perm_stocktake_finalize_name;
      case 'products.view':
        return perm_products_view_name;
      case 'products.manage':
        return perm_products_manage_name;
      case 'products.delete':
        return perm_products_delete_name;
      case 'products.view_cost':
        return perm_products_view_cost_name;
      case 'products.view_wholesale':
        return perm_products_view_wholesale_name;
      case 'pricing.manage':
        return perm_pricing_manage_name;
      case 'pricing.rates':
        return perm_pricing_rates_name;
      case 'contacts.view':
        return perm_contacts_view_name;
      case 'contacts.manage':
        return perm_contacts_manage_name;
      case 'contacts.delete':
        return perm_contacts_delete_name;
      case 'contacts.view_balances':
        return perm_contacts_view_balances_name;
      case 'dashboard.view_totals':
        return perm_dashboard_view_totals_name;
      case 'reports.view_sales':
        return perm_reports_view_sales_name;
      case 'reports.view_purchases':
        return perm_reports_view_purchases_name;
      case 'reports.view_receivables':
        return perm_reports_view_receivables_name;
      case 'reports.view_inventory_cost':
        return perm_reports_view_inventory_cost_name;
      case 'reports.view_financials':
        return perm_reports_view_financials_name;
      case 'reports.export_pdf':
        return perm_reports_export_pdf_name;
      case 'data.export_csv':
        return perm_data_export_csv_name;
      case 'data.import_csv':
        return perm_data_import_csv_name;
      case 'backup.create':
        return perm_backup_create_name;
      case 'backup.restore':
        return perm_backup_restore_name;
      case 'system.repair':
        return perm_system_repair_name;
      case 'accounting.period_lock':
        return perm_accounting_period_lock_name;
      case 'settings.manage':
        return perm_settings_manage_name;
      case 'payment_methods.manage':
        return perm_payment_methods_manage_name;
      case 'tax_profiles.manage':
        return perm_tax_profiles_manage_name;
      case 'audit.view':
        return perm_audit_view_name;
      case 'users.manage':
        return perm_users_manage_name;
      case 'roles.manage':
        return perm_roles_manage_name;
      case 'license.manage':
        return perm_license_manage_name;
      default:
        return accessGenericPermission;
    }
  }

  String permissionDescription(String key) {
    switch (key) {
      case 'sales.view':
        return perm_sales_view_desc;
      case 'sales.create':
        return perm_sales_create_desc;
      case 'sales.edit':
        return perm_sales_edit_desc;
      case 'sales.edit_price':
        return perm_sales_edit_price_desc;
      case 'sales.edit_discount':
        return perm_sales_edit_discount_desc;
      case 'sales.cancel':
        return perm_sales_cancel_desc;
      case 'sales.delete':
        return perm_sales_delete_desc;
      case 'sales.refund':
        return perm_sales_refund_desc;
      case 'purchases.view':
        return perm_purchases_view_desc;
      case 'purchases.create':
        return perm_purchases_create_desc;
      case 'purchases.edit':
        return perm_purchases_edit_desc;
      case 'purchases.cancel':
        return perm_purchases_cancel_desc;
      case 'purchases.delete':
        return perm_purchases_delete_desc;
      case 'payments.record':
        return perm_payments_record_desc;
      case 'vouchers.create':
        return perm_vouchers_create_desc;
      case 'expenses.view':
        return perm_expenses_view_desc;
      case 'stock.adjust':
        return perm_stock_adjust_desc;
      case 'stock.view_cost':
        return perm_stock_view_cost_desc;
      case 'stocktake.manage':
        return perm_stocktake_manage_desc;
      case 'stocktake.finalize':
        return perm_stocktake_finalize_desc;
      case 'products.view':
        return perm_products_view_desc;
      case 'products.manage':
        return perm_products_manage_desc;
      case 'products.delete':
        return perm_products_delete_desc;
      case 'products.view_cost':
        return perm_products_view_cost_desc;
      case 'products.view_wholesale':
        return perm_products_view_wholesale_desc;
      case 'pricing.manage':
        return perm_pricing_manage_desc;
      case 'pricing.rates':
        return perm_pricing_rates_desc;
      case 'contacts.view':
        return perm_contacts_view_desc;
      case 'contacts.manage':
        return perm_contacts_manage_desc;
      case 'contacts.delete':
        return perm_contacts_delete_desc;
      case 'contacts.view_balances':
        return perm_contacts_view_balances_desc;
      case 'dashboard.view_totals':
        return perm_dashboard_view_totals_desc;
      case 'reports.view_sales':
        return perm_reports_view_sales_desc;
      case 'reports.view_purchases':
        return perm_reports_view_purchases_desc;
      case 'reports.view_receivables':
        return perm_reports_view_receivables_desc;
      case 'reports.view_inventory_cost':
        return perm_reports_view_inventory_cost_desc;
      case 'reports.view_financials':
        return perm_reports_view_financials_desc;
      case 'reports.export_pdf':
        return perm_reports_export_pdf_desc;
      case 'data.export_csv':
        return perm_data_export_csv_desc;
      case 'data.import_csv':
        return perm_data_import_csv_desc;
      case 'backup.create':
        return perm_backup_create_desc;
      case 'backup.restore':
        return perm_backup_restore_desc;
      case 'system.repair':
        return perm_system_repair_desc;
      case 'accounting.period_lock':
        return perm_accounting_period_lock_desc;
      case 'settings.manage':
        return perm_settings_manage_desc;
      case 'payment_methods.manage':
        return perm_payment_methods_manage_desc;
      case 'tax_profiles.manage':
        return perm_tax_profiles_manage_desc;
      case 'audit.view':
        return perm_audit_view_desc;
      case 'users.manage':
        return perm_users_manage_desc;
      case 'roles.manage':
        return perm_roles_manage_desc;
      case 'license.manage':
        return perm_license_manage_desc;
      default:
        return '';
    }
  }

  // ========== ACCESS CONTROL & ERRORS ==========
  String get accessDeniedTitle => _t('غير مصرح بالدخول', 'Access Denied');
  String accessDeniedScreenBody(String screen) => _t(
    'لا تملك الصلاحية اللازمة لفتح هذه الشاشة ($screen).',
    'You do not have permission to open this screen ($screen).',
  );
  String accessDeniedActionBody(String action) => _t(
    'لا تملك الصلاحية اللازمة لتنفيذ هذا الإجراء ($action).',
    'You do not have permission to perform this action ($action).',
  );
  String accessDeniedMissingPerm(String permission) => _t(
    'الصلاحية المطلوبة: $permission.',
    'Required permission: $permission.',
  );
  String get accessDeniedOwnerOnlyHint => _t(
    'هذه الميزة مقتصرة حصرياً على مالك النظام. راجع مالك المتجر إذا كنت بحاجة للوصول.',
    'This feature is restricted to the system Owner. Contact the store owner if you need access.',
  );
  String get accessDeniedDelegateHint => _t(
    'يمكنك طلب منح هذه الصلاحية من مالك النظام أو مدير الصلاحيات.',
    'You can request this permission from the system Owner or an administrator.',
  );
  String get accessDeniedLockedHint => _t(
    'الجلسة مقفلة. يرجى إدخال رمز PIN أو تسجيل الدخول للمتابعة.',
    'Session is locked. Please enter your PIN or sign in to continue.',
  );
  String get accessDeniedBack => _t('العودة', 'Go Back');
  String get accessDeniedGoToLock =>
      _t('التبديل إلى شاشة القفل', 'Switch to Lock Screen');
  String get accessGenericPermission =>
      _t('صلاحية غير محددة', 'unspecified permission');
  String get accessGenericAction => _t('هذا الإجراء', 'this action');
  String get accessGenericScreen => _t('هذه الشاشة', 'this screen');

  String get errUnauthenticated =>
      _t('يجب تسجيل الدخول للمتابعة', 'Please sign in to continue');
  String get errSessionLocked =>
      _t('الجلسة مقفلة، يرجى إدخال رمز PIN', 'Session is locked, please enter PIN');
  String get errOwnerOnly => _t(
    'هذا الإجراء مقتصر حصرياً على مالك النظام',
    'Restricted to the system Owner',
  );
  String get errTargetIsOwner => _t(
    'لا يمكن تعديل أو إدارة حساب المالك',
    'Cannot modify or manage the Owner account',
  );
  String get errTargetIsPeerOrSuperior => _t(
    'لا يمكن تعديل مستخدم يملك رتبة إدارية مماثلة أو أعلى',
    'Cannot modify a user with equal or higher admin privileges',
  );
  String get errTargetHasPermissionsActorLacks => _t(
    'لا يمكن تعديل مستخدم يملك صلاحيات لا تملكها',
    'Cannot modify a user holding permissions you lack',
  );
  String get errAssignRoleWithUnheldPermissions => _t(
    'لا يمكن إسناد دور يحتوي على صلاحيات لا تملكها',
    'Cannot assign a role containing permissions you lack',
  );
  String get errGrantUnheldPermission =>
      _t('لا يمكن منح صلاحية لا تملكها', 'Cannot grant a permission you lack');
  String get errEditRoleWithUnheldPermissions => _t(
    'لا يمكن تعديل دور يحتوي على صلاحيات لا تملكها',
    'Cannot modify a role containing permissions you lack',
  );
  String get errEditOwnRole => _t(
    'لا يمكن تعديل الدور الخاص بك لتجنب تصعيد الصلاحيات',
    'Cannot modify your own role',
  );
  String get errChangeOwnRole =>
      _t('لا يمكن تغيير دورك بنفسك', 'Cannot change your own role');
  String get errChangeOwnActiveStatus =>
      _t('لا يمكن تعطيل حسابك بنفسك', 'Cannot deactivate your own account');
  String get errCreateOwner => _t(
    'لا يمكن إنشاء حساب مالك إضافي',
    'Cannot create an additional Owner account',
  );
  String get errDeleteSystemRole =>
      _t('لا يمكن حذف أدوار النظام الأساسية', 'Cannot delete system roles');
  String get errRoleInUse => _t(
    'لا يمكن حذف الدور لأنه مستخدم من قبل مستخدمين نشطين',
    'Cannot delete role because it is assigned to active users',
  );
  String get errSelfCredentialRequiresCurrentSecret => _t(
    'يجب إدخال كلمة المرور أو رمز PIN الحالي لتعديل بيانات الدخول',
    'Current password or PIN is required to change credentials',
  );
  String get errUsernameRequired =>
      _t('اسم المستخدم مطلوب', 'Username is required');
  String get errDisplayNameRequired =>
      _t('الاسم الظاهر مطلوب', 'Display name is required');
  String get errUsernameTaken => _t(
    'اسم المستخدم مسجل مسبقاً، يرجى اختيار اسم آخر',
    'Username is already taken',
  );
  String get errUsernameInvalid => _t(
    'اسم المستخدم غير صالح (3-32 حرفاً إنجليزياً أو أرقام أو _ - .)',
    'Username is invalid (3–32 letters, digits, _, -, .)',
  );
  String get errPasswordTooShort => _t(
    'كلمة المرور يجب أن تتكون من 6 أحرف على الأقل',
    'Password must be at least 6 characters',
  );
  String get errPasswordsMismatch =>
      _t('كلمتا المرور غير متطابقتين', 'Passwords do not match');
  String get errPinInvalid => _t(
    'رمز PIN يجب أن يتكون من 4 إلى 8 أرقام',
    'PIN must be 4 to 8 digits',
  );
  String get errRoleNotFound =>
      _t('الدور المحدد غير موجود', 'Selected role not found');
  String get errUserNotFound =>
      _t('المستخدم غير موجود', 'User not found');
  String get errUserDisabled => _t(
    'تم تعطيل هذا الحساب، راجع مالك النظام',
    'Account disabled, contact store owner',
  );
  String errAccountLocked(String duration) => _t(
    'الحساب مقفل مؤقتاً، يرجى المحاولة بعد $duration',
    'Account locked temporarily, try again after $duration',
  );
  String errAttemptsRemaining(int count) => _t(
    'متبقي $count محاولات قبل تعليق الحساب',
    '$count attempts remaining before temporary lockout',
  );
  String errDeviceThrottled(String duration) => _t(
    'تم تجاوز المحاولات المسموحة على هذا الجهاز، انتظر $duration',
    'Device throttled, wait $duration',
  );
  String get errNoPasswordSet => _t(
    'لم يتم تعيين كلمة مرور لهذا الحساب',
    'No password configured for this account',
  );
  String get errNoPinSet => _t(
    'لم يتم تعيين رمز PIN لهذا الحساب',
    'No PIN configured for this account',
  );
  String get errWrongPassword =>
      _t('كلمة المرور غير صحيحة', 'Incorrect password');
  String get errWrongPin => _t('رمز PIN غير صحيح', 'Incorrect PIN');
  String get errWrongCurrentPassword =>
      _t('كلمة المرور الحالية غير صحيحة', 'Current password is incorrect');
  String get errWrongCurrentSecret => _t(
    'كلمة المرور أو رمز PIN الحالي غير صحيح',
    'Current password or PIN is incorrect',
  );
  String get errRecoveryCodeInvalid =>
      _t('رمز الاسترداد غير صالح', 'Recovery code is invalid');
  String errRecoveryLocked(String duration) => _t(
    'الاسترداد مقفل مؤقتاً لكثرة المحاولات، انتظر $duration',
    'Recovery locked temporarily, wait $duration',
  );
  String get errOwnerCannotBeDisabled =>
      _t('لا يمكن تعطيل حساب المالك', 'Owner account cannot be disabled');
  String get errOwnerUsernameImmutable => _t(
    'اسم مستخدم المالك ثابت ولا يمكن تغييره',
    'Owner username cannot be changed',
  );
  String get errOwnerRoleImmutable => _t(
    'دور المالك ثابت ولا يمكن تغييره',
    'Owner role cannot be changed',
  );
  String get errUndeclaredScreen => _t(
    'الشاشة المطلوبة غير معتمدة أمنياً',
    'Requested screen is not registered in security policy',
  );
  String get errMultiUserDisableOwnerOnly => _t(
    'لا يمكن إلغاء تعدد المستخدمين إلا بواسطة المالك',
    'Multi-user mode can only be disabled by the Owner',
  );
  String get errNoActiveOwner => _t(
    'لا يوجد حساب مالك نشط في النظام',
    'No active Owner account in the system',
  );
  String get errRoleNameRequired =>
      _t('اسم الدور مطلوب', 'Role name is required');
  String get errUnexpected => _t(
    'حدث خطأ غير متوقع، يرجى المحاولة مجدداً',
    'An unexpected error occurred, please try again',
  );
  String get actorSystem => _t('النظام', 'System');
  String get actorUnauthenticated => _t('غير مسجل', 'Unauthenticated');
  String get actorOwner => _t('المالك', 'Owner');

  // Additional Access screen & audit keys
  String get auditFilterAll => _t('الكل', 'All');
  String get auditFilterSecurity => _t('الأمان والحماية', 'Security');
  String get auditFilterLogins => _t('الدخول والخروج', 'Logins');
  String get auditFilterChanges => _t('التعديلات', 'Changes');
  String auditVerifiedEntries(int count) =>
      _t('$count سجل موثق', '$count verified entries');
  String auditBrokenAtId(int id) =>
      _t('تم اكتشاف الخلل عند السجل رقم $id', 'Chain broken at entry #$id');
  String get auditUnknownTime => _t('وقت غير معروف', 'Unknown time');
  String get auditActionGenesis => _t('بدء سجل التدقيق', 'Audit Chain Genesis');
  String get auditActionUserCreated => _t('إنشاء مستخدم', 'User Created');
  String get auditActionUserUpdated => _t('تعديل مستخدم', 'User Updated');
  String get auditActionUserUnlocked => _t('إلغاء قفل حساب', 'User Unlocked');
  String get auditActionRoleCreated => _t('إنشاء دور', 'Role Created');
  String get auditActionRoleUpdated => _t('تعديل دور', 'Role Updated');
  String get auditActionRoleDeleted => _t('حذف دور', 'Role Deleted');
  String get auditActionEscalationDenied => _t('محاولة تصعيد صلاحيات مرفوضة', 'Privilege Escalation Blocked');
  String get auditActionRecoveryFailed => _t('فشل استرداد الحساب', 'Recovery Failed');
  String get auditActionRecoveryCompleted => _t('اكتمال استرداد الحساب', 'Recovery Completed');
  String get auditActionMultiUserEnabled => _t('تفعيل وضع تعدد المستخدمين', 'Multi-User Enabled');
  String get auditActionMultiUserDisabled => _t('تعطيل وضع تعدد المستخدمين', 'Multi-User Disabled');
  String get auditActionUserLogout => _t('تسجيل خروج', 'User Logout');
  String get auditActionUserLogin => _t('تسجيل دخول', 'User Login');
  String get auditActionLoginFailed => _t('فشل تسجيل الدخول', 'Login Failed');
  String get auditActionSessionLocked => _t('قفل الجلسة', 'Session Locked');
  String get auditActionSensitiveReauth => _t('تأكيد عملية حساسة', 'Sensitive Action Reauth');

  String get auditDetailUserId => _t('معرف المستخدم', 'User ID');
  String get auditDetailUsername => _t('اسم المستخدم', 'Username');
  String get auditDetailDisplayName => _t('الاسم المعروض', 'Display Name');
  String get auditDetailRole => _t('الدور', 'Role');
  String get auditDetailPermissionsCount => _t('عدد الصلاحيات', 'Permissions Count');
  String get auditDetailUpdatedFields => _t('الحقول المعدلة', 'Updated Fields');
  String get auditDetailAction => _t('الإجراء المستهدف', 'Target Action');
  String get auditDetailDecision => _t('القرار', 'Decision');
  String get auditDetailReason => _t('السبب', 'Reason');
  String get auditDetailActor => _t('المنفذ', 'Actor');
  String get auditDetailFailedAttempts => _t('المحاولات الفاشلة', 'Failed Attempts');
  String get loadMore => _t('تحميل المزيد', 'Load More');
  String get auditVerifyingProgress => _t('جارٍ التحقق من السجلات...', 'Verifying audit records...');

  String get ownerPinHelper => _t(
        'اختياري: رمز PIN للدخول السريع من شاشة البيع بدون إدخال كلمة المرور كاملة',
        'Optional: PIN for quick unlocking without entering full password',
      );
  String get securingAccount =>
      _t('جاري تأمين الحساب...', 'Securing account...');
  String get accessBack => _t('رجوع', 'Back');
  String get cancelSetup => _t('إلغاء الإعداد', 'Cancel Setup');
  String get cancelSetupConfirm => _t(
        'هل أنت متأكد من إلغاء الإعداد؟ سيتم تجاهل رمز الاسترداد الذي تم إنشاؤه.',
        'Are you sure you want to cancel setup? The generated recovery code will be discarded.',
      );
  String get ownerRole => _t('المالك', 'Owner');
  String get securityInitFailedTitle =>
      _t('تعذر التحقق من إعدادات الأمان', 'Cannot verify security settings');
  String get securityInitFailedBody => _t(
        'فشلت قراءة إعدادات الأمان. تم إبقاء التطبيق مقفلاً لحماية البيانات.',
        'Failed to read security configuration. Kept locked to protect data.',
      );
  String disableUserConfirm(String name) =>
      _t('تعطيل المستخدم: $name؟', 'Disable user: $name?');
  String get ownerUsernameImmutable => _t(
        'اسم مستخدم المالك ثابت ولا يمكن تعديله',
        'Owner username is immutable',
      );
  String get usernameMinLength => _t(
        'اسم المستخدم يجب أن لا يقل عن 3 أحرف',
        'Username must be at least 3 characters',
      );
  String get passwordMinLength => _t(
        'كلمة المرور يجب أن لا تقل عن 6 أحرف',
        'Password must be at least 6 characters',
      );
  String get pinDigitsCount => _t(
        'رمز PIN يجب أن يتكون من 4 إلى 6 أرقام',
        'PIN must be 4 to 6 digits',
      );
  String get noCustomOverrides =>
      _t('بدون استثناءات مخصصة', 'No custom overrides');
  String customPermissionsCount(int count) =>
      _t('$count صلاحيات مخصصة', '$count custom permissions');

  String get disableMultiUserOwnerOnly => _t(
        'فقط المالك يمكنه تعطيل وضع تعدد المستخدمين',
        'Only the Owner can disable multi-user mode',
      );
  String get disableMultiUserConfirmMsg => _t(
        'يتطلب تعطيل وضع تعدد المستخدمين تأكيد كلمة مرور المالك لحماية بيانات المتجر.',
        'Disabling multi-user mode requires confirming the Owner password.',
      );
  String get disableMultiUserDialogMsg => _t(
        'هل أنت متأكد من رغبتك في تعطيل وضع تعدد المستخدمين والعودة لنمط المستخدم الفردي؟',
        'Are you sure you want to disable multi-user mode and return to single-user mode?',
      );
  String get disableMultiUserSuccess => _t(
        'تم تعطيل وضع تعدد المستخدمين بنجاح',
        'Multi-user mode disabled successfully',
      );
  String get searchUser => _t('بحث عن مستخدم...', 'Search user...');
  String get multiUserActiveBanner => _t(
        'وضع تعدد المستخدمين مفعل. يمكنك الآن إضافة كاشير أو محاسب أو مدير لتوزيع المهام بأمان.',
        'Multi-User Mode is active. Add cashiers or managers to safely delegate store operations.',
      );
  String userLockedUntilBadge(String time) =>
      _t('معلق حتى $time', 'Locked until $time');
  String get noPinBadge => _t('بدون PIN', 'No PIN');
  String get unlockUserAction => _t('إلغاء قفل الحساب', 'Unlock account');
  String unlockUserConfirm(String name) => _t(
        'هل أنت متأكد من إلغاء قفل حساب $name وإعادة تصفير محاولات الدخول الفاشلة؟',
        'Are you sure you want to unlock $name and reset failed login attempts?',
      );
  String get userUnlockedSuccess =>
      _t('تم إلغاء قفل الحساب بنجاح', 'User account unlocked successfully');
  String get currentPasswordLabel =>
      _t('كلمة المرور الحالية', 'Current Password');
  String get currentPasswordHelper => _t(
        'مطلوبة لتأكيد تغيير كلمة المرور أو رمز PIN الخاص بك',
        'Required to confirm changing your own password or PIN',
      );
  String get cannotEditHeldPermissionsHelper => _t(
        'لا يمكنك تعديل صلاحيات لا تملكها',
        'Cannot modify permissions you do not hold',
      );
  String get discardAction => _t('تجاهل', 'Discard');
  String get recoveryLeaveBlocked => _t(
        'يجب تدوين رمز الاسترداد وتأكيده قبل مغادرة الشاشة',
        'You must write down and confirm the recovery code before leaving',
      );
  String get enterPasswordToSignIn =>
      _t('الدخول بكلمة المرور', 'Sign in with password');
  String get passwordRequired =>
      _t('كلمة المرور مطلوبة', 'Password is required');
  String get signingIn => _t('جاري التحقق...', 'Verifying...');
  String get stepPassword => _t('كلمة المرور', 'Password');
  String get stepRecoveryCode => _t('رمز الاسترداد', 'Recovery Code');

  // Role templates (A8)
  String get roleOwner_name => _t('المالك', 'Owner');
  String get roleOwner_desc => _t(
    'مالك النظام بجميع الصلاحيات',
    'System Owner with full access',
  );
  String get roleTemplate_salesperson_name => _t('بائع', 'Salesperson');
  String get roleTemplate_salesperson_desc => _t(
    'إصدار الفواتير، التحصيل، وعرض العملاء والمنتجات',
    'Invoicing, payments, and browsing customers and products',
  );
  String get roleTemplate_inventory_name =>
      _t('مسؤول مخزون', 'Inventory Manager');
  String get roleTemplate_inventory_desc => _t(
    'إدارة المنتجات، تسوية المخزون، والجرد والمشتريات',
    'Product management, stock adjustments, stocktake, and purchases',
  );
  String get roleTemplate_accountant_name => _t('محاسب', 'Accountant');
  String get roleTemplate_accountant_desc => _t(
    'التقارير المالية، السندات، الحسابات، وإقفال الفترات',
    'Financial reports, vouchers, ledger, and period closing',
  );
  String get roleTemplate_manager_name => _t('مدير فرع', 'Branch Manager');
  String get roleTemplate_manager_desc => _t(
    'إدارة العمليات اليومية والتقارير والأسعار مع استثناء صلاحيات النظام الحساسة',
    'Daily operations, reports, and pricing excluding sensitive system permissions',
  );

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

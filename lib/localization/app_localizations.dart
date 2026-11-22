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
    'أنشئ أول فاتورة أو عرض سعر وابدأ بتنظيم عملك.',
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
    'لديك تغييرات غير محفوظة. هل تريد تجاهلها والخروج؟',
    'You have unsaved changes. Discard them and leave?',
  );
  String get discardChanges => _t('تجاهل التعديلات', 'Discard Changes');
  String get confirmDeleteLine => _t('حذف هذا البند؟', 'Delete this item?');
  String get deleteLineWarning => _t(
    'سيُحذف هذا البند من المستند.',
    'This item will be removed from the document.',
  );

  // ========== BUSINESS & SETTINGS ==========
  String get businessData =>
      _t('بيانات النشاط التجاري', 'Business Information');
  String get languageLabel => _t('اللغة', 'Language');
  String get arabic => _t('العربية', 'Arabic');
  String get english => _t('الإنجليزية', 'English');
  String get backup => _t('النسخ الاحتياطي', 'Backup');
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
  String get mobileWallet => _t('محفظة إلكترونية', 'Mobile Wallet');
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
  String get stock => _t('المخزون', 'Stock');
  String get stockQuantity => _t('الكمية المتوفرة', 'Stock Quantity');
  String get lowStockThreshold => _t('حد المخزون المنخفض', 'Low Stock Threshold');
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
    'لهذا العميل مستندات مسجّلة، وحذفه سيمحو سجل حسابه وأرصدته. يمكنك أرشفته بدلاً من ذلك: لن يظهر في المستندات الجديدة وتبقى جميع السجلات سليمة.',
    'This customer has recorded documents, and deleting would erase their account history and balances. You can archive the customer instead: they will no longer appear for new documents, and all records remain intact.',
  );
  String get archiveCustomer => _t('أرشفة العميل', 'Archive Customer');
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
  String get validityHint => _t(
    'أدخل عدد الأيام حتى انتهاء صلاحية العرض (مثال: 7)',
    'Enter the number of days until the quotation expires (e.g. 7)',
  );
  String get title => _t('عنوان المستند', 'Document Title');
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
    'ورقتك تطبيق بسيط لإنشاء الفواتير وعروض الأسعار والإيصالات، مع متابعة المدفوعات وإدارة العملاء والمنتجات، ويعمل بالكامل على هاتفك دون الحاجة إلى إنترنت.',
    'Waraqatak is a simple app for creating invoices, quotations, and receipts, tracking payments, and managing customers and products. It works entirely offline, right on your phone.',
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
    'الشروط التي تحكم استخدامك لتطبيق ورقتك.',
    'The terms that govern your use of Waraqatak.',
  );
  String get deleteAccountData =>
      _t('حذف بيانات الحساب', 'Delete Account Data');
  String get deleteAccountDataDescription => _t(
    'إرشادات لحذف بياناتك من هذا الجهاز ومن خوادم المطور.',
    'How to delete your data from this device and from the developer servers.',
  );
  String get appLogoLabel => _t('شعار ورقتك', 'Waraqatak logo');

  // ========== DIAGNOSTICS & ERROR REPORTING ==========
  String get diagnosticSharingTitle =>
      _t('مشاركة تقارير الأعطال والتشخيص', 'Share Diagnostic & Crash Reports');
  String get diagnosticSharingDesc => _t(
    'إرسال تقارير تقنية خالية من البيانات الشخصية عند حدوث أخطاء غير متوقعة، للمساعدة في تحسين استقرار التطبيق.',
    'Send sanitized technical reports when unexpected errors occur, to help improve the stability of the app.',
  );
  String get diagnosticSharingModalTitle =>
      _t('حول تقارير التشخيص والخصوصية', 'About Diagnostics & Privacy');
  String get diagnosticSharingModalBody => _t(
    'نحن نحترم خصوصيتك وأمان بياناتك التجارية:\n\n'
        '• ما نجمعه: إصدار التطبيق، ونظام التشغيل، ونوع الخطأ التقني، واسم العملية (مثل إنشاء ملف PDF)، وسجل تتبّع الأخطاء بعد تنقيته من أي بيانات حساسة.\n\n'
        '• ما لا نجمعه إطلاقاً: محتوى الفواتير، أو أسماء العملاء والموردين وأرقامهم، أو المبالغ المالية، أو كلمات المرور، أو أي بيانات شخصية.\n\n'
        '• مدة الاحتفاظ: تُحذف التقارير تلقائياً من خوادمنا بعد 30 يوماً.\n\n'
        '• التحكم: يمكنك إيقاف هذه الميزة في أي وقت، وحذف التقارير المعلّقة من جهازك فوراً.',
    'We respect your privacy and the security of your business data:\n\n'
        '• What we collect: app version, operating system version, technical error type, a generic operation name (such as invoice PDF generation), and a sanitized stack trace.\n\n'
        '• What we never collect: invoice contents, customer or supplier names and numbers, monetary amounts, passwords, or any personal data.\n\n'
        '• Retention: reports are automatically deleted from our servers after 30 days.\n\n'
        '• Control: you can turn this feature off at any time and immediately delete any pending reports from your device.',
  );

  // ========== OPEN-SOURCE LICENSES ==========
  String get appName => _t('ورقتك', 'Waraqatak');
  String get openSourceLicenses =>
      _t('تراخيص المصادر المفتوحة', 'Open-source Licenses');
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
    'No, leave it unencrypted',
  );
  String get backupWithPassword =>
      _t('نعم، حماية بكلمة مرور', 'Yes, protect with password');
  String get backupPassword => _t('كلمة المرور', 'Password');
  String get backupConfirmPassword =>
      _t('تأكيد كلمة المرور', 'Confirm password');
  String get backupPasswordRequired =>
      _t('أدخل كلمة المرور', 'Please enter a password');
  String get backupPasswordMinLength => _t(
    'يجب ألا تقل كلمة المرور عن 8 أحرف',
    'Password must be at least 8 characters',
  );
  String get backupPasswordsDoNotMatch =>
      _t('كلمتا المرور غير متطابقتين', 'Passwords do not match');
  String get backupPasswordWarning => _t(
    'تحذير: إذا نسيت كلمة المرور فلن يستطيع أحد فتح هذه النسخة، لا أنت ولا نحن.',
    'Warning: if you forget the password, no one, including us, can open this backup.',
  );
  String get backupPasswordHint => _t(
    'تلميح: استخدام الأحرف والأرقام الإنجليزية يجنّبك مشاكل اختلاف لوحات المفاتيح.',
    'Tip: Use English letters and digits to avoid keyboard layout issues.',
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
    'جارٍ فك التشفير والتحقق من البيانات…',
    'Decrypting and verifying data…',
  );
  String get backupEncrypting => _t(
    'جارٍ تشفير النسخة الاحتياطية والتحقق منها…',
    'Encrypting backup and verifying…',
  );
  String get backupSlowNotice => _t(
    'قد تستغرق هذه العملية دقيقة على الهواتف القديمة',
    'This operation may take up to a minute on older phones',
  );
  String get backupInvalidFormat =>
      _t('صيغة ملف النسخة الاحتياطية غير صالحة', 'Invalid backup file format');
  String get backupIntegrityFailed => _t(
    'فشل التحقق من سلامة البيانات بعد الاستعادة، وتمت إعادة بياناتك السابقة',
    'Data integrity check failed after the restore, so your previous data was put back',
  );
  String get backupUnencryptedCloudConfirm => _t(
    'رفع نسخة غير مشفرة إلى السحابة سيحفظ بيانات نشاطك التجاري على Google Drive دون حماية بكلمة مرور. هل تريد المتابعة بدون تشفير؟',
    'Uploading an unencrypted backup to the cloud will store your business data on Google Drive without password protection. Do you wish to continue without encryption?',
  );
  String get backupReminder7Days => _t(
    'تذكير: مرّت 7 أيام أو أكثر على آخر نسخة احتياطية. يُنصح بإنشاء نسخة جديدة لحماية بياناتك.',
    'Reminder: It has been 7 days or more since your last backup. Create a new one to protect your data.',
  );
  String lastBackupDate(String date) =>
      _t('آخر نسخة احتياطية: $date', 'Last backup: $date');
  String get noBackupYet =>
      _t('لم يتم إنشاء أي نسخة احتياطية بعد', 'No backup created yet');
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
  String get paymentRecorded => _t('تم تسجيل الدفعة بنجاح', 'Payment recorded successfully');
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

  String get cancelInvoiceInventoryNotice => _t(
    'إلغاء هذه الفاتورة سيعيد الأصناف تلقائياً إلى المخزون ويعكس القيود المحاسبية. لا يمكن التراجع عن هذا الإجراء.',
    'Cancelling this invoice will automatically return items to stock and reverse accounting entries. This cannot be undone.',
  );

  String get cancelPurchaseInventoryNotice => _t(
    'إلغاء فاتورة الشراء سيخصم الأصناف من المخزون ويعكس حساب المورد. لا يمكن التراجع عن هذا الإجراء.',
    'Cancelling this purchase will deduct items from stock and reverse the supplier account. This cannot be undone.',
  );
  String cannotCancelWithActiveVouchers(String voucherNumbers) => _t(
    'لا يمكن إلغاء المستند لوجود سندات قبض/صرف نشطة مرتبطة به (${_iso(voucherNumbers)}). ألغِ هذه السندات أولاً.',
    'This document cannot be cancelled because it has active receipts or vouchers linked to it ($voucherNumbers). Cancel them first.',
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
    'يُوزَّع المبلغ على فواتير العميل المفتوحة بدءاً من الأقدم.',
    'The amount is applied to the customer\'s open invoices, oldest first.',
  );
  String get voucherAllocationHintSupplier => _t(
    'يُوزَّع المبلغ على فواتير شراء المورد المفتوحة بدءاً من الأقدم.',
    'The amount is applied to the supplier\'s open purchase invoices, oldest first.',
  );
  String voucherAmountExceedsOutstanding(String amount) => _t(
    'المبلغ أكبر من المستحق (${_iso(amount)}).',
    'The amount exceeds the outstanding balance (${_iso(amount)}).',
  );
  String get voucherNoOpenDocuments => _t(
    'لا توجد مستندات مفتوحة لهذا الطرف. اترك الحقل فارغاً لتسجيل المبلغ كإيراد أو مصروف آخر.',
    'There are no open documents for this contact. Leave the contact field empty to record the amount as other income or expense.',
  );
  String voucherAllocatedSnack(String count) => _t(
    'تم توزيع المبلغ على عدة مستندات (${_iso(count)})، وأُنشئ سند لكل مستند.',
    'The amount was split across several documents (${_iso(count)}); a receipt was created for each.',
  );
  String get errorPaymentExceedsOutstanding => _t(
    'المبلغ أكبر من المستحق على الطرف.',
    'The amount exceeds the outstanding balance.',
  );
  String get errorDocumentAlreadyCancelled =>
      _t('المستند ملغى بالفعل.', 'This document is already cancelled.');
  String get errorCannotReduceTotalBelowPayments => _t(
    'لا يمكن تقليل الإجمالي إلى أقل من المدفوعات المسجلة.',
    'Cannot reduce total below recorded payments.',
  );
  String get errorInsufficientStockToCancelPurchase => _t(
    'لا يمكن إلغاء فاتورة الشراء لعدم توفر مخزون كافٍ.',
    'The purchase invoice cannot be cancelled because there is not enough stock.',
  );
  String get cancelPaidSupplierReturnInstruction => _t(
    'يجب استرداد هذا المبلغ من المورد يدوياً خارج التطبيق.',
    'This money must be recovered from the supplier manually outside the app.',
  );
  String get cancelPaidDoubleCountWarning => _t(
    'تنبيه مهم: لا تُسجّل سند صرف لهذا المبلغ؛ لأن الدفعة مستبعدة تلقائياً من تقارير الصندوق، وتسجيل سند صرف سيؤدي إلى خصم المبلغ مرتين.',
    'Important: Do not record an expense voucher for this refund; the payment is already excluded from cash reports, and recording a voucher will deduct it twice.',
  );
  String get cancelPaidDoubleCountWarningPurchase => _t(
    'تنبيه مهم: لا تُسجّل سند قبض لهذا المبلغ؛ لأن الدفعة مستبعدة تلقائياً من تقارير الصندوق، وتسجيل سند قبض سيؤدي إلى إضافة المبلغ مرتين.',
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
      _t('رجوع (الإبقاء على المستند)', 'Go Back (Keep Document)');
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
  String get deleteDraft => _t('حذف المسودة', 'Delete Draft');
  String get deleteDraftMessage =>
      _t('هل تريد حذف هذه المسودة؟', 'Delete this draft?');
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
  String get relatedInvoice => _t('الفاتورة المرتبطة', 'Related Invoice');
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
    'اختر طرق الدفع التي تريد عرضها',
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
  String get chooseFromGallery => _t('اختيار من معرض الصور', 'Choose from Gallery');
  String get imageLoadError => _t('تعذر تحميل الصورة', 'Could not load the image');
  String get imagePickFailed =>
      _t('تعذر اختيار الصورة أو حفظها', 'Could not select or save the image');
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
  String get flashlight => _t('المصباح', 'Flashlight');
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
    'A product with stock cannot be converted to a service. Set its stock to 0 first.',
  );
  String get stockCannotBeEditedDirectly => _t(
    'لا يمكن تعديل كمية المخزون مباشرة هنا. استخدم «تعديل المخزون».',
    'Stock quantity cannot be edited directly here. Use “Stock Adjustment” instead.',
  );

  // ========== DEVELOPER ==========
  String get madeBy => _t('تطوير', 'Made by');

  // ========== PURCHASES & ORDERS ==========
  String get purchase => _t('فاتورة شراء', 'Purchase Invoice');
  String get purchases => _t('فواتير الشراء', 'Purchase Invoices');
  String get newPurchase => _t('فاتورة شراء جديدة', 'New Purchase Invoice');
  String get finalizePurchase => _t('اعتماد فاتورة الشراء', 'Finalize Purchase Invoice');
  String get purchaseDocument => _t('مستند شراء', 'Purchase Document');
  String get purchasesOnly => _t('المشتريات', 'Purchases');

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
    'This contact is used in existing documents. Deactivate it instead of deleting it?',
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
  String get openingStock => _t('مخزون افتتاحي', 'Opening Stock');
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
  String get documentCancellation => _t('إلغاء مستند', 'Document Cancellation');
  String showingMovementsLimit(int count) => _t(
    'يتم عرض أول $count حركة فقط.',
    'Showing first $count movements only.',
  );
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
  String get healthyStock => _t('مخزون كافٍ', 'Sufficient Stock');
  String get filterByMovementType => _t('نوع الحركة', 'Movement Type');
  String get viewFullHistory => _t('عرض السجل الكامل', 'View Full History');
  String get scanOrSearchProduct =>
      _t('مسح أو بحث عن منتج', 'Scan or Search for a Product');
  String get createProductWithBarcode =>
      _t('إنشاء منتج بهذا الباركود', 'Create Product with This Barcode');
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
      _t('تاريخ غير صالح (سنة/شهر/يوم)', 'Invalid date (YYYY/MM/DD)');
  String get dateOutOfRange =>
      _t('التاريخ خارج النطاق المسموح', 'Date is outside the allowed range');
  String get dateFromMustBeBeforeTo => _t(
    'يجب ألا يتأخر تاريخ البداية عن تاريخ النهاية',
    'The start date must be on or before the end date',
  );

  // ========== DASHBOARD METRIC CARDS ==========
  String get salesPeriod => _t('المبيعات', 'Sales');
  String get purchasesPeriod => _t('المشتريات', 'Purchases');
  String get paymentsIn => _t('المقبوضات', 'Payments In');
  String get paymentsOut => _t('المدفوعات', 'Payments Out');
  String get allTimeBalance => _t('الرصيد الكلي', 'Overall Balance');
  String get noDataForPeriod =>
      _t('لا توجد بيانات خلال هذه الفترة', 'No data for this period');
  String get inventorySummary => _t('ملخص المخزون', 'Inventory Summary');
  String get trackedProducts => _t('منتجات تتم متابعة مخزونها', 'Tracked Products');
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
  String get purchaseCount => _t('عدد فواتير الشراء', 'Purchase Invoices');
  String get cancelledCount => _t('الملغاة', 'Cancelled');
  String get finalized => _t('معتمدة', 'Finalized');
  String get receivedPayments => _t('المقبوضات', 'Received Payments');
  String get madePayments => _t('المدفوعات', 'Made Payments');
  String get salesQty => _t('كمية المبيعات', 'Quantity Sold');
  String get salesValue => _t('قيمة المبيعات', 'Sales Value');
  String get purchasedQty => _t('كمية المشتريات', 'Quantity Purchased');
  String get stockStatus => _t('حالة المخزون', 'Stock Status');
  String get noReportData =>
      _t('لا توجد بيانات لهذا التقرير', 'No report data');
  String get relatedDoc => _t('المستند المرتبط', 'Related Document');

  // ========== PRINT & THERMAL SETTINGS ==========
  String get printSettings => _t('إعدادات الطباعة', 'Print Settings');
  String get paperSize => _t('حجم الورق', 'Paper Size');
  String get paperA4 => _t('A4', 'A4');
  String get paperA5 => _t('A5', 'A5');
  String get paperThermal80 => _t('ورق حراري 80 مم', 'Thermal Paper 80 mm');
  String get defaultPaperSize =>
      _t('حجم الورق الافتراضي', 'Default Paper Size');

  // ========== PAYMENT METHODS CONFIGURATION ==========
  String get addPaymentMethod => _t('إضافة طريقة دفع', 'Add Payment Method');
  String get editPaymentMethod =>
      _t('تعديل طريقة الدفع', 'Edit Payment Method');
  String get methodName => _t('اسم الطريقة', 'Method Name');
  String get predefinedMethods => _t('الطرق المضمّنة', 'Built-in Methods');
  String get customMethods => _t('طرق مخصصة', 'Custom Methods');
  String get noCustomMethods =>
      _t('لا توجد طرق مخصصة بعد', 'No custom methods yet');
  String get confirmDeleteMethod =>
      _t('حذف طريقة الدفع', 'Delete Payment Method');

  // ========== PAYMENT METHODS STORAGE ==========
  String get defaultMethod => _t('الافتراضي', 'Default');
  String get setAsDefault => _t('تعيين كافتراضي', 'Set as Default');
  String get cannotDeleteMethodInUse => _t(
    'لا يمكن حذف طريقة دفع مستخدمة في مستندات',
    'This method cannot be deleted because it is used in documents',
  );
  String get methodLabelAr => _t('الاسم بالعربية', 'Arabic Name');
  String get methodLabelEn => _t('الاسم بالإنجليزية', 'English Name');
  String get noPaymentMethodsEnabled =>
      _t('لا توجد طرق دفع مفعّلة', 'No payment methods enabled');

  // ========== BARCODE SCANNER ==========
  String get scannerHint =>
      _t('وجّه الكاميرا نحو الباركود', 'Point the camera at the barcode');
  String get scannerPermDenied =>
      _t('إذن الكاميرا مطلوب', 'Camera permission required');
  String get scannerPermMsg => _t(
    'اسمح للتطبيق باستخدام الكاميرا لمسح الباركود',
    'Allow camera access to scan barcodes',
  );
  String get manualEntry => _t('إدخال يدوي', 'Manual Entry');

  // ========== INVENTORY ADJUSTMENTS ==========
  String get newStockQuantity => _t('الكمية بعد التعديل', 'New Stock Quantity');
  String get adjustmentReason => _t('سبب التعديل', 'Adjustment Reason');
  String get inStock => _t('متوفر', 'In Stock');
  String get scanToLocate => _t('مسح للبحث', 'Scan to Locate');

  // ========== AUDIT TRAIL ==========
  String get auditLog => _t('سجل التدقيق', 'Audit Log');

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
  String get commercialReg => _t('رقم السجل التجاري', 'Commercial Registration No.');
  String get branch => _t('الفرع', 'Branch');

  String get taxSettings => _t('إعدادات الضريبة', 'Tax Settings');
  String get taxesEnabled => _t('تفعيل الضريبة', 'Enable Taxes');
  String get taxesEnabledDesc =>
      _t('عرض الضريبة في الفواتير', 'Show tax on invoices');
  String get pricesIncludeTax =>
      _t('الأسعار شاملة الضريبة', 'Prices Include Tax');
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
      _t('الحد الأدنى لكمية الجملة', 'Minimum Wholesale Quantity');
  String get wholesaleMinQuantityHelp => _t(
    'أقل كمية لتطبيق سعر الجملة تلقائياً',
    'Minimum quantity at which the wholesale price is applied automatically',
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
    'Note: Bulk price adjustments apply to base units only and do not change the prices of additional sales units.',
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
      _t('إنشاء نسب الضريبة وإدارتها', 'Create and manage tax rates');
  String get addTaxProfile => _t('إضافة نسبة ضريبة', 'Add Tax Profile');
  String get editTaxProfile => _t('تعديل نسبة الضريبة', 'Edit Tax Profile');
  String get taxProfileName => _t('اسم النسبة', 'Profile Name');
  String get taxProfileType => _t('نوع الضريبة', 'Tax Type');
  String get taxProfileRate => _t('نسبة الضريبة (%)', 'Tax Rate (%)');
  String get taxProfileDefault => _t('افتراضي', 'Default');
  String get taxProfileInclusive =>
      _t('شامل (مضمّن في السعر)', 'Inclusive (included in price)');
  String get taxProfileExclusive =>
      _t('غير شامل (تُضاف إلى السعر)', 'Exclusive (added to price)');
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
    'Shown on invoices in place of “Invoice”',
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
    'This payment method cannot be deleted because it is used in past transactions. You can disable it instead to stop it being used in new transactions while keeping your history.',
  );
  String get cannotDeletePaymentMethodTitle =>
      _t('تعذر حذف طريقة الدفع', 'Cannot Delete Payment Method');
  String get currencyScopeNote => _t(
    'العملة الافتراضية تنطبق على المستندات والمنتجات الجديدة. تحتفظ المعاملات السابقة بالعملة التي سُجلت بها.',
    'Default currency applies to new documents and products. Existing transactions retain their recorded currency.',
  );
  String get currencyLockedNote => _t(
    'العملة الأساسية مقفلة نهائياً لوجود معاملات مالية أو حركات مخزون مسجلة.',
    'The base currency is permanently locked because financial transactions or stock movements have been recorded.',
  );
  String get currencyInitialWarningNote => _t(
    'تنبيه: تصبح هذه العملة دائمة ولا يمكن تغييرها بمجرد تسجيل أول فاتورة أو إيصال أو حركة مخزون.',
    'Note: The currency becomes permanent and cannot be changed once the first transaction or stock movement is recorded.',
  );
  String get currencyConfirmTitle =>
      _t('تأكيد اختيار العملة الأساسية', 'Confirm Base Currency');
  String currencyConfirmMessage(String currency) => _t(
    'اخترت العملة (${_iso(currency)}). بمجرد تسجيل أول فاتورة أو إيصال أو حركة مخزون، ستصبح هذه العملة دائمة ولا يمكن تغييرها من الإعدادات. هل تريد المتابعة؟',
    'You selected ($currency). Once your first invoice, receipt, or stock movement is recorded, this currency becomes permanent and cannot be changed. Do you want to continue?',
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
    'Difference: disabling taxes turns off tax calculation entirely, while a zero rate (0%) treats the item as taxable at 0%.',
  );
  String get basicInfo =>
      _t('البيانات الأساسية ومعلومات الاتصال', 'Basic Information & Contact');
  String get visualBranding => _t('الشعار والمظهر', 'Logo & Visual Branding');
  String get financialDefaults =>
      _t('الإعدادات المالية الافتراضية', 'Financial Defaults');
  String get legalAndTaxInfo =>
      _t('البيانات القانونية والضريبية', 'Legal & Tax Details');
  String get notConfigured => _t('غير محدد', 'Not set');
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
      _t('أدخل مفتاح التفعيل', 'Enter Activation Key');
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
    'تعذّر الاتصال بالخادم. تأكد من اتصالك بالإنترنت ثم حاول مجدداً.',
    'Could not reach the server. Check your internet connection and try again.',
  );
  String get activationDeviceUnavailable => _t(
    'تعذّر التحقق من هذا الجهاز. أعد المحاولة، وإن تكرر الخطأ تواصل مع الدعم.',
    'Could not verify this device. Try again, and contact support if the problem persists.',
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
    'Tip: Restart your phone and try again. If the problem persists, contact support.',
  );
  String get pasteKey => _t('لصق', 'Paste');
  String get deviceModelLabel => _t('موديل الجهاز', 'Device Model');
  String get deviceIdLabel => _t('معرّف الجهاز', 'Device Identifier');
  String get copyDeviceId => _t('نسخ معرّف الجهاز', 'Copy Device Identifier');
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
      _t('نسخ معلومات الدعم الفني', 'Copy Support Info');
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
    'We couldn\'t find this document. It may have been deleted.',
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
    'لديك تجربة مجانية لمدة 14 يوماً لجميع مميزات ورقتك Pro. المتبقي: $days يوم.',
    'You have a 14-day free trial for all Waraqatak Pro features. $days day(s) remaining.',
  );
  String get trialExpiredStatusMessage => _t(
    'انتهت التجربة المجانية. يمكنك إدخال مفتاح التفعيل للاستمرار في استخدام ميزات Pro.',
    'The free trial has expired. You can enter an activation key to continue using Pro features.',
  );
  String get whatsappNotInstalled => _t(
    'واتساب غير مثبت على جهازك',
    'WhatsApp is not installed on your device',
  );
  String get freeVsProIntroText => _t(
    'تحميل ورقتك مجاني. جرّب Pro كاملاً لمدة 14 يوماً دون أي رسوم، وبعدها تحتاج إلى مفتاح تفعيل.',
    'Waraqatak is free to download. Try the full Pro experience free for 14 days; after that, an activation key is required.',
  );
  String get freeTierHeader => _t('المجاني', 'Free');
  String get proTierHeader => _t('Pro (مع المفتاح)', 'Pro (with key)');
  String get alreadyHaveKeyTitle => _t('لديك مفتاح تفعيل؟', 'Already have a key?');
  String get enterKeyHintText => _t(
    'الصق المفتاح هنا ثم اضغط "تفعيل".',
    'Paste the key here and tap "Activate".',
  );
  String get activationKeyHelperText => _t(
    'هذه الصفحة مخصصة لمن يملك مفتاح تفعيل مسبقاً. الصق المفتاح واضغط تفعيل، والتطبيق يعمل بشكل كامل بدون مفتاح.',
    'This screen is for users who already have an activation key. Paste it and tap Activate. The app works fully without one.',
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
    'Could not open the email app. You can reach us at: $email',
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
      _t('مقارنة ميزات المجاني و Pro', 'Free vs Pro Features Comparison');
  String get activationTipStorage => _t(
    'تلميح: تأكد من توفر مساحة تخزين كافية وصلاحيات التخزين الآمن بالجهاز.',
    'Tip: Make sure your device has enough free storage and that secure storage is accessible.',
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
      _t('المخزون وعمليات الجرد', 'Inventory & stocktake operations');
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
    'تم التفعيل بنجاح. أصبحت مميزات Pro متاحة لك.',
    'Activated successfully! Pro features are now available to you.',
  );
  String get activationFailureGuidance => _t(
    'تعذّر التفعيل. تأكد أن المفتاح منسوخ كاملاً بدون مسافات وأن الإنترنت يعمل. إذا استمرت المشكلة، يمكنك طلب الدعم الفني.',
    'Activation failed. Make sure the key is copied in full, without spaces, and that you are connected to the internet. If the problem persists, contact support.',
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
  String get seeFreeVsPro => _t('ما المتاح مجاناً؟', 'See What\'s Free vs Pro');

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
      _t('فواتير الشراء والموردون', 'Purchase invoices and suppliers');
  String get featureInventory =>
      _t('إدارة المخزون المتقدمة', 'Advanced inventory management');
  String get featureAdvancedReports =>
      _t('التقارير التفصيلية الكاملة', 'Full detailed reports');

  // ========== FREE / PRO GATING ==========
  String get proBadgeLabel => _t('احترافي', 'Pro');
  String get proFeatureTitle => _t('ميزة احترافية', 'Pro Feature');
  String get proIncludesPurchases =>
      _t('فواتير الشراء والموردون', 'Purchases & Suppliers');
  String get proIncludesInventory =>
      _t('إدارة المخزون المتقدمة', 'Advanced Inventory Management');
  String get proIncludesReports =>
      _t('التقارير التفصيلية الكاملة', 'Full Detailed Reports');
  String get proAdvancedReports =>
      _t('التقارير المتقدمة', 'Advanced Reports');
  String get enterActivationKeyAction =>
      _t('إدخال مفتاح التفعيل', 'Enter Activation Key');
  String get freeDataAlwaysAvailable => _t(
    'بياناتك ومستنداتك محفوظة دائماً حتى في الوضع المجاني.',
    'Your data and documents are always available, even in Free mode.',
  );
  String get freeModeBannerMsg => _t(
    'الوضع المجاني نشط — الفواتير والعملاء والمنتجات متاحة دائماً.',
    'Free mode active — invoices, customers, and products are always available.',
  );

  // ========== QUICK SALE (POS) ==========
  String get posQuickSale => _t('بيع سريع', 'Quick Sale');
  String get posQuickSaleDesc => _t(
    'بيع بالمسح أو اللمس مع إيصال فوري',
    'Tap or scan to sell with an instant receipt',
  );
  String get posSearchHint =>
      _t('ابحث بالاسم أو الكود أو الباركود', 'Search by name, code or barcode');
  String get posViewCart => _t('السلة', 'Cart');
  String get posEmptyCartHint =>
      _t('اضغط على منتج لإضافته', 'Tap a product to add it');
  String get posLongPressQuantityHint =>
      _t('اضغط مطولاً لتحديد الكمية', 'Long-press to set quantity');
  String get posCartEmpty => _t(
    'السلة فارغة. اضغط على منتج لإضافته.',
    'Cart is empty. Tap a product to add it.',
  );
  String get posAmountReceived => _t('المبلغ المستلم', 'Amount Received');
  String get posChange => _t('الباقي للعميل', 'Change');
  String get posCompleteSale => _t('إتمام البيع', 'Complete Sale');
  String get posSaleCompleted => _t('تم البيع بنجاح', 'Sale Completed');
  String get posPrintReceipt => _t('طباعة إيصال', 'Print Receipt');
  String get posShare => _t('مشاركة', 'Share');
  String get posViewInvoice => _t('عرض الفاتورة', 'View Invoice');
  String get posNewSale => _t('بيع جديد', 'New Sale');
  String get posClearCart => _t('تفريغ السلة', 'Clear Cart');
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
  String get posCustomerDebt =>
      _t('مديونية العميل السابقة', 'Previous Customer Debt');
  String get posCustomerTotalDebt =>
      _t('إجمالي مديونية العميل بعد البيع', 'Total Customer Debt After Sale');
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
  String get supportAndContact => _t('الدعم والتواصل', 'Support & Contact');
  String get whatsappSupport => _t('واتساب', 'WhatsApp');
  String get whatsappSupportDesc =>
      _t('للمساعدة الفنية والاستفسارات', 'Technical help and questions');
  String get supportWhatsAppGreeting => _t(
    'مرحباً، أحتاج مساعدة في تطبيق ورقتك',
    'Hello, I need help with Waraqatak',
  );
  String get facebookPage => _t('صفحتنا على فيسبوك', 'Our Facebook Page');
  String get facebookPageDesc =>
      _t('الأخبار والتحديثات والنصائح', 'News, updates and tips');
  String get developerWebsite => _t('موقع المطوّر', 'Developer Website');
  String get whatYouCanDo => _t('ماذا يمكنك أن تفعل', 'What You Can Do');
  String get legalAndPrivacy => _t('الخصوصية والشروط', 'Privacy & Terms');
  String get rateApp => _t('قيّم التطبيق', 'Rate app');
  String get shareApp => _t('شارك التطبيق', 'Share app');
  String get getHelp => _t('مساعدة', 'Get Help');
  String get shareAppMessage => _t(
    'جرّب تطبيق ورقتك لإنشاء الفواتير والمستندات بسهولة:',
    'Try Waraqatak to create invoices and business documents easily:',
  );

  // ========== SETTINGS SECTIONS & APPEARANCE ==========
  String get settingsSectionBusiness => _t('النشاط التجاري', 'Business');
  String get settingsSectionAppearance =>
      _t('المظهر واللغة', 'Appearance & Language');
  String get settingsSectionData =>
      _t('البيانات والنسخ الاحتياطي', 'Data & Backup');
  String get settingsSectionSupport => _t('الدعم والمعلومات', 'Support & Info');
  String get themeModeLabel => _t('المظهر', 'Theme');
  String get themeLight => _t('فاتح', 'Light');
  String get themeDark => _t('داكن', 'Dark');
  String get themeSystem => _t('حسب النظام', 'System');
  String get aboutSubtitle =>
      _t('الدعم والتواصل والإصدار', 'Support, contact and version');

  // ========== PDF CUSTOMIZATION ==========
  String get pdfSignature => _t('التوقيع', 'Signature');
  String get pdfStamp => _t('الختم', 'Stamp');
  String get pdfCustomize =>
      _t('تخصيص المستندات (PDF)', 'Document Design (PDF)');
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
  String get pdfAccentColor => _t('اللون الرئيسي', 'Accent Color');
  String get pdfLogo => _t('الشعار', 'Logo');
  String get pdfLogoCircle => _t('دائري', 'Circle');
  String get pdfLogoRounded => _t('مستدير الزوايا', 'Rounded');
  String get pdfLogoHidden => _t('إخفاء', 'Hidden');
  String get pdfTextSize => _t('حجم الخط', 'Text Size');
  String get pdfTextSmall => _t('صغير', 'Small');
  String get pdfTextNormal => _t('متوسط', 'Medium');
  String get pdfTextLarge => _t('كبير', 'Large');
  String get pdfFields => _t('محتوى المستند', 'Document Content');
  String get pdfShowBusinessContact =>
      _t('بيانات التواصل للنشاط', 'Business Contact Details');
  String get pdfShowTaxId => _t('الرقم الضريبي', 'Tax ID');
  String get pdfShowCustomer => _t('بيانات العميل', 'Customer Details');
  String get pdfShowNotes => _t('الملاحظات', 'Notes');
  String get pdfShowPaymentSummary =>
      _t('المدفوع والمتبقي (الفواتير)', 'Paid and Remaining (invoices)');
  String get pdfShowSignature =>
      _t('خانة التوقيع والختم', 'Signature and Stamp Area');
  String get pdfSealsSection =>
      _t('الختم والتوقيع الرقمي', 'Digital Stamp & Signature');
  String get pdfSealStamp => _t('الختم الرقمي', 'Digital Stamp');
  String get pdfSealSignature => _t('التوقيع الرقمي', 'Digital Signature');
  String get pdfUploadSeal => _t('رفع صورة', 'Upload Image');
  String get pdfReplaceSeal => _t('استبدال', 'Replace');
  String get pdfRemoveSeal => _t('إزالة', 'Remove');
  String get pdfSealOpacity => _t('درجة الشفافية', 'Opacity');
  String get pdfSealPagePlacement => _t('الظهور في الصفحات', 'Show On');
  String get pdfSealPageLast => _t('الصفحة الأخيرة', 'Last Page');
  String get pdfSealPageFirst => _t('الصفحة الأولى', 'First Page');
  String get pdfSealPageAll => _t('جميع الصفحات', 'All Pages');
  String get pdfSealVisualEditor =>
      _t('محرر الموضع والحجم', 'Position & Size Editor');
  String get pdfSealResetPosition => _t('إعادة ضبط الموضع', 'Reset Position');
  String get pdfSealEditorHint => _t(
    'اسحب للتحريك أو اسحب من الزوايا لتغيير الحجم',
    'Drag to move or drag corners to resize',
  );
  String get pdfSealInvalidFormat => _t(
    'صيغة غير مدعومة. يرجى اختيار صورة PNG أو JPG',
    'Unsupported format. Please select a PNG or JPG image',
  );
  String get pdfSealOversized => _t(
    'حجم الصورة كبير جداً (الحد الأقصى 10 ميغابايت)',
    'The image is too large (maximum 10 MB)',
  );
  String get pdfSealInvalidOrUnsupported => _t(
    'الملف ليس صورة صالحة أو أبعاده غير مدعومة',
    'Invalid or unsupported image file',
  );
  String get pdfSealSaveFailed =>
      _t('تعذر حفظ الختم', 'Could not save the stamp');
  String get pdfSealUploadFailed =>
      _t('تعذر رفع الصورة', 'Could not upload the image');
  String get pdfSealActive => _t('مفعل', 'Enabled');
  String get pdfSealInactive => _t('معطل', 'Disabled');
  String get pdfShowPageNumbers => _t('أرقام الصفحات', 'Page Numbers');
  String get pdfZebraRows =>
      _t('تظليل صفوف الجدول بالتناوب', 'Striped Table Rows');
  String get pdfFooterText => _t('نص التذييل', 'Footer Text');
  String get pdfFooterTextHint =>
      _t('مثال: شكراً لتعاملكم معنا', 'e.g. Thank you for your business');
  String get pdfResetDefaults =>
      _t('استعادة الإعدادات الافتراضية', 'Reset to Defaults');
  String get pdfSampleItem1 => _t('خدمة تصميم', 'Design service');
  String get pdfSampleItem2 => _t('منتج تجريبي', 'Sample product');
  String get pdfSampleCustomer => _t('عميل تجريبي', 'Sample customer');
  String get pdfSampleNotes =>
      _t('هذه معاينة للتصميم فقط.', 'This is a design preview only.');

  // ========== ACCOUNTING ==========
  String get accounting =>
      _t('المحاسبة والقوائم المالية', 'Accounting & Statements');
  String get incomeStatement => _t('قائمة الدخل', 'Income Statement');
  String get balanceSheet => _t('الميزانية العمومية', 'Balance Sheet');
  String get trialBalance => _t('ميزان المراجعة', 'Trial Balance');
  String get chartOfAccounts => _t('دليل الحسابات', 'Chart of Accounts');
  String get accountStatement =>
      _t('كشف حساب (دفتر الأستاذ)', 'Account Ledger');
  String get journalEntry => _t('قيد يومية', 'Journal Entry');
  String get debit => _t('مدين', 'Debit');
  String get credit => _t('دائن', 'Credit');
  String get accountBalance => _t('الرصيد', 'Balance');
  String get accountCode => _t('الرمز', 'Code');
  String get accountColumn => _t('الحساب', 'Account');
  String get openingBalance => _t('الرصيد الافتتاحي', 'Opening Balance');
  String get closingBalance => _t('الرصيد الختامي', 'Closing Balance');
  String get revenueSection => _t('الإيرادات', 'Revenue');
  String get grossProfit => _t('مجمل الربح', 'Gross Profit');
  String get expensesSection => _t('المصروفات', 'Expenses');
  String get netProfit => _t('صافي الربح', 'Net Profit');
  String get netLoss => _t('صافي الخسارة', 'Net Loss');
  String get assetsSection => _t('الأصول', 'Assets');
  String get liabilitiesSection => _t('الالتزامات', 'Liabilities');
  String get equitySection => _t('حقوق الملكية', 'Equity');
  String get retainedEarnings => _t('الأرباح المحتجزة', 'Retained Earnings');
  String get totalAssets => _t('إجمالي الأصول', 'Total Assets');
  String get totalLiabilitiesEquity =>
      _t('إجمالي الالتزامات وحقوق الملكية', 'Total Liabilities & Equity');
  String get balancedLabel => _t('متوازن', 'Balanced');
  String get notBalancedLabel => _t('غير متوازن', 'Not Balanced');
  String get noEntriesYet => _t('لا توجد قيود بعد', 'No Entries Yet');
  String asOfDate(String d) => _t('كما في ${_iso(d)}', 'As of $d');
  String get accountingNote => _t(
    'تُنشأ القيود تلقائياً بنظام القيد المزدوج من مستنداتك، ولا تُرحَّل المسودات والمستندات الملغاة. يُقيَّم المخزون بطريقة المتوسط المرجح.',
    'Double-entry records are created automatically from your documents; drafts and cancelled documents are not posted. Stock is valued at weighted-average cost.',
  );
  String get entryInvoicePayment => _t('تحصيل فاتورة', 'Invoice Payment');
  String get entryPurchasePayment =>
      _t('سداد فاتورة شراء', 'Purchase Invoice Payment');
  String get entryCostOfSales => _t('تكلفة البضاعة المباعة', 'Cost of Sales');
  String get entryOpeningStock => _t('مخزون افتتاحي', 'Opening Stock');
  String get entryStockAdjustment => _t('تعديل مخزون', 'Stock Adjustment');

  String accountName(String code) => switch (code) {
    '1110' => _t('الصندوق (النقدية)', 'Cash on Hand'),
    '1120' => _t('البنوك والمحافظ الإلكترونية', 'Bank & E-Wallets'),
    '1130' => _t('العملاء (ذمم مدينة)', 'Accounts Receivable'),
    '1140' => _t('المخزون', 'Inventory'),
    '1150' => _t('ضريبة مستردة (مدخلات)', 'Tax Receivable (Input)'),
    '2110' => _t('الموردون (ذمم دائنة)', 'Accounts Payable'),
    '2120' => _t('ضريبة مستحقة (مخرجات)', 'Tax Payable (Output)'),
    '2130' => _t('دفعات مقدمة من العملاء', 'Customer Deposits'),
    '3100' => _t('رأس المال / أرصدة افتتاحية', 'Opening Balance Equity'),
    '4100' => _t('إيرادات المبيعات', 'Sales Revenue'),
    '4900' => _t('إيرادات أخرى', 'Other Income'),
    '5100' => _t('تكلفة البضاعة المباعة', 'Cost of Goods Sold'),
    '5200' => _t('عجز وتسويات المخزون', 'Inventory Adjustments'),
    '6100' => _t('المصروفات التشغيلية', 'Operating Expenses'),
    _ => code,
  };

  // ========== IN-APP NOTIFICATIONS & OPS ==========
  String get inboxTitle => _t('الإعلانات والتنبيهات', 'Announcements & Alerts');
  String get noNotifications =>
      _t('لا توجد إعلانات حالياً', 'No announcements at this time');
  String get markAllRead => _t('تحديد الكل كمقروء', 'Mark All as Read');
  String get announcementDetails =>
      _t('تفاصيل الإعلان', 'Announcement Details');
  String get openLink => _t('فتح الرابط المرفق', 'Open Link');
  String get unreadBadge => _t('جديد', 'New');
  String get categoryAnnouncement => _t('إعلان عام', 'Announcement');
  String get categoryUpdate => _t('تحديث جديد', 'Update');
  String get categoryCritical => _t('تنبيه مهم', 'Important');
  String get categoryTips => _t('نصائح وإرشادات', 'Tips & Guides');
  String get undo => _t('تراجع', 'Undo');
  String get deleteAll => _t('حذف الكل', 'Delete All');
  String get confirmDeleteAll =>
      _t('تأكيد حذف جميع التنبيهات؟', 'Delete all notifications?');
  String get confirmDeleteAllMessage => _t(
    'ستُحذف جميع التنبيهات والإعلانات القابلة للحذف نهائياً، وتبقى التنبيهات المهمة محفوظة.',
    'All dismissible announcements will be permanently deleted. Critical notices will be preserved.',
  );
  String get notificationDeleted =>
      _t('تم حذف التنبيه', 'Notification deleted');
  String get notificationsDeleted =>
      _t('تم حذف التنبيهات المحددة', 'Selected notifications deleted');
  String get cannotDeleteCritical => _t(
    'لا يمكن حذف التنبيهات المهمة أو الحرجة',
    'Critical notifications cannot be deleted',
  );
  String get selectedCount => _t('محدد', 'selected');

  // ========== CUSTOMER ACCOUNT STATEMENT ==========
  String get customerStatement => _t('كشف حساب عميل', 'Customer Statement');
  String get statementPeriod => _t('فترة الكشف', 'Statement Period');
  String get totalInvoiced => _t('إجمالي الفواتير', 'Total Invoiced');
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
  String get generatedAt => _t('تاريخ ووقت الإصدار', 'Generated At');
  String get page => _t('صفحة', 'Page');
  String get allTime => _t('كل المعاملات', 'All Transactions');
  String get selectCurrency => _t('اختر العملة', 'Select Currency');
  String get shareWhatsApp => _t('مشاركة عبر واتساب', 'Share via WhatsApp');
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
  String get costReconstructed => _t('أُعيد احتسابها', 'Recalculated');
  String get unresolvedCostProducts =>
      _t('منتجات بتكلفة غير محددة', 'Unresolved Cost Products');
  String get averageCost => _t('متوسط التكلفة', 'Average Cost');
  String get cogs => _t('تكلفة البضاعة المباعة', 'Cost of Goods Sold');
  String get profitMargin => _t('هامش الربح', 'Profit Margin');
  String get profit => _t('الربح', 'Profit');
  String get warningSalePriceBelowCost => _t(
    'تحذير: سعر البيع أقل من سعر الشراء (التكلفة)',
    'Warning: Selling price is below purchase cost',
  );
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
    'This purchase invoice cannot be edited because later sales or stock movements have already used this stock',
  );
  String get legacyCostSummaryTitle =>
      _t('ملخص تدقيق التكلفة التاريخية', 'Historical Cost Audit Summary');
  String get valuedStockCount => _t('منتجات مقيَّمة بالتكلفة', 'Valued Products');
  String get unvaluedStockQty =>
      _t('كمية المخزون غير المقيَّم', 'Unvalued Stock Quantity');
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
  String get shortageQuantity => _t('الكمية الناقصة', 'Shortage Quantity');
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
  String get reportGeneratedAt => _t('تاريخ ووقت إصدار التقرير', 'Generated At');
  String get unitsSummary =>
      _t('إجمالي الكميات حسب الوحدة', 'Quantities by Unit');
  String get grossProfitNotice => _t(
    'مجمل الربح = الإيراد الصافي - تكلفة البضاعة المباعة (لا يشمل المصروفات التشغيلية)',
    'Gross Profit = Net Revenue − COGS (excludes operating expenses)',
  );
  String get unknownCostNotice => _t(
    'تنبيه: يحتوي هذا التقرير على مبيعات بتكلفة تاريخية غير محددة',
    'Note: This report includes sales with an unknown historical cost',
  );
  String get mixedCurrenciesNotice => _t(
    'تنبيه: تتضمن البيانات معاملات بعملات مختلفة دون تحويل إلى عملة موحدة',
    'Warning: The data includes multiple currencies that have not been converted to a single currency',
  );
  String get inventoryValuationReport =>
      _t('تقرير تقييم المخزون', 'Inventory Valuation Report');
  String get transactionCount => _t('عدد الفواتير', 'Number of Invoices');
  String get currentInventoryReport =>
      _t('تقرير المخزون الحالي', 'Current Inventory Report');
  String get searchProductsHint =>
      _t('بحث بالاسم أو الباركود…', 'Search by name or barcode…');
  String get activeFilterAll => _t('الكل', 'All');
  String get noReplenishmentNeeded => _t(
    'لا توجد منتجات تحتاج لإعادة طلب حالياً',
    'No products need reordering right now',
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
  String get systemQty => _t('كمية النظام', 'System Quantity');
  String get countedQty => _t('الكمية الفعلية', 'Counted Quantity');
  String get variance => _t('الفارق', 'Variance');
  String get uncounted => _t('غير مجرود', 'Uncounted');
  String get reviewAndFinalize =>
      _t('مراجعة وتأكيد الجرد', 'Review & Finalize');
  String get confirmFinalizeStocktake =>
      _t('تأكيد تسوية المخزون', 'Confirm Stock Reconciliation');
  String get stocktakeDiscrepancyWarning => _t(
    'ستُعدَّل كميات المخزون لتطابق الجرد الفعلي، وستُسجَّل حركات التسوية.',
    'Stock quantities will be updated to match the physical count, and adjustment movements will be recorded.',
  );
  String get interimMovementWarning => _t(
    'تنبيه: حدثت حركات مخزون بعد بدء الجلسة. ستُحسب التسوية على الرصيد الحالي.',
    'Note: Stock movements occurred after the session started. The reconciliation will be calculated against the current stock.',
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
    'Cancel this stocktake session without reconciling?',
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
  String get bothPrices => _t('سعري البيع والشراء', 'Both Selling & Purchase Prices');
  String get roundingRule =>
      _t('تقريب الأسعار المحوّلة', 'Round Converted Prices');
  String get roundNone => _t('بدون تقريب', 'No Rounding');
  String get roundNearestWhole => _t('لأقرب عدد صحيح', 'Nearest Whole');
  String get roundNearestTen => _t('لأقرب عشرة', 'Nearest Ten');
  String get roundUp => _t('تقريب للأعلى', 'Round Up');
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
  String get downloadTemplate => _t('تنزيل نموذج CSV', 'Download CSV Template');
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
    'Note: Stock quantities are not changed through CSV files, to keep the stock movement history accurate.',
  );

  String get advancedInventoryAnalytics =>
      _t('تحليلات المخزون المتقدمة', 'Advanced Inventory Analytics');
  String get inventoryTurnover =>
      _t('معدل دوران المخزون', 'Inventory Turnover');
  String get salesVelocity =>
      _t('سرعة المبيعات (وحدة/يوم)', 'Sales Velocity (units/day)');
  String get estimatedDaysRemaining =>
      _t('الأيام المتبقية التقريبية', 'Estimated Days Remaining');
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
  String get savePurchase => _t('حفظ فاتورة الشراء', 'Save Purchase Invoice');
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
      _t('تأكيد تعديل المخزون', 'Confirm Stock Adjustment');
  String get enterAdjustmentDelta => _t(
    'أدخل كمية التعديل (لا تساوي صفراً)',
    'Enter an adjustment quantity other than zero',
  );
  String get openingStockHelp => _t(
    'الكمية الابتدائية المتوفرة في المخزون لبدء متابعة حركة المنتج بدقة.',
    'The quantity currently on hand, used as the starting point for tracking this product\'s stock.',
  );
  String get purchasePriceCostHelp => _t(
    'سعر التكلفة للوحدة، يُعتمد في تقييم المخزون واحتساب أرباح المبيعات بدقة.',
    'Unit purchase cost used for stock valuation and profit calculations.',
  );
  String get pleaseAddItems => _t(
    'أضف بنداً واحداً على الأقل',
    'Add at least one item to the document',
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
      _t('المخزون وحركته', 'Inventory & Stock Movements');
  String get reportCatAudit =>
      _t('سجلات التدقيق والمراجعة', 'Audit & Activity Logs');
  String get reportSubtitleSales => _t(
    'ملخص الفواتير، تكلفة البضاعة المباعة ومجمل الربح',
    'Invoices, COGS and gross profit summary',
  );
  String get reportSubtitlePurchases => _t(
    'فواتير الشراء المسجلة ومستحقات الموردين',
    'Purchase invoices and supplier payables',
  );
  String get reportSubtitlePayments => _t(
    'حركة المقبوضات والمدفوعات النقدية والبنكية',
    'Incoming and outgoing cash and bank payments',
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
    'Product performance by sales, quantity, and profit',
  );
  String get reportSubtitleAdvancedAnalytics => _t(
    'معدل دوران المخزون، المنتجات الراكدة وهامش الربح',
    'Inventory turnover, slow stock & margin alerts',
  );
  String get reportSubtitleAudit => _t(
    'سجل الأنشطة والتعديلات وتسويات المخزون',
    'Activity log, price changes & adjustments',
  );

  // ========== ACTIVATION SUPPORT & GUIDANCE ==========
  String get activationTroubleTitle =>
      _t('واجهت مشكلة في التفعيل؟', 'Having trouble with activation?');
  String get activationTroubleBody => _t(
    'يمكنك التواصل مع الدعم عبر واتساب أو البريد الإلكتروني للمساعدة في حل المشكلة.',
    'Contact support via WhatsApp or email and we\'ll help you resolve the problem.',
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
    'Help with Waraqatak License Activation',
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
    'Tip: Wait a few minutes before trying again to avoid a temporary lockout.',
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
    'Records, balances, and inventory were checked, and no issues or discrepancies were found.',
  );
  String get diagnosticsTotalChecks =>
      _t('إجمالي الفحوصات المنفذة', 'Total Checks Run');
  String get diagnosticsLastScan => _t('وقت الفحص', 'Scan Time');
  String get diagnosticsCategoryAll => _t('الكل', 'All');
  String get diagnosticsCategoryOrphaned =>
      _t('سجلات غير مرتبطة', 'Orphaned Records');
  String get diagnosticsCategoryBalances =>
      _t('تطابق أرصدة المستندات', 'Document Balances');
  String get diagnosticsCategoryStatuses =>
      _t('حالات المستندات', 'Document Statuses');
  String get diagnosticsCategoryPayments =>
      _t('اختلاف بين المبلغ المسدد وسجل المدفوعات', 'Payment Discrepancies');
  String get diagnosticsCategoryStock =>
      _t('اختلاف بين رصيد المخزون وسجل الحركات', 'Stock vs. Movement Discrepancy');
  String get diagnosticsCategoryMissingOpeningStock =>
      _t('مخزون افتتاحي مفقود', 'Missing Opening Stock');
  String get diagnosticsCategoryNegativeStock =>
      _t('رصيد مخزون سالب', 'Negative Physical Stock');
  String get diagnosticsCategoryCosting =>
      _t('تكلفة المخزون', 'Inventory Costing');
  String get diagnosticsCategoryDuplicates =>
      _t('أرقام مستندات مكررة', 'Duplicate Document Numbers');
  String get diagnosticsAffectedIds => _t('المعرّفات المتأثرة', 'Affected IDs');
  String get diagnosticsMoreIds => _t('إضافية', 'more');
  String get diagnosticsManualReviewRequired =>
      _t('تتطلب مراجعة يدوية', 'Requires Manual Review');
  String get diagnosticsDisclaimer => _t(
    'هذا التقرير للمعاينة فقط (قراءة فقط). لا يتم إجراء أي تعديل أو حذف تلقائي للبيانات حفاظاً على السجلات المالية.',
    'This report is read-only. No data is modified or deleted automatically, in order to preserve your financial records.',
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
    'هذا السجل غير مرتبط بأي مستند رئيسي نشط.',
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
        'document_payments' => 'payment records',
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
    'نسخ البيانات واستعادتها بأمان عبر مجلد التطبيق الخاص',
    'Back up and restore securely using the app\'s private folder',
  );
  String get googleDriveConnect =>
      _t('ربط حساب Google', 'Connect Google Account');
  String get googleDriveDisconnect =>
      _t('فصل الحساب', 'Disconnect Account');
  String get googleDriveUploadNow =>
      _t('رفع نسخة احتياطية الآن', 'Upload Backup Now');
  String get googleDriveRestoreFromCloud =>
      _t('استعادة من Google Drive', 'Restore from Google Drive');
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
      _t('اختر نسخة احتياطية للاستعادة', 'Select a backup to restore');
  String get googleDriveConfirmRestoreTitle =>
      _t('تأكيد استعادة النسخة السحابية', 'Confirm Cloud Restore');
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
    'Could not connect to Google Drive. Check your internet connection and try again.',
  );
  String get googleDriveErrorAuthExpired => _t(
    'انتهت جلسة تسجيل الدخول. أعد ربط حساب Google.',
    'Session expired. Please reconnect your Google account.',
  );
  String get googleDriveErrorRestoreCorrupt => _t(
    'فشلت الاستعادة: ملف النسخة الاحتياطية غير صالح أو تالف.',
    'Restore failed: Backup file is invalid or corrupted.',
  );
  String get googleDriveSignInCancelled => _t(
    'تم إلغاء تسجيل الدخول أو لم يتم إكمال التحقق.',
    'Sign-in was cancelled or verification was not completed.',
  );
  String get googleDriveErrorConfig => _t(
    'تعذّر ربط حساب Google على هذا الجهاز. يُرجى التحقق من إعدادات Google Cloud وشهادة التطبيق، ثم المحاولة مجدداً.',
    'Could not link your Google account on this device. Verify the Google Cloud settings and the app certificate, then try again.',
  );
  String get googleDriveDeleteBackup => _t('حذف النسخة', 'Delete Backup');
  String get googleDriveConfirmDeleteTitle =>
      _t('تأكيد حذف النسخة السحابية', 'Confirm Cloud Backup Deletion');
  String get googleDriveConfirmDeleteBody => _t(
    'ستُحذف هذه النسخة من Google Drive نهائياً ولا يمكن استرجاعها.',
    'This backup will be permanently deleted from Google Drive and cannot be recovered.',
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
  String get googleDriveRetentionNote => _t(
    'يحتفظ التطبيق بأحدث 7 نسخ سحابية تلقائياً، وتُحذف النسخ الأقدم لتوفير المساحة.',
    'The app automatically keeps the latest 7 cloud backups; older backups are pruned.',
  );
  String get googleDriveMobileDataWarning => _t(
    'قد يستهلك رفع أو تنزيل النسخ الاحتياطية بيانات الهاتف المحمول.',
    'Uploading or downloading backups may consume mobile data.',
  );
  String get googleDriveEncryptedBadge => _t('مشفرة', 'Encrypted');
  String get googleDriveUnencryptedBadge => _t('غير مشفرة', 'Unencrypted');

  // ========== ADVANCED REPAIR SYSTEM ==========
  String get repairSystemTitle =>
      _t('نظام الإصلاح المتقدم', 'Advanced Repair System');
  String get repairSystemSubtitle => _t(
    'فحص وإصلاح مشكلات الحسابات وترابط السجلات بأمان داخل معاملات موثّقة',
    'Inspect and safely repair accounting and record-linking issues using verified transactions',
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
    'سيتم تنفيذ جميع الإصلاحات الآمنة والمحدَّدة داخل معاملة واحدة في قاعدة البيانات، مع إنشاء نسخة أمان محلية تلقائياً قبل البدء. لن تُعدَّل السجلات المالية التي تتطلب قراراً يدوياً.',
    'All safe, deterministic repairs will run in a single database transaction, after an automatic local safety backup is created. Financial records that require a manual decision will not be modified.',
  );
  String get repairSuccess => _t(
    'تم تنفيذ الإصلاح بنجاح والتحقق من سلامة البيانات',
    'Repair completed and data integrity verified',
  );
  String get repairPartial => _t(
    'اكتملت بعض الإصلاحات، يرجى مراجعة المشكلات المتبقية',
    'Some repairs were completed. Please review the remaining issues.',
  );
  String get repairFailed => _t(
    'فشل الإصلاح وتم التراجع عن المعاملة بالكامل للحفاظ على البيانات',
    'Repair failed, and the transaction was fully rolled back to protect your data',
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
    'This record already exists. Make sure you are not entering it twice.',
  );
  String get errorForeignKeyConstraint => _t(
    'لا يمكن إتمام العملية لأن هذا العنصر مرتبط بمستندات أو سجلات أخرى.',
    'This operation cannot be completed because the item is linked to existing documents or records.',
  );
  String get errorInsufficientStockGeneral => _t(
    'الكمية المتوفرة في المخزون غير كافية لإتمام العملية',
    'Insufficient stock to complete this transaction',
  );
  String get errorNetworkConnectivity => _t(
    'تعذّر الاتصال بالإنترنت. تأكد من الشبكة ثم حاول مجدداً.',
    'Could not connect to the network. Check your internet connection and try again.',
  );
  String get errorOperationTimeout => _t(
    'استغرقت العملية وقتاً أطول من المتوقع. حاول مرة أخرى.',
    'The operation timed out. Please try again',
  );
  String get errorInvalidNumberFormat => _t(
    'تأكد من كتابة الأرقام والمبالغ بشكل صحيح.',
    'Please enter valid numbers and amounts.',
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
    'يجب ألا يسبق تاريخ انتهاء العرض تاريخ الإصدار',
    'Valid-until date must be on or after issue date',
  );
  String get errorValidityMinDays => _t(
    'مدة صلاحية العرض يجب أن تكون يوماً واحداً على الأقل',
    'Quotation validity period must be at least 1 day',
  );

  String get pdfTaxIdLabel => _t('الرقم الضريبي:', 'Tax ID:');
  String get pdfTaxRegLabel => _t('رقم التسجيل الضريبي:', 'Tax Reg. No.:');
  String get pdfCommercialRegLabel => _t('السجل التجاري:', 'Commercial Reg. No.:');
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
      _t('دفتر اليومية المحفوظ (مفعّل)', 'Persisted Journal (Active)');
  String get triggerJournalBackfill =>
      _t('إعادة إنشاء دفتر اليومية', 'Rebuild Journal (Backfill)');
  String get journalBackfillSuccess => _t(
    'تمت إعادة إنشاء القيود بنجاح ومطابقة الأرصدة',
    'Journal entries rebuilt successfully with verified parity',
  );
  String get switchJournalReportsTitle =>
      _t('تبديل مصدر التقارير المالية', 'Switch Financial Reports Source');
  String get switchJournalReportsConfirm => _t(
    'هل تريد تغيير مصدر التقارير المالية؟ سيتم احتساب القوائم مباشرة من دفتر اليومية المحفوظ بدلاً من إنشائها لحظياً.',
    'Do you want to switch the financial reports source? Statements will be generated directly from the persisted double-entry journal.',
  );

  // ========== STOCK ADJUSTMENT REASONS & PERIOD LOCK ==========
  String get adjustmentReasonCountGain =>
      _t('تسوية جرد (زيادة مخزون)', 'Stock Count (Gain)');
  String get adjustmentReasonCountLoss =>
      _t('تسوية جرد (عجز مخزون)', 'Stock Count (Loss)');
  String get adjustmentReasonDamageLoss => _t('بضاعة تالفة', 'Damaged Goods');
  String get adjustmentReasonExpiryLoss =>
      _t('بضاعة منتهية الصلاحية', 'Expired Stock');
  String get adjustmentReasonOpeningStock =>
      _t('مخزون افتتاحي', 'Opening Stock');
  String get adjustmentReasonCorrection =>
      _t('تصحيح خطأ سابق', 'Correction of Previous Error');
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
      _t('الفترة مفتوحة بالكامل (لا يوجد إقفال)', 'All periods open (no lock)');
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
    'Remove the period lock? Transactions in earlier periods will become editable again.',
  );
  String get errorPeriodClosed => _t(
    'الفترة المحاسبية مقفلة حتى هذا التاريخ. لا يمكن إضافة أو تعديل أو إلغاء المعاملات.',
    'Accounting period is closed through this date. Transactions cannot be posted, revised, or cancelled.',
  );

  // ========== REFERENCE PRICING ==========
  String get exchangeRates => _t('أسعار الصرف', 'Exchange Rates');
  String get exchangeRatesDesc => _t(
    'سعّر منتجاتك بعملة أخرى وحدّث سعر الصرف يدوياً',
    'Price products in another currency and update the rate manually',
  );
  String get pricingCurrency => _t('عملة التسعير', 'Pricing Currency');
  String get exchangeRate => _t('سعر الصرف', 'Exchange Rate');
  String get addCurrency => _t('إضافة عملة', 'Add Currency');
  String get customCurrency => _t('عملة مخصصة', 'Custom Currency');
  String get currencyCode => _t('رمز العملة', 'Currency Code');
  String get currencySymbol => _t('الرمز المختصر', 'Symbol');
  String get roundingNone => _t('بدون تقريب', 'No Rounding');
  String get roundingChangedRecalculatePrompt => _t(
    'تغيّرت قاعدة التقريب. هل تريد إعادة حساب الأسعار الآن؟',
    'Rounding changed. Recalculate prices now?',
  );
  String get rateMissingForCurrency => _t(
    'لا يوجد سعر صرف لهذه العملة. أضف سعر الصرف أولاً.',
    'No exchange rate for this currency. Add the rate first.',
  );
  String get repriceConfirmTitle => _t('تحديث الأسعار', 'Update Prices');
  String repriceConfirmBody(Object products, Object units) => _t(
    'سيتم تحديث أسعار ${_iso(products)} منتج و${_iso(units)} وحدة.',
    'Prices of $products products and $units units will be updated.',
  );
  String repriceDone(Object products, Object units) => _t(
    'تم تحديث ${_iso(products)} منتج و${_iso(units)} وحدة.',
    'Updated $products products and $units units.',
  );
  String get recalculateAll =>
      _t('إعادة حساب كل الأسعار', 'Recalculate All Prices');
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
  String get chooseCurrency => _t('اختر العملة', 'Choose Currency');
  String get currencyCodeField =>
      _t('رمز العملة (مثال: EUR)', 'Currency code (e.g. EUR)');
  String get currencyNameArField =>
      _t('اسم العملة بالعربية', 'Currency Name in Arabic');
  String get currencyNameEnField => _t(
    'اسم العملة بالإنجليزية (اختياري)',
    'Currency name in English (optional)',
  );
  String get currencySymbolField =>
      _t('رمز العرض (اختياري، مثل: €)', 'Display symbol (optional, e.g. €)');

  String get currencyCodeHelper =>
      _t('مثال: USD, EUR (2-5 أحرف)', 'e.g. USD, EUR (2-5 letters)');

  String get currencyCodeInvalid => _t(
    'رمز العملة يجب أن يتكون من 2 إلى 5 أحرف إنجليزية',
    'Currency code must be 2-5 English letters',
  );

  String get currencyFieldsRequired => _t(
    'يرجى ملء جميع حقول العملة المطلوبة',
    'Please fill all required currency fields',
  );

  String get selectCurrencyFirst => _t(
    'يرجى اختيار العملة أولاً',
    'Please select a currency first',
  );
  String get currencyRateField => _t('سعر الصرف', 'Exchange Rate');
  String get currencyRateHelper => _t(
    'كم وحدة من عملتك الأساسية تساوي 1 من هذه العملة',
    'How many units of your base currency equal 1 of this currency',
  );
  String get updateExchangeRate =>
      _t('تحديث سعر الصرف', 'Update Exchange Rate');
  String get recalculatePrices =>
      _t('إعادة تسعير المنتجات الآن', 'Recalculate Product Prices Now');
  String get recalculateAllConfirm => _t(
    'سيُعاد حساب أسعار الأساس لكل المنتجات المرتبطة بعملات صرف بسعر الصرف الحالي لكل عملة. متابعة؟',
    'Base prices of all products linked to an exchange rate will be recalculated. Continue?',
  );
  String get repricePreviewTitle =>
      _t('معاينة إعادة التسعير', 'Reprice Preview');
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
    'The exchange rate must be greater than zero, with up to 6 decimal places.',
  );
  String get refErrInvalidPrice => _t(
    'السعر المرجعي يجب أن يكون رقماً موجباً وبما لا يتجاوز 4 خانات عشرية.',
    'The reference price must be positive, with up to 4 decimal places.',
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
    'A repricing operation is already in progress. Please wait.',
  );
  String get refErrCurrencyExists =>
      _t('رمز العملة مسجل مسبقاً.', 'This currency code already exists.');
  String get refErrCurrencyIsBase => _t(
    'لا يمكن إضافة العملة الأساسية كعملة صرف.',
    'The base currency cannot be added as an exchange-rate currency.',
  );
  String get refErrCurrencyArchived => _t(
    'العملة المختارة مؤرشفة حالياً. تمت استعادة الاختيار السابق.',
    'The selected currency is archived. Your previous selection was restored.',
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
    'احفظ هذا الرمز في مكان آمن خارج هذا الجهاز. هو الرمز الوحيد الذي يمكنك استخدامه لإعادة تعيين كلمة مرور المالك في حال نسيانها.',
    'Save this code in a safe place outside this device. It is the only way to recover Owner access if you forget the password.',
  );
  String get recoveryCodeSavedConfirm => _t(
    'حفظتُ رمز الاسترداد في مكان آمن',
    'I have saved the recovery code in a safe place',
  );
  String get enableMultiUserButton =>
      _t('تفعيل تعدد المستخدمين', 'Enable Multi-User');
  String get disableMultiUserButton =>
      _t('تعطيل تعدد المستخدمين', 'Disable Multi-User');
  String get disableMultiUserConfirm => _t(
    'هل تريد تعطيل تعدد المستخدمين؟ سيعود النظام لوضع المستخدم الفردي المباشر.',
    'Disable multi-user mode? The app will return to direct single-user mode.',
  );
  String get enterPin => _t('أدخل رمز PIN', 'Enter PIN');
  String get unlock => _t('فتح القفل', 'Unlock');
  String get invalidPin => _t('رمز PIN غير صحيح', 'Incorrect PIN');
  String get switchUser => _t('تبديل المستخدم', 'Switch User');
  String get loginWithPassword =>
      _t('تسجيل الدخول بكلمة المرور', 'Log In with Password');
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
    'دور مدمج في النظام (للقراءة فقط)',
    'Built-in system role (read-only)',
  );
  String get customRole => _t('دور مخصص', 'Custom Role');
  String get permissionOverrides =>
      _t('استثناءات الصلاحيات للمستخدم', 'User Permission Overrides');
  String get auditTrail => _t('سجل التدقيق والأنشطة', 'Audit Trail');
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
      : _plural(
          m,
          zero: _t('معطل', 'Disabled'),
          one: _t('دقيقة واحدة', '1 minute'),
          two: _t('دقيقتان', '2 minutes'),
          few: _t('${_iso(m)} دقائق', '$m minutes'),
          many: _t('${_iso(m)} دقيقة', '$m minutes'),
          other: _t('${_iso(m)} دقيقة', '$m minutes'),
          enOne: '1 minute',
          enOther: '$m minutes',
        );
  String get currentActiveUser => _t('المستخدم الحالي', 'Current User');
  String get lockNow => _t('قفل التطبيق الآن', 'Lock App Now');
  String get logout => _t('تسجيل الخروج', 'Log Out');
  String get logoutConfirmTitle => _t('تسجيل الخروج', 'Log Out');
  String get logoutConfirmMessage => _t(
    'هل تريد تسجيل الخروج؟ ستُقفل الجلسة وتُفقد أي تعديلات غير محفوظة في النماذج المفتوحة، ثم تعود إلى شاشة الدخول.',
    'Log out? Any unsaved changes in open forms will be lost, and you will return to the lock screen.',
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
    'يجب ألا تقل كلمة المرور عن 6 أحرف',
    'Password must be at least 6 characters',
  );

  // ========== ANALYTICS & TELEMETRY ==========
  String get diagnosticsConsentTitle =>
      _t('المساهمة في تحسين التطبيق', 'Help Improve the App');
  String get diagnosticsConsentDesc => _t(
    'إرسال بيانات استخدام وتقارير أعطال مجهولة، بدون مبالغ أو أسماء أو فواتير.',
    'Share anonymous usage data and crash reports. Never includes amounts, names, or invoices.',
  );
  String get consentDialogTitle =>
      _t('ساعدنا في تحسين ورقتك', 'Help us improve');
  String get consentDialogBody => _t(
    'نجمع بيانات تشغيلية مجهولة وتقارير الأعطال لتحسين الأداء وإصلاح الأخطاء بسرعة. لا نجمع أي مبالغ أو أسماء عملاء أو فواتير أو بيانات شخصية. يمكنك تغيير اختيارك في أي وقت من الإعدادات.',
    'We collect anonymous usage data and crash reports to improve performance and fix bugs faster. We never collect amounts, customer names, invoices, or personal data. You can change this anytime in Settings.',
  );
  String get consentDialogAgree => _t('موافق', 'Agree');
  String get consentDialogNotNow => _t('ليس الآن', 'Not now');
  String get digitalSealsProUpgradeMessage => _t(
    'الأختام والتوقيعات الرقمية ميزة حصرية في النسخة الاحترافية (Pro).',
    'Digital stamps and signatures are exclusive to the Pro version.',
  );
  String get anonymousAnalyticsTitle =>
      _t('إحصائيات الاستخدام المجهولة', 'Anonymous Usage Statistics');
  String get anonymousAnalyticsSubtitle => _t(
    'بيانات مجهولة لتحسين الأداء بدون مبالغ أو أسماء',
    'Anonymous metrics to improve performance, with no amounts or names',
  );
  String get anonymousAnalyticsExplainer => _t(
    'يجمع التطبيق إحصائيات مجهولة حول الميزات المستخدمة (مثل إنشاء الفواتير والنسخ الاحتياطي) لتحسين الاستقرار. لا يتم إرسال أي مبالغ، أسعار، تكاليف، أرقام هواتف، أسماء عملاء أو موردين، أو معلومات شخصية إطلاقاً. يمكنك إيقاف هذا الخيار في أي وقت من الإعدادات.',
    'The app collects anonymous statistics on feature usage (such as document creation and backup) to improve reliability. No amounts, prices, costs, phone numbers, contact names, or personal data are ever collected. You can disable this anytime in Settings.',
  );

  // ========== PERMISSION GROUPS ==========
  String get permGroup_sales_label => _t('المبيعات', 'Sales');
  String get permGroup_purchases_label => _t('المشتريات', 'Purchases');
  String get permGroup_payments_label =>
      _t('المدفوعات والسندات', 'Payments & Vouchers');
  String get permGroup_stock_label => _t('المخزون والجرد', 'Stock & Inventory');
  String get permGroup_products_label =>
      _t('المنتجات والتسعير', 'Products & Pricing');
  String get permGroup_contacts_label =>
      _t('العملاء والموردين', 'Customers & Suppliers');
  String get permGroup_dashboard_label => _t('لوحة المعلومات', 'Dashboard');
  String get permGroup_reports_label => _t('التقارير والمؤشرات', 'Reports');
  String get permGroup_data_label =>
      _t('الاستيراد والتصدير', 'Data Import & Export');
  String get permGroup_system_label =>
      _t('إدارة النظام والنسخ', 'System & Backup');
  String get permGroup_settings_label =>
      _t('إعدادات النشاط والضرائب', 'Settings');
  String get permGroup_access_label =>
      _t('المستخدمون والصلاحيات', 'Users & Roles');

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

  String get perm_sales_view_name =>
      _t('عرض المبيعات والفواتير', 'View Sales and Invoices');
  String get perm_sales_view_desc => _t(
    'عرض قائمة فواتير المبيعات وتفاصيلها',
    'View list of sales invoices and details',
  );
  String get perm_sales_create_name =>
      _t('إنشاء فواتير المبيعات', 'Create Sales Invoices');
  String get perm_sales_create_desc => _t(
    'إصدار فواتير بيع جديدة وعروض أسعار',
    'Issue new sales invoices and quotations',
  );
  String get perm_sales_edit_name =>
      _t('تعديل فواتير المبيعات', 'Edit Sales Invoices');
  String get perm_sales_edit_desc =>
      _t('تعديل فواتير المبيعات القائمة', 'Edit existing sales invoices');
  String get perm_sales_edit_price_name =>
      _t('تعديل سعر البيع يدوياً', 'Manual Price Override');
  String get perm_sales_edit_price_desc => _t(
    'تغيير سعر بيع الصنف أثناء إنشاء الفاتورة',
    'Change item unit price on the invoice',
  );
  String get perm_sales_edit_discount_name =>
      _t('إضافة وتعديل الخصومات', 'Apply and Edit Discounts');
  String get perm_sales_edit_discount_desc => _t(
    'تطبيق تخفيض على الفاتورة أو البنود',
    'Apply discounts to documents or line items',
  );
  String get perm_sales_cancel_name =>
      _t('إلغاء فواتير المبيعات', 'Cancel Sales Invoices');
  String get perm_sales_cancel_desc => _t(
    'إلغاء فواتير البيع واسترجاع كميات المخزون',
    'Cancel invoices and restore inventory stock',
  );
  String get perm_sales_delete_name =>
      _t('حذف مسودات المبيعات', 'Delete Draft Invoices');
  String get perm_sales_delete_desc => _t(
    'حذف فواتير المبيعات غير الصادرة نهائياً',
    'Permanently delete draft sales documents',
  );
  String get perm_sales_refund_name =>
      _t('إدارة رد المبالغ', 'Manage Document Refunds');
  String get perm_sales_refund_desc => _t(
    'تحديث حالة رد المبالغ للفواتير الملغاة',
    'Update refund status on cancelled invoices',
  );
  String get perm_purchases_view_name =>
      _t('عرض فواتير الشراء', 'View Purchase Invoices');
  String get perm_purchases_view_desc => _t(
    'عرض مشتريات البضائع وفواتير الموردين',
    'View purchase invoices from suppliers',
  );
  String get perm_purchases_create_name =>
      _t('إنشاء فواتير الشراء', 'Create Purchase Invoices');
  String get perm_purchases_create_desc => _t(
    'تسجيل شراء بضاعة وتحديث تكلفة المخزون',
    'Record incoming stock and update cost',
  );
  String get perm_purchases_edit_name =>
      _t('تعديل فواتير الشراء', 'Edit Purchase Invoices');
  String get perm_purchases_edit_desc => _t(
    'تعديل بنود وأسعار فواتير الشراء القائمة',
    'Edit items and costs on purchase invoices',
  );
  String get perm_purchases_cancel_name =>
      _t('إلغاء فواتير الشراء', 'Cancel Purchase Invoices');
  String get perm_purchases_cancel_desc => _t(
    'إلغاء فاتورة شراء واسترجاع كميات المخزون',
    'Cancel purchase invoice and reverse stock',
  );
  String get perm_purchases_delete_name =>
      _t('حذف مسودات الشراء', 'Delete Draft Purchases');
  String get perm_purchases_delete_desc =>
      _t('حذف فواتير الشراء غير الصادرة', 'Delete unissued purchase drafts');
  String get perm_payments_record_name =>
      _t('تسجيل الدفعات والتحصيل', 'Record Payments and Collections');
  String get perm_payments_record_desc => _t(
    'تسجيل دفعات نقدية أو بنكية على الفواتير',
    'Record cash or bank payments on invoices',
  );
  String get perm_vouchers_create_name => _t(
    'إنشاء سندات القبض والصرف',
    'Create Payment Receipts and Expense Vouchers',
  );
  String get perm_vouchers_create_desc => _t(
    'إصدار سندات مالية مستقلة للمصروفات والقبض',
    'Issue financial receipt and payment vouchers',
  );
  String get perm_expenses_view_name =>
      _t('عرض سندات المصروفات', 'View Expense Vouchers');
  String get perm_expenses_view_desc => _t(
    'الاطلاع على سجل المصروفات وسندات الصرف',
    'View operating expenses and expense vouchers',
  );
  String get perm_stock_adjust_name =>
      _t('تعديل المخزون يدوياً', 'Manual Stock Adjustment');
  String get perm_stock_adjust_desc => _t(
    'تعديل كميات المخزون بالزيادة أو النقص يدوياً',
    'Manually add or reduce product stock levels',
  );
  String get perm_stock_view_cost_name =>
      _t('الاطلاع على تكلفة المخزون', 'View Stock Movement Costs');
  String get perm_stock_view_cost_desc => _t(
    'عرض أسعار وتكلفة حركات المخزون الداخلة والخارجة',
    'View unit and total cost of stock movements',
  );
  String get perm_stocktake_manage_name =>
      _t('بدء وإدارة جلسات الجرد', 'Start and Manage Stocktake');
  String get perm_stocktake_manage_desc => _t(
    'فتح جلسات الجرد الدوري وتسجيل الكميات المعدودة',
    'Open stocktake sessions and enter counted stock',
  );
  String get perm_stocktake_finalize_name =>
      _t('اعتماد تسويات الجرد', 'Finalize Stocktake Reconciliation');
  String get perm_stocktake_finalize_desc => _t(
    'ترحيل فروقات الجرد وتحديث المخزون محاسبياً',
    'Post stocktake variances to inventory ledger',
  );
  String get perm_products_view_name =>
      _t('عرض قائمة المنتجات', 'View Products Catalog');
  String get perm_products_view_desc => _t(
    'تصفح قائمة الأصناف والباركود وسعر البيع',
    'Browse product catalog, barcodes, and sale prices',
  );
  String get perm_products_manage_name =>
      _t('إضافة وتعديل المنتجات والوحدات', 'Create and Edit Products & Units');
  String get perm_products_manage_desc => _t(
    'إنشاء أصناف جديدة وتعديل الأسعار والوحدات',
    'Add products and manage pricing and units',
  );
  String get perm_products_delete_name => _t('حذف المنتجات', 'Delete Products');
  String get perm_products_delete_desc => _t(
    'حذف أو تعطيل الأصناف غير المستخدمة',
    'Delete or deactivate unused products',
  );
  String get perm_products_view_cost_name => _t(
    'الاطلاع على سعر الشراء وتكلفة المنتج',
    'View Purchase Price and Average Cost',
  );
  String get perm_products_view_cost_desc => _t(
    'إظهار سعر التكلفة وسعر الشراء في شاشات الأصناف',
    'Show purchase price and average cost on product views',
  );
  String get perm_products_view_wholesale_name =>
      _t('الاطلاع على أسعار الجملة', 'View Wholesale Prices');
  String get perm_products_view_wholesale_desc => _t(
    'عرض سعر الجملة والحد الأدنى لكمية الجملة',
    'View wholesale tier prices and minimum quantities',
  );
  String get perm_pricing_manage_name =>
      _t('إدارة التسعير الجماعي', 'Bulk Pricing Management');
  String get perm_pricing_manage_desc => _t(
    'تطبيق زيادات أو تخفيضات جماعية على أسعار الأصناف',
    'Apply bulk price adjustments across catalog',
  );
  String get perm_pricing_rates_name => _t(
    'إدارة العملات وأسعار الصرف المرجعية',
    'Manage Exchange Rates & Reference Currency',
  );
  String get perm_pricing_rates_desc => _t(
    'تعديل أسعار صرف العملات المرجعية في النظام',
    'Update reference currency exchange rates',
  );
  String get perm_contacts_view_name =>
      _t('عرض العملاء والموردين', 'View Contacts List');
  String get perm_contacts_view_desc => _t(
    'تصفح سجل العملاء والموردين وأرقام هواتفهم',
    'Browse customers and suppliers list and contact info',
  );
  String get perm_contacts_manage_name =>
      _t('إضافة وتعديل العملاء والموردين', 'Create and Edit Contacts');
  String get perm_contacts_manage_desc => _t(
    'تسجيل عميل أو مورد جديد وتعديل بيانات الاتصال',
    'Add customer/supplier and update details',
  );
  String get perm_contacts_delete_name =>
      _t('حذف العملاء والموردين', 'Delete Contacts');
  String get perm_contacts_delete_desc => _t(
    'حذف جهات الاتصال غير المرتبطة بمعاملات',
    'Delete contacts not referenced in documents',
  );
  String get perm_contacts_view_balances_name => _t(
    'الاطلاع على مديونيات وحسابات العملاء والموردين',
    'View Balances, Debts, and Account Statements',
  );
  String get perm_contacts_view_balances_desc => _t(
    'عرض إجمالي ديون العملاء ومستحقات الموردين وكشف الحساب',
    'View receivables, payables, and account statements',
  );
  String get perm_dashboard_view_totals_name => _t(
    'عرض إجماليات المبيعات والأرباح بالرئيسية',
    'View Dashboard Totals and Revenue Metrics',
  );
  String get perm_dashboard_view_totals_desc => _t(
    'إظهار بطاقات إجمالي مبيعات اليوم والديون بالرئيسية',
    'Show sales revenue cards and summary metrics on home',
  );
  String get perm_reports_view_sales_name =>
      _t('تقرير المبيعات وحركة الفواتير', 'Sales Report');
  String get perm_reports_view_sales_desc => _t(
    'عرض تقرير المبيعات التفصيلي مع المجموع',
    'View detailed sales and invoice reports',
  );
  String get perm_reports_view_purchases_name =>
      _t('تقرير المشتريات والمصروفات', 'Purchases Report');
  String get perm_reports_view_purchases_desc => _t(
    'عرض إجماليات المشتريات ومصروفات العمليات',
    'View purchases spending and supplier invoices',
  );
  String get perm_reports_view_receivables_name =>
      _t('تقرير الديون والمستحقات', 'Receivables and Payables Report');
  String get perm_reports_view_receivables_desc => _t(
    'تقرير أرصدة ومطالبات العملاء والموردين',
    'View aging debts and supplier balances',
  );
  String get perm_reports_view_inventory_cost_name => _t(
    'تقرير تقييم المخزون وأرباح الأصناف',
    'Inventory Valuation and Profit Reports',
  );
  String get perm_reports_view_inventory_cost_desc => _t(
    'عرض قيمة المخزون بسعر الشراء وصافي أرباح المنتجات',
    'View inventory cost valuation and product gross profits',
  );
  String get perm_reports_view_financials_name => _t(
    'التقارير المالية (قائمة الدخل والميزانية)',
    'Financial Statements (Income Statement & Balance Sheet)',
  );
  String get perm_reports_view_financials_desc => _t(
    'الاطلاع على قائمة الدخل، الميزانية العمومية، وميزان المراجعة',
    'View Income Statement, Balance Sheet, and Trial Balance',
  );
  String get perm_reports_export_pdf_name =>
      _t('تصدير وطباعة تقارير PDF', 'Export and Print PDF Reports');
  String get perm_reports_export_pdf_desc => _t(
    'طباعة أو مشاركة تقارير الأعمال كملفات PDF',
    'Print or share business reports as PDF documents',
  );
  String get perm_data_export_csv_name =>
      _t('تصدير البيانات إلى ملفات CSV', 'Export Data to CSV / Excel');
  String get perm_data_export_csv_desc => _t(
    'تصدير قائمة الأصناف والبيانات إلى ملفات خارجية',
    'Export catalog and records to external spreadsheets',
  );
  String get perm_data_import_csv_name =>
      _t('استيراد البيانات من ملفات CSV', 'Import Data from CSV');
  String get perm_data_import_csv_desc => _t(
    'إدخال أصناف وقوائم أسعار من ملفات CSV خارجية',
    'Batch import products and prices from CSV',
  );
  String get perm_backup_create_name =>
      _t('إنشاء نسخة احتياطية', 'Create Database Backup (.waraq)');
  String get perm_backup_create_desc => _t(
    'تصدير نسخة احتياطية محلية أو إلى Google Drive',
    'Create local or Google Drive backups, with optional encryption',
  );
  String get perm_backup_restore_name => _t(
    'استعادة النسخة الاحتياطية (حساس)',
    'Restore Database Backup (Sensitive)',
  );
  String get perm_backup_restore_desc => _t(
    'استعادة قاعدة البيانات واستبدال البيانات الحالية',
    'Restore database from backup file, replacing local data',
  );
  String get perm_system_repair_name => _t(
    'أدوات الفحص والإصلاح وتشخيص القاعدة',
    'Diagnostics and Database Repair Tools',
  );
  String get perm_system_repair_desc => _t(
    'تشغيل فحوصات سلامة قاعدة البيانات وإصلاحها وتصدير تقرير التشخيص',
    'Run database health checks and repairs',
  );
  String get perm_accounting_period_lock_name =>
      _t('إقفال الفترات المحاسبية', 'Accounting Period Closing and Lock');
  String get perm_accounting_period_lock_desc => _t(
    'تحديد تاريخ إقفال الحسابات لمنع تعديل الفترات السابقة',
    'Set a books-closed date to prevent changes to past periods',
  );
  String get perm_settings_manage_name => _t(
    'تعديل بيانات النشاط التجاري والإعدادات العامة',
    'Business Profile and General Settings',
  );
  String get perm_settings_manage_desc => _t(
    'تغيير اسم النشاط التجاري والشعار والخيارات العامة',
    'Update store profile, branding, and global settings',
  );
  String get perm_payment_methods_manage_name =>
      _t('إدارة طرق الدفع والحسابات', 'Manage Payment Methods');
  String get perm_payment_methods_manage_desc => _t(
    'تفعيل وإضافة طرق دفع نقدية أو بنكية مخصصة',
    'Configure payment methods and bank options',
  );
  String get perm_tax_profiles_manage_name =>
      _t('إدارة نسب الضريبة', 'Manage Tax Profiles');
  String get perm_tax_profiles_manage_desc => _t(
    'إنشاء وتعديل نسب الضريبة (القيمة المضافة وغيرها)',
    'Configure tax profiles and VAT rates',
  );
  String get perm_audit_view_name =>
      _t('الاطلاع على سجل التدقيق والأنشطة', 'View Activity and Audit Trail');
  String get perm_audit_view_desc => _t(
    'تصفح سجل العمليات وسلسلة التحقق الرقمية',
    'Review system activity log and tamper-evident chain',
  );
  String get perm_users_manage_name =>
      _t('إدارة المستخدمين وكلمات المرور', 'Manage Users and Credentials');
  String get perm_users_manage_desc => _t(
    'إضافة موظفين، تعيين الأدوار، وإعادة ضبط كلمات المرور',
    'Create users, assign roles, and reset credentials',
  );
  String get perm_roles_manage_name => _t(
    'إدارة الأدوار ومصفوفة الصلاحيات',
    'Manage Roles and Permission Matrix',
  );
  String get perm_roles_manage_desc => _t(
    'إنشاء أدوار مخصصة وتعديل صلاحيات الأدوار',
    'Create custom roles and customize permissions',
  );
  String get perm_license_manage_name =>
      _t('إدارة الترخيص والتفعيل', 'License & Activation Management');
  String get perm_license_manage_desc => _t(
    'إدخال مفاتيح التفعيل وإدارة ترخيص التطبيق',
    'Enter activation keys and manage the app license',
  );

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
  String get accessDeniedTitle => _t('غير مسموح بالوصول', 'Access Denied');
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
    'هذه الميزة متاحة لمالك النظام فقط. راجع مالك النشاط إذا كنت بحاجة للوصول.',
    'This feature is restricted to the system Owner. Contact the business owner if you need access.',
  );
  String get accessDeniedDelegateHint => _t(
    'يمكنك طلب منح هذه الصلاحية من مالك النظام أو مدير الصلاحيات.',
    'You can request this permission from the system Owner or an administrator.',
  );
  String get accessDeniedLockedHint => _t(
    'الجلسة مقفلة. يرجى إدخال رمز PIN أو تسجيل الدخول للمتابعة.',
    'The session is locked. Please enter your PIN or log in to continue.',
  );
  String get accessDeniedBack => _t('العودة', 'Go Back');
  String get accessDeniedGoToLock =>
      _t('التبديل إلى شاشة القفل', 'Switch to Lock Screen');
  String get accessGenericPermission =>
      _t('صلاحية غير محددة', 'unspecified permission');
  String get accessGenericAction => _t('هذا الإجراء', 'this action');
  String get accessGenericScreen => _t('هذه الشاشة', 'this screen');

  String get errUnauthenticated =>
      _t('يجب تسجيل الدخول للمتابعة', 'Please log in to continue');
  String get errSessionLocked => _t(
    'الجلسة مقفلة. يرجى إدخال رمز PIN',
    'The session is locked. Please enter your PIN.',
  );
  String get errOwnerOnly => _t(
    'هذا الإجراء متاح لمالك النظام فقط',
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
    'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل',
    'Password must be at least 6 characters',
  );
  String get errPasswordsMismatch =>
      _t('كلمتا المرور غير متطابقتين', 'Passwords do not match');
  String get errPinInvalid =>
      _t('يجب أن يتكون رمز PIN من 4 إلى 6 أرقام', 'PIN must be 4 to 6 digits');
  String get errRoleNotFound =>
      _t('الدور المحدد غير موجود', 'Selected role not found');
  String get errUserNotFound => _t('المستخدم غير موجود', 'User not found');
  String get errUserDisabled => _t(
    'تم تعطيل هذا الحساب. تواصل مع مالك النظام.',
    'This account is disabled. Contact the business owner.',
  );
  String errAccountLocked(String duration) => _t(
    'الحساب مقفل مؤقتاً، يرجى المحاولة بعد $duration',
    'Your account is temporarily locked. Try again in $duration.',
  );
  String errAttemptsRemaining(int count) => _t(
    'المحاولات المتبقية قبل تعليق الحساب: $count',
    '$count attempts remaining before temporary lockout',
  );
  String errDeviceThrottled(String duration) => _t(
    'تم تجاوز المحاولات المسموحة على هذا الجهاز، انتظر $duration',
    'Too many attempts on this device. Please wait $duration.',
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
    'Recovery is temporarily locked due to too many attempts. Please wait $duration.',
  );
  String get errOwnerCannotBeDisabled =>
      _t('لا يمكن تعطيل حساب المالك', 'Owner account cannot be disabled');
  String get errOwnerUsernameImmutable => _t(
    'اسم مستخدم المالك ثابت ولا يمكن تغييره',
    'Owner username cannot be changed',
  );
  String get errOwnerRoleImmutable =>
      _t('دور المالك ثابت ولا يمكن تغييره', 'Owner role cannot be changed');
  String get errUndeclaredScreen => _t(
    'الشاشة المطلوبة غير معتمدة أمنياً',
    'Requested screen is not registered in security policy',
  );
  String get errMultiUserDisableOwnerOnly => _t(
    'لا يمكن تعطيل تعدد المستخدمين إلا بواسطة المالك',
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
    'An unexpected error occurred. Please try again.',
  );
  String get actorSystem => _t('النظام', 'System');
  String get actorUnauthenticated => _t('غير مسجّل الدخول', 'Not Logged In');
  String get actorOwner => _t('المالك', 'Owner');

  // Additional Access screen & audit keys
  String get auditFilterAll => _t('الكل', 'All');
  String get auditFilterSecurity => _t('الأمان والحماية', 'Security');
  String get auditFilterLogins => _t('الدخول والخروج', 'Logins');
  String get auditFilterChanges => _t('التعديلات', 'Changes');
  String auditVerifiedEntries(int count) =>
      _plural(
        count,
        zero: 'لا توجد سجلات موثّقة',
        one: 'سجل واحد موثّق',
        two: 'سجلان موثّقان',
        few: '$count سجلات موثّقة',
        many: '$count سجلاً موثّقاً',
        other: '$count سجل موثّق',
        enOne: '1 verified entry',
        enOther: '$count verified entries',
      );
  String auditBrokenAtId(int id) =>
      _t('تم اكتشاف الخلل عند السجل رقم $id', 'Chain broken at entry #$id');
  String get auditUnknownTime => _t('وقت غير معروف', 'Unknown time');
  String get auditActionGenesis => _t('بدء سجل التدقيق', 'Audit Log Started');
  String get auditActionUserCreated => _t('إنشاء مستخدم', 'User Created');
  String get auditActionUserUpdated => _t('تعديل مستخدم', 'User Updated');
  String get auditActionUserUnlocked => _t('إلغاء قفل حساب', 'User Unlocked');
  String get auditActionRoleCreated => _t('إنشاء دور', 'Role Created');
  String get auditActionRoleUpdated => _t('تعديل دور', 'Role Updated');
  String get auditActionRoleDeleted => _t('حذف دور', 'Role Deleted');
  String get auditActionEscalationDenied =>
      _t('محاولة تصعيد صلاحيات مرفوضة', 'Privilege Escalation Blocked');
  String get auditActionRecoveryFailed =>
      _t('فشل استرداد الحساب', 'Recovery Failed');
  String get auditActionRecoveryCompleted =>
      _t('اكتمال استرداد الحساب', 'Recovery Completed');
  String get auditActionMultiUserEnabled =>
      _t('تفعيل وضع تعدد المستخدمين', 'Multi-User Enabled');
  String get auditActionMultiUserDisabled =>
      _t('تعطيل وضع تعدد المستخدمين', 'Multi-User Disabled');
  String get auditActionUserLogout => _t('تسجيل خروج', 'User Logout');
  String get auditActionUserLogin => _t('تسجيل دخول', 'User Login');
  String get auditActionLoginFailed => _t('فشل تسجيل الدخول', 'Login Failed');
  String get auditActionSessionLocked => _t('قفل الجلسة', 'Session Locked');
  String get auditActionSensitiveReauth =>
      _t('إعادة التحقق لعملية حساسة', 'Re-authentication for Sensitive Action');

  String get auditDetailUserId => _t('معرّف المستخدم', 'User ID');
  String get auditDetailUsername => _t('اسم المستخدم', 'Username');
  String get auditDetailDisplayName => _t('الاسم الظاهر', 'Display Name');
  String get auditDetailRole => _t('الدور', 'Role');
  String get auditDetailPermissionsCount =>
      _t('عدد الصلاحيات', 'Number of Permissions');
  String get auditDetailUpdatedFields => _t('الحقول المعدَّلة', 'Updated Fields');
  String get auditDetailAction => _t('الإجراء المستهدف', 'Target Action');
  String get auditDetailDecision => _t('القرار', 'Decision');
  String get auditDetailReason => _t('السبب', 'Reason');
  String get auditDetailActor => _t('المنفذ', 'Actor');
  String get auditDetailFailedAttempts =>
      _t('المحاولات الفاشلة', 'Failed Attempts');
  String get loadMore => _t('تحميل المزيد', 'Load More');
  String get auditVerifyingProgress =>
      _t('جارٍ التحقق من السجلات…', 'Verifying audit records…');

  String get ownerPinHelper => _t(
    'اختياري: رمز PIN للدخول السريع من شاشة البيع بدون إدخال كلمة المرور كاملة',
    'Optional: a PIN for quick unlock without typing the full password',
  );
  String get securingAccount => _t('جارٍ تأمين الحساب…', 'Securing account…');
  String get accessBack => _t('رجوع', 'Back');
  String get cancelSetup => _t('إلغاء الإعداد', 'Cancel Setup');
  String get cancelSetupConfirm => _t(
    'تأكيد إلغاء الإعداد؟ سيتم تجاهل رمز الاسترداد الذي تم إنشاؤه.',
    'Cancel setup? The generated recovery code will be discarded.',
  );
  String get ownerRole => _t('المالك', 'Owner');
  String get securityInitFailedTitle =>
      _t('تعذر التحقق من إعدادات الأمان', 'Cannot verify security settings');
  String get securityInitFailedBody => _t(
    'فشلت قراءة إعدادات الأمان. تم إبقاء التطبيق مقفلاً لحماية البيانات.',
    'Could not read the security settings. The app was kept locked to protect your data.',
  );
  String disableUserConfirm(String name) =>
      _t('هل تريد تعطيل المستخدم $name؟', 'Disable user $name?');
  String get ownerUsernameImmutable => _t(
    'اسم مستخدم المالك ثابت ولا يمكن تعديله',
    'The Owner username cannot be changed',
  );
  String get usernameMinLength => _t(
    'يجب ألا يقل اسم المستخدم عن 3 أحرف',
    'Username must be at least 3 characters',
  );
  String get passwordMinLength => _t(
    'يجب ألا تقل كلمة المرور عن 6 أحرف',
    'Password must be at least 6 characters',
  );
  String get pinDigitsCount =>
      _t('يجب أن يتكون رمز PIN من 4 إلى 6 أرقام', 'PIN must be 4 to 6 digits');
  String get noCustomOverrides =>
      _t('بدون استثناءات مخصصة', 'No custom overrides');
  String customPermissionsCount(int count) =>
      _plural(
        count,
        zero: 'لا توجد صلاحيات مخصصة',
        one: 'صلاحية مخصصة واحدة',
        two: 'صلاحيتان مخصصتان',
        few: '$count صلاحيات مخصصة',
        many: '$count صلاحية مخصصة',
        other: '$count صلاحية مخصصة',
        enOne: '1 custom permission',
        enOther: '$count custom permissions',
      );

  String get disableMultiUserOwnerOnly => _t(
    'فقط المالك يمكنه تعطيل وضع تعدد المستخدمين',
    'Only the Owner can disable multi-user mode',
  );
  String get disableMultiUserConfirmMsg => _t(
    'يتطلب تعطيل وضع تعدد المستخدمين تأكيد كلمة مرور المالك لحماية بيانات النشاط التجاري.',
    'Disabling multi-user mode requires confirming the Owner password.',
  );
  String get disableMultiUserDialogMsg => _t(
    'تأكيد تعطيل وضع تعدد المستخدمين والعودة لنمط المستخدم الفردي؟',
    'Disable multi-user mode and return to single-user mode?',
  );
  String get disableMultiUserSuccess => _t(
    'تم تعطيل وضع تعدد المستخدمين بنجاح',
    'Multi-user mode disabled successfully',
  );
  String get searchUser => _t('بحث عن مستخدم…', 'Search user…');
  String get multiUserActiveBanner => _t(
    'وضع تعدد المستخدمين مفعل. يمكنك الآن إضافة كاشير أو محاسب أو مدير لتوزيع المهام بأمان.',
    'Multi-user mode is active. Add cashiers, accountants, or managers to delegate tasks safely.',
  );
  String userLockedUntilBadge(String time) =>
      _t('مقفل حتى $time', 'Locked until $time');
  String get noPinBadge => _t('بدون PIN', 'No PIN');
  String get unlockUserAction => _t('إلغاء قفل الحساب', 'Unlock Account');
  String unlockUserConfirm(String name) => _t(
    'هل تريد إلغاء قفل حساب $name وإعادة ضبط محاولات الدخول الفاشلة؟',
    'Unlock $name and reset failed login attempts?',
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
      _t('الدخول بكلمة المرور', 'Log In with Password');
  String get passwordRequired =>
      _t('كلمة المرور مطلوبة', 'Password is required');
  String get signingIn => _t('جارٍ التحقق…', 'Verifying…');
  String get stepPassword => _t('كلمة المرور', 'Password');
  String get stepRecoveryCode => _t('رمز الاسترداد', 'Recovery Code');

  // Role templates (A8)
  String get roleOwner_name => _t('المالك', 'Owner');
  String get roleOwner_desc =>
      _t('مالك النظام بجميع الصلاحيات', 'System Owner with full access');
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

  // ========== PRODUCT IMAGES ==========
  String get posShowProductImages =>
      _t('إظهار صور المنتجات', 'Show Product Images');
  String get posHideProductImages =>
      _t('إخفاء صور المنتجات', 'Hide Product Images');
  String get quickSaleImagesSettingTitle => _t(
    'إظهار صور المنتجات في البيع السريع',
    'Show Product Images in Quick Sale',
  );
  String get quickSaleImagesSettingDesc => _t(
    'أوقفه على الأجهزة البطيئة أو عند وجود منتجات كثيرة.',
    'Turn off on slow devices or when you have many products.',
  );
  String get cameraPermissionDenied => _t(
    'تم رفض إذن الكاميرا. فعّله من إعدادات التطبيق لالتقاط الصور.',
    'Camera permission was denied. Enable it in app settings to take photos.',
  );
  String get photoPermissionDenied => _t(
    'تم رفض إذن الصور. فعّله من إعدادات التطبيق لاختيار صورة.',
    'Photo access was denied. Enable it in app settings to choose a photo.',
  );
  String get openAppSettings => _t('فتح إعدادات التطبيق', 'Open App Settings');
  String get imagePhotoRecovered => _t(
    'تمت استعادة الصورة التي التقطتها.',
    'Your captured photo was recovered.',
  );
  String get imageCroppedHint => _t(
    'تظهر الصورة مقصوصة على شكل مربع في القوائم.',
    'The photo is shown cropped to a square in lists.',
  );
  String get imageInvalid =>
      _t('الصورة غير صالحة أو تالفة.', 'The image is invalid or corrupted.');
  String get imageTooLarge =>
      _t('حجم الصورة كبير جداً.', 'The image is too large.');
  String get imageDiskFull => _t(
    'لا توجد مساحة كافية لحفظ الصورة.',
    'Not enough storage space to save the image.',
  );
  String get imageSemanticLabel => _t('صورة المنتج', 'Product image');
  String get imageChangeSemanticLabel =>
      _t('تغيير صورة المنتج', 'Change product photo');
  String imageRestoreSkipped(int count) => _t(
    'تعذّر استعادة $count صورة، وتمت استعادة باقي البيانات.',
    '$count image(s) couldn\'t be restored; the rest of the data was restored.',
  );
  String get errProductInUse => _t(
    'لا يمكن حذف منتج مستخدم في مستندات. يمكنك تعطيله بدلاً من ذلك.',
    'A product used in documents can\'t be deleted. You can deactivate it instead.',
  );
  String get customerRequiredForCreditSale => _t(
    'يجب اختيار عميل للمبيعات الآجلة.',
    'Customer selection is required for credit sales.',
  );
  String get supplierRequiredForCreditPurchase => _t(
    'يجب اختيار مورد للمشتريات الآجلة.',
    'Supplier selection is required for credit purchases.',
  );

  // ========== EXPENSE CATEGORIES ==========
  String get expenseRent => _t('إيجار', 'Rent');
  String get expenseElectricity => _t('كهرباء', 'Electricity');
  String get expenseSalaries => _t('رواتب', 'Salaries');
  String get expenseTransport => _t('مواصلات', 'Transportation');
  String get expenseMaintenance => _t('صيانة', 'Maintenance');
  String get expenseOther => _t('أخرى', 'Other');

  // ========== POS HOLD / RECALL & FILTERS ==========
  String get posHoldCart => _t('تعليق الفاتورة', 'Hold Cart');
  String get posHeldCarts => _t('الفواتير المعلقة', 'Held Carts');
  String get posCartHeldSuccess =>
      _t('تم تعليق الفاتورة بنجاح', 'Cart held successfully');
  String get posRecallCart => _t('استرجاع الفاتورة', 'Recall Cart');
  String get posNoHeldCarts => _t('لا توجد فواتير معلقة', 'No held carts');
  String get posFrequentlySold => _t('الأكثر مبيعاً', 'Frequently Sold');
  String get posContinuousScanning => _t('مسح مستمر', 'Continuous Scanning');
  String get posItemRemoved =>
      _t('تم حذف العنصر من السلة', 'Item removed from cart');
  String get voucherPayFullBalance =>
      _t('سداد كامل الرصيد', 'Pay Full Balance');
  String get exact => _t('المبلغ المطابق', 'Exact Amount');
  String get selectCustomer => _t('اختيار عميل', 'Select Customer');
  String get clear => _t('مسح', 'Clear');

  // ========== STATUS COLORS & UX KEYS ==========
  String get removeDeviceLicenseTitle =>
      _t('إزالة ترخيص الجهاز', 'Remove Device License');
  String get voucherLoadingBalance =>
      _t('جارٍ تحميل الرصيد المستحق…', 'Loading outstanding balance…');
  String get voucherBalanceLoadFailed =>
      _t('تعذر جلب الرصيد المستحق', 'Could not load the outstanding balance');
  String get voucherSelectCustomerHint => _t(
    'اختر العميل من القائمة لتسجيل سند قبض',
    'Pick the customer from the list to record a receipt',
  );
  String get roleOwner => _t('المالك', 'Owner');
  String get roleAdministrator => _t('مدير النظام', 'Administrator');
  String get cannotDisableLastMethod => _t(
    'يجب أن تبقى طريقة دفع واحدة مفعّلة على الأقل',
    'At least one payment method must stay enabled',
  );
  String get cannotDisableDefaultMethod => _t(
    'عيّن طريقة أخرى كافتراضية ثم عطّل هذه',
    'Set another method as default before disabling this one',
  );
  String get switchToBaseTitle =>
      _t('التحويل إلى العملة الأساسية؟', 'Switch to Base Currency?');
  String get lowStockConfirmTitle => _t('مخزون غير كافٍ', 'Insufficient Stock');
  String lowStockConfirmMessage(String names) => _t(
    'الكمية غير كافية للأصناف: $names. هل تريد المتابعة؟',
    'Not enough stock for: $names. Continue anyway?',
  );
  String get continueAnyway => _t('المتابعة على أي حال', 'Continue Anyway');
  String get pdfResetConfirmTitle =>
      _t('استعادة الإعدادات الافتراضية؟', 'Reset to Defaults?');
  String get pdfResetConfirmMessage => _t(
    'ستعود القوالب والألوان والحقول إلى الوضع الافتراضي. الأختام والتوقيع لن تتأثر.',
    'The template, colors, and fields will return to their defaults. Stamps and signatures are not affected.',
  );
  String confirmSetPeriodLockWithDate(String date) => _t(
    'سيتم إغلاق الدفاتر حتى $date. لن يكون بالإمكان إنشاء أي معاملة مؤرخة في هذا التاريخ أو قبله، ولا تعديلها أو حذفها.',
    'Books will be closed through $date. Transactions dated on or before this date can no longer be created, edited, or deleted.',
  );
  String taxProfileInUse(int count) =>
      _plural(
        count,
        zero: 'غير مرتبط بأي منتج',
        one: 'مرتبط بمنتج واحد',
        two: 'مرتبط بمنتجين',
        few: 'مرتبط بـ $count منتجات',
        many: 'مرتبط بـ $count منتجاً',
        other: 'مرتبط بـ $count منتج',
        enOne: 'Used by 1 product',
        enOther: 'Used by $count products',
      );
  String get taxRateRange =>
      _t('يجب أن تكون النسبة بين 0 و 100', 'The rate must be between 0 and 100');
  String get clearFilters => _t('مسح عوامل التصفية', 'Clear Filters');
  String unitRemoved(String name) =>
      _t('تم حذف الوحدة: $name', 'Unit removed: $name');
  String get logoInvalidImage =>
      _t('الملف المختار ليس صورة صالحة', 'The selected file is not a valid image');
  String csvPreviewLimited(int shown, int total) =>
      _t('عرض أول $shown صفاً من $total', 'Showing first $shown of $total rows');
  String get legacyPayablesOtherCurrencies =>
      _t('التزامات قديمة للموردين بعملات أخرى', 'Legacy payables in other currencies');
  String get legacyReceivablesOtherCurrencies =>
      _t('مستحقات قديمة على العملاء بعملات أخرى', 'Legacy receivables in other currencies');

  // ── Digital & Paper Seals Customization ──────────────────────────────────
  String get pdfDigitalSealsHeader =>
      _t('الأختام والتوقيعات الرقمية', 'Digital Stamps & Signatures');
  String get pdfDigitalStampDesc =>
      _t('ختم رقمي جاهز يظهر مطبوعاً على الفاتورة', 'Digital stamp printed on the invoice');
  String get pdfDigitalSignatureDesc =>
      _t('توقيع رقمي يظهر مطبوعاً على الفاتورة', 'Digital signature printed on the invoice');
  String get pdfPaperStampSignatureSection =>
      _t('مربعات الختم والتوقيع الورقي', 'Paper Stamp & Signature Boxes');
  String get pdfShowSignatureLine =>
      _t('سطر التوقيع اليدوي', 'Manual Signature Line');
  String get pdfShowSignatureLineDesc => _t(
    'ترك مساحة فارغة في الفاتورة للتوقيع يدوياً بعد الطباعة',
    'Leave blank space on the invoice for a handwritten signature after printing',
  );
  String get pdfShowStampBox =>
      _t('مربع الختم اليدوي', 'Manual Stamp Box');
  String get pdfShowStampBoxDesc => _t(
    'ترك مربع فارغ في الفاتورة للختم الورقي بعد الطباعة',
    'Leave an empty box on the invoice for a physical stamp after printing',
  );
  String get pdfStampNoticeBoth => _t(
    'تنبيه: تم تفعيل كل من الختم الرقمي ومربع الختم اليدوي معاً',
    'Note: Both the digital stamp and the manual stamp box are enabled',
  );

  // ── Quick Sale & POS Credit Sales ────────────────────────────────────────
  String get posListView => _t('عرض كقائمة', 'List View');
  String get posGridView => _t('عرض كشبكة', 'Grid View');
  String get posPayCashFull => _t('نقداً بالكامل', 'Full Cash');
  String get posPayCredit => _t('آجل بالكامل', 'Full Credit');
  String get posPayPartial => _t('دفعة مقدمة', 'Partial Payment');
  String get posCompleteCreditSale => _t('إتمام البيع الآجل', 'Complete Credit Sale');
  String get posCompletePartialSale => _t('إتمام البيع بالدفعة', 'Complete Partial Sale');
  String get posRemainingOnAccount => _t('المتبقي على الحساب', 'Remaining on Account');
  String get posLayoutSettingTitle =>
      _t('طريقة عرض المنتجات في البيع السريع', 'Quick Sale Product Layout');

  // ── Stocktake History ────────────────────────────────────────────────────
  String get stocktakeHistoryTitle =>
      _t('سجل عمليات الجرد', 'Stocktake History');

  // ── Discount Input Field ─────────────────────────────────────────────────
  String get discountTypeAmount => _t('مبلغ', 'Amount');
  String get discountTypePercentage => _t('نسبة', 'Percentage');
  String get discountAmountExceedsSubtotal =>
      _t('قيمة الخصم تتجاوز إجمالي البنود', 'Discount exceeds subtotal');
  String get discountPercentExceedsMax =>
      _t('نسبة الخصم لا يمكن أن تتجاوز 100%', 'Discount cannot exceed 100%');

  // ── Pro Subscription Landing Page ───────────────────────────────────────
  String get proSubscriptionBrand =>
      _t('ورقتك | Waraqatak By Elmahdi Dev', 'Waraqatak by Elmahdi Dev');
  String get proSubscriptionTitle =>
      _t('باقات اشتراك ورقتك برو', 'Waraqatak Pro Subscription Plans');
  String get proSubscriptionSubtitle => _t(
    'اختر الباقة المناسبة لنشاطك التجاري واستفد من الإمكانات الكاملة لإدارة فواتيرك ومخزونك باحترافية',
    'Choose the plan that fits your business and unlock the full power of invoicing and inventory management',
  );
  String get proValuePointInvoices =>
      _t('فواتير وعروض أسعار وسندات غير محدودة', 'Unlimited invoices, quotations, and vouchers');
  String get proValuePointInventory =>
      _t('إدارة متقدمة للمخزون والتنبيهات وجرد الباركود', 'Advanced inventory management, low-stock alerts, and barcode stocktake');
  String get proValuePointReports =>
      _t('تقارير مالية وأرباح مفصلة مع تصدير وطباعة', 'Detailed financial and profit reports with export and printing');
  String get proValuePointBranding =>
      _t('تخصيص كامل للفواتير بالشعار والأختام والتوقيع', 'Fully customizable invoices with your logo, stamps, and signatures');

  // Plan Names & Durations
  String get plan1MonthTitle => _t('باقة شهر واحد', '1-Month Plan');
  String get plan1MonthDuration => _t('1 شهر', '1 Month');
  String get plan3MonthsTitle => _t('باقة 3 أشهر', '3-Month Plan');
  String get plan3MonthsDuration => _t('3 أشهر', '3 Months');
  String get plan6MonthsTitle => _t('باقة 6 أشهر', '6-Month Plan');
  String get plan6MonthsDuration => _t('6 أشهر', '6 Months');
  String get plan1YearTitle => _t('باقة سنة كاملة', '1-Year Plan');
  String get plan1YearDuration => _t('1 سنة', '1 Year');
  String get plan1YearFeaturedBadge =>
      _t('العرض الأفضل · الأكثر توفيراً', 'Best Value · Biggest Savings');

  // Pricing & Badges
  String get planCurrencySdg => _t('ج.س', 'SDG');
  String get save60kBadge => _t('وفر 60,000 ج.س', 'Save 60,000 SDG');
  String get save20kBadge => _t('وفر 20,000 ج.س', 'Save 20,000 SDG');
  String get save5kBadge => _t('وفر 5,000 ج.س', 'Save 5,000 SDG');
  String get discount33PercentBadge => _t('خصم 33%', '33% OFF');
  String get equivalentMonthly10k =>
      _t('يعادل 10,000 ج.س فقط في الشهر', 'Only 10,000 SDG per month');
  String get originalAnnualPriceCrossing => _t('180,000 ج.س', '180,000 SDG');

  // Subscription Actions & Instructions
  String get subscribeNowAction => _t('اشترك الآن', 'Subscribe Now');
  String get howToActivateTitle => _t('طريقة الاشتراك والتفعيل', 'How to Subscribe & Activate');
  String get howToActivateBody => _t(
    '1. اضغط على «اشترك الآن» في الباقة المختارة للتواصل معنا عبر واتساب مباشرة.\n2. سيزوّدك فريق الدعم ببيانات الدفع (تطبيق بنكك أو تحويل مصرفي).\n3. بعد تأكيد التحويل ستستلم مفتاح التفعيل فوراً لتفعيل باقتك.',
    '1. Tap “Subscribe Now” on your chosen plan to message us directly on WhatsApp.\n2. Our support team will send you the payment details (Bankak or bank transfer).\n3. Once your payment is confirmed, you will receive an activation key right away to activate your plan.',
  );
  String get alreadyHaveKeyHeader => _t('لديك مفتاح تفعيل؟', 'Already have an activation key?');
  String get alreadyHaveKeyDesc => _t(
    'إذا تواصلت مع الدعم واستلمت مفتاح التفعيل، أدخله هنا لتفعيل نسختك فوراً:',
    'If you have contacted support and received your activation key, enter it here to activate right away:',
  );
  String get myDeviceIdLabel => _t('معرّف جهازك:', 'Your Device ID:');
  String get copyDeviceIdAction => _t('نسخ المعرف', 'Copy ID');
  String get deviceIdCopiedSnack => _t('تم نسخ معرف الجهاز', 'Device ID copied to clipboard');
}

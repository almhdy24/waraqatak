/// Permission categories for grouping in UI permission matrix.
enum PermissionGroup {
  sales('المبيعات', 'Sales'),
  purchases('المشتريات', 'Purchases'),
  payments('المدفوعات والسندات', 'Payments & Vouchers'),
  stock('المخزون والجرد', 'Stock & Inventory'),
  products('المنتجات والتسعير', 'Products & Pricing'),
  contacts('العملاء والموردين', 'Customers & Suppliers'),
  dashboard('لوحة المعلومات', 'Dashboard'),
  reports('التقارير والمؤشرات', 'Reports'),
  data('الاستيراد والتصدير', 'Data Import & Export'),
  system('إدارة النظام والنسخ', 'System & Backup'),
  settings('إعدادات العمل والضرائب', 'Settings'),
  access('المستخدمون والصلاحيات', 'Users & Roles');

  final String labelAr;
  final String labelEn;
  const PermissionGroup(this.labelAr, this.labelEn);

  String label(bool isArabic) => isArabic ? labelAr : labelEn;
}

/// Metadata definition of an application permission key.
class PermissionItem {
  final String key;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final PermissionGroup group;
  final bool isSensitive;

  const PermissionItem({
    required this.key,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.group,
    this.isSensitive = false,
  });

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
  String description(bool isArabic) => isArabic ? descriptionAr : descriptionEn;
}

/// Single authoritative registry of all application permissions.
abstract final class PermissionRegistry {
  // Sales
  static const String salesView = 'sales.view';
  static const String salesCreate = 'sales.create';
  static const String salesEdit = 'sales.edit';
  static const String salesEditPrice = 'sales.edit_price';
  static const String salesEditDiscount = 'sales.edit_discount';
  static const String salesCancel = 'sales.cancel';
  static const String salesDelete = 'sales.delete';
  static const String salesRefund = 'sales.refund';

  // Purchases
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesEdit = 'purchases.edit';
  static const String purchasesCancel = 'purchases.cancel';
  static const String purchasesDelete = 'purchases.delete';

  // Payments & Vouchers
  static const String paymentsRecord = 'payments.record';
  static const String vouchersCreate = 'vouchers.create';
  static const String expensesView = 'expenses.view';

  // Stock & Inventory
  static const String stockAdjust = 'stock.adjust';
  static const String stockViewCost = 'stock.view_cost';
  static const String stocktakeManage = 'stocktake.manage';
  static const String stocktakeFinalize = 'stocktake.finalize';

  // Products & Pricing
  static const String productsView = 'products.view';
  static const String productsManage = 'products.manage';
  static const String productsDelete = 'products.delete';
  static const String productsViewCost = 'products.view_cost';
  static const String productsViewWholesale = 'products.view_wholesale';
  static const String pricingManage = 'pricing.manage';
  static const String pricingRates = 'pricing.rates';

  // Contacts
  static const String contactsView = 'contacts.view';
  static const String contactsManage = 'contacts.manage';
  static const String contactsDelete = 'contacts.delete';
  static const String contactsViewBalances = 'contacts.view_balances';

  // Dashboard
  static const String dashboardViewTotals = 'dashboard.view_totals';

  // Reports
  static const String reportsViewSales = 'reports.view_sales';
  static const String reportsViewPurchases = 'reports.view_purchases';
  static const String reportsViewReceivables = 'reports.view_receivables';
  static const String reportsViewInventoryCost = 'reports.view_inventory_cost';
  static const String reportsViewFinancials = 'reports.view_financials';
  static const String reportsExportPdf = 'reports.export_pdf';

  // Data
  static const String dataExportCsv = 'data.export_csv';
  static const String dataImportCsv = 'data.import_csv';

  // System & Backup
  static const String backupCreate = 'backup.create';
  static const String backupRestore = 'backup.restore';
  static const String systemRepair = 'system.repair';
  static const String accountingPeriodLock = 'accounting.period_lock';

  // Settings
  static const String settingsManage = 'settings.manage';
  static const String paymentMethodsManage = 'payment_methods.manage';
  static const String taxProfilesManage = 'tax_profiles.manage';

  // Access & Admin
  static const String auditView = 'audit.view';
  static const String usersManage = 'users.manage';
  static const String rolesManage = 'roles.manage';
  static const String licenseManage = 'license.manage';

  static const List<PermissionItem> all = [
    // Sales
    PermissionItem(
      key: salesView,
      nameAr: 'عرض المبيعات والفواتير',
      nameEn: 'View sales and invoices',
      descriptionAr: 'عرض قائمة فواتير المبيعات وتفاصيلها',
      descriptionEn: 'View list of sales invoices and details',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesCreate,
      nameAr: 'إنشاء فواتير المبيعات',
      nameEn: 'Create sales invoices',
      descriptionAr: 'إصدار فواتير بيع جديدة وعروض أسعار',
      descriptionEn: 'Issue new sales invoices and quotations',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEdit,
      nameAr: 'تعديل فواتير المبيعات',
      nameEn: 'Edit sales invoices',
      descriptionAr: 'تعديل فواتير المبيعات القائمة',
      descriptionEn: 'Edit existing sales invoices',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEditPrice,
      nameAr: 'تعديل سعر البيع يدوياً',
      nameEn: 'Manual price override',
      descriptionAr: 'تغيير سعر بيع الصنف أثناء إنشاء الفاتورة',
      descriptionEn: 'Change item unit price on the invoice',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesEditDiscount,
      nameAr: 'إضافة وتعديل الخصومات',
      nameEn: 'Apply and edit discounts',
      descriptionAr: 'تطبيق تخفيض على الفاتورة أو البنود',
      descriptionEn: 'Apply discounts to documents or line items',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesCancel,
      nameAr: 'إلغاء فواتير المبيعات',
      nameEn: 'Cancel sales invoices',
      descriptionAr: 'إلغاء فواتير البيع واسترجاع كميات المخزون',
      descriptionEn: 'Cancel invoices and restore inventory stock',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesDelete,
      nameAr: 'حذف مسودات المبيعات',
      nameEn: 'Delete draft invoices',
      descriptionAr: 'حذف فواتير المبيعات غير الصادرة نهائياً',
      descriptionEn: 'Permanently delete draft sales documents',
      group: PermissionGroup.sales,
    ),
    PermissionItem(
      key: salesRefund,
      nameAr: 'إدارة استرجاع المبالغ (Refund)',
      nameEn: 'Manage document refunds',
      descriptionAr: 'تحديث حالة استرجاع المبالغ للفواتير الملغاة',
      descriptionEn: 'Update refund status on cancelled invoices',
      group: PermissionGroup.sales,
      isSensitive: true,
    ),

    // Purchases
    PermissionItem(
      key: purchasesView,
      nameAr: 'عرض فواتير المشتريات',
      nameEn: 'View purchase invoices',
      descriptionAr: 'عرض مشتريات البضائع وفواتير الموردين',
      descriptionEn: 'View purchase invoices from suppliers',
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesCreate,
      nameAr: 'إنشاء فواتير المشتريات',
      nameEn: 'Create purchase invoices',
      descriptionAr: 'تسجيل شراء بضاعة وتحديث تكلفة المخزون',
      descriptionEn: 'Record incoming stock and update cost',
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesEdit,
      nameAr: 'تعديل فواتير المشتريات',
      nameEn: 'Edit purchase invoices',
      descriptionAr: 'تعديل بنود وأسعار فواتير الشراء القائمة',
      descriptionEn: 'Edit items and costs on purchase invoices',
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesCancel,
      nameAr: 'إلغاء فواتير المشتريات',
      nameEn: 'Cancel purchase invoices',
      descriptionAr: 'إلغاء فاتورة شراء واسترجاع كميات المخزون',
      descriptionEn: 'Cancel purchase invoice and reverse stock',
      group: PermissionGroup.purchases,
    ),
    PermissionItem(
      key: purchasesDelete,
      nameAr: 'حذف مسودات المشتريات',
      nameEn: 'Delete draft purchases',
      descriptionAr: 'حذف فواتير الشراء غير الصادرة',
      descriptionEn: 'Delete unissued purchase drafts',
      group: PermissionGroup.purchases,
    ),

    // Payments & Vouchers
    PermissionItem(
      key: paymentsRecord,
      nameAr: 'تسجيل الدفعات والتحصيل',
      nameEn: 'Record payments and collections',
      descriptionAr: 'تسجيل دفعات نقدية أو بنكية على الفواتير',
      descriptionEn: 'Record cash or bank payments on invoices',
      group: PermissionGroup.payments,
    ),
    PermissionItem(
      key: vouchersCreate,
      nameAr: 'إنشاء سندات القبض والصرف',
      nameEn: 'Create payment receipts and expense vouchers',
      descriptionAr: 'إصدار سندات مالية مستقلة للمصروفات والقبض',
      descriptionEn: 'Issue financial receipt and payment vouchers',
      group: PermissionGroup.payments,
    ),
    PermissionItem(
      key: expensesView,
      nameAr: 'عرض سندات المصروفات',
      nameEn: 'View expense vouchers',
      descriptionAr: 'الاطلاع على سجل المصروفات وسندات الصرف',
      descriptionEn: 'View operating expenses and expense vouchers',
      group: PermissionGroup.payments,
      isSensitive: true,
    ),

    // Stock & Inventory
    PermissionItem(
      key: stockAdjust,
      nameAr: 'تسوية المخزون اليدوية',
      nameEn: 'Manual stock adjustment',
      descriptionAr: 'تعديل كميات المخزون بالزيادة أو النقص يدوياً',
      descriptionEn: 'Manually add or reduce product stock levels',
      group: PermissionGroup.stock,
    ),
    PermissionItem(
      key: stockViewCost,
      nameAr: 'الاطلاع على تكلفة المخزون',
      nameEn: 'View stock movement costs',
      descriptionAr: 'عرض أسعار وتكلفة حركات المخزون الداخلة والخارجة',
      descriptionEn: 'View unit and total cost of stock movements',
      group: PermissionGroup.stock,
      isSensitive: true,
    ),
    PermissionItem(
      key: stocktakeManage,
      nameAr: 'بدء وإدارة جلسات الجرد',
      nameEn: 'Start and manage stocktake',
      descriptionAr: 'فتح جلسات الجرد الدوري وتسجيل الكميات المعدودة',
      descriptionEn: 'Open stocktake sessions and enter counted stock',
      group: PermissionGroup.stock,
    ),
    PermissionItem(
      key: stocktakeFinalize,
      nameAr: 'اعتماد تسويات الجرد',
      nameEn: 'Finalize stocktake reconciliation',
      descriptionAr: 'ترحيل فروقات الجرد وتحديث المخزون محاسبياً',
      descriptionEn: 'Post stocktake variances to inventory ledger',
      group: PermissionGroup.stock,
      isSensitive: true,
    ),

    // Products & Pricing
    PermissionItem(
      key: productsView,
      nameAr: 'عرض قائمة المنتجات',
      nameEn: 'View products catalog',
      descriptionAr: 'تصفح قائمة الأصناف والباركود وسعر البيع',
      descriptionEn: 'Browse product catalog, barcodes, and sale prices',
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsManage,
      nameAr: 'إضافة وتعديل المنتجات والوحدات',
      nameEn: 'Create and edit products & units',
      descriptionAr: 'إنشاء أصناف جديدة وتعديل الأسعار والوحدات',
      descriptionEn: 'Add products and manage pricing and units',
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsDelete,
      nameAr: 'حذف المنتجات',
      nameEn: 'Delete products',
      descriptionAr: 'حذف أو تعطيل الأصناف غير المستخدمة',
      descriptionEn: 'Delete or deactivate unused products',
      group: PermissionGroup.products,
    ),
    PermissionItem(
      key: productsViewCost,
      nameAr: 'الاطلاع على سعر الشراء وتكلفة المنتج',
      nameEn: 'View purchase price and average cost',
      descriptionAr: 'إظهار سعر التكلفة وسعر الشراء في شاشات الأصناف',
      descriptionEn: 'Show purchase price and average cost on product views',
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: productsViewWholesale,
      nameAr: 'الاطلاع على أسعار الجملة',
      nameEn: 'View wholesale prices',
      descriptionAr: 'عرض سعر الجملة والحد الأدنى لكمية الجملة',
      descriptionEn: 'View wholesale tier prices and minimum quantities',
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: pricingManage,
      nameAr: 'إدارة التسعير الشامل (Bulk Pricing)',
      nameEn: 'Bulk pricing management',
      descriptionAr: 'تطبيق زيادات أو تخفيضات جماعية على أسعار الأصناف',
      descriptionEn: 'Apply bulk price adjustments across catalog',
      group: PermissionGroup.products,
      isSensitive: true,
    ),
    PermissionItem(
      key: pricingRates,
      nameAr: 'إدارة العملات وأسعار الصرف المرجعية',
      nameEn: 'Manage exchange rates & reference currency',
      descriptionAr: 'تعديل أسعار صرف العملات المرجعية في النظام',
      descriptionEn: 'Update reference currency exchange rates',
      group: PermissionGroup.products,
    ),

    // Contacts
    PermissionItem(
      key: contactsView,
      nameAr: 'عرض العملاء والموردين',
      nameEn: 'View contacts list',
      descriptionAr: 'تصفح سجل العملاء والموردين وأرقام هواتفهم',
      descriptionEn: 'Browse customers and suppliers list and contact info',
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsManage,
      nameAr: 'إضافة وتعديل العملاء والموردين',
      nameEn: 'Create and edit contacts',
      descriptionAr: 'تسجيل عميل أو مورد جديد وتعديل بيانات الاتصال',
      descriptionEn: 'Add customer/supplier and update details',
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsDelete,
      nameAr: 'حذف العملاء والموردين',
      nameEn: 'Delete contacts',
      descriptionAr: 'حذف جهات الاتصال غير المرتبطة بمعاملات',
      descriptionEn: 'Delete contacts not referenced in documents',
      group: PermissionGroup.contacts,
    ),
    PermissionItem(
      key: contactsViewBalances,
      nameAr: 'الاطلاع على مديونيات وحسابات العملاء والموردين',
      nameEn: 'View balances, debts, and account statements',
      descriptionAr: 'عرض إجمالي ديون العملاء ومستحقات الموردين وكشف الحساب',
      descriptionEn: 'View receivables, payables, and account statements',
      group: PermissionGroup.contacts,
      isSensitive: true,
    ),

    // Dashboard
    PermissionItem(
      key: dashboardViewTotals,
      nameAr: 'عرض إجماليات المبيعات والأرباح بالرئيسية',
      nameEn: 'View dashboard totals and revenue metrics',
      descriptionAr: 'إظهار بطاقات إجمالي مبيعات اليوم والديون بالرئيسية',
      descriptionEn: 'Show sales revenue cards and summary metrics on home',
      group: PermissionGroup.dashboard,
      isSensitive: true,
    ),

    // Reports
    PermissionItem(
      key: reportsViewSales,
      nameAr: 'تقرير المبيعات وحركة الفواتير',
      nameEn: 'Sales report',
      descriptionAr: 'عرض تقرير المبيعات التفصيلي مع المجموع',
      descriptionEn: 'View detailed sales and invoice reports',
      group: PermissionGroup.reports,
    ),
    PermissionItem(
      key: reportsViewPurchases,
      nameAr: 'تقرير المشتريات والمصروفات',
      nameEn: 'Purchases report',
      descriptionAr: 'عرض إجماليات المشتريات ومصروفات العمليات',
      descriptionEn: 'View purchases spending and supplier orders',
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewReceivables,
      nameAr: 'تقرير الديون والمستحقات',
      nameEn: 'Receivables and payables report',
      descriptionAr: 'تقرير أرصدة ومطالبات العملاء والموردين',
      descriptionEn: 'View aging debts and supplier balances',
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewInventoryCost,
      nameAr: 'تقرير تقييم المخزون وأرباح الأصناف',
      nameEn: 'Inventory valuation and profit reports',
      descriptionAr: 'عرض قيمة المخزون بسعر الشراء وصافي أرباح المنتجات',
      descriptionEn: 'View inventory cost valuation and product gross profits',
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsViewFinancials,
      nameAr: 'التقارير المالية (قائمة الدخل والميزانية)',
      nameEn: 'Financial statements (Income Statement & Balance Sheet)',
      descriptionAr: 'الاطلاع على قائمة الدخل، الميزانية العمومية، وميزان المراجعة',
      descriptionEn: 'View Income Statement, Balance Sheet, and Trial Balance',
      group: PermissionGroup.reports,
      isSensitive: true,
    ),
    PermissionItem(
      key: reportsExportPdf,
      nameAr: 'تصدير وطباعة تقارير PDF',
      nameEn: 'Export and print PDF reports',
      descriptionAr: 'طباعة أو مشاركة تقارير الأعمال كملفات PDF',
      descriptionEn: 'Print or share business reports as PDF documents',
      group: PermissionGroup.reports,
    ),

    // Data
    PermissionItem(
      key: dataExportCsv,
      nameAr: 'تصدير البيانات إلى ملفات CSV / Excel',
      nameEn: 'Export data to CSV / Excel',
      descriptionAr: 'تصدير قائمة الأصناف والبيانات إلى ملفات خارجية',
      descriptionEn: 'Export catalog and records to external spreadsheets',
      group: PermissionGroup.data,
      isSensitive: true,
    ),
    PermissionItem(
      key: dataImportCsv,
      nameAr: 'استيراد البيانات من ملفات CSV',
      nameEn: 'Import data from CSV',
      descriptionAr: 'إدخال أصناف وقوائم أسعار من ملفات CSV خارجية',
      descriptionEn: 'Batch import products and prices from CSV',
      group: PermissionGroup.data,
    ),

    // System & Backup
    PermissionItem(
      key: backupCreate,
      nameAr: 'إنشاء نسخة احتياطية (.waraq)',
      nameEn: 'Create database backup (.waraq)',
      descriptionAr: 'تصدير نسخة احتياطية محلية أو إلى Google Drive',
      descriptionEn: 'Generate encrypted or local backup archives',
      group: PermissionGroup.system,
      isSensitive: true,
    ),
    PermissionItem(
      key: backupRestore,
      nameAr: 'استعادة النسخة الاحتياطية (حساس)',
      nameEn: 'Restore database backup (Sensitive)',
      descriptionAr: 'استرجاع قاعدة البيانات ومسح البيانات الحالية',
      descriptionEn: 'Restore database from backup file, replacing local data',
      group: PermissionGroup.system,
      isSensitive: true,
    ),
    PermissionItem(
      key: systemRepair,
      nameAr: 'أدوات الفحص والإصلاح وتشخيص القاعدة',
      nameEn: 'Diagnostics and database repair tools',
      descriptionAr: 'تشغيل إصلاحات جدولية وتصدير سجل التشخيص',
      descriptionEn: 'Run database health diagnostics and repair scripts',
      group: PermissionGroup.system,
      isSensitive: true,
    ),
    PermissionItem(
      key: accountingPeriodLock,
      nameAr: 'إقفال الفترات المحاسبية (Period Lock)',
      nameEn: 'Accounting period closing and lock',
      descriptionAr: 'تحديد تاريخ إقفال الحسابات لمنع التعديل السابق',
      descriptionEn: 'Set books closed date preventing past mutations',
      group: PermissionGroup.system,
      isSensitive: true,
    ),

    // Settings
    PermissionItem(
      key: settingsManage,
      nameAr: 'تعديل بيانات المنشأة والإعدادات العامة',
      nameEn: 'Business profile and general settings',
      descriptionAr: 'تغيير اسم المنشأة، الشعار، والخيارات العامة',
      descriptionEn: 'Update store profile, branding, and global settings',
      group: PermissionGroup.settings,
      isSensitive: true,
    ),
    PermissionItem(
      key: paymentMethodsManage,
      nameAr: 'إدارة طرق الدفع والحسابات',
      nameEn: 'Manage payment methods',
      descriptionAr: 'تفعيل وإضافة طرق دفع نقدية أو بنكية مخصصة',
      descriptionEn: 'Configure payment methods and bank options',
      group: PermissionGroup.settings,
    ),
    PermissionItem(
      key: taxProfilesManage,
      nameAr: 'إدارة الملفات الضريبية ونسب الضريبة',
      nameEn: 'Manage tax profiles',
      descriptionAr: 'إنشاء وتعديل ملفات ونسب ضريبة القيمة المضافة',
      descriptionEn: 'Configure tax profiles and VAT rates',
      group: PermissionGroup.settings,
    ),

    // Access & Admin
    PermissionItem(
      key: auditView,
      nameAr: 'الاطلاع على سجل النشاط والرقابة (Audit Trail)',
      nameEn: 'View activity and audit trail',
      descriptionAr: 'تصفح سجل العمليات وسلسلة التحقق الرقمية',
      descriptionEn: 'Review system activity log and tamper-evident chain',
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: usersManage,
      nameAr: 'إدارة المستخدمين وكلمات المرور',
      nameEn: 'Manage users and credentials',
      descriptionAr: 'إضافة موظفين، تعيين الأدوار، وإعادة ضبط كلمات المرور',
      descriptionEn: 'Create users, assign roles, and reset credentials',
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: rolesManage,
      nameAr: 'إدارة الأدوار ومصفوفة الصلاحيات',
      nameEn: 'Manage roles and permission matrix',
      descriptionAr: 'إنشاء أدوار مخصصة وتعديل صلاحيات الأدوار',
      descriptionEn: 'Create custom roles and customize permissions',
      group: PermissionGroup.access,
      isSensitive: true,
    ),
    PermissionItem(
      key: licenseManage,
      nameAr: 'إدارة الترخيص والتفعيل (Pro Activation)',
      nameEn: 'License and Pro subscription management',
      descriptionAr: 'إدخال مفاتيح التفعيل وإدارة ترخيص التطبيق',
      descriptionEn: 'Activate license keys and manage subscription',
      group: PermissionGroup.access,
      isSensitive: true,
    ),
  ];

  static final Map<String, PermissionItem> _byKey = {
    for (final item in all) item.key: item,
  };

  /// Returns [PermissionItem] for [key] if registered, null otherwise.
  static PermissionItem? get(String key) => _byKey[key];

  /// Returns all permission keys registered in the system.
  static Set<String> get allKeys => _byKey.keys.toSet();

  /// Groups registered permissions by their [PermissionGroup].
  static Map<PermissionGroup, List<PermissionItem>> get byGroup {
    final map = <PermissionGroup, List<PermissionItem>>{};
    for (final item in all) {
      map.putIfAbsent(item.group, () => []).add(item);
    }
    return map;
  }
}

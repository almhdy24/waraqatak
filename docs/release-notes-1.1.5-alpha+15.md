# Release notes — 1.1.5-alpha+15

Alpha pre-release delivering Wholesale and Retail Pricing tiers, Custom Sales Units with conversion factors, Base Currency locking safeguards, multi-currency reporting isolation, safe legacy costing replay (migration v20), and database diagnostic navigation fixes.

## English (en-US)

• Wholesale & Retail Pricing Architecture: Introduced a complete multi-tier pricing framework. Business-level wholesale toggle, product-level wholesale pricing with optional minimum base-quantity thresholds, and customer-level default pricing tiers (Retail/Wholesale) with per-item manual overrides.
• Custom Sales Units & Conversion Factors: Added flexible sales packaging units per product (e.g. 1 Carton = 10 Pieces, 1 Box = 24 Units). Supports distinct retail and wholesale prices per unit with real-time stock limits and inventory movements tracked strictly in base units.
• POS & Quick Sale Upgrades: Point-of-sale cart and Quick Sale screens allow selecting packaging units per line, instant tier switching, and multi-line stock deduction against physical inventory limits.
• Database Schema & Migrations v20–v23:
  - Migration v20: Safe legacy costing replay for clean historical valuation.
  - Migration v21: Permanent base currency lock once financial transactions or inventory movements exist, preventing accidental data corruption.
  - Migration v22: Wholesale pricing toggles and customer tier columns.
  - Migration v23: `product_units` table and `document_items` unit snapshot columns (`sale_unit`, `unit_conversion_factor`, `base_quantity`).
• Multi-Currency Reporting Isolation: Product performance and sales reports isolate revenue and costs per currency, completely eliminating cross-currency nominal addition.
• CSV Import & Export Compatibility: Product CSV import and export fully support wholesale prices, wholesale minimum quantities, and serialized custom sales units while maintaining backward compatibility with legacy spreadsheets.
• PDF Custom Unit Rendering: Invoice and receipt PDF tables render custom packaging unit names directly beside line quantities.
• Database Diagnostic Navigation Fix: Resolved mock/database initialization safety in product diagnostics navigation.

## العربية (ar)

• نظام تسعير الجملة والتجزئة: بنية متكاملة لأسعار الجملة والتجزئة تشمل مفتاح تفعيل التسعير على مستوى المنشأة، وتحديد سعر الجملة والحد الأدنى للكمية لكل منتج، وتصنيف العملاء (تجزئة / جملة) مع إمكانية التعديل اليدوي لكل بند.
• وحدات البيع المخصصة ومعاملات التحويل: دعم إضافة وحدات تعبئة وبيع فرعية لكل منتج (مثل كرتونة = 10 قطع، دستة = 12 قطعة) مع تحديد سعر تجزئة وجملة مستقل لكل وحدة، مع خصم المخزون بدقة تامة بالوحدات الأساسية.
• نقاط البيع والبيع السريع (POS): تحديث سلة البيع السريع لدعم اختيار وحدة البيع لكل بند، والتبديل السريع بين فئات الأسعار، والتحقق الصارم من توفر المخزون الفعلي.
• ترقيات وهجرات قاعدة البيانات (v20 إلى v23):
  - الهجرة v20: إعادة احتساب تكاليف المخزون التاريخية بطريقة آمنة وذرية.
  - الهجرة v21: قفل العملة الأساسية بشكل دائم بمجرد تسجيل أول حركة مالية أو مخزنية لحماية سلامة الحسابات.
  - الهجرة v22: جداول وأعمدة تسعير الجملة والتجزئة وتصنيف العملاء.
  - الهجرة v23: جدول وحدات المنتجات `product_units` وتوثيق لقطات وحدات البنود في المستندات.
• عزل التقارير متعددة العملات: منع الجمع الاسمي بين العملات المختلفة في تقارير أداء المنتجات وفصل الإيرادات وهوامش الربح لكل عملة على حدة.
• تصدير واستيراد CSV متوافق: دعم حقول أسعار الجملة ووحدات البيع في ملفات Excel وCSV مع التوافق التام مع الملفات القديمة.
• إظهار وحدات البيع في طباعة الفواتير: إظهار اسم وحدة البيع المخصصة بجوار الكمية في جداول فواتير وإيصالات PDF.
• تصحيح أمان الفحص التشخيصي: معالجة التهيئة الآمنة لقاعدة البيانات عند فحص المنتجات وتشخيص السجلات.

## Version

| | |
|---|---|
| Previous release | `1.1.4+13` |
| This release | `1.1.5-alpha+15` (`pubspec.yaml`) |

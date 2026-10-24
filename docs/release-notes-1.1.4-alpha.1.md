# Release notes — 1.1.4-alpha.1 (build 8)

Alpha pre-release introducing Google Drive cloud backup & restore and accounting calculation accuracy hardening.

## English (en-US)

- **Google Drive Backup & Restore (Alpha)**: Cloud backup to Google Drive AppData folder with automatic authentication and error handling.
- **Monetary Precision**: Exact minor-unit monetary rounding and payment settlement consistency across invoices, purchases, POS, and account balances.
- **Proportional Discount Allocation**: Numerically overflow-safe proportional allocation of invoice-level discounts across line items in product performance reports.
- **Multi-Currency Clarity**: Added currency disclosures and notices on product performance reports when multiple transaction currencies are detected.
- **General Ledger Integrity**: Proper balance sheet treatment for receipts linked to cancelled invoices, preventing negative accounts receivable and aligning 1-to-1 with customer account statements.

## العربية (ar)

- **النسخ الاحتياطي السحابي عبر Google Drive (نسخة تجريبية)**: دعم النسخ الاحتياطي واستعادة البيانات عبر مجلد بيانات التطبيق في Google Drive مع تهيئة تلقائية لتسجيل الدخول ومعالجة الأخطاء.
- **دقة الحسابات المالية**: ضبط دقيق لتقريب الوحدات النقدية الصغرى وتسوية المدفوعات عبر الفواتير والمشتريات ونقاط البيع وأرصدة الحسابات.
- **توزيع الخصومات بدقة عددية**: توزيع نسبي آمن ضد الطفح العددي للخصومات على مستوى الفاتورة عبر بنود المنتجات في تقارير أداء المنتجات.
- **وضوح التقارير متعددة العملات**: إضافة تنبيهات وإفصاحات شفافة في تقارير أداء المنتجات عند وجود معاملات بعملات متعددة.
- **سلامة دفتر الأستاذ العام**: تصحيح المعالجة المحاسبية لسندات القبض المرتبطة بفواتير ملغاة لمنع الأرصدة المدينة السالبة وضمان التطابق التام 1-إلى-1 مع كشوف حسابات العملاء.

## Version

| | |
|---|---|
| Previous release | `1.1.3+7` |
| This release | `1.1.4-alpha.1+8` (`pubspec.yaml`) |

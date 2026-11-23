# Changelog

All notable changes to the Waraqatak (ورقتك) project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Reports Modernization & Hardening
- **N+1 Costing Query Elimination:** Replaced per-document item query loop in `InventoryCostingService.getSalesReportWithCost` with a single batch `IN (...)` chunked query (250 items/chunk), preserving async non-blocking execution while eliminating SQLite variable limit risks.
- **Reports Access Control & Security Hardening:**
  - Wrapped 7 previously unguarded report screens (`AccountingScreen`, `CustomerReportScreen`, `SupplierReportScreen`, `InventoryReportScreen`, `ProductReportScreen`, `PurchasesReportScreen`, `SalesReportScreen`) in `ScreenAccessGate`.
  - Realigned permissions: Gated Customer and Supplier reports by `reports.view_receivables` instead of customer management permissions; corrected Low Stock report permission from `stock.adjust` (write) to `products.view` (read).
  - Fixed Payments Report visibility leak where default Cashier role could view financial payments.
- **Universal Date Range Synchronization:**
  - Introduced session-scoped `ReportsDateNotifier` and `ReportsDateScope` (`InheritedNotifier`) persisting the active date range across all reports without disk I/O.
  - Enlarged quick date filter touch targets to >= 48 dp with `MaterialTapTargetSize.padded`.
- **Universal Data Export:**
  - Implemented standard RFC 4180 CSV export in `CsvService` with UTF-8 BOM for Microsoft Excel compatibility and sanitized formula injection prefixes (`=`, `+`, `-`, `@`, `\t`, `\r`).
  - Added support for 80mm thermal receipt roll format (`PdfPageFormat.roll80`) alongside standard A4 in `PdfReportBuilder` and `PdfService`.
  - Added uniform `ReportExportMenu` (Print, Share PDF, 80mm roll, WhatsApp text summary, CSV export) to every report screen.
- **New Reports & Analytics:**
  - **Daily Closing Report (`DailyClosingReportScreen`):** Daily register summary separating current-invoice cash from debt collection on prior credit sales, breakdown by payment method (Cash vs Bankak), live cash drawer reconciliation with surplus/shortage variance feedback, and PDF/CSV export.
  - **Receivables & Payables Aging Report (`AgingReportScreen`):** Standard 4-bucket aging analysis (0–30, 31–60, 61–90, 90+ days from invoice date) for customer receivables and supplier payables with one-tap WhatsApp payment reminders.
  - **Taxes & Discounts Summary Report (`TaxDiscountReportScreen`):** Comprehensive accounting summary of sales tax collected, purchase tax paid, net tax liability, sales discounts given, and purchase discounts received with complete transaction drilldown.
  - **Payment Methods Cash Flow:** Integrated payment method cash flow chips and `AppPercentageBar` in Payments Report, and enabled click-through drilldown for standalone expense/receipt vouchers.
  - **Sales Report Period Comparison:** Added growth delta indicator (`+X.X% vs previous period`) computed against prior period of equal length.
- **UI/UX Polish & Consistency:**
  - Replaced cramped horizontal summary chips with responsive `AppMetricCard(compact: true)` across Sales, Purchases, Customers, and Suppliers reports.
  - Integrated debounced search (300ms) with sequence counters to prevent race conditions.
  - Added `RefreshIndicator` pull-to-refresh on all report lists.
  - Added direct drilldown navigation to `StockMovementsScreen` from inventory and product performance cards.
  - Replaced all inline language ternaries with localized `AppLocalizations` getters.

## [1.2.1] - 2026-11-22

### ما الجديد في الإصدار 1.2.1:
• تحسينات محاسبية شاملة لدقة التكاليف، والضرائب، وتسجيل الدفعات، وسلامة كشوف الحسابات.
• تحسين تجربة إدخال رمز PIN وتوافق الشاشة في الوضع الأفقي وعلى الشاشات الصغيرة.
• مرونة وسلاسة أكبر في تعديل بيانات العملاء وأسعار المنتجات.
• تحسين توافق الواجهة مع إعدادات تكبير الخط وإمكانية الوصول.
• تنقيح الترجمة العربية والإنجليزية وتحسينات شاملة في الاستقرار وسرعة الأداء.

### Accounting Hardening & Audit Remediation (ACC-01..12)
- **Net Unit Cost for Tax-Inclusive Purchases (ACC-02):** Deduct input VAT before writing stock movement cost so stock ledger reflects true net cost.
- **Customer Deposits Liability for Unallocated Receipts (ACC-09):** Direct unallocated customer payment receipts to Account 2130 (Customer Deposits) instead of payables or revenue.
- **Inventory Opening Equity Entry on Cost Reconciliation (ACC-10):** Post opening equity balanced journal entries for historical inventory discrepancies.
- **Sale Return Cost Restoration (ACC-12):** Restore inventory valuation using exact historical sale line snapshot unit cost on sales item reduction or cancellation.
- **Standalone Voucher Reporting (ACC-03):** Include standalone expense and receipt vouchers in period financial summaries and cash flow reports.
- **Customer Statements Completeness (ACC-05):** Include unallocated customer payment advances on customer statements.
- **Voucher Deletion Safety Guard (ACC-06):** Prohibit hard deletion of allocated payment vouchers with guided cancellation instructions.
- **Multi-Rate Tax Representation (ACC-11):** Prevent misleading single-rate tax display on documents featuring items with differing tax rates.
- **Zero-Total Invoices COGS & Inventory Posting (ACC-04):** Post inventory and cost of goods sold for zero-total 100% discount promotions.
- **Stock Adjustment Currency Decimals (ACC-08):** Ensure stock adjustment valuations use accurate currency minor units.

### User Experience & Interface Refinements (UX-01..16)
- **Landscape PIN Screen (UX-01):** Made PIN lock screen scrollable to eliminate layout overflow in landscape orientation.
- **Customer Details Navigation Lifecycle (UX-02):** Reload customer details in place after edit without popping back to directory.
- **Controller Lifecycle Management (UX-03, UX-07):** Wrap dialogs and bottom sheets in dedicated StatefulWidgets to prevent post-dispose controller use.
- **Bulk Pricing Undo SnackBar (UX-04):** Preserve undo SnackBar throughout batch price modifications.
- **Button Accessibility Font Scaling (UX-05):** Replace rigid fixed button heights with flexible minimum constraints to accommodate larger accessibility font scales.
- **Activation Screen Streamlined Entry (UX-06):** Responsive activation layout with autofocus on key entry.
- **Currency Validation & Localization (UX-08):** Fixed currency validation error messages and localized custom currency symbols.
- **Confirmation Flow Simplification (UX-14):** Eliminate duplicate dialog prompts on sensitive actions with single re-authentication flow.
- **Cancellation Impact Notices (UX-15):** Clear localized explanations of inventory and accounting reversals when cancelling invoices or purchases.
- **Phone Input Keyboard Type (UX-16):** Set `TextInputType.phone` on document recipient phone inputs.

### Localization & Consistency Polish
- Comprehensive Arabic and English translation refinement.
- Strictly aligned PIN validation instructions and error messages to 4-6 digits across all views.

### Fixed
- **Customer & Supplier Name Persistence on Scroll:**
  - Added `AutomaticKeepAliveClientMixin` to `ContactAutocompleteField` to preserve state and text when scrolled offscreen.
  - Added persistent controllers and initial text synchronization across `QuotationScreen`, `InvoiceScreen`, `PurchaseScreen`, and `EditDocumentScreen`.
  - Fixed custom recipient name persistence when saving documents without selecting an existing contact.

### Fixed
- **Quotation & Document Creation/Editing:**
  - Fixed product name input disappearing when typing custom/unlisted items (`ProductAutocompleteField` & `DocumentItemForm` state persistence with `AutomaticKeepAliveClientMixin`, dedicated text controller, and synchronization to item description).
  - Prevented keyboard enter/submission from silently overwriting typed product names with autocomplete suggestions.
  - Added support for separate custom product name and description persistence across quotation, invoice, purchase, and document edit flows.
  - Added stable keys (`ObjectKey`) to item forms across quotation, invoice, purchase, and edit document screens to prevent state corruption when deleting or reordering items.
  - Fixed offer validity date validation with a unified rule (>= 1 calendar day, timezone-safe UTC date difference), interactive calendar date picker with `firstDate` restriction, localized Arabic error messages (`errorValidityMinDays`, `errorValidUntilBeforeDate`), and automatic scroll-to-field on validation failure.
  - Fixed quotation discounts being zeroed out upon save in `DocumentService` (`createDocument` and `updateDocument`).
  - Added audit logging (`document_edited`) for document updates in `DatabaseHelper` and permission checks (`salesEdit`, `purchasesEdit`) on edit document screens.
  - Fixed 32px flex overflow in `AppTotalsCard` and bottom bar amount text overflow on narrow (384px) screens.

## [1.2.0] - 2026-11-16

### ما الجديد في الإصدار 1.2.0:
• خصوصية أقوى: خيار واحد بعنوان "المساهمة في تحسين التطبيق" للتحكم ببيانات التشخيص.
• رسالة موافقة أوضح عند أول تشغيل.
• الختم الرقمي والتوقيع الرقمي أصبحا من مزايا Pro، مع الحفاظ الكامل على إعداداتك وملفاتك.
• واجهة أنعم ودعم أفضل للاتجاه من اليمين إلى اليسار (RTL)، وأداء أكثر ثباتًا.
شكرًا لكل من ساهم في اختبار النسخة التجريبية!

### What's New in 1.2.0:
• Enhanced privacy: Single unified "Contribute to app improvement" toggle for diagnostic data.
• Clearer first-run consent dialog.
• Digital Stamp and Signature are now Pro features, while fully preserving your existing files and settings.
• Smoother UI, improved Right-to-Left (RTL) support, and enhanced stability.
Thank you to everyone who participated in testing the Beta release!

## [1.2.0-beta.4] - 2026-11-16

### ما الجديد في هذا الإصدار (Google Play)
• دمج خيارات التشخيص في خيار موحد "المساهمة في تحسين التطبيق" لتعزيز حماية وخصوصية البيانات.
• رسالة موافقة مبسطة وواضحة عند أول تشغيل.
• توفير ميزتي الختم الرقمي والتوقيع الرقمي حصرياً لباقة برو (Pro) مع الحفاظ التام على إعدادات وملفات المستخدمين.
• تحسينات شاملة في واجهة المستخدم ودعم الاتجاه من اليمين لليسار (RTL) وثبات الأداء.

## [1.2.0-beta.1] - 2026-11-08

> **Note:** This is a pre-release beta build (`1.2.0-beta.1+23`) for testing telemetry, error reporting, and privacy controls prior to production rollout.

### Added
- **AlmHdy Analytics Integration (v1.1.0 SDK):**
  - Offline-first telemetry using the upgraded AlmHdy Analytics Flutter SDK with configurable queue sizing (default: 500 events) and idle flush timer pause/resume.
  - Hard-coded write-only project ingestion key in AnalyticsConfig, removing the `--dart-define` key requirement while keeping the key injectable and empty by default in unit tests.
- **Dual Telemetry Channels & Independent Settings Toggles:**
  - Separated anonymous usage statistics and anonymous error reports into two distinct channels with independent toggles in Settings.
  - Legacy opt-out migration preserving prior opt-outs across both channels.
  - Channel isolation: opting out of either channel clears its enqueued events immediately without affecting the other channel.
  - Permission-gated management under `settings.manage` (hidden or view-only for restricted roles).
- **First-Run Privacy Notice:**
  - One-time non-blocking privacy notice dialog displayed on first launch after multi-user unlock.
  - Clear explanation of anonymous telemetry with direct one-tap navigation to Settings to customize preferences.
  - Notice status is persisted locally and never displayed again across updates.
- **Privacy-Preserving Error Sanitizer:**
  - Comprehensive `ErrorSanitizer` redacting phone numbers, email addresses, financial amounts in all supported currencies, customer identifiers, auth tokens, license keys, and local file system paths.
  - Fingerprint deduplication and session capping (max 20 errors per session).
  - Global error reporting integration hooking `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded` with non-blocking, fail-safe chaining.
- **Strict Invariant Protections:**
  - Multi-user lock-screen suppression (no events or error reports emitted while locked).
  - Silent failure on server rejections without crashing the app or disrupting offline workflows.

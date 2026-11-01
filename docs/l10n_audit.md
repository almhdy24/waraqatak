# Waraqatak (ورقتك) — Comprehensive Localization (l10n) Audit Report

**Branch:** `l10n/localization-polish`  
**Scope:** Step 0 Read-Only Audit (lib/, android/, test/, docs/)  
**Application Architecture:** Offline-first Flutter app for business documents with Arabic-first (RTL) primary locale and English secondary locale.  

---

## A. Coverage: Hardcoded User-Facing Strings Outside `app_localizations.dart`

An audit across all Dart source files in `lib/` identified several user-facing strings embedded directly in screen widgets, reports, and utilities rather than using `AppLocalizations`:

### 1. UI Screens & Reusable Widgets

| File | Line(s) | Hardcoded String (Literal) | Proposed AppLocalizations Key | Proposed Arabic & English |
|---|---|---|---|---|
| `lib/screens/audit_history_screen.dart` | 111 | `(بدء)` in `'${l10n.eventStocktake} (بدء)'` | `eventStocktakeStarted` | `(بدء)` / `(Started)` |
| `lib/screens/audit_history_screen.dart` | 113 | `(تسوية)` in `'${l10n.eventStocktake} (تسوية)'` | `eventStocktakeFinalized` | `(تسوية)` / `(Reconciled)` |
| `lib/screens/audit_history_screen.dart` | 115 | `(إلغاء)` in `'${l10n.eventStocktake} (إلغاء)'` | `eventStocktakeCancelled` | `(إلغاء)` / `(Cancelled)` |
| `lib/screens/payment_methods_screen.dart` | 66 | `hintText: 'مثال: بنكك، محفظة إلكترونية'` | `paymentMethodHintAr` | `مثال: بنكك، محفظة إلكترونية` / `e.g., Bankak, E-Wallet` |
| `lib/screens/payment_methods_screen.dart` | 83 | `hintText: 'e.g., Bank Transfer, E-Wallet'` | `paymentMethodHintEn` | `مثال: تحويل بنكي، محفظة إلكترونية` / `e.g., Bank Transfer, E-Wallet` |
| `lib/screens/csv_import_export_screen.dart` | 81 | `'الملف المحدد فارغ'` | `selectedFileEmpty` | `الملف المحدد فارغ` / `Selected file is empty` |
| `lib/screens/csv_import_export_screen.dart` | 312 | `'(صف غير صالح)'` | `invalidRow` | `(صف غير صالح)` / `(Invalid row)` |
| `lib/screens/csv_import_export_screen.dart` | 321 | `'سعر: ${r.salePrice} ${r.isExisting ? "• منتج موجود" : "• منتج جديد"}'` | `csvPriceRowSubtitle(price, isExisting)` | `سعر: $price ${isExisting ? '• منتج موجود' : '• منتج جديد'}` / `Price: $price ${isExisting ? '• Existing' : '• New'}` |
| `lib/screens/reports/advanced_inventory_analytics_screen.dart` | 300 | `'/يوم • '` | `perDay` | `/يوم` / `/day` |
| `lib/screens/reports/advanced_inventory_analytics_screen.dart` | 301 | `"~${it.estimatedDaysRemaining} يوم"` | `daysCount(n)` | Parameterized plural method |
| `lib/screens/reports/advanced_inventory_analytics_screen.dart` | 312 | `'طلب: ${FormatUtils.formatQuantity(...)}'` | `reorderSuggestionTag(qty)` | `طلب: $qty` / `Order: $qty` |
| `lib/screens/reports/advanced_inventory_analytics_screen.dart` | 367 | `'ممتاز! لا توجد منتجات تباع بأقل من متوسط التكلفة'` | `noProductsBelowCost` | `ممتاز! لا توجد منتجات تباع بأقل من متوسط التكلفة` / `Great! No products are sold below average cost` |
| `lib/screens/reports/advanced_inventory_analytics_screen.dart` | 392 | `'خسارة: -${_numFmt.format(loss)}'` | `lossAmount(amount)` | `خسارة: -$amount` / `Loss: -$amount` |
| `lib/screens/reports/product_report_screen.dart` | 163 | `' ($summary.unvaluedSalesCount مبيعات)'` | `salesCount(n)` | Parameterized plural method |
| `lib/widgets/app_totals_card.dart` | 68-69 | `l10n.isArabic ? 'الملخص المالي والحسابات' : 'Financial Summary & Balance'` | `financialSummaryCardTitle` | `الملخص المالي والحسابات` / `Financial Summary & Balance` |

### 2. Error & Diagnostics Layer (`lib/utils/error_utils.dart`)

In `lib/utils/error_utils.dart`, technical database and runtime exceptions are converted into user-friendly messages using inline ternaries (`l10n.isArabic ? '...' : '...'`) instead of dedicated getters in `AppLocalizations`:

| Line(s) | Current Inline Text | Proposed Key | Arabic & English |
|---|---|---|---|
| 31–32 | `'رمز المنتج (SKU) مسجل مسبقاً لمنتج آخر'` | `errorDuplicateSku` | `رمز المنتج (SKU) مسجل مسبقاً لمنتج آخر` / `Product SKU is already in use by another product` |
| 38–39 | `'هذا السجل مسجل مسبقاً في النظام، يرجى التحقق من عدم التكرار'` | `errorDuplicateRecord` | `هذا السجل مسجل مسبقاً في النظام، يرجى التحقق من عدم التكرار` / `This record already exists in the system` |
| 45–46 | `'لا يمكن إتمام العملية لوجود مستندات أو سجلات مرتبطة بهذا العنصر'` | `errorForeignKeyConstraint` | `لا يمكن إتمام العملية لوجود مستندات أو سجلات مرتبطة بهذا العنصر` / `Cannot complete operation because this item is referenced by existing records` |
| 52–53 | `'الكمية المتوفرة في المخزن غير كافية لإتمام العملية'` | `errorInsufficientStockGeneral` | `الكمية المتوفرة في المخزون غير كافية لإتمام العملية` / `Insufficient stock to complete this transaction` |
| 70–71 | `'تعذّر الاتصال بالإنترنت، يرجى التحقق من الشبكة ثم إعادة المحاولة'` | `errorNetworkConnectivity` | `تعذّر الاتصال بالإنترنت، يرجى التحقق من الشبكة ثم إعادة المحاولة` / `Could not connect to the network. Please check your internet connection` |
| 77–78 | `'استغرقت العملية وقتاً أطول من المتوقع، يرجى إعادة المحاولة'` | `errorOperationTimeout` | `استغرقت العملية وقتاً أطول من المتوقع، يرجى إعادة المحاولة` / `The operation timed out. Please try again` |
| 84–85 | `'يرجى التأكد من كتابة الأرقام والمبالغ بشكل صحيح'` | `errorInvalidNumberFormat` | `يرجى التأكد من كتابة الأرقام والمبالغ بشكل صحيح` / `Please enter valid numbers` |

### 3. PDF Header & Document Builders

In `lib/services/pdf/pdf_header_builder.dart` lines 59–83, metadata headers use inline ternaries:
- Line 59: `isArabic ? 'الرقم الضريبي:' : 'Tax ID:'` -> `pdfTaxIdLabel`
- Line 67: `isArabic ? 'رقم التسجيل الضريبي:' : 'Tax Reg:'` -> `pdfTaxRegLabel`
- Line 75: `isArabic ? 'السجل التجاري:' : 'CR:'` -> `pdfCommercialRegLabel`
- Line 83: `isArabic ? 'الفرع:' : 'Branch:'` -> `pdfBranchLabel`

### 4. License Notifications (`lib/services/license_notification_service.dart`)

Lines 109–205 construct in-app notifications with inline ternaries and contain a critical Arabic copy typo where "ورقتك" (Waraqatak) was written as "ورقك" (three times in lines 114, 136, 155). These should use dedicated methods in `AppLocalizations`.

### 5. Excluded From Audit (Intentionally Developer-Only or Stored Data)
- Database schema column names, SQL triggers, and migrations (`lib/database/`).
- Stored enum codes: `'draft'`, `'issued'`, `'paid'`, `'partially_paid'`, `'cancelled'`.
- Internal diagnostic check titles in `lib/services/database_diagnostic_service.dart` (developer diagnostic output).
- Debug logging `developer.log` and `debugPrint` calls.
- Unit and integration tests in `test/`.

---

## B. MaterialApp & Framework Localization (`lib/main.dart`)

### 1. Current Architecture
- `lib/main.dart` wraps `MaterialApp` inside `LanguageProvider` (an `InheritedWidget` holding `langCode` and `onChangeLanguage`).
- In `_WaraqatakAppState.build()`:
  - `locale: Locale(_langCode)` is passed to `MaterialApp`.
  - `supportedLocales: const [Locale('ar'), Locale('en')]` is registered.
  - `localizationsDelegates`:
    - `GlobalMaterialLocalizations.delegate`
    - `GlobalWidgetsLocalizations.delegate`
    - `GlobalCupertinoLocalizations.delegate`
- State Persistence:
  - Initial language is read asynchronously from `SharedPreferences` (`prefs.getString('language') ?? 'ar'`).
  - When the user changes language in Settings, `changeLanguage(String lang)` writes to `SharedPreferences` and calls `setState(() => _langCode = lang)`.
  - Because `LanguageProvider` is the parent of `MaterialApp`, changing `_langCode` rebuilds the entire widget tree with the new locale.

### 2. Gaps and Findings
- **Missing `localeResolutionCallback`:** If `SharedPreferences` has no stored language yet, it defaults unconditionally to `'ar'`. While Waraqatak is Arabic-first, a safe `localeResolutionCallback` allows matching device locale if supported.
- **Built-in Material Widgets Localization:**
  - DatePicker, TimePicker, PaginatedDataTable, and system text selection toolbars ("Select All", "Copy", "Paste") correctly receive Arabic localized strings because `GlobalMaterialLocalizations.delegate` is already included.
- **AppLocalizations is Not a `LocalizationsDelegate`:**
  - `AppLocalizations.of(context)` does not query `Localizations.of<AppLocalizations>(context, AppLocalizations)`.
  - Instead, it queries `LanguageProvider.of(context)` and instantiates a lightweight instance: `AppLocalizations(provider?.langCode ?? 'ar')`.
  - This avoids Flutter delegate boilerplate while ensuring immediate rebuild on language change.

---

## C. Terminology Consistency & Domain Glossary

An analysis of 824 translation pairs revealed domain variations across modules:

### 1. Occurrences Count in Current Codebase

| Concept | Variants Found in Arabic | Occurrences | Variants Found in English | Occurrences | Issues Identified |
|---|---|---|---|---|---|
| **Product / Item** | منتج / المنتجات<br>صنف / الأصناف | 54<br>8 | Product / Products<br>Item / Items | 34<br>7 | Mixed in tax help (808) & POS items count ("5 صنف"). "منتج" is dominant. |
| **Customer / Client** | عميل / العملاء | 25 | Customer / Customers | 18 | Clean and consistent across Arabic and English. No "زبون" or "Client". |
| **Supplier / Vendor** | مورد / الموردين | 18 | Supplier / Suppliers | 14 | Clean and consistent. No "بائع" used for supplier. |
| **Invoice / Bill** | فاتورة / الفواتير | 24 | Invoice / Invoices | 22 | Consistent. |
| **Quotation / Estimate** | عرض سعر / عروض الأسعار | 8 | Quotation / Quotations | 8 | Consistent. |
| **Payment Receipt / Voucher** | إيصال دفع / سند قبض<br>سند مصروف / سند صرف | 10<br>2 | Payment Receipt<br>Expense Voucher | 10<br>2 | Mostly consistent. Need to ensure "إيصال دفع" is strictly for inbound and "سند مصروف" for outbound. |
| **Stock / Inventory / Warehouse** | مخزون (Stock/Inventory)<br>مخزن (Warehouse/Store)<br>جرد (Stocktake) | 68<br>3<br>15 | Stock<br>Inventory<br>Stocktake | 36<br>17<br>15 | "مخزون" refers to goods/inventory; "مخزن" refers to physical storehouse. In 3 places "مخزن" was mistakenly used for inventory. |
| **Balance / Outstanding** | رصيد / الرصيد<br>متبقي / المتبقي | 17<br>7 | Balance<br>Remaining / Outstanding | 15<br>8 | Consistent distinction: "الرصيد" for ledger/account, "المتبقي" for invoice unpaid amount. |
| **Discount / Markdown** | خصم<br>تخفيض | 2<br>2 | Discount<br>Decrease | 2<br>2 | "خصم" for invoice discounts; "تخفيض" for bulk price decrements. Proper distinction. |
| **Tax / VAT** | ضريبة / الضريبة | 47 | Tax | 44 | Consistent. |
| **Cancel / Void** | إلغاء / ملغاة | 19 | Cancel / Cancelled | 18 | Consistent. |
| **Draft** | مسودة | 4 | Draft | 4 | Consistent. |
| **Issue / Post** | إصدار / صادرة | 9 | Issue / Issued | 9 | Consistent. |

### 2. Proposed Authoritative Glossary

| Concept | Preferred Arabic Term | Preferred English Term | Context & Rules |
|---|---|---|---|
| **Catalog Product** | **منتج** (جمع: **منتجات**) | **Product** (pl: **Products**) | Use across Catalog, Pricing, Reports, Inventory. |
| **Document Line Item** | **بند** (جمع: **بنود**) | **Item** (pl: **Items**) | Use specifically for document line rows ("إضافة بند", "3 بنود"). |
| **Customer** | **عميل** (جمع: **عملاء**) | **Customer** (pl: **Customers**) | Standard across all screens. |
| **Supplier** | **مورد** (جمع: **موردون / موردين**) | **Supplier** (pl: **Suppliers**) | Standard across all screens. |
| **Physical Location** | **مستودع / مخزن** | **Warehouse / Store** | Physical storage facility only. |
| **Goods On Hand** | **المخزون** | **Inventory / Stock** | Stock on hand, inventory valuation. |
| **Physical Count** | **جرد المخزون** | **Stocktake** | Stocktake sessions and reconciliations. |
| **Commercial Invoice** | **فاتورة** (جمع: **فواتير**) | **Invoice** (pl: **Invoices**) | Sales invoices, purchase invoices. |
| **Price Quotation** | **عرض سعر** (جمع: **عروض أسعار**) | **Quotation** (pl: **Quotations**) | Non-posting price estimates. |
| **Customer Payment** | **إيصال دفع** | **Payment Receipt** | Inbound payment from customer. |
| **Expense Payment** | **سند مصروف** | **Expense Voucher** | Outbound payment for expenses or supplier. |
| **Financial Balance** | **الرصيد** | **Balance** | Ledger and account running balances. |
| **Unpaid Portion** | **المتبقي** | **Remaining** | Unpaid balance on an invoice. |
| **Trade Discount** | **الخصم** | **Discount** | Commercial discount on invoices. |
| **Price Adjustment** | **تخفيض / زيادة** | **Decrease / Increase** | Bulk pricing modifications. |
| **Value Added Tax** | **الضريبة** | **Tax** | Standard VAT and tax profiles. |
| **Void Status** | **ملغاة** (مستند) / **إلغاء** (إجراء) | **Cancelled** (status) / **Cancel** (action) | Standard status and button label. |
| **Unposted Status** | **مسودة** | **Draft** | Unposted documents. |
| **Issued Status** | **صادرة** | **Issued** | Finalized active documents. |

---

## D. Arabic Copy Quality & Linguistic Analysis

### 1. Punctuation Inconsistencies
- **Mixed Ellipsis Styles:**
  - Standard 3-dot ASCII (`...`) used in 4 getters: `L239` (حفظ نسخة إلى...), `L856` (جاري التحقق...), `L1389` (بحث بالاسم...), `L1674` (جاري فحص...).
  - Single Unicode character (`…` U+2026) used in `L896` (جارٍ التفعيل…).
  - *Recommendation:* Normalize all ellipses to the Unicode horizontal ellipsis `…` (U+2026) or standard `...`. Standardizing on `…` provides cleaner typography and prevents line-breaking across individual dots.
- **Arabic vs Western Commas and Question Marks:**
  - Arabic comma (`،` U+060C) is correctly used in most places, but some concatenated strings in `error_utils.dart` and `csv_import_export_screen.dart` use English commas.
  - Arabic question mark (`؟` U+061F) is used consistently in dialog titles.

### 2. Spelling & Grammar Anomalies
- **Defective Noun Declension (اسم منقوص):**
  - "جاري" vs "جارٍ":
    - Line 856: `'جاري التحقق من التحديثات...'` (Incorrect formal Arabic).
    - Line 1674: `'جاري فحص قاعدة البيانات...'` (Incorrect formal Arabic).
    - Line 896: `'جارٍ التفعيل…'` (Correct formal Arabic: حذف الياء والتنوين بالكسر).
  - *Recommendation:* Normalize all instances to `'جارٍ ...'` or verbal form `'يجري ...'`.
- **App Name Misspelling:**
  - In `lib/services/license_notification_service.dart:114, 136, 155`, the app name is misspelled as `"ورقك"` instead of `"ورقتك"`.

### 3. Tone & Button Phrasing
- Buttons currently mix infinitive forms ("حفظ", "إلغاء", "تعديل") with imperative forms ("أضف منتج").
- *Recommendation:* Maintain the standard infinitive/action noun convention for primary buttons in business applications: "حفظ" (Save), "إلغاء" (Cancel), "تعديل" (Edit), "حذف" (Delete), "إضافة منتج" (Add Product).

---

## E. English Copy Quality

- **Capitalization Uniformity:**
  - Out of 699 short English strings:
    - 565 use **Title Case** ("New Invoice", "Cash Flow", "Payment Methods").
    - 127 use **Sentence case** ("Your documents, ready", "Category (e.g. Groceries)").
  - *Policy:* All action buttons, navigation tabs, section headers, dialog titles, and table headers should use **Title Case**. All helper subtitles, error messages, and descriptions should use **Sentence case**.
- **Tone:** English strings are direct, professional, and clear. No ambiguous technical abbreviations are exposed to end users.

---

## F. Plurals, Genders, and Parameterized Text

### 1. The Arabic Plural System Gap
Arabic possesses six grammatical plural categories:
1. **Zero (`0`):** `صفر منتج` or `لا توجد منتجات`
2. **One (`1`):** `منتج واحد` (not `1 منتج`)
3. **Two (`2`):** `منتجان / منتجين` (dual form, not `2 منتج`)
4. **Few (`3–10`):** `3 منتجات` (plural noun `منتجات`)
5. **Many (`11–99`):** `15 منتجاً` (singular accusative noun `منتجاً`)
6. **Other (`100+`):** `100 منتج` (singular genitive noun `منتج`)

Currently, `app_localizations.dart` has only single-form templates like:
```dart
String posItemsCount(String n) => _t('$n صنف', '$n items');
```
This produces ungrammatical Arabic ("1 صنف", "2 صنف", "5 صنف") and ungrammatical English ("1 items").

### 2. Parameterized Methods Inventory

| Method | Parameters | Current Output (ar) | Flaw / Needed Fix |
|---|---|---|---|
| `posItemsCount(n)` | `String n` | `$n صنف` | Lacks plural agreement in Arabic and English. |
| `posInStock(n)` | `String n` | `متوفر: $n` | Functional, but needs number formatting. |
| `insufficientStock(name, avail, req)` | `String, double, double` | Inline string | Bypasses `_t`; needs bidi isolation around `$name`. |
| `asOfDate(d)` | `String d` | `كما في $d` | Needs date isolation. |
| `statementWarningDetail(inv, amt, sym)` | `String, String, String` | Inline string | `#$inv` and `$amt $sym` flip in RTL sentences. |
| `whatsAppStatementCaption(...)` | 6 parameters | Inline string | Mixed Latin and Arabic names cause line-wrapping jumps. |
| `currencyConfirmMessage(currency)` | `String currency` | Inline string | Latin currency codes ("USD", "SAR") flip inside parentheses. |

---

## G. Numbers, Dates, Currency, and Bidirectional (Bidi) Text

### 1. Digit Formatting & Currency
- **Current Behavior:** Every screen constructs `NumberFormat('#,##0.##')` or `DateFormat('dd/MM/yyyy')` ad-hoc.
- **Digit Policy:** Waraqatak uses standard Western Arabic numerals (`0, 1, 2, ...`) across both Arabic and English interfaces. This is standard in modern commercial accounting software across the Middle East, North Africa, and Sudan, preventing confusion in tax IDs, bank account numbers, and barcodes.
- **Currency Placement:**
  - In Arabic: `1,500.00 ر.س` or `1,500.00 ج.س` (amount followed by currency symbol).
  - In English: `SAR 1,500.00` or `1,500.00 SDG`.

### 2. Bidirectional Text & Unicode Isolates
When an English token (e.g., invoice number `"INV-00042"` or currency code `"USD"`) or punctuation (`#`, `:`, `-`) is embedded in an Arabic RTL sentence, the Unicode Bidirectional Algorithm (UBA) can invert adjacent characters.
- Example:
  `'الفاتورة #$inv تتضمن فارقاً'`
  If `$inv` is `"INV-001"`, the `#` jumps to the right of `INV-001` or into the Arabic text.
- **Solution:** Wrap interpolated dynamic values in First Strong Isolate (`\u2068` and `\u2069`) or Left-to-Right Mark (`\u200E`):
  `'الفاتورة \u2066#$inv\u2069 تتضمن...'`

---

## H. PDF & Print Localization

- **Font & Shaping:** PDFs utilize `Tajawal` (Regular and Bold) loaded from TTF assets with the custom `ArabicTtfFont` wrapper in `lib/services/pdf/pdf_fonts.dart`. This successfully fixes the `pdf` package's isolated letter-yeh mapping bug (`U+064A` vs `U+FEF1`).
- **Table Directionality:** Handled via `PdfTextUtils.directionalText` with `pw.TextDirection.rtl`.
- **Labels:** PDF headers and footers currently contain some hardcoded strings (e.g. `'الرقم الضريبي:'`). Migrating these to `AppLocalizations` ensures complete bilingual print support.

---

## I. System-Level Strings & Platform Integration

- **Android Launcher Label:**
  - In `android/app/src/main/AndroidManifest.xml:5`: `android:label="ورقتك"` is hardcoded.
  - Currently no `res/values/strings.xml` or `res/values-ar/strings.xml` exists.
  - *Recommendation:* Safe to provide `res/values/strings.xml` (`Waraqatak`) and `res/values-ar/strings.xml` (`ورقتك`) without changing the package ID (`com.waraqatak.app`).
- **Notification Titles/Bodies:**
  - Defined in `lib/services/license_notification_service.dart`. Ready to be linked to `AppLocalizations`.

---

## J. Structure and Maintainability of `app_localizations.dart`

### 1. Historical Section Headers
Currently, 19 sections are named after engineering phases (`PHASE 3.1`, `PHASE 3.2`, `PHASE 3.3`, `Milestone 2`, `UI OVERHAUL`).
- Reorganization Plan (comments only; zero renames):
  1. `// ========== APP & BRAND ==========`
  2. `// ========== NAVIGATION & SHELL ==========`
  3. `// ========== COMMON ACTIONS & DIALOGS ==========`
  4. `// ========== DOCUMENTS & INVOICES ==========`
  5. `// ========== PRODUCTS & CATALOG ==========`
  6. `// ========== INVENTORY & STOCK ==========`
  7. `// ========== CONTACTS & CUSTOMERS ==========`
  8. `// ========== POINT OF SALE (POS) ==========`
  9. `// ========== FINANCIAL & ACCOUNTING ==========`
  10. `// ========== REPORTS & ANALYTICS ==========`
  11. `// ========== SETTINGS & BUSINESS SETUP ==========`
  12. `// ========== BACKUP & DATABASE DIAGNOSTICS ==========`
  13. `// ========== LICENSING & PRO ENTITLEMENTS ==========`
  14. `// ========== NOTIFICATIONS & SYSTEM ==========`

### 2. Multi-File Splitting Analysis
- **Option:** Split `app_localizations.dart` into domain parts using `part` / `part of`.
  - **Pros:** Smaller, focused files (~250 lines each); lighter memory footprint in Termux editors.
  - **Cons:** Any syntax issue in a part file breaks the parent library; refactoring requires updating part directives.
  - **Recommendation:** Keep `app_localizations.dart` unified during initial text polishing to minimize file tracking complexity in Termux, but reorganize internal comments cleanly.

### 3. Third-Language Extensibility
- Current architecture: `_t(String ar, String en) => langCode == 'ar' ? ar : en`.
- To support a 3rd language (e.g., French `fr`):
  - Update `_t` to `_t(String ar, String en, {String? fr}) => langCode == 'fr' ? (fr ?? en) : (langCode == 'ar' ? ar : en);`.
  - All existing getters remain 100% backwards-compatible without code churn.

---

## K. Prioritized Backlog

| ID | Finding / Task | Severity | Effort | Risk to Logic | Target Batch |
|---|---|---|---|---|---|
| **L-01** | Apply authoritative glossary ("منتج", "المخزون", "بند") to existing strings | High | M | None | **Batch L1** |
| **L-02** | Normalize punctuation (Arabic comma `،`, question mark `؟`, ellipsis `…`, no double spaces) | Medium | S | None | **Batch L1** |
| **L-03** | Fix "جاري" to "جارٍ" and fix "ورقك" app name typos | High | S | None | **Batch L1** |
| **L-04** | Extract hardcoded UI strings in audit history, CSV preview, and analytics | High | M | None | **Batch L2** |
| **L-05** | Extract hardcoded PDF header labels (`Tax ID:`, `CR:`, `Branch:`) | Medium | S | None | **Batch L2** |
| **L-06** | Extract hardcoded error messages from `ErrorUtils` into `AppLocalizations` | High | M | None | **Batch L2** |
| **L-07** | Implement standalone Arabic plural rule helper (`zero`, `one`, `two`, `few`, `many`, `other`) | High | M | None | **Batch L3** |
| **L-08** | Migrate `posItemsCount`, `daysCount`, and counted getters to plural helper | High | M | None | **Batch L3** |
| **L-09** | Standardize `insufficientStock` to use `_t` mechanism | Medium | S | None | **Batch L3** |
| **L-10** | Add Unicode directional isolates (`\u2066` / `\u2069`) for mixed-direction tokens | High | M | None | **Batch L3** |
| **L-11** | Unify `DateFormat` and `NumberFormat` across screens through `FormatUtils` | Medium | M | None | **Batch L4** |
| **L-12** | Verify RTL currency symbol placement and negative amount bidi formatting | Medium | S | None | **Batch L4** |
| **L-13** | Add unit tests in `test/services/format_utils_test.dart` for formatting behavior | Medium | S | None | **Batch L4** |
| **L-14** | Add localized Android app label via `res/values/strings.xml` and `res/values-ar/` | Low | S | Low | **Batch L5** |
| **L-15** | Verify `GlobalMaterialLocalizations` and language switching resilience | Medium | S | None | **Batch L5** |
| **L-16** | Apply glossary and bidi formatting to PDF documents and customer statements | Medium | M | None | **Batch L6** |
| **L-17** | Reorganize `app_localizations.dart` section comments by domain feature | Low | S | None | **Batch L7** |
| **L-18** | Create automated localization quality test (`test/localization/localization_quality_test.dart`) | High | M | None | **Batch L8** |

---
*Report saved to `docs/l10n_audit.md`. Awaiting user approval of glossary and implementation plan before proceeding to Batch L1.*

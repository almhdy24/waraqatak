# Waraqatak (ورقتك) — Official Localization Glossary & Style Guide

This document establishes the official terminology, stylistic conventions, and grammar rules for all current and future user-facing copy in Waraqatak (Arabic & English).

---

## 1. Domain Terminology Glossary

| Concept | Preferred Arabic | Preferred English | Usage Context & Strict Rules |
|---|---|---|---|
| **Catalog Item** | **منتج** (جمع: **منتجات**) | **Product** (pl: **Products**) | Standard across Catalog, Pricing, Inventory, Reports. Never use "صنف" for catalog items. |
| **Service Item** | **خدمة** (جمع: **خدمات**) | **Service** (pl: **Services**) | Use when distinguishing non-stocked service items from physical products. |
| **Document Line** | **بند** (جمع: **بنود**) | **Item** (pl: **Items**) | Used strictly for line item entries in documents ("إضافة بند", "3 بنود"). |
| **Customer** | **عميل** (جمع: **عملاء**) | **Customer** (pl: **Customers**) | Standard across all screens. Never use "زبون" or "Client". |
| **Supplier** | **مورد** (جمع: **موردون / موردين**) | **Supplier** (pl: **Suppliers**) | Standard across all screens. Never use "بائع". |
| **Goods On Hand** | **المخزون** | **Inventory / Stock** | Stock on hand, inventory valuation, stock movements. Never use "مخزن" to mean inventory. |
| **Physical Facility**| **مخزن** (جمع: **مخازن**) | **Warehouse / Store** | Physical storage building or room only. |
| **Physical Count** | **جرد المخزون** | **Stocktake** | Stock counting sessions and reconciliations. |
| **Commercial Invoice**| **فاتورة** (جمع: **فواتير**) | **Invoice** (pl: **Invoices**) | Sales invoices, purchase invoices. |
| **Price Quotation**| **عرض سعر** (جمع: **عروض أسعار**) | **Quotation** (pl: **Quotations**) | Non-posting price estimates. |
| **Inbound Payment** | **إيصال دفع** | **Payment Receipt** | Payment received from customer. |
| **Expense Payment** | **سند مصروف** | **Expense Voucher** | Operating expense or supplier payment. |
| **Account Balance** | **الرصيد** | **Balance** | Ledger accounts and customer statements. |
| **Unpaid Portion** | **المتبقي** | **Remaining** | Unpaid balance on a specific document. |
| **Trade Discount** | **الخصم** | **Discount** | Commercial discount on invoices. |
| **Price Adjustment**| **تخفيض / زيادة** | **Decrease / Increase** | Bulk pricing modifications. |
| **Tax** | **الضريبة** | **Tax** | Standard VAT and tax profiles. |
| **Draft Status** | **مسودة** | **Draft** | Unposted documents. |
| **Issued Status** | **صادر** (عام) / **صادرة** (فاتورة)| **Issued** | Finalized active documents. |
| **Paid Status** | **مدفوع** (عام) / **مدفوعة** (فاتورة)| **Paid** | Fully paid documents. |
| **Partially Paid** | **مدفوع جزئياً** | **Partially Paid** | Partial payments recorded. |
| **Cancelled Status**| **ملغي** (عام) / **ملغاة** (فاتورة)| **Cancelled** (status) / **Cancel** (action)| Voided documents and actions. |

---

## 2. Arabic Style Rules

### Punctuation
- **Arabic Comma:** Always use Arabic comma (`،` U+060C). Never use English comma (`,`) in Arabic text.
- **Arabic Question Mark:** Always use Arabic question mark (`؟` U+061F). Never use English question mark (`?`).
- **Ellipsis:** Always use single Unicode ellipsis (`…` U+2026). Never type three separate dots (`...`).
- **Colons:** Place directly after the preceding Arabic word without leading space: `الرصيد: 500`.

### Grammar & Orthography
- **Defective Noun Declension (اسم منقوص):** In indefinite nominative/genitive states, drop the yaa and apply tanween kasr: use **`جارٍ`** (e.g. `جارٍ التحقق…`), never `جاري`.
- **App Name:** Always write **`ورقتك`** (Waraqatak). Never drop the taa (`ورقك` is incorrect).
- **Tone:** Modern Standard Arabic (فصحى معاصرة), clear, professional, concise, avoiding bureaucratic jargon.
- **Button Phrasing:** Use standard infinitive action nouns for buttons:
  - `حفظ` (Save), `إلغاء` (Cancel), `تعديل` (Edit), `حذف` (Delete), `إضافة منتج` (Add Product), `تأكيد` (Confirm).

---

## 3. English Style Rules

- **Capitalization:**
  - **Title Case:** All navigation labels, page titles, action buttons, dialog titles, table headers, and form field labels (e.g. "New Invoice", "Payment Methods", "Save Changes").
  - **Sentence case:** Sentences, subtitles, help text, descriptions, and error messages (4+ words or ending with punctuation) (e.g. "Your documents, ready", "Category (e.g. Groceries)").
- **Clarity & Brevity:** Prefer short, actionable verbs ("Scan", "Export", "Select", "Restore").

---

## 4. Number & Currency Policy

- **Digits:** Western Arabic numerals (`0, 1, 2, 3, 4, 5, 6, 7, 8, 9`) are used exclusively across both Arabic and English interfaces.
- **Currency Display:**
  - Arabic: `1,500.00 ر.س` (formatted amount followed by space and currency symbol).
  - English: `SAR 1,500.00` or `1,500.00 SDG`.

---

## 5. Bidirectional (Bidi) Text & Unicode Isolates Policy

- Dynamic tokens with neutral or LTR directionality (invoice numbers like `#INV-001`, currency codes like `USD`, phone numbers, dates) embedded in Arabic sentences must be wrapped in Unicode First Strong Isolates:
  `\u2068` (FSI) and `\u2069` (PDI).
- **Strict Prohibition:** NEVER put Unicode isolates in:
  - PDF document strings (may render as missing glyph boxes).
  - CSV exports or database values.
  - Search query strings, keys, or file names.

---

## 6. Arabic Plural System Policy

Always apply proper Arabic grammatical plurals for counted quantities:
- `0`: `لا توجد منتجات` or `صفر منتج`
- `1`: `منتج واحد` (singular noun followed by واحد)
- `2`: `منتجان / منتجين` (dual noun form without digit)
- `3–10`: `3 منتجات` (plural of few: جمع تكسير / مذكر سالم)
- `11–99`: `15 منتجاً` (singular accusative: مفرد منصوب)
- `100+`: `100 منتج` (singular genitive: مفرد مجرور)

---

## 7. Do's and Don'ts Examples

| Don't (Incorrect) | Do (Correct) | Reason |
|---|---|---|
| `جاري التحقق من التحديثات...` | `جارٍ التحقق من التحديثات…` | Defective noun declension + Unicode ellipsis |
| `يرجى إضافة صنف واحد` | `يرجى إضافة بند واحد` | Document line item is "بند", not "صنف" |
| `الكمية المتوفرة في المخزن` | `الكمية المتوفرة في المخزون` | Inventory is "المخزون"; warehouse is "المخزن" |
| `5 صنف` | `5 منتجات` | Correct plural agreement and terminology |
| `1 items` | `1 item` | English singular agreement |
| `تطبيق ورقك` | `تطبيق ورقتك` | Correct spelling of application name |
| `فاتورة, سند` | `فاتورة، سند` | Arabic comma `،` |
| `الفاتورة #$inv تتضمن` | `الفاتورة \u2068#$inv\u2069 تتضمن` | Unicode isolate prevents punctuation flipping |

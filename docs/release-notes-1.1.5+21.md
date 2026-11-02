# Release Notes — Waraqatak 1.1.5+21

## Overview / نظرة عامة
Waraqatak `1.1.5+21` delivers critical integrity fixes to the **Accounting Backbone** journal rebuild and reconciliation engines, brings direct decimal quantity input to the POS quick sale experience, and redesigns manual stock adjustments with an intuitive Add Stock (+) / Remove Stock (−) selector.

تأتي النسخة `1.1.5+21` بمعالجات جذرية لسلامة **العمود الفقري المحاسبي** في عمليات إعادة بناء القيود والتحقق من التوازن، مع إتاحة إدخال الكميات العشرية والكسرية مباشرة في نقطة البيع السريعة (POS)، وإعادة تصميم نافذة تعديل المخزون بمحدد واضح للإضافة والخصم لمنع الأخطاء وتعزيز سهولة الاستخدام.

---

## Key Highlights & Improvements / أبرز التحسينات

### 1. Journal Rebuild Parity & Account Doubling Fix (إصلاح تضاعف الأرصدة وتوازن اليومية)
- **Root Cause Resolved:** Fixed `JournalBackfillService.runBackfill()` to purge all journal lines and entries when cursor is zero (`cursor == 0`), preventing previous `live` entries and newly derived backfill entries from co-existing and doubling account balances.
- **Rollback on Parity Failure:** Ensures complete cleanup of incomplete/corrupted entries and cursor reset if trial balance parity verification fails or an exception occurs mid-backfill.
- **Reconciliation Query Accuracy:** Updated `JournalReconciliationService._checkDocumentJournalEffects()` to ignore reversed entries and correctly compute net debits/credits `(debit_minor - credit_minor)` for purchase documents.
- **Diagnostics Verification:** `DatabaseDiagnosticService.runDiagnostics()` and reconciliation reports confirm 100% exact parity with zero errors.

### 2. POS Direct Decimal Quantity Input (إدخال الكميات العشرية في البيع السريع)
- Added direct numeric decimal input in POS Quick Sale (`quick_sale_screen.dart`), allowing users to enter fractional quantities (e.g. `44.5`, `25.25`, `0.125`) directly with a decimal numeric keyboard.
- Full preservation of custom sales units, wholesale/retail pricing tiers, and unit conversions.
- Accurate PDF thermal and standard invoice rendering without unintended rounding.

### 3. Redesigned Stock Adjustment Flow (تحسين تجربة تعديل المخزون)
- Replaced manual sign typing (`+` / `−`) with a prominent, intuitive `SegmentedButton` selector: **Add Stock (+)** / **Remove Stock (−)**.
- Input is strictly positive numeric decimal; sign is applied internally to prevent user error.
- Contextual adjustment reasons (auto-switches between gain reasons and loss reasons based on the selected mode).
- Real-time stock calculation preview with RTL directional indicator, highlighting dangerous negative projections in red.
- Enforced non-negative inventory constraint with clear, localized validation.
- Added direct adjustment shortcut button in the Stock Movements report screen when inspecting specific product movements.

---

## Verification & Quality Assurance / التحقق وضمان الجودة
- **Journal Backfill & Reconciliation Tests:** `test/accounting/journal_backfill_test.dart`, `test/accounting/journal_reconciliation_test.dart` passing.
- **POS Decimal & Cart Regression Tests:** `test/services/pos_cart_test.dart`, `test/database/pos_sale_db_test.dart` passing.
- **Stock Adjustment Test Suite:** `test/database/stock_adjustment_test.dart` passing.
- **Architecture Guards & Invariants:** `test/guards/architecture_guards_test.dart`, `test/invariants/accounting_backbone_invariants_test.dart` passing (100% match).
- **Static Analysis:** `flutter analyze` — zero issues found.

---

## Version Metadata / بيانات الإصدار
- **Version:** `1.1.5`
- **Build Number:** `21`
- **Application ID:** `com.elmahdi.waraqatak`
- **Tag:** `v1.1.5+21`

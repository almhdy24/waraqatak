# WARAQATAK — REMEDIATION STATE

**Current Branch:** `integration/ref-currency`  
**Base Branches:** `remediation/full-audit` + `feat/reference-currency-pricing`  
**Database dbVersion in Current Branch:** 28  
**Backup Format Version:** 5  
**Verdict:** CONDITIONAL PASS — CI REQUIRED (integration tests never executed locally)  

---

## 1. Integration Status Overview

- **Reference Currency Pricing Integration:** COMPLETED
  - Merged `feat/reference-currency-pricing` into `integration/ref-currency` without losing fixes from `remediation/full-audit`.
  - Resolved conflicts across:
    - `lib/database/database_helper.dart`: `dbVersion = 28`; extracted `_upgradeToReferenceCurrencySchema` which runs idempotently in `oldVersion < 26 && newVersion >= 26` AND `oldVersion < 28 && newVersion >= 28`, preserving the v27 unique index migration for devices upgrading from v25 or v27.
    - `lib/screens/product_form_screen.dart`: combined reference-pricing fields and currency selector with `NumberInput.formatForInput` formatting, `NumberInput.parse` digit normalization, `AmountField` fallback for base prices, and `if (!mounted) return;` lifecycle guards.
    - `lib/services/backup_service.dart`: added `exchange_rates` to snapshot and restore tables while maintaining atomic `.tmp` staging, byte-identical failure rollback, logo safety, and `jsonEncode` plain serialization.
  - Verified reference pricing invariants: Converted prices calculated at entry/repricing time only; documents and journal entries keep immutable historical price snapshots; exchange rate modifications make zero updates to documents, items, movements, or journal entries.

---

## 2. Batch Status Overview

| Batch | Scope | Status | Notes / Blockers |
|---|---|---|---|
| **Batch 0** | Repo safety & inventory | DONE | Clean branch created; FIFO uncommitted work preserved & committed; schema collision analyzed |
| **Batch 1** | Database integrity audit | DONE | Comprehensive review of migrations, indexes, constraints, numbering races |
| **Batch 2** | Document lifecycle audit | DONE | Inspected insert, update, cancel, issue, delete; F-PERIOD-01 confirmed |
| **Batch 3** | Accounting backbone audit | DONE | JournalWriter, PostingService, Ledger, backfill, INV-14..18 verified |
| **Batch 4** | FIFO allocation verification & implementation | DONE | Supplemental D: PaymentAllocator pure Dart logic, DatabaseHelper.recordFifoPayment, DocumentService.recordFifoPayment, VoucherScreen FIFO UI & validation, l10n strings, ErrorUtils error mappings, Linux CI test suite |
| **Batch 5** | Inventory & POS audit | DONE | INV-16 single stock writer audit; POS and stock flows audited |
| **Batch 6** | IMPLEMENT: DB constraints + audit atomicity | DONE | Migration v27: unique indexes, safe de-duplication, atomic audit logging, period lock in issueDocument |
| **Batch 7** | IMPLEMENT: POS tax, purchase units, track_inventory | DONE (POS tax) / BLOCKED — USER DECISION (track_inventory) | POS tax preview parity resolved; track_inventory marked BLOCKED — USER DECISION per Override A3 (type 'service' already bypasses stock; physical untracked goods UI/costing specification needed) |
| **Batch 8** | IMPLEMENT: Arabic search, number formatting, UI error handling | DONE | ArabicSearchUtils (Alif variants, Taa Marbuta/Haa, Yaa/Alif Maqsura, Tashkeel/Tatweel removal, SQL normalize), NumberInput Arabic-Indic digits, ErrorUtils error mappings, mounted guards across screen async methods, controller disposal in bulk pricing, and AppErrorState load-failed handling in edit document |
| **Batch 9** | Deep financial review | DONE | Verified financial report queries exclude draft/cancelled, segregate currencies, round via MoneyUtils; verified CSV exports use UTF-8 BOM and import fallback to Windows-1256 |
| **Batch 10** | IMPLEMENT: Backup hardening | DONE | Single PBKDF2 key derivation per operation, strict future version rejection, post-restore PRAGMA integrity_check, atomic local backup write via staging file rename with byte-identical failure preservation, safe logo restore clearing nonexistent paths, plain JSON encoding (withIndent removed), pure unit tests passed |
| **Batch 11** | Localization | SKIPPED BY USER | Skipped per supplemental override A2; user will run dedicated language prompt |
| **Batch 12** | Licensing & entitlements | DONE | Verified UTC clock comparisons, monotonic last-seen guard, rollback protection, unreachable network offline preservation, and core offline features unblocked; 68 unit tests passed |
| **Batch 13** | Hostile review & final verdict | DONE | Adversarial git diff review, 0 analyze errors across target files, pure unit and guard tests passed twice ("Double check the Double check"); Verdict: CONDITIONAL PASS — CI REQUIRED (integration tests never executed locally) |

---

## 3. Confirmed Findings

| ID | Severity | File:Line | Description | Status |
|---|---|---|---|---|
| **F-AUDIT-01** | High | `lib/database/database_helper.dart:6732` | `logAuditEvent` silently swallowed exceptions. | FIXED in Batch 6 |
| **F-AUDIT-02** | High | `lib/database/database_helper.dart:3083, 5600` | Audit events in `adjustStock` and `recordPaymentWithReceipt` were outside transaction. | FIXED in Batch 6 |
| **F-PERIOD-01** | Critical | `lib/database/database_helper.dart:5891` | `issueDocument` did not call `assertPeriodOpen`. | FIXED in Batch 6 |
| **F-SCHEMA-01** | High | `lib/database/database_helper.dart:316` | `products.barcode` had non-unique index. | FIXED in Batch 6 (v27 unique partial index) |
| **F-SCHEMA-02** | High | `lib/database/database_helper.dart:370` | `documents.document_number` lacked UNIQUE constraint. | FIXED in Batch 6 (v27 unique index per type) |
| **F-RACE-01** | Medium | `lib/database/database_helper.dart:6253` | `getNextDocumentNumber` did not guard against existing numbers or retry. | FIXED in Batch 6 |
| **F-INVENTORY-01** | Medium | `lib/models/product.dart`, `database_helper.dart` | Missing `track_inventory` column for untracked physical products. | BLOCKED — USER DECISION per Override A3 |

---

## 4. Test Suite Execution & Verification

### Requires Linux CI (sqflite FFI) — NOT RUN in Termux
- `test/database/migration_26_28_test.dart` (NEW: covers fresh v28 install, upgrade 25->28, upgrade 27->28, and repeated onUpgrade idempotency)
- `test/database/batch6_constraints_and_audit_test.dart`
- `test/reference_pricing_db_test.dart`
- `test/database/backup_restore_db_test.dart`
- `test/database/journal_migration_test.dart`
- `test/database/custom_sales_units_phase2_test.dart`
- `test/database/wholesale_pricing_phase1_test.dart`
- `test/invariants/cancel_paid_invoice_test.dart`
- `test/services/single_base_currency_test.dart`

### Pure Dart / Unit / Widget Tests — EXECUTED and PASSING (Double Checked)
- `test/reference_pricing_math_test.dart`: 12/12 PASS (Run 1 & Run 2 identical)
- `test/services/backup_version_validation_test.dart`: 4/4 PASS (Run 1 & Run 2 identical)
- `test/services/payment_allocator_test.dart`: 15/15 PASS (Run 1 & Run 2 identical)
- `test/utils/arabic_search_utils_test.dart`: 16/16 PASS (Run 1 & Run 2 identical)
- `test/utils/number_input_test.dart`: 14/14 PASS (Run 1 & Run 2 identical)
- `test/services/license_offline_tamper_test.dart`: 20/20 PASS (Run 1 & Run 2 identical)
- `test/services/license_service_test.dart`: 48/48 PASS (Run 1 & Run 2 identical)
- `test/invariants/units_wholesale_invariants_test.dart`: PASS (Run 1 & Run 2 identical)
- `test/guards/architecture_guards_test.dart`: PASS (Run 1 & Run 2 identical)
- `test/guards/single_stock_writer_guard_test.dart`: PASS (Run 1 & Run 2 identical)

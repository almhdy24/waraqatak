# WARAQATAK — REMEDIATION STATE

**Current Branch:** `remediation/full-audit`  
**Base Commit:** `438c75a` (Batch 4 FIFO allocation commit on `fix/batch5-robustness`)  
**Main Branch HEAD:** `c60ddc4` (tag `v1.1.5+21`)  
**Database dbVersion in Current Branch:** 26  
**Backup Format Version:** 5  

---

## 1. Batch Status Overview

| Batch | Scope | Status | Notes / Blockers |
|---|---|---|---|
| **Batch 0** | Repo safety & inventory | DONE | Clean branch created; FIFO uncommitted work preserved & committed; schema collision analyzed |
| **Batch 1** | Database integrity audit | DONE | Comprehensive review of migrations, indexes, constraints, numbering races |
| **Batch 2** | Document lifecycle audit | DONE | Inspected insert, update, cancel, issue, delete; F-PERIOD-01 confirmed |
| **Batch 3** | Accounting backbone audit | DONE | JournalWriter, PostingService, Ledger, backfill, INV-14..18 verified |
| **Batch 4** | FIFO allocation verification & implementation | DONE | Supplemental D: PaymentAllocator pure Dart logic, DatabaseHelper.recordFifoPayment, DocumentService.recordFifoPayment, VoucherScreen FIFO UI & validation, l10n strings, ErrorUtils error mappings, Linux CI test suite |
| **Batch 5** | Inventory & POS audit | DONE | INV-16 single stock writer audit; POS and stock flows audited |
| **Batch 6** | IMPLEMENT: DB constraints + audit atomicity | DONE | Migration v26: unique indexes, safe de-duplication, atomic audit logging, period lock in issueDocument |
| **Batch 7** | IMPLEMENT: POS tax, purchase units, track_inventory | IN PROGRESS | POS tax parity, track_inventory (optional last item per A3) |
| **Batch 8** | IMPLEMENT: Arabic search, number formatting, UI error handling | PENDING | Arabic search normalization, AmountField consistency, unhandled async states |
| **Batch 9** | Deep financial review | PENDING | Line-by-line report queries, currencies, rounding, CSV |
| **Batch 10** | IMPLEMENT: Backup hardening | PENDING | Key derivation once, version validation, atomic swap |
| **Batch 11** | Localization | SKIPPED BY USER | Skipped per supplemental override A2; user will run dedicated language prompt |
| **Batch 12** | Licensing & entitlements | PENDING | UTC clock, offline fallback |
| **Batch 13** | Hostile review & final verdict | PENDING | Adversarial diff review, final verdict |

---

## 2. Confirmed Findings

| ID | Severity | File:Line | Description | Status |
|---|---|---|---|---|
| **F-AUDIT-01** | High | `lib/database/database_helper.dart:6732` | `logAuditEvent` silently swallowed exceptions. | FIXED in Batch 6 |
| **F-AUDIT-02** | High | `lib/database/database_helper.dart:3083, 5600` | Audit events in `adjustStock` and `recordPaymentWithReceipt` were outside transaction. | FIXED in Batch 6 |
| **F-PERIOD-01** | Critical | `lib/database/database_helper.dart:5891` | `issueDocument` did not call `assertPeriodOpen`. | FIXED in Batch 6 |
| **F-SCHEMA-01** | High | `lib/database/database_helper.dart:316` | `products.barcode` had non-unique index. | FIXED in Batch 6 (v26 unique partial index) |
| **F-SCHEMA-02** | High | `lib/database/database_helper.dart:370` | `documents.document_number` lacked UNIQUE constraint. | FIXED in Batch 6 (v26 unique index per type) |
| **F-RACE-01** | Medium | `lib/database/database_helper.dart:6253` | `getNextDocumentNumber` did not guard against existing numbers or retry. | FIXED in Batch 6 |
| **F-INVENTORY-01** | Medium | `lib/models/product.dart`, `database_helper.dart` | Missing `track_inventory` column for untracked physical products. | Remediation in Batch 7 |

---

## 3. Schema Version & Branch Collision Resolution

- `main`: `dbVersion = 25`
- `remediation/full-audit`: Migration to `dbVersion = 26` implemented:
  - Non-destructive de-duplication of barcodes & document numbers
  - `CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_unique ON products(barcode) WHERE barcode IS NOT NULL AND barcode != ""`
  - `CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_type_docnum_unique ON documents(type, document_number)`
- Next migration for Batch 7 (`track_inventory`) will be schema version 27.

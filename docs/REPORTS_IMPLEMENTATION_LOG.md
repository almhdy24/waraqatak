# Reports Improvements Implementation Log

**Branch:** `feat/reports-improvements`  
**Base Commit:** `b25831f9b1f2c9bca08df942ad7cc866469384e3`  
**Started:** 2026-11-23

---

## Batch Status Overview

- [x] **Batch A** - Performance and correctness
- [ ] **Batch B** - Permissions and gates
- [ ] **Batch C** - Localization cleanup
- [ ] **Batch D** - Export and share foundation
- [ ] **Batch E** - Shared date range across reports
- [ ] **Batch F** - Daily closing (end-of-day) report [new]
- [ ] **Batch G** - Receivables and payables aging [new]
- [ ] **Batch H** - Payments report: cash flow by method
- [ ] **Batch I** - UI/UX polish across reports
- [ ] **Batch J** - Phase 3 extras (J1: Period comparison; J2: Tax & discounts report)
- [ ] **Docs & Verification** - CHANGELOG, reports_section.md, checklist

---

### Batch A: Performance and correctness

- **Batch ID:** `batch-a`
- **Files Changed:**
  - `lib/services/inventory_costing_service.dart`: Replaced N+1 query loop with a single grouped subquery `WHERE document_id IN (SELECT id FROM documents WHERE ...)` to avoid parameter limits.
  - `lib/screens/reports/inventory_report_screen.dart`: Added 300ms debounce timer and request sequence counter (`_querySeq`) to prevent typing stutter and out-of-order async race conditions. Removed fixed `height: 40` wrappers from search and category dropdowns to prevent text scaling overflow.
  - `lib/screens/reports/product_report_screen.dart`: Removed fixed `height: 40` wrappers from category and sort-by dropdowns.
  - `test/services/sales_report_costing_test.dart`: Added unit test verifying that the optimized single-query sales report returns byte-for-byte equivalent results compared to the reference calculation.
- **Decisions Taken:**
  - Used subquery `WHERE document_id IN (SELECT id FROM documents WHERE ...)` instead of `IN (?, ...)` to completely eliminate SQLite variable limit errors on older Android devices.
  - Enforced `_querySeq` guard on `_load()` in `inventory_report_screen.dart` alongside `Timer` cancellation in `dispose()`.
- **Validation:**
  - `dart format`: 4 files formatted.
  - `dart analyze`: Clean (0 issues).
  - `tool/check_play_compliance.sh`: Play compliance guard: OK.


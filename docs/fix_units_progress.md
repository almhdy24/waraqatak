# Progress Tracker: Units & Wholesale Fixes

| Step / Fix | Status | Commit SHA | Files Changed | Checks Passed | Notes |
|---|---|---|---|---|---|
| Step 0: Inspection & Verification | DONE | - | None (`lib/` untouched) | Static audit, queries checked | Step 0 completed |
| Step 1: Red First (Characterization) | DONE | - | `test/audit/units_wholesale_audit_test.dart` (unskip Scenario 4b) | `Scenario 4b` failed as expected on unfixed code | Proved BUG-1 failure |
| FIX-1: Authoritative Stock Validator (BUG-1) | IN_PROGRESS | pending | `lib/database/database_helper.dart` | `dart analyze` (0 issues), `units_wholesale_audit_test.dart` (10/10 passed) | Solved BUG-1 |
| FIX-2: Repricing Entry Point (BUG-2) | PENDING | - | `lib/services/document_service.dart`, screens | - | - |
| FIX-3: Quotation Parity (BUG-3/GAP-1) | PENDING | - | `lib/screens/quotation_screen.dart`, etc. | - | - |
| FIX-4: Show Unit & Tier in Detail (GAP-2) | PENDING | - | `lib/screens/document_detail_screen.dart` | - | - |
| FIX-5: Bulk Pricing Unit Warning (GAP-3) | PENDING | - | `lib/screens/bulk_pricing_screen.dart` | - | - |
| FIX-6: Prevent Duplicate Unit Names (GAP-4) | PENDING | - | `lib/screens/product_form_screen.dart` | - | - |
| P1..P4: Prevention Invariants & Guards | PENDING | - | `test/invariants/`, `test/guards/`, `docs/` | - | - |
| Mutation Check & Final Report | PENDING | - | `docs/fix_units_report.md` | - | - |

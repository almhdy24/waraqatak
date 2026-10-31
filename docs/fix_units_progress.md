# Progress Tracker: Units & Wholesale Fixes

| Step / Fix | Status | Commit SHA | Files Changed | Checks Passed | Notes |
|---|---|---|---|---|---|
| Step 0: Inspection & Verification | DONE | - | None (`lib/` untouched) | Static audit, queries checked | Step 0 completed |
| Step 1: Red First (Characterization) | DONE | - | `test/audit/units_wholesale_audit_test.dart` (unskip Scenario 4b) | `Scenario 4b` failed as expected on unfixed code | Proved BUG-1 failure |
| FIX-1: Authoritative Stock Validator (BUG-1) | DONE | cfbf9e2 | `lib/database/database_helper.dart` | `dart analyze` (0 issues), `units_wholesale_audit_test.dart` (10/10 passed) | Solved BUG-1 |
| FIX-2: Repricing Entry Point (BUG-2) | DONE | 77add4a | `lib/services/document_service.dart`, `lib/screens/invoice_screen.dart`, `lib/screens/edit_document_screen.dart`, `lib/widgets/document_item_form.dart`, `lib/services/pos_cart.dart`, `lib/screens/quick_sale_screen.dart` | `dart analyze` (0 issues), `units_wholesale_fix_test.dart` (7/7 passed) | Solved BUG-2 with `resolveLinePrice` |
| FIX-3: Quotation Parity (BUG-3/GAP-1) | DONE | 92cbdc0 | `lib/screens/quotation_screen.dart` | `dart analyze` (0 issues), `units_wholesale_fix_test.dart` (7/7 passed) | Solved BUG-3/GAP-1 with quotation unit/tier parity |
| FIX-4: Show Unit & Tier in Detail (GAP-2) | DONE | 8029678 | `lib/screens/document_detail_screen.dart`, `lib/localization/app_localizations.dart` | `dart analyze` (0 issues) | Displays sale unit and tier badge on document detail lines |
| FIX-5: Bulk Pricing Unit Warning (GAP-3) | DONE | 161bf3e | `lib/screens/bulk_pricing_screen.dart`, `lib/localization/app_localizations.dart` | `dart analyze` (0 issues) | Added custom unit warning banner and dialog note; logged to skipped |
| FIX-6: Prevent Duplicate Unit Names (GAP-4) | DONE | pending | `lib/screens/product_form_screen.dart`, `lib/localization/app_localizations.dart` | `dart analyze` (0 issues) | Added dialog and save-time duplicate unit validation |
| P1..P4: Prevention Invariants & Guards | PENDING | - | `test/invariants/`, `test/guards/`, `docs/` | - | - |
| Mutation Check & Final Report | PENDING | - | `docs/fix_units_report.md` | - | - |

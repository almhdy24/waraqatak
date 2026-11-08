# Multi-User Progress
Last updated: 2026-11-08
Branch: feat/multi-user

## Batches
| # | Title | Status (TODO/IN_PROGRESS/DONE/BLOCKED) | Commit | Tests run | Notes |
|---|-------|---|---|---|---|
| 1 | Schema v29, migration, fresh-install parity | DONE | 8ed9ba1 | guard tests (12 passed), analyze (0 issues) | Schema v29, access_dao.dart, migration_29_test.dart |
| 2 | Authentication, sessions, recovery | DONE | 0f7796e | auth_service_test (8 passed), analyze (0 issues) | AuthService, SessionManager, RecoveryService, UserSessionScope |
| 3 | Permission registry, engine, AccessGuard, seeding | DONE | f8a5e39 | permission_engine_test (11 passed), architecture_guards (3 passed), analyze (0 issues) | PermissionRegistry, PermissionService, AccessGuard, AccessSeeder |
| 4 | Protected, attributed audit log | DONE | cc5f728 | audit_service_test (3 passed), architecture_guards (3 passed), analyze (0 issues) | AuditService, tamper-evident hash chain, triggers, backup_service fix |
| 5 | Write-path enforcement and attribution | DONE | 6f756e0 | access_guards_test (7 passed), architecture_guards (3 passed), analyze (0 issues) | Write-path guards, field-level price/discount checks, attribution stamping |
| 6 | Read, report and export enforcement, redaction | DONE | 819782e | redaction_test (6 passed), access_guards_test (7 passed), analyze (0 issues) | Product redaction, CSV/PDF gates, dashboard & reports filter, product form price hiding, stock movements cost hiding |
| 7 | UI and flows (Arabic RTL + English) | DONE | f40a89a | 39 tests passed, analyze (0 issues) | PinLockScreen, RecoveryScreen, MultiUserWizardScreen, UsersListScreen, UserFormScreen, RolesScreen, AuditTrailScreen, MainShell lock |
| 8 | Backup/restore, license, repair interplay | DONE | commit pending | backup_access_interplay_test (3 passed), analyze (0 issues) | Decision D7, D8, license expiry fail-closed, backup preservation |
| 9 | Phase-2 notes and final verification | IN_PROGRESS | - | - | Starting Batch 9 |

## DECISIONS
- D1: Schema v29, single migration block.
- D2: New tables use TEXT UUID PKs; created_by/updated_by are TEXT soft refs, no FK.
- D3: No backfill: NULL created_by = legacy/Owner.
- D4: One role per user in Phase 1.
- D5: Choke point = DatabaseHelper mutators + services; system context for startup/migrations/restore/repair.
- D6: Reuse waraqatak_device_id from secure storage.
- D7: audit_log delete removed from restoreBackup; triggers block UPDATE/DELETE; restore never touches access tables or audit log.
- D8: Pro lapse keeps enforcement on.
- D9: Redaction never allowed to overwrite stored costs.
- D10: Developer reset challenge deferred.

## OPEN ISSUES
(None yet)

## FILES CHANGED
(Will be tracked per batch)

## LEAK POINT CHECKLIST (audit section 5)
| Surface | Status | Guard Mechanism | Test Name |
|---|---|---|---|
| Dashboard totals (home_screen.dart) | DONE | dashboard.view_totals | PermissionGate |
| Income Statement / Balance Sheet (accounting_screen.dart) | DONE | reports.view_financials | reports_screen filter |
| Sales Report (sales_report_screen.dart) | DONE | reports.view_sales | reports_screen filter |
| Product Report (product_report_screen.dart) | DONE | reports.view_sales | reports_screen filter |
| Inventory Report (inventory_report_screen.dart) | DONE | reports.view_inventory_cost | reports_screen filter |
| Advanced Inventory Analytics (advanced_inventory_analytics_screen.dart) | DONE | reports.view_inventory_cost | reports_screen filter |
| Purchases Report (purchases_report_screen.dart) | DONE | reports.view_purchases | reports_screen filter |
| Supplier / Customer Reports (debts/balances) | DONE | contacts.view_balances | reports_screen filter |
| Product Form / Screen (purchase cost & wholesale) | DONE | products.view_cost, products.view_wholesale | redaction_test, product_form_screen preserve on save |
| Stock Movements (cost columns) | DONE | stock.view_cost | Gated in PDF export & card UI |
| Universal PDF Reports (pdf_report_builder.dart) | DONE | reports.export_pdf | redaction_test |
| Customer Statements (statement dialog & PDF) | DONE | contacts.view_balances | reports_screen filter |
| Product CSV Export (csv_service.dart) | DONE | data.export_csv, omit cost/wholesale | redaction_test |
| Database Diagnostics / Reports | DONE | system.repair | DatabaseHelper / access_guard |

## RESUME NOTE
Batch 8 completed. Starting Batch 9: Phase-2 notes, final verification & documentation.

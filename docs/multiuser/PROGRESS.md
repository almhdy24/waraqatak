# Multi-User Progress
Last updated: 2026-11-08
Branch: feat/multi-user

## Batches
| # | Title | Status (TODO/IN_PROGRESS/DONE/BLOCKED) | Commit | Tests run | Notes |
|---|-------|---|---|---|---|
| 1 | Schema v29, migration, fresh-install parity | DONE | 8ed9ba1 | guard tests (12 passed), analyze (0 issues) | Schema v29, access_dao.dart, migration_29_test.dart |
| 2 | Authentication, sessions, recovery | DONE | 0f7796e | auth_service_test (8 passed), analyze (0 issues) | AuthService, SessionManager, RecoveryService, UserSessionScope |
| 3 | Permission registry, engine, AccessGuard, seeding | DONE | f8a5e39 | permission_engine_test (11 passed), architecture_guards (3 passed), analyze (0 issues) | PermissionRegistry, PermissionService, AccessGuard, AccessSeeder |
| 4 | Protected, attributed audit log | DONE | (pending commit) | audit_service_test (3 passed), architecture_guards (3 passed), analyze (0 issues) | AuditService, tamper-evident hash chain, triggers, backup_service fix |
| 5 | Write-path enforcement and attribution | IN_PROGRESS | - | - | Starting Batch 5 |
| 6 | Read, report and export enforcement, redaction | TODO | - | - | - |
| 7 | UI and flows (Arabic RTL + English) | TODO | - | - | - |
| 8 | Backup/restore, license, repair interplay | TODO | - | - | - |
| 9 | Phase-2 notes and final verification | TODO | - | - | - |

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
| Dashboard totals (home_screen.dart) | Pending | dashboard.view_totals | - |
| Income Statement / Balance Sheet (accounting_screen.dart) | Pending | reports.view_financials | - |
| Sales Report (sales_report_screen.dart) | Pending | reports.view_sales | - |
| Product Report (product_report_screen.dart) | Pending | reports.view_inventory_cost | - |
| Inventory Report (inventory_report_screen.dart) | Pending | reports.view_inventory_cost | - |
| Advanced Inventory Analytics (advanced_inventory_analytics_screen.dart) | Pending | reports.view_inventory_cost | - |
| Purchases Report (purchases_report_screen.dart) | Pending | reports.view_purchases | - |
| Supplier / Customer Reports (debts/balances) | Pending | contacts.view_balances | - |
| Product Form / Screen (purchase cost & wholesale) | Pending | products.view_cost, products.view_wholesale | - |
| Stock Movements (cost columns) | Pending | stock.view_cost | - |
| Universal PDF Reports (pdf_report_builder.dart) | Pending | reports.export_pdf | - |
| Customer Statements (statement dialog & PDF) | Pending | contacts.view_balances | - |
| Product CSV Export (csv_service.dart) | Pending | data.export_csv, omit cost/wholesale | - |
| Database Diagnostics / Reports | Pending | system.repair | - |

## RESUME NOTE
Batch 4 completed. Starting Batch 5: Write-path enforcement and attribution.

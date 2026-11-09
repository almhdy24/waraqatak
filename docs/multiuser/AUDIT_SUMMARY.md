# Multi-User & Permissions Architecture Audit — Executive Summary

**Application:** Waraqatak (ورقتك) v1.1.5+22  
**Target Architecture:** Phase 1 (Local multi-user & role-based permissions on a single device)  
**Readiness Level:** Requires targeted architectural safeguards before Phase 1 implementation.

---

## 1. Top Architectural Risks

1. **40 UI Bypass Points (The "Open Window" Risk):**  
   40 UI screens/widgets call `DatabaseHelper.instance` directly. 9 UI screens perform direct write mutations (`insertContact`, `deleteDocument`, `deleteProduct`, `updateBusiness`, `setBooksClosedThrough`). If permissions are only enforced in service classes (`DocumentService`, etc.), non-admin users can easily bypass authorization through UI screens that touch the database directly.
2. **Migration v29 Default Backfill:**  
   Every existing record across 21 tables currently lacks a user association. Schema migration v29 must create an initial `"Owner / Admin"` record and keep new foreign keys nullable or default-backfilled to avoid bricking existing databases.
3. **Backup Restore Privilege Escalation & Data Loss:**  
   `BackupService.restoreBackup` wipes and repopulates all tables from JSON. Any user with restore access can overwrite the database, alter business ownership, or bypass PIN locks.
4. **Phase 2 Sync Incompatibilities (Immediate Architectural Debt):**  
   Auto-increment integer primary keys (`INTEGER PRIMARY KEY AUTOINCREMENT`) and sequential document counters (`document_counters`) are used everywhere. Concurrent creation on two offline devices will produce identical IDs and document numbers, causing catastrophic collisions in multi-device sync unless UUIDs/prefixed keys are introduced.

---

## 2. Recommended Insertion Points

### (A) Auth & Session Gate
* **Entry Gate:** [lib/screens/splash_screen.dart#L34-L37](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/splash_screen.dart#L34-L37). After cache pre-warming, evaluate `isMultiUserEnabled`. If false (default single-user), route immediately to `MainShell` (preserving existing friction-free startup). If true, route to `UserLoginScreen` / `PinGateScreen`.
* **State Scope:** [lib/main.dart#L125-L131](file:///data/data/com.termux/files/home/projects/waraqatak/lib/main.dart#L125-L131). Introduce `UserSessionScope` (an `InheritedWidget` alongside `LanguageProvider`) exposing `currentUser`, `userRole`, and permission checker methods to the entire widget tree.
* **Auto-Lock on Resume:** [lib/main.dart#L98-L103](file:///data/data/com.termux/files/home/projects/waraqatak/lib/main.dart#L98-L103) (`didChangeAppLifecycleState`). Check elapsed background time; if timeout exceeded, display lock screen overlay.

### (B) Permission Checks
* **Dual-Layer Enforcement:**
  1. **UI Layer:** Hide/disable action buttons and drawer tabs based on `UserSessionScope.of(context).can(...)`.
  2. **Service & Database Layer (Mandatory Gate):** Centralize authorization checks inside service methods and core `DatabaseHelper` mutators by passing `UserContext` or evaluating an ambient `SessionManager.current`. Throw `PermissionDeniedException` before touching SQLite transactions.

### (C) Audit Log
* **Schema Upgrade (v29):** Extend `audit_log` ([lib/database/database_helper.dart#L507](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L507)) with `user_id INTEGER`, `user_name TEXT`, and `device_id TEXT`.
* **Central Log Hook:** Wire audit logging directly into `DatabaseHelper.logAuditEvent` and double-entry postings in `JournalWriter.write`, capturing actor identity across all document creations, edits, cancellations, and stock movements.

---

## 3. Complete List of Service Methods Requiring Permission Guards

| Domain | Service / DAO Method | File Reference | Required Permission |
|---|---|---|---|
| **Sales & Documents** | `DocumentService.createDocument` (type: invoice) | `lib/services/document_service.dart#L72` | `sales.create` |
| | `DocumentService.updateDocument` (type: invoice) | `lib/services/document_service.dart#L291` | `sales.edit` |
| | `DocumentService.cancelDocument` / `db.cancelDocument` | `lib/services/document_service.dart#L573` | `sales.cancel` |
| | `DatabaseHelper.deleteDocument` | `lib/database/database_helper.dart#L4921` | `sales.delete` |
| | `DocumentService.updateDocumentRefundStatus` | `lib/services/document_service.dart#L591` | `sales.refund` |
| **Purchases** | `DocumentService.createDocument` (type: purchase) | `lib/services/document_service.dart#L72` | `purchases.create` |
| | `DocumentService.updateDocument` (type: purchase) | `lib/services/document_service.dart#L291` | `purchases.edit` |
| **Payments & Vouchers** | `DocumentService.recordPayment` | `lib/services/document_service.dart#L522` | `payments.record` |
| | `DocumentService.createDocument` (type: receipt / expense) | `lib/services/document_service.dart#L72` | `vouchers.create` |
| **Stock & Inventory** | `InventoryService.adjust` | `lib/services/inventory_service.dart#L26` | `stock.adjust` |
| | `DatabaseHelper.adjustStock` | `lib/database/database_helper.dart#L3486` | `stock.adjust` |
| | `StocktakeService.createSession` / `reconcile` | `lib/services/stocktake_service.dart` | `stocktake.manage` |
| | `DatabaseHelper.finalizeStocktakeSession` | `lib/database/database_helper.dart#L7975` | `stocktake.finalize` |
| **Catalog & Pricing** | `DatabaseHelper.saveProductWithUnits` | `lib/database/database_helper.dart#L2930` | `products.manage` |
| | `DatabaseHelper.deleteProduct` | `lib/database/database_helper.dart#L2961` | `products.delete` |
| | `BulkPricingService.applyBulkPriceAdjustment` | `lib/services/bulk_pricing_service.dart#L291` | `pricing.manage` |
| | `ReferencePricingDao.updateRate` | `lib/database/reference_pricing_dao.dart` | `pricing.rates` |
| **Contacts** | `DatabaseHelper.insertContact` / `updateContact` | `lib/database/database_helper.dart#L2645` | `contacts.manage` |
| | `DatabaseHelper.deleteContact` / `setContactActive` | `lib/database/database_helper.dart#L2670` | `contacts.delete` |
| **Reports & Export** | `LedgerService.getIncomeStatement` / `BalanceSheet` | `lib/services/accounting/ledger_service.dart` | `reports.view_financials` |
| | `PdfService.printOrShareReportPdf` | `lib/services/pdf_service.dart#L137` | `reports.export_pdf` |
| | `CsvService.exportProductsCsv` | `lib/services/csv_service.dart#L101` | `data.export_csv` |
| **System & Data** | `BackupService.createBackup` / `UserChosen` | `lib/services/backup_service.dart#L362` | `backup.create` |
| | `BackupService.restoreBackup` | `lib/services/backup_service.dart#L396` | `backup.restore` (Admin only) |
| | `DatabaseRepairService.repairIssue` / `repairAllSafe` | `lib/services/database_repair_service.dart` | `system.repair` (Admin only) |
| | `DatabaseHelper.setBooksClosedThrough` | `lib/database/database_helper.dart#L1797` | `accounting.period_lock` (Admin only) |
| | `DatabaseHelper.updateBusiness` | `lib/database/database_helper.dart#L2607` | `settings.manage` (Admin only) |

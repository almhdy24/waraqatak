# Phase 2 Synchronization Architecture Notes

This document specifies the transition path from Phase 1 (local multi-user on a single device) to Phase 2 (multi-device synchronization and cloud-edge collaboration).

---

## 1. Phase 1 Foundations Designed for Phase 2

Phase 1 was intentionally architected so that the introduction of multi-device synchronization will **never require a rewrite** of access control, permissions, or database schemas:

1. **UUID Primary Keys & Soft References:**
   - All access control tables (`users`, `roles`, `role_permissions`, `user_permission_overrides`, `workspaces`) use `TEXT` UUID primary keys (e.g., `user-owner`, `role-template-salesperson`, `default-workspace`).
   - Write attribution columns added in Phase 1 (`created_by`, `updated_by`) are `TEXT` soft references without foreign keys. This guarantees that importing records or synchronizing offline transactions created by a user on another device will never trigger foreign key constraint violations if that user has not yet replicated locally.

2. **Workspace Scoping:**
   - Every user and role is tagged with a `workspace_id` (`default-workspace` in Phase 1). In Phase 2, this enables multi-tenant sync boundaries and organization-level scoping.

3. **Additive, Non-Destructive Migrations:**
   - Legacy records (`created_by IS NULL`) are preserved as-is and safely attributed to the Owner at display-time. No backfill rewrite was performed.

4. **Independent Audit Log with Local Node Identity:**
   - The SHA-256 audit log tamper-evident hash chain records the originating `device_id` (`waraqatak_device_id`).

---

## 2. Catalog of Phase 2 Hazards & Mitigations

The architecture audit catalogued 7 architectural hazards that must be addressed when introducing multi-device sync:

### Hazard 1: Integer AUTOINCREMENT Primary Keys on Business Entities
- **Current State:** Tables `documents`, `products`, `contacts`, `document_items`, `document_payments`, `stock_movements`, `stocktake_items`, `journal_entries`, `journal_lines` use integer `AUTOINCREMENT` primary keys.
- **Sync Hazard:** Two independent offline devices will generate conflicting IDs (e.g. Document #14 on Device A and Document #14 on Device B).
- **Phase 2 Mitigation Strategy:**
  - Add a `global_id TEXT UNIQUE` (UUIDv4) column to existing integer-PK tables.
  - Foreign key relations across synced tables must target `global_id` or resolve through a local ID mapping translation table (`sync_id_map: entity_type, global_id, local_id`).
  - Integer PKs remain device-local row identifiers for high SQLite query performance.

### Hazard 2: Sequential Human-Readable Document Numbers (`document_counters`)
- **Current State:** Invoices and orders increment a local monotonic counter (`document_counters` table) producing sequential numbers like `INV-001`, `INV-002`.
- **Sync Hazard:** Concurrent offline document generation will create duplicate human-readable numbers.
- **Phase 2 Mitigation Strategy:**
  - Introduce node-prefixed counter formatting: e.g. `INV-A-001` (Terminal A) and `INV-B-001` (Terminal B), or allocate counter ranges from the synchronization coordinator (e.g., Terminal A: 1000-1999, Terminal B: 2000-2999).

### Hazard 3: Sequential Moving-Average Inventory Costing (INV-16)
- **Current State:** Average inventory cost is updated sequentially in SQLite per stock movement via `StockLedger.record(txn, ...)`.
- **Sync Hazard:** If Device A receives stock at cost \$10 and Device B sells stock at cost \$8 concurrently while disconnected, reconciling the chronological timeline requires re-evaluating the moving average.
- **Phase 2 Mitigation Strategy:**
  - Stock movements remain append-only and stamped with the originating node timestamp and monotonic sequence.
  - Periodic inventory reconciliation runs in the background using `InventoryCostingService` to compute post-sync revalued averages without mutating historical journal lines outside the accounting close lock.

### Hazard 4: Local Device File Paths (`logo_path`)
- **Current State:** `businesses.logo_path` and document attachments store local filesystem paths (e.g., `/data/user/0/...`).
- **Sync Hazard:** Absolute local paths are invalid across devices.
- **Phase 2 Mitigation Strategy:**
  - Store content-addressed hashes (SHA-256) of media assets in the database, with sync payloads synchronizing binary blob assets into a shared local app storage directory.

### Hazard 5: Audit Log Hash Chain Synchronization
- **Current State:** Each audit record chains `prev_hash` to the previous record's `hash`.
- **Sync Hazard:** Concurrent offline audit events cannot form a single linear hash chain without divergence.
- **Phase 2 Mitigation Strategy:**
  - Transition the linear hash chain to a Merkle Directed Acyclic Graph (DAG) or maintain per-device audit streams merged append-only by the coordinator.

### Hazard 6: Conflict Resolution Strategy (RBAC & Overrides)
- **Rule:** Last-Write-Wins (LWW) based on `updated_at` ISO-8601 timestamps with node ID tie-breaking for user profile metadata.
- **Permission Overrides:** Explicit `DENY` overrides always take precedence over `ALLOW` across all synchronized nodes.
- **Owner Protection:** The Owner account (`user-owner`) is immutable across all nodes; sync engines must reject any remote payload attempting to delete, deactivate, or demote the Owner.

### Hazard 7: Offline-First Operation & Queueing
- All local operations must succeed completely offline.
- A dedicated `sync_outbox` table will queue local mutations as idempotent JSON-serialized change events.
- Synchronization workers stream outbox payloads when connectivity is available, handling backpressure and network retries gracefully.

# Release Notes - v1.1.5+20 (Draft)

**Target Release**: Waraqatak Mobile App v1.1.5+20  
**Status**: Draft (Not tagged, pubspec unchanged)  
**Date**: November 2026  

---

### Highlights & Reliability Improvements

This release hardens the Phase 1 Accounting Backbone introduced in v1.1.5+19, focusing on transaction safety, rounding resilience, startup performance, and backup security.

#### 1. Shadow Posting Isolation & Fault Tolerance
- **Savepoint Isolation**: Shadow double-entry journal operations now execute within transactional SQLite savepoints. In the unlikely event of an unexpected journal calculation failure, the savepoint is rolled back and diagnostic logs are recorded, completely preventing shadow errors from failing or interrupting sales, purchases, payments, or cancellations.
- **Period Lock Gate Integrity**: The period-lock gate remains strictly authoritative; attempts to modify documents or stock within a locked period continue to be blocked as intended.
- **Draft Issue Posting**: Shadow journal entries are now recorded consistently when issuing saved drafts.

#### 2. Deterministic Currency & Minor-Unit Math
- **Purchase Line Rounding**: Hardened net purchase split calculations across inventory and expense lines against floating-point rounding anomalies. All journal entries maintain zero-tolerance integer minor unit debit/credit balance across all supported currency precisions.

#### 3. Startup Performance & Responsive Launch
- **Non-blocking Backfill**: Historical journal backfill is decoupled from the critical database open sequence (`onOpen`). The app splash screen and home dashboard now render immediately without waiting for historical database indexing.
- **Automatic Safety Backup**: Added pre-backfill safety backup protection and execution locking to prevent duplicate concurrent indexing.

#### 4. Backup & Restore Security
- **Restore Parity Protection**: Restoring a backup now guarantees that the `journal_reports_enabled` flag defaults to `false` until database parity is verified, ensuring users are never exposed to inconsistent reporting after data migration.
- **Diagnostic Logging**: Post-restore parity validation issues are logged directly to the audit log and diagnostic settings for proactive troubleshooting.

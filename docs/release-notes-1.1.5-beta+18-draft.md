# Release Notes — Waraqatak 1.1.5-beta+18 (Draft)

See [`docs/release-notes-1.1.5-beta+19-draft.md`](file:///data/data/com.termux/files/home/projects/waraqatak/docs/release-notes-1.1.5-beta+19-draft.md) for the complete Accounting Backbone release notes.

## Overview
Waraqatak Accounting Backbone introduces:
1. Schema v25 with persisted double-entry journal (`accounts`, `journal_entries`, `journal_lines`, `app_settings`).
2. Authoritative Single Stock Movement Writer (`StockLedger.record`).
3. Reason-coded stock adjustments with UI selector.
4. Accounting Period Lock (`books_closed_through`).
5. Continuous 8-Point Reconciliation Engine.
6. Zero-drift Parity Oracle & Report Switch (`journal_reports_enabled`).
7. Hard Invariants INV-14..INV-18.

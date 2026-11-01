# Accounting Backbone Decisions Log

This document records architectural and technical decisions made during the implementation of the Accounting Backbone.
Format: Decision | Alternatives | Why Safest | How to Reverse.

---

## Decision 1: Reversal Dating at Original Entry Date (D3)
- **Decision:** When a document or transaction is cancelled or reversed, the reversal entry is dated at the **original entry's effective_date**, while `posted_at` records the true wall-clock time (`DateTime.now()`).
- **Alternatives Considered:**
  1. Date reversal at the cancellation date (`DateTime.now()`).
  2. Delete or mutate the original journal entry.
- **Why Safest:** Dating at the original effective date maintains mathematical parity with the existing derived ledger (`ledger.dart`), which filters out cancelled documents retroactively (`d.status != cancelled`). Both rows remain in SQLite for a permanent audit trail, but period-scoped reports produce identical historical figures.
- **How to Reverse:** Change reversal posting factory in `PostingService` to use current timestamp for `effective_date`.

---

## Decision 2: Minor Unit Integer Storage for Journal Lines (D1)
- **Decision:** Store debits and credits as integer minor units (`debit_minor`, `credit_minor` INTEGER) converted using `MoneyUtils.toMinorUnits`.
- **Alternatives Considered:**
  1. Store REAL floating point numbers.
  2. Store TEXT formatted decimals.
- **Why Safest:** Eliminates IEEE 754 precision drift, epsilon discrepancies, and rounding accumulation errors in journal balance verification (`sum(debit_minor) == sum(credit_minor)`).
- **How to Reverse:** Schema migration converting columns to REAL (not recommended).

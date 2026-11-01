# Accounting & Single-Currency Skipped Items

This document records items needing an external product decision or forbidden action.
Format: Item | Reason skipped | Impact | Future resolution path.

---

## Skipped Items & Product Decisions Needed

### 1. BUG-03: Proportional Discount Apportionment in Ledger Purchase Replay
- **Location:** `lib/services/accounting/ledger.dart:421` (`_allocatedNet`)
- **Description:** Uses proportional scalar ratio `it.total / d.subtotal * (d.total - d.taxAmount)` rather than Hamilton-Hare Largest-Remainder Method (`MoneyUtils.allocateDocumentDiscount`).
- **Reason Skipped:** Under the Historical-Number Rule, changing the derived replay calculation for historical purchases would alter derived cost-of-sales figures on historical documents that had fractional-cent apportionment residuals ($\pm 0.01$). The difference is bounded to $\le 0.01$ and only affects theoretical multi-item purchases with document-level discounts. Changing historical derived numbers without a formal product decision is forbidden.
- **Impact:** Negligible ($\le 0.01$ rounding difference in derived purchase unit cost in edge cases).
- **Future Resolution Path:** If product requires 100% strict integer-cent matching between `ledger.dart` purchase unit costs and `DocumentService` discount allocation, apply `MoneyUtils.allocateDocumentDiscount` in `ledger.dart` guarded by a release milestone flag.

### 2. BUG-05: Diagnostic Check for Orphaned Payment Receipts
- **Location:** `lib/services/database_diagnostic_service.dart: Section 1`
- **Description:** Integrity check 1 does not explicitly query for `document_payments` where `document_id NOT IN (SELECT id FROM documents)`.
- **Reason Skipped:** SQLite schema foreign key constraints (`FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE`) already guarantee relational integrity at the engine level. Adding a manual orphan query is Low priority and does not represent an accounting logic error.
- **Impact:** None; SQLite engine enforces relational consistency.
- **Future Resolution Path:** Add as an additional informational query during next scheduled diagnostics expansion.

### 3. Retirement Policy for Legacy Foreign-Currency Documents
- **Description:** Historical documents created under legacy multi-currency tests or restored backups may contain currency codes different from active `businesses.currency_code`.
- **Reason Skipped (Product Decision Needed):** Per Phase 3 Rule 4, retiring or settling historical foreign-currency debt balances (e.g. converting a legacy 100 USD customer debt into the base currency SDG) requires an explicit exchange rate and human business decision (for example, creating an explicit debt adjustment document at a user-provided rate). The system strictly forbids automated currency conversion or guessing historical exchange rates.
- **Impact:** Legacy foreign documents remain safely preserved in SQLite, visible in dedicated read-only sections, and reported by Database Diagnostics (`legacy_foreign_currency_documents`).
- **Future Resolution Path:** Provide a dedicated UI wizard in a future major release allowing the business owner to enter a settlement rate and generate an explicit redenomination adjustment document.


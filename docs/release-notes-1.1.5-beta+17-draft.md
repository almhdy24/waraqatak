# Release Notes Draft — Waraqatak 1.1.5-beta+17

## Overview
This release establishes strict single base currency enforcement across Waraqatak, resolves high-priority monetary precision scaling in line items (BUG-01), adds comprehensive accounting invariant suites and runtime guards, and resolves the CI test failure on customer detail formatting.

## Key Changes & Improvements

### 1. Single Base Currency Architecture
- Business accounts now operate strictly on a single authoritative base currency (`businesses.currency_code`), locked upon recording the first transaction.
- Removed legacy multi-currency selection dropdowns from the Accounting Report and Customer Statement dialogs.
- Segregated legacy foreign-currency transactions in financial reports and period summaries, ensuring base-currency metrics remain pure without cross-currency nominal addition.
- Added diagnostic check `legacy_foreign_currency_documents` in `DatabaseDiagnosticService` to transparently identify historical foreign currency records.

### 2. Monetary Precision & Rounding (BUG-01)
- Fixed `DocumentItemInput.calculateTotal` to respect currency-specific decimal scale rather than defaulting to hardcoded 2 decimals.
- Added comprehensive oracle tests verifying integer arithmetic, half-up rounding, Hamilton-Hare largest-remainder discount apportionment, and VAT extraction.

### 3. Structural & Architectural Guards
- Added 8 structural guards (`test/guards/single_currency_guard_test.dart`) covering static UI scan, direct SQL bypass prevention, test mapping preservation, and runtime database insertion/issuance/duplication validation.
- All 901 unit, widget, and integration tests pass across the entire suite.

### 4. Accessibility & UI Polish
- Hardened `AppAmountText` with unified accessibility semantics container and explicit decimal precision formatting.

### 5. Play Compliance Guard
- Fully verified with `tool/check_play_compliance.sh`: zero Play Billing policy violations.

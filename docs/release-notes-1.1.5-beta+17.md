# Release Notes — Waraqatak 1.1.5-beta+17

## Overview
Waraqatak `1.1.5-beta+17` establishes a single authoritative base currency architecture, fixes line-total precision scaling across items, resolves the AppAmountText format regression that triggered the beta+16 CI failure, cleans up redundant settings controls and support-guide UI, and permanently sets the Android launcher app label to Arabic "ورقتك".

---

## What's New & Fixed

### 1. Single Base Currency Architecture
- **Permanent Base Currency Lock:** Financial operations operate strictly on one base currency (`businesses.currency_code`), locked upon recording the first transaction (`currency_locked_at`).
- **UI Simplification:** Removed multi-currency dropdown selectors from the Accounting Report and Customer Statement dialogs.
- **Legacy Record Preservation:** Historical documents, payments, and journals created in foreign currencies remain intact as immutable historical snapshots. They are segregated in dedicated sections in sales, purchases, payments, customer detail, and period summaries, preventing any cross-currency nominal addition. No currency conversion or artificial exchange rates are introduced.
- **Database Diagnostic Check:** Added check `legacy_foreign_currency_documents` in `DatabaseDiagnosticService` to transparently identify historical foreign currency records.

### 2. Monetary Precision & Rounding Fix (BUG-01)
- Fixed `DocumentItemInput.calculateTotal([int? digits])` to propagate currency-specific decimal scale rather than defaulting to hardcoded 2 decimals.
- Added comprehensive oracle tests covering integer arithmetic, round-half-up, and Hamilton-Hare largest-remainder discount apportionment.

### 3. Amount Formatting & Accessibility Fix (CI Failure Root-Cause)
- Resolved the `AppAmountText` formatting regression in `CustomerDetailScreen`: restored intentional integer-precision formatting for whole currency amounts via `fmt.maximumFractionDigits`.
- Added canonical getters (`formattedAmount`, `resolvedPrefix`, `fullText`) and unified `Semantics(container: true, label: resolvedSemantics, excludeSemantics: true)` accessibility tree grouping.

### 4. Settings & Support UI Cleanups
- **Financial & Legal Settings:** Removed the redundant wholesale/retail pricing toggle and card from `financial_settings_screen.dart`. The feature remains authoritatively controlled in the main Settings screen with an explicit confirmation dialog before disabling (`wholesalePricingDisableWarning`).
- **Support Guidance UI Surfaces:** Removed support guidance cards, the "Open About" button, "Copy support info" button, and reference ID lines from `activation_screen.dart`, `license_screen.dart`, `locked_feature_screen.dart`, and `pro_upgrade_sheet.dart`.
- **Underlying Plumbing Intact:** All diagnostic correlation ID capture, `SupportDiagnostics`, and error handling plumbing remain intact for headless debugging, while official support contact channels remain in `about_screen.dart`.

### 5. Android Launcher App Label
- Permanently set Android launcher name to Arabic "ورقتك" across all device language settings via `@string/app_name` in `res/values/strings.xml`, removing the redundant `values-ar` override.

---

## What Did NOT Change
- **Signing & Application ID:** `com.elmahdi.waraqatak` and release keystore configuration remain strictly untouched.
- **Database Schema:** Zero table drops, zero column removals, zero destructive updates, zero DB version bump (v23 preserved).
- **Historical Stored Totals:** Stored documents, payments, and movements remain immutable snapshots.
- **Invariants:** Stock availability checks remain authoritative in `DatabaseHelper._assertSaleStockAvailable`. Line-level repricing routes strictly through `DocumentService.resolveLinePrice`.

---

## Known Limitations & Skipped Items
- **Purchases:** Purchases do not yet support custom sales units (purchases operate in base product units).
- **Accounting Items BUG-03 & BUG-05 Skipped:** In accordance with the historical-number preservation rule, proportional discount apportionment in `ledger.dart:421` (BUG-03) and orphan payment diagnostic check (BUG-05) were deliberately skipped to protect existing ledger COGS and honor SQLite engine foreign-key constraints (documented in `docs/accounting_skipped.md`).
- **Manual Hardware Checklists:** Physical Android thermal printing and physical device touch interactions remain pending manual device verification.

---

## Upgrade Notes
- Fully compatible with the current live API (`api.almhdy24.com`).
- Offline-first capabilities remain 100% operational without network connectivity.

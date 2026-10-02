# Features

Waraqatak is an offline-first business document application.

## Current Areas

The codebase contains functionality for:

- business setup
- customers and contacts
- products
- invoices
- quotations
- payment/expense vouchers
- custom documents
- quick sale (POS) with atomic paid sale + receipt + stock deduction
- purchase orders and suppliers
- inventory: stock movements, minimum levels, adjustments
- double-entry accounting derived from documents (income statement,
  balance sheet, trial balance, account ledger)
- reports (sales, purchases, payments, customers, suppliers, inventory,
  products)
- PDF design customization (templates, colours, sections, live preview)
- document history and details
- document editing
- PDF generation
- backup and restore
- application settings
- Arabic and English localization

## Product Management

The project contains product-related models, screens, services, and autocomplete UI.

Stock-management behavior must be confirmed from the current implementation before changing it.

## Accounting

`lib/services/accounting/ledger.dart` derives a double-entry journal from
issued documents (drafts and cancelled documents are excluded). Nothing is
stored, so the books always match the documents. Posting rules, the chart of
accounts and the IAS 2 weighted-average inventory replay are documented in
the code. `LedgerService` loads one currency's books at a time.
Tests: `test/services/ledger_test.dart`, `test/database/ledger_db_test.dart`.

## Documents

Document-related code includes:

- document models
- document items
- document numbering
- validation/business logic
- document screens
- PDF generation

Do not change document calculations without tracing the existing logic.

## Rule

The source code is the source of truth.

This document should be updated when a feature is confirmed or materially changed.

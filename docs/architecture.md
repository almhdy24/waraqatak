# Waraqatak Architecture

## Product

Waraqatak (ورقتك) is an offline-first Flutter application for creating and managing business documents.

## Current Code Structure

- `lib/main.dart` — application entry point
- `lib/theme.dart` — application theme
- `lib/core/` — shared application infrastructure
- `lib/database/` — SQLite database
- `lib/models/` — application models
- `lib/screens/` — application screens
- `lib/services/` — application services
- `lib/services/pdf/` — PDF builders and PDF utilities
- `lib/services/accounting/` — derived double-entry ledger and financial statements (read-only)
- `lib/widgets/` — reusable widgets
- `lib/localization/` — localization
- `lib/utils/` — utilities

## Current Domain Models

The project currently contains models for:

- Business
- Contact
- Currency
- Document
- DocumentItem
- Product

## Document Features

The codebase contains screens and services related to:

- invoices
- quotations
- vouchers
- custom documents
- document management
- customers
- products

The exact business rules should always be confirmed from the implementation before making changes.

## Database

SQLite is used for local persistence.

Database-related code is located in:

`lib/database/database_helper.dart`

The database should be treated as user data and must not be destroyed during normal development or migration.

## PDF

PDF generation is implemented under:

`lib/services/pdf/`

The system contains separate builders for document sections and PDF utilities.

Arabic PDF rendering must remain functional.

## Localization

The application supports Arabic and English.

RTL behavior is important and must not regress.

## Important Principle

This document describes the current high-level structure only.

The source code is the source of truth.

Do not assume undocumented business rules.

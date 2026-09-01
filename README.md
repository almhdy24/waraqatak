# ورقتك | Waraqatak

Offline-first business document management app built with Flutter.

## Features

- Business profile
- Customers and contacts
- Products
- Invoices
- Quotations
- Payment and expense vouchers
- Custom documents
- PDF generation
- Backup and restore
- Arabic and English
- RTL support
- Local SQLite storage

## Structure

lib/
  core/
  database/
  localization/
  models/
  screens/
  services/
  utils/
  widgets/

assets/
android/

## Development

Requires the Flutter SDK.

    flutter pub get
    flutter analyze
    flutter test
    flutter run

## Database

SQLite: lib/database/database_helper.dart

Database changes must use migrations and preserve existing user data.

## Agent

Codex instructions: AGENTS.md

The source code is the source of truth.

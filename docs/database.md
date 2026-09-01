# Database

Waraqatak uses SQLite for local, offline-first data storage.

## Location

Database implementation:

`lib/database/database_helper.dart`

## Known Domain Tables

The current project contains database logic related to:

- businesses
- contacts
- documents
- document_items
- document_counters
- products

## Rules

- SQLite data belongs to the user.
- Never delete or recreate the database to fix a normal application problem.
- Inspect the current schema before changing it.
- Inspect the current database version and migrations before modifying tables.
- Schema changes require explicit migrations.
- Preserve existing user data.
- Consider existing installations when changing the schema.
- Keep database access out of UI screens.
- Do not introduce destructive migrations without explicit approval.

## Source of Truth

The actual implementation in `lib/database/database_helper.dart` is the source of truth.

Do not assume undocumented columns, constraints, relationships, or migration behavior.

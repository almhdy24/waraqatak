# Waraqatak — Codex Instructions

Waraqatak (ورقتك) is an offline-first Flutter app for business documents.

## Core Rules

- Inspect existing code before changing it.
- Prefer small, focused changes.
- Reuse existing models, services, widgets, and utilities.
- Do not rewrite working functionality without a clear reason.
- Do not modify unrelated files.
- Do not invent features unless requested.

## Architecture

- `lib/screens/` — UI screens and flows
- `lib/widgets/` — reusable UI components
- `lib/models/` — domain/data models
- `lib/services/` — application and business logic
- `lib/database/` — SQLite database
- `lib/localization/` — Arabic/English localization
- `lib/services/pdf/` — PDF generation
- `lib/utils/` — shared utilities
- `lib/core/` — shared infrastructure

Keep UI, business logic, and database access separated.

## Database

SQLite contains user data.

- Never delete or recreate the database to solve a problem.
- Inspect the current schema before making changes.
- Use explicit migrations for schema changes.
- Preserve existing user data.
- Do not bypass the database layer from UI code.

## Localization

Arabic and English are supported.

- Preserve RTL.
- Do not hardcode user-facing strings.
- Use the existing localization system.
- Do not break Arabic translations.

## PDF

PDF generation is a core feature.

- Preserve Arabic text rendering.
- Reuse the existing PDF builders.
- Avoid duplicating PDF logic.
- Do not redesign documents unless requested.

## Dependencies

- Do not add dependencies unnecessarily.
- Do not upgrade dependencies without a reason.
- Prefer the existing project dependencies.

## Environment

Flutter SDK is currently unavailable in this Termux environment.

- Do not assume Flutter commands are available.
- Do not install Flutter unless explicitly requested.
- Never claim that analysis, tests, or builds passed unless actually executed.
- Static inspection is allowed.

## Git

Use focused commits:

- `feat:` new functionality
- `fix:` bug fixes
- `refactor:` restructuring
- `chore:` maintenance
- `docs:` documentation
- `test:` tests

Do not rewrite history or force-push unless explicitly requested.

## Safety

Before destructive changes:

1. Inspect the current state.
2. Explain the risk.
3. Prefer a reversible solution.

Never remove existing functionality just because another implementation is preferred.

## Verification

When Flutter is available:

    flutter analyze
    flutter test

For Android changes when appropriate:

    flutter build apk --debug

When Flutter is unavailable, clearly state what could not be verified.

## Workflow

For every task:

1. Inspect relevant code.
2. Understand the existing data flow.
3. Identify the smallest safe change.
4. Make the change.
5. Review the diff.
6. Verify what is possible.
7. Summarize changed files and remaining risks.

Read `docs/architecture.md` when architectural context is needed.
Read `docs/development.md` when development workflow details are needed.

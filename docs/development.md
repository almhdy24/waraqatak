# Waraqatak Development Workflow

## Before Changes

Inspect the relevant implementation first.

Check:

- models
- services
- database code
- screens
- widgets
- localization
- PDF code

Trace the data flow before changing it.

## Database Changes

Before changing the schema:

1. Inspect the current database version.
2. Inspect existing migrations.
3. Define the required schema change.
4. Add an explicit migration.
5. Preserve existing data.
6. Review upgrade behavior.

Never delete the database as a migration strategy.

## UI Changes

Preserve:

- Material 3 direction
- Arabic RTL
- existing localization
- existing navigation
- existing functionality

Avoid unnecessary redesigns.

## PDF Changes

Inspect the existing PDF builders before modifying PDF output.

Preserve:

- Arabic fonts
- RTL
- document structure
- existing calculations

## Git

Before risky work:

    git status
    git diff

After changes:

    git status
    git diff

Keep commits focused and descriptive.

## Verification

Flutter is currently unavailable in the Termux environment.

When available, use:

    flutter analyze
    flutter test

Only report commands as successful when they actually ran successfully.

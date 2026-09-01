# Testing

## Current Environment

Flutter SDK is currently unavailable in the Termux development environment.

Therefore Flutter tests and Flutter analysis cannot currently be assumed to be available.

## When Flutter Is Available

Run:

    flutter analyze

Then:

    flutter test

For relevant Android changes:

    flutter build apk --debug

## Rules

Never report a command as passing unless it actually ran successfully.

## Before Reporting Completion

Review:

- git diff
- git status
- changed files
- database impact
- localization impact
- RTL impact
- PDF impact
- error handling

If automated verification cannot be performed, state that clearly.

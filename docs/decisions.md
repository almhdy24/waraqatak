# Architecture Decisions

This file records important project decisions.

## Offline First

The application is designed to work primarily offline.

Local SQLite storage is therefore a core part of the product.

## Local Database

SQLite is used for application data.

Database migrations must preserve existing user data.

## Localization

Arabic and English are supported.

Arabic RTL support must remain a first-class requirement.

## PDF Generation

PDF generation is part of the core application functionality.

PDF changes must preserve Arabic rendering and existing document calculations.

## Architecture

The existing project structure should be improved incrementally.

Do not perform large rewrites without a demonstrated need.

## Dependencies

Prefer existing dependencies.

New dependencies require a clear technical reason.

## Decision Log

Add future architectural decisions here with:

- date
- decision
- reason
- alternatives considered

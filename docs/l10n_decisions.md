# Localization Implementation Decisions

Record of all autonomous decisions made during localization batches L1 through L8.

Format per decision:
- **Decision:** What was chosen
- **Alternatives:** What other choices were considered
- **Why Safest:** Why this choice preserves existing behavior best
- **How to Reverse:** Steps to revert if needed

---

### Decision 1 (Batch L1): Gender-Neutral Masculine Status Labels and Terminology Normalization
- **Decision:** Updated general status getters (`statusIssued: 'صادر'`, `statusPaid: 'مدفوع'`, `statusPartiallyPaid: 'مدفوع جزئياً'`, `statusCancelled: 'ملغي'`) to masculine forms agreeing with "المستند" (The Document) because these getters are shared across heterogeneous document lists (Invoices, Quotations, Receipts, Vouchers). Preserved `statusDraft: 'مسودة'` as a gender-neutral noun. Replaced deprecated "صنف" with "منتج" (catalog item) and "بند" (document line). Normalized "جاري" to "جارٍ" and three-dots (`...`) to Unicode ellipsis (`…` U+2026).
- **Alternatives:** Keeping feminine status forms everywhere (which causes grammatical clashes when viewing masculine documents like "عرض سعر صادر" or "إيصال مدفوع") or mass-renaming getters (which violates API stability).
- **Why Safest:** Zero getter renames; preserves all database status string codes ('draft', 'issued', 'paid', 'partially_paid', 'cancelled') completely untouched. Only updates display-layer Arabic text inside existing getters.
- **How to Reverse:** In `lib/localization/app_localizations.dart`, revert string literals back to 'صادرة', 'مدفوعة', 'ملغاة'.

---

### Decision 2 (Batch L3): Zero-Dependency Arabic/English Plural Helper & Presentation-Only Bidi Isolates
- **Decision:** Implemented a zero-dependency CLDR-compliant Arabic plural category helper (`_arabicPluralCategory`) and `_plural(...)` method supporting 6 Arabic forms (zero, one, two, 3-10 few, 11-99 many, 100+ other) and standard 2-form English. Implemented `_iso(...)` (First Strong Isolate U+2068 and Pop Directional Isolate U+2069) strictly for dynamic tokens displayed in Flutter Text widgets and WhatsApp captions. Never injected into PDF templates or stored DB records.
- **Alternatives:** Adding external packages like `intl_translation` (violates constraint 4 against heavy dependencies) or doing naive string concatenations without plural forms (results in broken Arabic grammar such as "5 صنف" or reversed Latin tokens).
- **Why Safest:** Self-contained within `AppLocalizations` with zero new external dependencies; verified by dedicated unit tests in `test/localization/plural_test.dart`; preserves exact method signatures and backward compatibility.
- **How to Reverse:** In `lib/localization/app_localizations.dart`, revert `_plural` and `_iso` helpers and restore the simple string templates.

---

### Decision 3 (Batch L4): Centralized Date and Number Formatting Preserving Western Digits
- **Decision:** Standardized date presentation via centralized helpers in `FormatUtils` (`formatDate`, `formatDateTime`, `formatTimestamp`) defaulting to standard format `dd/MM/yyyy` (and `HH:mm` / `HH:mm:ss`) with Western digits (0-9) strictly preserved everywhere per user instruction. No changes were made to `MoneyUtils` or financial calculations.
- **Alternatives:** Introducing Arabic-Indic digits (١، ٢، ٣) (explicitly forbidden by instructions) or mass-editing date formatting patterns across PDF files (would risk breaking receipt/document printer layout).
- **Why Safest:** Leaves existing callers and PDF layout completely intact while providing clean, reusable formatting methods backed by unit tests.
- **How to Reverse:** Revert added helper methods in `lib/utils/format_utils.dart`.

---

### Decision 4 (Batch L5): Android String Resources & Dynamic MaterialApp Title
- **Decision:** Configured `res/values/strings.xml` ("Waraqatak") and `res/values-ar/strings.xml` ("ورقتك") with `android:label="@string/app_name"` in `AndroidManifest.xml` so Android system launchers display the correct name matching the OS device locale. Updated `MaterialApp` in `lib/main.dart` with `onGenerateTitle: (context) => AppLocalizations.of(context).appTitle` for in-app task switching title localization.
- **Alternatives:** Leaving the hardcoded Arabic label in `AndroidManifest.xml` (leads to Arabic title on English devices) or hardcoding English (leads to English title on Arabic devices).
- **Why Safest:** Zero impact on Flutter business logic; passes `tool/check_play_compliance.sh` and widget tests cleanly.
- **How to Reverse:** Restore `android:label="ورقتك"` in `AndroidManifest.xml` and delete the added resource files.

---

### Decision 5 (Batch L6): PDF Text Architecture & Strict Isolate Exclusion
- **Decision:** Verified that all PDF builders in `lib/services/pdf/` retrieve user-facing labels through `AppLocalizations` and contain zero hardcoded deprecated terms ("صنف", "مخزن"). Confirmed zero Unicode Bidi isolates (`\u2068` / `\u2069`) in `lib/services/pdf/` as Tajawal font would render them as missing glyph boxes. All directional alignment in PDF is handled structurally via `PdfTextUtils.directionalText`.
- **Alternatives:** Injecting Bidi isolates into PDF builder strings (which corrupts PDF font rendering and breaks document layout).
- **Why Safest:** Completely preserves Arabic text rendering and existing PDF layout across all templates (classic, modern, minimal) and sizes (A4, A5, Thermal 80mm).
- **How to Reverse:** N/A (verified existing architecture complies with isolate exclusion).

---

### Decision 6 (Batch L7): Section Comment Reorganization by Feature Domain
- **Decision:** Replaced all 20 legacy section comments named after historical engineering phases (e.g., "PHASE 3.1", "PHASE 3.2 — PURCHASES", "Milestone 2", "Phase 3 — Inventory Costing & Profit", "BATCH L2") with standardized functional feature domains (`PURCHASES & ORDERS`, `SUPPLIERS`, `INVENTORY & STOCK MOVEMENTS`, `DASHBOARD METRIC CARDS`, `REPORTS HUB`, `PRINT & THERMAL SETTINGS`, `PAYMENT METHODS CONFIGURATION`, `DIAGNOSTICS & ERROR REPORTING`). Kept exact member declaration order and signatures 100% unchanged.
- **Alternatives:** Re-sorting getters and methods alphabetically or by domain (which would create a massive 2000-line diff and destroy git blame/history).
- **Why Safest:** Comment-only edit; zero code changes; exactly 0 members removed or re-ordered; API diff confirmed 1003/1003 members stable.
- **How to Reverse:** Revert comment lines back in `lib/localization/app_localizations.dart`.

---

### Decision 7 (Batch L8): Automated Comprehensive Quality Test Suite
- **Decision:** Implemented `test/localization/localization_quality_test.dart` asserting 10 automated test suites: locale identification, brand consistency ("ورقتك" / "Waraqatak"), non-empty getter checks, masculine status agreement, 6-form Arabic plural categories (0, 1, 2, 3..10, 11..99, 100+), days remaining plurals, presentation Bidi isolation in UI and WhatsApp, strict isolate exclusion in PDF labels, absence of deprecated terminology ("صنف", "جاري", "..."), and absence of legacy phase comments.
- **Alternatives:** Relying solely on manual inspection (prone to regressions in future PRs).
- **Why Safest:** Adds automated regression prevention suite that runs in <6 seconds on Termux with zero new external dependencies.
- **How to Reverse:** Delete `test/localization/localization_quality_test.dart`.

---

### Decision 8: Neutralize Unicode Bidi Isolates at Central PDF Choke Point
- **Finding:** Read-only verification found that `statementWarningDetail` (which wraps invoice number, discrepancy amount, and currency symbol in `_iso` isolates `\u2068` / `\u2069`) was rendered in customer statement PDFs via `PdfTextUtils.directionalText` in `lib/services/pdf/pdf_customer_statement_builder.dart:391`. This leaked isolate control characters into the PDF text layer, which could cause missing-glyph replacement boxes in fonts like Tajawal.
- **Decision:** Added `PdfTextUtils.stripBidiIsolates(String)` to `lib/services/pdf/pdf_text_utils.dart` stripping all Unicode Bidi isolates (`U+2066..U+2069`) and integrated it into `PdfTextUtils.directionalText`. Because all directional text in customer statements, reports, items tables, and headers routes through `directionalText`, this provides a single central choke point ensuring zero isolate control characters reach `pw.Text` in the PDF layer.
- **Alternatives:** Stripping isolates in `statementWarningDetail` within `app_localizations.dart` (rejected: would strip isolates from on-screen UI Text and WhatsApp captions where they are necessary), or adding custom sanitization in each individual PDF builder (rejected: duplicative and prone to omissions).
- **Why Safest:** Sanitizer targets only `U+2066..U+2069`, preserving all printable characters, whitespace, control codes (`\n`, `\t`), and punctuation. Zero changes to on-screen UI, numbers, totals, or business logic. 31/31 PDF tests and 11/11 customer statement tests pass cleanly.
- **How to Reverse:** Remove `stripBidiIsolates` call inside `PdfTextUtils.directionalText`.

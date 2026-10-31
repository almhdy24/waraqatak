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

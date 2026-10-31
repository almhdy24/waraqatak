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

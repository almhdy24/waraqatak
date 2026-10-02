# Website ↔ app consistency — `play-compliance` branch

Scope: compare every user-facing claim on `https://almhdy24.com/products/waraqatak/*`
against the actual behaviour of the Waraqatak Flutter app as it stands on this
branch. This document is **read-only on the website**: the author will fold the
website-side fixes into a separate deploy. App-side fixes are tracked below and
land as part of Step 6.

Audit date: 2026-10-02.
Website source: `~/almhdy24.com/products/waraqatak/*.html` (local tree — public
URLs still 404; see `docs/progress.md` → Step 4).
App source: `lib/services/`, `lib/screens/`, `lib/core/constants/`,
`lib/localization/app_localizations.dart`.

---

## Verdicts

### Features & gating

| Claim | Website | App | Verdict |
|---|---|---|---|
| Free features list | 8 bullets: invoices, quotations, vouchers, custom documents, customers+products, barcode, basic reports, backup/restore (`index.html`) | 9 enum values in `FeatureAccess.freeFeatures` — same list, with customers and products as two separate enum values collapsed into one bullet on the website | ✓ match |
| Pro features list | 3 bullets: purchases + suppliers, advanced inventory, detailed reports (`index.html`) | `FeatureAccess.proFeatures = {purchases, inventory, advancedReports}` | ✓ match |
| No Google Play Billing | "لا توجد عملية شراء داخل التطبيق" (`index.html`, `terms.html`, `whats-new.html`) | No billing imports; activation is key-only | ✓ match |

### Trial & activation

| Claim | Website | App | Verdict |
|---|---|---|---|
| Trial length | 14 days from first launch (`index.html`, `whats-new.html`) | `_trialDays = 14` in `lib/services/license_service.dart` | ✓ match |
| Trial → free on expiry | "تنتقل بعدها إلى النسخة المجانية" (`index.html`) | `EntitlementStatus.trialExpired` keeps free features accessible via `FeatureAccess.canAccess` | ✓ match |
| In-app activation path | "الإعدادات ← التفعيل" in 4 places (`index.html` ×2, `terms.html`, `whats-new.html`) | Settings menu now routes to **License** screen. Arabic label is "التفعيل والترخيص"; English label is "License" | ⚠ wording drift |
| In-app activation path | "الإعدادات ← الترخيص" in 1 place (`support.html`) | matches current app | ✓ match |
| Activation endpoint | `POST api.almhdy24.com/api/v1/pay/licenses/activate` (`privacy.html`) | Same endpoint, body `{license_key, machine_id}` exactly (asserted in test) | ✓ match |
| Data sent at activation | "مفتاح التفعيل" + "معرّف جهاز عشوائي (UUID v4)" only (`privacy.html`) | Request body carries only `license_key` and `machine_id`; no device fingerprint, no IMEI, no ad id | ✓ match |
| Clock-rollback protection | Not mentioned on the website | `_updateLastLaunch` detects rollback >2 min and advances `wq_trial_start` | ⚠ app does more than it promises (not a user complaint, note for completeness) |

### Data & storage

| Claim | Website | App | Verdict |
|---|---|---|---|
| Business data stays on device | "لا تُرسل بيانات الأعمال … إلى خوادمنا" (`index.html`, `privacy.html`) | SQLite via `getApplicationDocumentsDirectory()`; no business-data upload path exists | ✓ match |
| License data in Android Keystore | "مُشفَّر: Android EncryptedSharedPreferences المحمي بـ Android Keystore" (`privacy.html`) | `flutter_secure_storage` resolves to `EncryptedSharedPreferences` + Keystore on Android | ✓ match |
| What is stored under Keystore | license key, machine_id (UUID v4), status, expiry, trial start, last-launch marker (`privacy.html`) | `wq_license_key`, `wq_license_expiry`, `wq_license_status`, `wq_device_id`, `wq_trial_start`, `wq_last_launch` | ✓ match |

### Contact & company

| Claim | Website | App | Verdict |
|---|---|---|---|
| Support email | `support@almhdy24.com` across site | `AppConstants.supportEmail` same | ✓ match |
| Developer / publisher name | "Elmahdi Dev" / "المهدي عبدالله" in copyright footers | `AppConstants.developerName = 'Elmahdi Abdallh'` | ⚠ three variants (Elmahdi Dev / المهدي عبدالله / Elmahdi Abdallh) — reviewer-visible inconsistency |
| WhatsApp / Facebook contact | not advertised | removed from `AppConstants` in Step 4 | ✓ match (both now email-only) |

### Backup & deletion

| Claim | Website | App | Verdict |
|---|---|---|---|
| Backup file format | `.waraq` JSON, unencrypted (`index.html`, `privacy.html`) | `BackupService` writes `.waraq` JSON via `JsonEncoder.withIndent` | ✓ match |
| Full-data deletion | "الإعدادات ← التطبيقات ← ورقتك ← التخزين ← مسح البيانات" (`delete.html`) | Correct Android path; app has no in-app wipe button | ✓ match |
| Server-side deletion of activation record | email `support@almhdy24.com` (`delete.html`) | No in-app flow; matches website | ✓ match |
| Remove activation key only | not described on website | Settings → License → "إزالة المفتاح من هذا الجهاز" clears license keys only, not business data | ⚠ app has a capability the website never mentions |

### Legal / Terms

| Claim | Website | App | Verdict |
|---|---|---|---|
| Refund policy | **placeholder: "⚠ موضع لمدة الاسترداد — يُحدَّد لاحقًا"** (`terms.html` §6) | n/a — no in-app checkout | ✗ blocker: must be filled before Play review |
| Governing law & jurisdiction | **placeholder: "سيُحدِّد المالك القانون المعمول به والاختصاص … هذا الجزء مؤقت"** (`terms.html` §12) | n/a | ✗ blocker: must be filled before Play review |
| "As-is, no warranty" | present in `terms.html` | no contradicting app claim | ✓ match |

### App-slug / product identifier

The app does **not** send any product/app slug to the activation endpoint. The
POST body is exactly `{license_key, machine_id}` (asserted in
`test/services/activation_service_test.dart`). The server infers the product
from the license key itself; there is no slug mismatch to find because there is
no slug at all.
Verdict: ✓ no action.

---

## Fixes needed on the website (hand to author)

1. **Fill the two placeholder sections in `terms.html`.** §6 (refund period) and
   §12 (governing law + jurisdiction) are blocker-grade for Play review — a
   reviewer who opens the Terms link must see finalized policy, not "TBD".
2. **Normalize the Settings path wording.** Replace "الإعدادات ← التفعيل" with
   "الإعدادات ← الترخيص" in `index.html` (two places), `terms.html`, and
   `whats-new.html`. `support.html` is already correct.
3. **Pick one developer name string and use it everywhere.** The site shows
   three variants ("Elmahdi Dev", "المهدي عبدالله", "Elmahdi Abdallh"). The app
   uses "Elmahdi Abdallh". Easiest fix: use "Elmahdi Abdallh" / "المهدي عبدالله"
   consistently; retire "Elmahdi Dev" as a brand marker in copyright footers.
4. **Deploy the three allowlisted pages publicly.** `privacy.html`,
   `terms.html`, and `delete.html` currently 404 at the public URLs the app
   points to (verified `curl -sI` on audit date). Already tracked in
   `docs/progress.md` → Step 4 but repeated here for the hand-off checklist.
5. **Optional:** add a brief note to `delete.html` describing the in-app
   "Remove key from this device" button — the capability exists in the app
   (added in Step 2) but the website never mentions it.

## Fixes needed in the app

None blocker. The app matches every verified website claim where the website
is itself consistent. The only drifts are wording ones that will be resolved by
the website edits above.

Nothing to change in `AppConstants`, `FeatureAccess`, `LicenseService`,
`ActivationService`, or the mandated-copy table in `docs/play-compliance.md`.

---

## Appendix — raw sources checked

Website pages read in full:
- `index.html` (19.5 KB)
- `privacy.html` (21.1 KB)
- `terms.html` (17.5 KB)
- `delete.html` (13.3 KB)
- `support.html` (15.8 KB)
- `licenses.html` (18.0 KB) — open-source licenses page, no app-side claim
- `whats-new.html` (13.2 KB)

App code read:
- `lib/core/constants/app_constants.dart`
- `lib/services/activation_service.dart`
- `lib/services/license_service.dart`
- `lib/services/feature_access.dart`
- `lib/services/backup_service.dart`
- `lib/screens/{about,license,transparency,activation}_screen.dart`
- `lib/localization/app_localizations.dart` (license + feature getters)
- `pubspec.yaml` (version 1.0.0+3)

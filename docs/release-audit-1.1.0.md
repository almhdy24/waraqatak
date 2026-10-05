# Release audit — Waraqatak 1.1.0 (licensing and Pro gating)

- **Scope:** read-only static review. Nothing was built, run or modified, and no
  key values were read or printed.
- **Revision:** no `v1.1.0` tag exists in the repository, so this audits `main` at
  `7e6473c`. `pubspec.yaml` declares `version: 1.1.0+4`. Source files under
  `lib/` are identical to the pre-merge tree.
- **Evidence format:** `file:line`.

## 1. Is `expires_at` from the server response persisted?

**No. The server response is not used at all.** The persisted expiry comes from
the claims inside the key itself.

- The SDK result of `activateLicense(...)` is discarded
  (`lib/services/activation_service.dart:133-135`). The catch-all comment states
  "we don't rely on any field in the response body" (`:148-152`).
- The expiry is parsed from the key payload: `LicenseKeyClaims.tryParse(key)`
  (`activation_service.dart:126`, `lib/services/license_key.dart:18-35`; field
  `expires_at` at `license_key.dart:28,31`).
- It is persisted with `storeLicense(expiresAt: claims?.expiresAt, ...)`
  (`activation_service.dart:155-159`). The writes go to secure storage under
  `wq_license_expiry` (`license_service.dart:188-189`, key name at `:32`), plus
  `wq_license_key` (`:187`) and `wq_license_status` (`:190-191`).
- `null` is stored as the empty string (`license_service.dart:189`).
- The app never verifies the key signature. `license_key.dart:6-9` says the
  signature is checked "by the server". The on-device expiry is therefore an
  unverified claim read from the key.
- Side finding: `activation_service.dart:148` is `catch (_)` and falls through to
  the success path. Any exception that is not one of the three typed SDK
  exceptions (rate limit, network, API) results in `success`, with the key stored
  and no server confirmation. The comment shows this is intended for malformed
  2xx bodies, but it is broader than that.

## 2. `LicenseService._compute`: null, past and malformed expiry

`_compute` is `license_service.dart:90-144`.

| Stored state | Behaviour | Evidence |
|---|---|---|
| `expiry == null` (lifetime key, stored as `''`) | `licensed`, never expires locally. For an empty stored value it re-reads the claims from the key itself. | `:107-112`, `:121-125` |
| Expiry in the past | `licenseExpired`; `isSubscriptionActive` is false, so Pro is denied. | `:114-120`; `lib/models/entitlement.dart:30-32` |
| Malformed non-empty stored expiry | `DateTime.tryParse` returns null, so it is treated as no expiry and the license stays `licensed` forever. Only an *empty* stored value falls back to the key's claims. | `:110-112` then `:121` |
| Status `revoked` | `licenseRevoked`, checked before expiry. | `:99-105` |

**Exactness.** The comparison is `expiry.isBefore(now)` (`:114`), so Pro locks
from the first instant after the expiry time. It is evaluated once per process
and cached (`:82-86`). Home and reports call `checkEntitlement(force: false)`
(`lib/screens/home_screen.dart:69`, `lib/screens/reports_screen.dart:32`), so a
session that is already running when the expiry passes stays Pro until a forced
check or a restart. Reports and the license screen force a recompute
(`reports_screen.dart:47`, `license_screen.dart:36`).

**Clock tamper resistance. The license expiry has none.**
- Expiry is compared against plain `DateTime.now()` (`:92`, `:114`).
- The "last launch" guard (`_updateLastLaunch`, `:155-178`) only protects the
  **trial**. On a rollback of more than 2 minutes it pushes `wq_trial_start`
  forward (`:164-171`). It never touches license expiry.
- Clock set **backwards**: an expired license reads as valid again, and the
  rollback guard does nothing for it.
- Clock set **forwards**: an unexpired license reads as expired. Setting the clock
  back afterwards restores Pro, because nothing records that the later time was
  seen.
- The trial guard has a related gap. A forward jump is not corrected; it only
  ends the trial early. If the clock is then moved back, the guard advances the
  trial start by the rollback amount, which restores the lost days.
- Tests for the rollback logic re-implement it locally rather than calling the
  service (`test/services/entitlement_test.dart:79-90`).

## 3. Server contact after activation, and behaviour at expiry

- **No re-contact.** The only call site of `ActivationService.activate` is
  `lib/screens/activation_screen.dart:43`. `ElmahdiPay*` and the server URL appear
  only in `activation_service.dart` (`:1`, `:44`, `:52-53`, `:133`). Everything
  else in `lib/` reads local storage. `docs/free-vs-pro.md` states the same
  ("does not re-contact ... after a successful activation").
- **Revocation is unreachable.** `storeLicense` is called in exactly one place,
  with `isActive: true` (`activation_service.dart:155-159`). Nothing in
  production writes `revoked` (`license_service.dart:191`), so the
  `licenseRevoked` branch (`:99-105`) and its UI strings
  (`lib/localization/app_localizations.dart:593`) cannot occur from the shipped
  flows. A server-side revocation never reaches the device.
- **At expiry: lock only.** Status becomes `licenseExpired`
  (`license_service.dart:114-120`) and `isSubscriptionActive` is false
  (`entitlement.dart:30-32`). `FeatureAccess.canAccess` then denies Pro features
  (`lib/services/feature_access.dart:41-44`). The gate is on screen entry only
  (`home_screen.dart:107-118`, `reports_screen.dart:39,126`).
- **Data preserved.** `license_service.dart` imports no database code
  (`:1-7`) and nothing in the expiry path deletes data. `clearLicense` only
  deletes the three license keys and deliberately keeps the device id and trial
  markers (`:197-209`). Free flows continue to work, and Pro data already stored
  remains in SQLite.

## 4. Feature gating (`lib/services/feature_access.dart`)

- **Pro (`:27-31`):** `purchases`, `inventory`, `advancedReports`.
- **Free (`:35-36`, the complement):** `invoices`, `quotations`, `vouchers`,
  `customDocuments`, `customers`, `products`, `barcode`, `basicReports`,
  `backupRestore` (enum at `:3-18`).
- **Where Pro is enforced:**
  - Purchases: `home_screen.dart:156`.
  - Inventory: `home_screen.dart:420`.
  - Advanced reports: `reports_screen.dart:67,80,99,106,113`.
- **Quick sale is FREE.** There is no `Feature` value for it, and no gate or
  entitlement check in `lib/screens/quick_sale_screen.dart`. It is launched
  directly from `home_screen.dart:282`.
- **Accounting statements are PRO.** The Accounting entry (income statement,
  balance sheet, trial balance, ledgers, all in `reports/accounting_screen.dart`)
  is declared with `proFeature: Feature.advancedReports`
  (`reports_screen.dart:63-67`). The screen has no gate of its own, so the gate is
  the entry point in the reports list.
- **Reports split:** Sales, Payments and Customer reports are free. Accounting,
  Purchases, Supplier, Inventory and Product reports are Pro
  (`reports_screen.dart:67-113`).
- **Trial:** all Pro features are open for 14 days (`license_service.dart:35`,
  `:128-143`).

## 5. User-facing strings about obtaining a key

**No string tells the user where or how to obtain a key.** The strings that
mention keys only say to *enter* one:

- `getActivationKeyInfo`: "Enter your activation key to unlock Pro features."
  (`app_localizations.dart:616-619`; shown in `locked_feature_screen.dart:51` and
  `pro_upgrade_sheet.dart:105`)
- `proFeaturesActivation`: "Pro features are unlocked with an activation key."
  (`:612-615`)
- `enterActivationKey`, `activationKeyHint`, `activate`, `invalidOrExpiredKey`
  (`:608-623`)

Code comments state the policy: keys are "obtained outside the app", with no
in-app pricing or ordering (`app_localizations.dart:585-586`,
`activation_screen.dart:12-13`, `about_screen.dart:12-16`).

The About screen has support channels with help-only wording
(`app_localizations.dart:741-744,752`; `about_screen.dart:73-86`): WhatsApp,
"Technical help and questions", and a support email. None of them mention keys
or licences.

## 6. Test coverage (not run)

| Case | Covered? | Evidence |
|---|---|---|
| Valid key with expiry: claim parsing | Yes, parsing only. | `test/services/license_key_test.dart:23-32` |
| Valid key with expiry: stored and honoured in `_compute` | **No.** No test calls `storeLicense` or `_compute` with an expiry. `LicenseService` appears in tests only for `uuidFromHash` (`license_key_test.dart:51-61`). | `grep LicenseService test` |
| Null / lifetime expiry | Partly: claim parsing (`license_key_test.dart:34-41`), activation with `expires_at: null` (`:108-117`), and `EntitlementState` with null expiry (`entitlement_test.dart:136-141`). Not through `_compute`. | as listed |
| Expired key | Partly: activation rejects an expired key without a request (`license_key_test.dart:97-106`) and `licenseExpired` denies access (`entitlement_test.dart:26-30`). The on-device `isBefore(now)` decision in `_compute` is untested. | as listed |
| Malformed stored expiry | **No.** | n/a |
| Clock rollback | Re-implemented logic only, not the service (`entitlement_test.dart:79-133`). | `:80-90` |

Activation outcomes (success, invalid, 429, 5xx, network error, timeout,
malformed body) are well covered in `test/services/activation_service_test.dart`.

## Findings, by priority

1. **Malformed stored expiry means unlimited Pro** (`license_service.dart:110-112`).
   A non-empty, unparsable `wq_license_expiry` should lock rather than license.
2. **License expiry is not clock-hardened.** The rollback guard covers only the
   trial (`:155-178`). A backwards clock extends an expired license.
3. **Revocation cannot happen**, and a server-side revocation is never seen
   (`activation_service.dart:155-159`). This is by design but not communicated in
   the UI.
4. **Unverified expiry claim.** The device trusts the key payload. Activation
   needs a server 2xx, but the broad `catch (_)` at `activation_service.dart:148`
   lets unexpected errors count as success.
5. **No test drives `LicenseService._compute`** for expiry, null expiry or
   malformed expiry.
6. **Cache means a running session survives expiry** until a forced check
   (`license_service.dart:82-86`).

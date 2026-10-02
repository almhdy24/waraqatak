# Google Play Payments Compliance — Waraqatak

**Branch:** `play-compliance`
**Package:** `com.elmahdi.waraqatak`
**Model:** Consumption-only (no in-app purchases).

## Why this branch exists

Google Play's Payments policy requires that any purchase of digital goods or
services consumed inside an Android app go through Google Play Billing. The
developer is based in Sudan and does not have access to a Play merchant
account, so Google Play Billing cannot be used.

The policy allows apps that **do not sell digital goods inside the app** to
ship without Google Play Billing (the "consumption-only" model):
<https://support.google.com/googleplay/android-developer/answer/10281818>.

This branch brings Waraqatak into that model.

## What that means in practice

- Nothing can be bought, priced, or paid for inside the app.
- Pro features (purchases, inventory, advanced reports) are unlocked by
  entering an **activation key** obtained **outside the app**. The app
  itself does not describe *where* or *how* to obtain that key — no URLs,
  phone numbers, website / WhatsApp hints, or "contact us" copy appear on
  the locked-feature screen, the activation screen, the Pro upgrade sheet,
  or any license error state.
- The merchant's own invoicing feature (how a business owner records that
  **their own customers** paid them for goods or services the merchant
  sells) is unchanged. That is the merchant's bookkeeping — it is not an
  in-app purchase.

## What changed on this branch

### Removed (user-facing)

- `lib/screens/subscription_screen.dart` — subscription plan comparison
- `lib/screens/payment_flow_screen.dart` — proof-of-payment upload flow
- `lib/screens/paywall_screen.dart` — pending/rejected order handling
- `lib/models/subscription_plan.dart` — pricing tier data
- `lib/services/subscription_service.dart` — order creation / payment-method
  listing

### Added

- `lib/screens/activation_screen.dart` — single text field accepting an
  activation key; shows success/failure state with no commerce copy.
- `lib/screens/locked_feature_screen.dart` — neutral "this feature requires
  Pro — enter an activation key" screen with no pricing.
- `lib/services/activation_service.dart` — thin wrapper over the Elmahdi Pay
  SDK; the server call sends **only `{license_key, machine_id}`**.
- `assets/fonts/OFL.txt` — SIL Open Font License for Tajawal.
- `tool/check_play_compliance.sh` — CI guard (see below).

### Reworked

- `lib/models/entitlement.dart` — dropped `PendingOrderStatus`, order
  references, and rejection notes. Status is now one of:
  `trialActive | trialExpired | licensed | licenseExpired | licenseRevoked`.
- `lib/services/license_service.dart` — removed all order-related keys and
  methods. Still owns the device ID, 14-day trial with clock-rollback
  detection, and encrypted license persistence via `flutter_secure_storage`.
- `lib/widgets/pro_upgrade_sheet.dart` — body replaced with the three
  mandated copy strings; CTA says "Enter activation key" rather than
  "Upgrade".
- `lib/screens/home_screen.dart`, `lib/screens/settings_screen.dart`,
  `lib/screens/reports_screen.dart` — all route to `ActivationScreen`
  instead of the removed subscription flow.

### Mandated approved copy (Arabic / English)

Four strings, defined in `lib/localization/app_localizations.dart`, are the
only Pro-gating messages shown to the user. All are deliberately neutral —
they describe *what* an activation key does, never *where* or *how* to get
one:

| Key | Arabic | English |
|---|---|---|
| `proFeaturesActivation` | تُفعَّل الميزات الاحترافية بمفتاح تفعيل. | Pro features are unlocked with an activation key. |
| `getActivationKeyInfo` | أدخل مفتاح التفعيل لإلغاء قفل الميزات الاحترافية. | Enter your activation key to unlock Pro features. |
| `invalidOrExpiredKey` | مفتاح تفعيل غير صالح أو منتهي الصلاحية. | Invalid or expired activation key. |
| `deviceAlreadyActivated` | هذا المفتاح مُستخدم على جهاز آخر. | This key is already in use on another device. |

No URLs, phone numbers, prices, currencies, or "contact us / website /
WhatsApp" wording appears anywhere in the Pro-gating UI.

## Server contract

Endpoint: `POST https://api.almhdy24.com/pay/licenses/activate`
Request body (the **only** fields sent):

```json
{ "license_key": "<user-entered>", "machine_id": "<per-install UUID>" }
```

Response: an opaque `activationToken`. No license data is sent back.

The device ID is created on first launch and persisted; re-entering the same
key never consumes an extra device slot. The license key is stored
encrypted via `EncryptedSharedPreferences` (Android Keystore, API 23+).

## CI compliance guard

`tool/check_play_compliance.sh` runs two independent passes against the
Dart tree:

1. **Purchase vocabulary.** Greps for identifiers and strings that would
   imply in-app purchases (English + Arabic: `buy pro`, `subscribe`,
   `اشتراك شهري`, etc.). A short whitelist of merchant-invoicing files
   (`payment_methods_screen.dart`, `document_payment.dart`, the payments
   report, the DB helper, localization) is exempted because those describe
   how a merchant records payments **against their own invoices** —
   bookkeeping, not an in-app purchase.
2. **Acquisition copy.** Scans the Pro-gating screens (locked feature,
   activation, Pro upgrade sheet) and the activation getters inside
   `app_localizations.dart` for any wording that would tell the user
   *where* or *how* to obtain a key — `contact us`, `through our website`,
   `on WhatsApp`, `wa.me`, URLs, `تواصل معنا`, `موقعنا`, `واتساب`, etc.
   The About screen is deliberately excluded from this pass; it is a
   company-info page that may list generic contact details.

The script runs as the first step in each GitHub Actions workflow
(`ci.yml`, `build-debug.yml`, `release.yml`) before analyze and tests. A
unit test (`test/services/play_compliance_test.dart`) mirrors both passes
against the `AppLocalizations` instance so a regression also fails
`flutter test`.

Run locally:

```sh
bash tool/check_play_compliance.sh
```

## Non-payments audit items applied on this branch

Carried over from `docs/pre-release-audit.md`:

- `compileSdk = 36`, `targetSdk = 36`, `minSdk = 23` (explicit — no
  `flutter.*` indirection).
- `AndroidManifest`: `android:allowBackup="false"`,
  `android:fullBackupContent="false"`, `android:extractNativeLibs="false"`,
  explicit `INTERNET` permission (activation call still goes to the
  licensing server).
- `lib/main.dart`: `runZonedGuarded` + `FlutterError.onError` +
  `PlatformDispatcher.instance.onError` route uncaught errors to the
  developer log.
- `lib/database/database_helper.dart`: `ALTER TABLE … ADD COLUMN` loops
  now catch only `DatabaseException`; legacy prefs JSON migration catches
  only `FormatException` / `TypeError` instead of bare `catch (_)`.
- `lib/screens/settings_screen.dart`: backup save shows a confirm dialog
  warning that the file is unencrypted before invoking the OS picker.
- `lib/screens/about_screen.dart`: new "Open-source Licenses" entry that
  opens the Flutter-provided `showLicensePage` and legalese mentioning
  the Tajawal font under OFL 1.1.
- `assets/fonts/OFL.txt`: SIL Open Font License 1.1 shipped alongside the
  Tajawal font files.
- GitHub Actions: Flutter pinned to `3.41.9` in all three workflows.

## Not merged to main

This branch intentionally stays separate from `main` until the Play review
process is complete. Do not merge without an explicit go-ahead from the
developer.

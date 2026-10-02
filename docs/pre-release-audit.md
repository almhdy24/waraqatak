# Waraqatak — Pre-Release Audit (Google Play, Public Release)

- **Package:** `com.elmahdi.waraqatak`
- **Current repo version:** `1.0.0+3` (versionName 1.0.0 / versionCode 3)
- **Audit date:** 2026-10-02
- **Scope:** full codebase, Android config, bundled `packages/elmahdi_pay_flutter` SDK, CI workflows, git history.
- **Reviewer:** static review only; `flutter analyze` / `flutter test` were **not** executed (Flutter SDK is not usable in the current Termux shell — AGENTS.md §Environment).

---

## Summary verdict: **NOT READY**

The app has at least **three Blocker-class issues** that will cause rejection, broken functionality in release, or Play Store removal. It also has several High-severity issues around privacy disclosure and release manifest completeness. The code quality, security hygiene around secrets/signing, and database migrations are good; the main problems are policy and release configuration.

The single biggest issue is the payment architecture: the app sells access to Pro features via an external manual-proof flow (bank transfer / mobile wallet / receipt upload), bypassing Google Play's billing system entirely and without being enrolled in the Alternative Billing or External Content Links programs. In every Play-distribution territory this currently violates the **Payments** policy under *Monetization and Ads*.

---

## How to read this report

Each finding has: **file:line → issue → policy / reason → recommended fix**. "Fix" is a direction, not an implementation — nothing has been changed. Policy names are cited as they appear on `play.google/developer-content-policy` and the referenced Play Console Help pages (fetched 2026-10-02).

---

## Blockers (will cause rejection, suspension, or a broken release)

### B1. Subscription is sold outside Google Play Billing with no program enrollment
- **Where:**
  - `lib/screens/paywall_screen.dart` (entry paywall)
  - `lib/screens/subscription_screen.dart:12-246` (4 plans, prices in SDG)
  - `lib/screens/payment_flow_screen.dart:16-569` (payment form, proof upload, order submission)
  - `lib/services/subscription_service.dart:16` — `serverUrl = 'https://api.almhdy24.com'`
  - `lib/services/license_service.dart` — license storage & trial logic
  - `packages/elmahdi_pay_flutter/lib/src/api/public_api.dart` — `POST /pay/orders`, `GET /pay/orders/{ref}`, `POST /pay/licenses/activate`
  - Plan prices: 20,000 / 55,000 / 100,000 / 180,000 SDG (`lib/models/subscription_plan.dart:44-77`)
  - "Attach Payment Proof": `app_localizations.dart:599`
  - "Enter your correct details — we'll contact you… and send your license key": `app_localizations.dart:622`
- **Issue:** The paid "Pro" tier unlocks in-app digital functionality (purchases/inventory/advanced reports — `lib/services/feature_access.dart:23-27`). Payment is taken out-of-band (bank transfer / wallet / proof screenshot) and a license key is issued by a proprietary server. There is **no `in_app_purchase` plugin**, no Google Play Billing integration, and no sign that the developer is enrolled in Google's **Alternative Billing Program** or **External Content Links Program** (which, since the Dec 9, 2025 update, are the only sanctioned alternatives to Play Billing and still require a service-fee payment).
- **Policy:** *Monetization and Ads → Payments* (`play.google/developer-content-policy`): developers offering products or services for use within an app distributed on Google Play must use Google Play's billing system unless they are enrolled in one of Google's alternative billing programs, in which case strict disclosure, UX, and fee-remittance rules apply.
- **Fix (pick one, in order of likelihood of approval):**
  1. **Replace the Elmahdi Pay checkout with `in_app_purchase` using Google Play subscriptions.** The existing `license_service.dart` entitlement model can stay; just set it from Play Billing's purchase/receipt callbacks instead of from the Elmahdi Pay response. Keep "Restore license" wired to Play's `queryPurchases`.
  2. If keeping the current flow is strategic (e.g. for Sudan where Google Play Billing has limited local payment-method support), enroll in **User Choice Billing / Alternative Billing** before release, implement both billing options side-by-side in the paywall, and comply with the fee-remittance and disclosure rules. This is complex and still subject to Play review.
  3. Distribute **only outside Google Play** (e.g. the website at `almhdy24.com/products/waraqatak`) and remove the app from Play entirely. Not recommended given the existing MVP is already published there.
- **Severity:** Blocker. This is the single most likely rejection reason. The Play Store already rejects apps for simply linking out to an external paywall for digital goods; a full external-pay flow with proof upload is substantially worse.

### B2. Release manifest is missing `INTERNET` — subscription/activation flow will fail on any release build
- **Where:** `android/app/src/main/AndroidManifest.xml:1-2` declares only `android.permission.CAMERA`. `INTERNET` is declared only in `android/app/src/debug/AndroidManifest.xml:6` and `android/app/src/profile/AndroidManifest.xml:6`. Those variants are **not** merged into release.
- **Issue:** None of the plugins the app depends on contributes `INTERNET` via its own manifest (`http` is pure Dart; `sqflite`, `path_provider`, `file_picker`, `shared_preferences`, `pdf`, `printing`, `share_plus`, `url_launcher`, `flutter_svg`, `intl`, `package_info_plus`, `mobile_scanner`, `flutter_secure_storage` — none of them). On a release AAB, every call to `api.almhdy24.com` will raise a `SocketException: Failed host lookup` (or similar) and the paywall, order creation, status check, and license activation will all break for end users. This is probably why the only tests in `test/` cover offline services.
- **Policy:** Not a Play policy directly, but violates *Spam, Minimum Functionality and User Experience* once the Pro flow is observed to be non-functional in a real release install. More importantly: this will cause the first paying customers to be unable to activate.
- **Fix:** Add `<uses-permission android:name="android.permission.INTERNET"/>` to `android/app/src/main/AndroidManifest.xml`. Keep it out of `android/app/src/debug/AndroidManifest.xml` and `android/app/src/profile/AndroidManifest.xml` to avoid duplication, or leave those entries alone (they're idempotent at merge time).
- **Severity:** Blocker — not for Play review (the APK still installs) but for release correctness. Also an engineering red flag that no end-to-end release-mode test has been performed.

### B3. `targetSdkVersion` is inherited from Flutter and must be ≥ 36 as of Aug 31, 2026 — already past the deadline
- **Where:** `android/app/build.gradle.kts:23,24` uses `minSdk = flutter.minSdkVersion` and `targetSdk = flutter.targetSdkVersion`. The resolved value depends on the Flutter version the CI uses (CI pins `3.41.9` in `.github/workflows/ci.yml:31,61`). Flutter 3.41.9's default `targetSdkVersion` is not guaranteed to be 36 — historically Flutter has lagged behind the Play requirement by one API level, and the project does not override it.
- **Issue:** Starting **August 31, 2026** (today is 2026-10-02 — past the cutoff), Google Play requires new apps and updates to target Android 16 (API 36). Phone/tablet apps targeting < 36 cannot be submitted (extensions available only until Nov 1, 2026, by request). Relying on the Flutter default is fragile and today may already produce a non-compliant AAB.
- **Policy:** *Target API level requirement* (`support.google.com/googleplay/android-developer/answer/11926878`).
- **Fix:** Explicitly set the values in `android/app/build.gradle.kts` instead of relying on Flutter:
  ```kotlin
  defaultConfig {
      minSdk = 23          // required for flutter_secure_storage EncryptedSharedPreferences
      targetSdk = 36
      // compileSdk stays 36
  }
  ```
  Then do a release build and physically test on an Android 16 (API 36) device/emulator (edge-to-edge, photo-picker, foreground-service rules, scheduled-exact-alarm, predictive-back — all of which land at API 34-36). Also confirm that `mobile_scanner`, `file_picker`, `share_plus`, `printing`, and `flutter_secure_storage` all still work with the plugin versions pinned in `pubspec.yaml`.
- **Severity:** Blocker — depending on what the Flutter default resolves to, the AAB may be rejected at upload with the exact message "Your app currently targets API level N and must target at least API level 36".

---

## High (significant risk of rejection, data-safety failure, or privacy violation)

### H1. No in-app account/data deletion path, despite the server storing identifying order data
- **Where:** no code implements it. The server (`api.almhdy24.com`) receives on every order creation (`packages/elmahdi_pay_flutter/lib/src/api/public_api.dart:30-47`): `buyer_name`, `buyer_contact` (phone or email), amount, optional free-text `proof_note`, optional `proof_file` (JPEG/PNG/WebP/GIF/PDF up to 10 MB), and the device `machine_id` (UUIDv4 from `license_service.dart`). None of this is deleted on uninstall and no in-app button requests server-side deletion.
- **Issue:** Google Play's **Account deletion** policy applies to any app that lets a user "create an account" within the app, which the Play team interprets to include license-key / subscription-identifier flows that bind to a user-supplied name + contact and persist server-side. The requirement is two-pronged: (a) an in-app deletion path *and* (b) a web-reachable deletion URL that is linked from the Play Store listing's Data Safety section. Neither exists today.
- **Policy:** *User Data → Account deletion* (`support.google.com/googleplay/android-developer/answer/13327111`).
- **Fix:**
  - Add a "Delete my data / account" entry in Settings → Account that calls a new `DELETE /pay/customers/{contact}` (or similar) endpoint on the Elmahdi Pay server, deletes all local secure-storage entries and the SQLite file, and signs the user out of their license.
  - Publish a web deletion form at `almhdy24.com/products/waraqatak/delete.html` and link it in the Play Console Data Safety form.
  - Confirm with the backend what order metadata is actually retained after deletion (for tax/legal reasons the server may need to keep records; disclose that retention clearly in the privacy policy).

### H2. Data Safety declarations are not drafted anywhere, and the current flow does not match a plausible "none collected" claim
- **Where:** data flows are documented in Finding B1 above and across `lib/services/subscription_service.dart`, `lib/services/license_service.dart`, `packages/elmahdi_pay_flutter/lib/src/api/public_api.dart`.
- **Issue:** The Play Console Data Safety form must list every category of personal data collected or shared, including anything transmitted to the developer's own servers. Submitting an inaccurate or incomplete form is grounds for rejection or removal. A draft needs to exist before the first upload.
- **Policy:** *User Data → Data Safety* (`support.google.com/googleplay/android-developer/answer/10787469`).
- **Fix — draft Data Safety answers:**
  - **Does your app collect or share any of the required user data types?** Yes.
  - **Collected (shared with developer servers):**
    - **Personal info → Name:** `buyer_name` submitted on each order. *Collected: Yes. Shared: No. Purpose: Account management, App functionality (license issuance). Required: Yes (for purchase only). Encrypted in transit: Yes (HTTPS). Deletion request: Yes (if H1 is implemented).*
    - **Personal info → Email address or Phone number** (user picks one for `buyer_contact`): same declarations as Name.
    - **Financial info → Purchase history:** order amounts and status are stored on the server tied to buyer contact. Collected, not shared, same purposes.
    - **Photos** (optional): `proof_file` when the user attaches a payment screenshot. *Optional, Collected, not shared, purpose "App functionality" (payment proof), encrypted in transit, deletion supported.*
    - **App activity → Other actions:** optional free-text `proof_note`.
    - **Device or other IDs:** `machine_id` is a locally-generated UUIDv4, **not** Android ID / advertising ID / IMEI, so this should be declared as "Not collected" per Play's definition — but keep a note that it is sent to the server for license binding.
  - **Collected but kept on-device only (no server share):** business profile (name, owner, phone, email, tax IDs), contacts (customers + suppliers with phone/email/address), invoices and payment history, products and prices, logo file. For Data Safety, data that never leaves the device does not need to be declared, *but* the privacy policy must still describe how it's stored.
  - **Shared with third parties:** None (confirmed — no Firebase, Sentry, Crashlytics, ads SDKs, or analytics).
  - **Security practices:** data is encrypted in transit (HTTPS to `api.almhdy24.com`), license and device IDs are encrypted at rest via Android Keystore / EncryptedSharedPreferences, backups are **not** encrypted (see H3).
  - **User can request data deletion:** Yes (contingent on H1).
- **Severity:** High. A wrong Data Safety declaration is itself a policy violation independent of the app's actual behavior.

### H3. Backup export is unencrypted plaintext JSON containing all business and customer PII
- **Where:** `lib/services/backup_service.dart` — the `.waraq` file is JSON with every row of `businesses`, `contacts`, `documents`, `document_items`, `document_payments`, `products`, `stock_movements`, `tax_profiles`, `payment_methods`, plus the business logo base64. Shared via `share_plus` or written to a user-chosen path with no password.
- **Issue:** The privacy policy localization string (`app_localizations.dart` → "Your data is always safe") implies protection that doesn't exist for exports. The moment the user attaches a backup to WhatsApp, email, or a cloud drive, every customer phone number and tax ID is in plaintext. Not a direct Play policy violation (user-initiated export), but misrepresenting it in the privacy policy is.
- **Fix:**
  - Either: (a) encrypt the backup with a user-supplied passphrase using Dart's `cryptography` or `pointycastle` (AES-GCM with PBKDF2-derived key); (b) at minimum, show a clear in-UI warning before export that the file is unencrypted plaintext; and (c) update the privacy policy text so it does not claim exports are protected.
- **Severity:** High for privacy claim consistency; Medium for the app itself.

### H4. The paywall's "pay outside the app" messaging is explicit in Arabic and English
- **Where:**
  - `app_localizations.dart:599` — "Attach Payment Proof (optional)" / "إرفاق إيصال الدفع (اختياري)"
  - `app_localizations.dart:622` — "we'll contact you if there's any issue and send your license key"
  - `payment_flow_screen.dart:320-330` — displays server-provided `method.instructions` which, for a "Bank Transfer" or "Mobile Wallet" method, will contain external bank/wallet details.
- **Issue:** Even if B1 is fixed by switching to Play Billing, any residual UI copy that instructs the user to pay by bank transfer/wallet/receipt will re-trigger the same violation. The entire payment UI needs to be removed, not just rewired.
- **Fix:** When implementing Play Billing, delete `payment_flow_screen.dart`, `payment_methods_screen.dart`, the "Attach proof" / "Payment Proof" / "Buyer contact" strings in `app_localizations.dart`, and the `payment_methods` seed data from `database_helper.dart`. Keep `subscription_screen.dart` but have it call Play Billing instead of `SubscriptionService.createOrder`.

---

## Medium (should fix before release, but unlikely to cause rejection on its own)

### M1. No global uncaught-error handler — one unhandled Future rejection takes the app down silently
- **Where:** `lib/main.dart:10-26`. There is no `FlutterError.onError`, no `PlatformDispatcher.instance.onError`, no `runZonedGuarded`.
- **Fix:** Wrap `runApp` with `runZonedGuarded` and set `FlutterError.onError` to log to local file (not to any analytics SDK — stay consistent with "no analytics" story) so crashes in release can be diagnosed from a user-exported log.

### M2. No ProGuard / R8 keep rules
- **Where:** `android/app/build.gradle.kts` — no `proguardFiles`, no `android/app/proguard-rules.pro`.
- **Issue:** `flutter build apk --release` enables R8 shrinking by default. Flutter's embedding ships with the default consumer rules for Flutter itself, but reflection-heavy packages (`pdf`, `printing`, `sqflite`, `flutter_secure_storage`'s encryption classes) sometimes need `-keep` rules. There is no evidence that a release build has been exercised, so a hidden `ClassNotFoundException` on first run is possible.
- **Fix:** Do a full release install on a real device, exercise invoice PDF export, printing, backup restore, and license activation (after fixing B2). If anything crashes, add targeted `-keep` rules in `android/app/proguard-rules.pro` and reference it from `release` build type.

### M3. `android:allowBackup` and `android:dataExtractionRules` are not explicitly declared
- **Where:** `android/app/src/main/AndroidManifest.xml:3-6`.
- **Issue:** Default `allowBackup=true` means Google's Auto Backup will push the SQLite database (including customer PII) to the user's Google account on devices targeting API ≤ 30 behavior. On API 31+ with `dataExtractionRules` undefined, the behavior changes but can still back up data. For a business-document app this is probably not desired.
- **Fix:** Decide explicitly:
  - If you want backups: set `android:allowBackup="true"` and add `android:dataExtractionRules="@xml/data_extraction_rules"` plus `android:fullBackupContent="@xml/backup_rules"` listing what to include/exclude. Exclude the SQLite file and secure-storage prefs if you don't want them going to Google Drive.
  - If you don't: set `android:allowBackup="false"` and leave the rules XML out. Simpler, safer for business data.
- Mention the choice in the privacy policy.

### M4. `applicationId` has a leftover `TODO` comment
- **Where:** `android/app/build.gradle.kts:19-20` — `// TODO: Specify your own unique Application ID`. The ID is already set correctly (`com.elmahdi.waraqatak`), the comment is just stale.
- **Fix:** Delete the comment.

### M5. CI pins Flutter 3.41.9 and will fall out of date silently
- **Where:** `.github/workflows/ci.yml:31,61`, and the newly-added `.github/workflows/build-debug.yml` uses `channel: stable` (which drifts).
- **Issue:** The release CI will keep building against 3.41.9 even after the Flutter default `targetSdk` moves. For release builds, pin the Flutter version *and* set `targetSdk` explicitly (see B3) so neither can drift silently.
- **Fix:** Keep the pin, but add `targetSdk = 36` in gradle so the Flutter default never matters. Consider pinning `build-debug.yml` to the same version for parity.

### M6. Font and asset licensing is not documented in-repo
- **Where:** `assets/fonts/Tajawal-Regular.ttf`, `assets/fonts/Tajawal-Bold.ttf`, `assets/icon/*`, `assets/logo.svg`, `assets/splash/*`. No `OFL.txt` / `LICENSE` alongside the fonts, no attribution screen in-app.
- **Issue:** Tajawal is distributed under the SIL Open Font License, which **requires** the license text to accompany the font files when redistributed. The app re-ships the TTFs inside the APK but ships no OFL.txt. Technically a license-term violation and an IP-policy risk. Also, the in-app "About" screen does not surface open-source attributions (recommended but not required by Play).
- **Fix:**
  - Drop `OFL.txt` into `assets/fonts/` and list it in `pubspec.yaml` under `assets:`.
  - Add an "Open-source licenses" entry in Settings/About that opens Flutter's built-in `showLicensePage()`.

### M7. The `onUpgrade` migration catches schema errors with `catch (_) {}`
- **Where:** `lib/database/database_helper.dart` around lines 400, 407, 467.
- **Issue:** The intent is "ALTER TABLE may fail if the column already exists; ignore and continue" (defensive migration). That's reasonable, but it also silently swallows real database corruption or driver bugs. On the first update from the published MVP, this could hide a broken migration from the developer.
- **Fix:** Narrow the catches to the specific SQLite exception for duplicate-column (`DatabaseException` with code `SQLITE_ERROR` and message matching "duplicate column"), rethrow anything else. Low effort, meaningfully safer.

### M8. Clock-rollback mitigation changes behavior silently
- **Where:** `lib/services/license_service.dart:146-166`.
- **Issue:** If the device clock is rolled back more than 2 minutes, the trial start date is advanced by the delta. On a user whose timezone changed, this will shorten their trial without any UI explanation. Minor product/UX issue; could generate 1-star reviews.
- **Fix:** Compare against `DateTime.now().toUtc()` instead of local time, and ignore timezone-only shifts. Alternatively, use `boot_time` + `elapsedRealtime` via a platform channel.

---

## Low (polish, not blocking)

### L1. `versionCode` must be strictly higher than the current Play Store MVP
- Current repo: `1.0.0+3` (versionCode 3). Confirm the published MVP's versionCode in Play Console (look at the "App bundle explorer"); if it's ≥ 3, bump the repo to `1.0.0+4` or higher before uploading. Flutter respects the `+N` suffix in `version:` and `android/app/build.gradle.kts:29` wires it correctly.

### L2. No analytics / crash reporting is a feature, keep it a feature
- Zero third-party SDKs is unusual and is actively good for the Data Safety story. The privacy policy should state this explicitly so the Data Safety declaration is defensible. ("We do not integrate any analytics, advertising, or crash reporting SDKs.")

### L3. Permissions declaration form — nothing requires one today
- The main manifest requests only `CAMERA` (for `mobile_scanner`). No `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `SMS`, `CALL_LOG`, or Accessibility. The `<queries>` block in the manifest uses specific `<intent>` and `<package>` entries (WhatsApp consumer + business), which is the privacy-friendly pattern Google explicitly recommends in place of `QUERY_ALL_PACKAGES`. No Permissions Declaration Form is needed for the current setup. (If you later add `file_picker` on API 33+ for images or `printing` with scoped storage, re-check which runtime permissions get pulled in via manifest merge.)
- **Policy citation:** *Permissions and APIs that Access Sensitive Information* (`support.google.com/googleplay/android-developer/answer/16558241`) and *QUERY_ALL_PACKAGES* (`support.google.com/googleplay/android-developer/answer/10158779`).

### L4. CAMERA permission needs a rationale and runtime handling
- `mobile_scanner` requests `CAMERA` at runtime. Confirm the barcode scanner screen (`lib/screens/barcode_scanner_screen.dart`) shows a graceful "camera permission denied" state and that the Play listing's "App permissions" section explains that the camera is used only for barcode scanning.

### L5. `kotlin { compilerOptions { jvmTarget = JVM_17 } }` is correct, no change needed
- Just noting that `compileOptions` and the Kotlin block agree. No action.

### L6. Local keystore files in the repo working tree
- `upload-keystore.jks`, `upload-keystore.base64`, `waraqatak-upload-cert.pem` are present on disk (confirmed), properly git-ignored, and verified never committed. Keep them out of any shared tar/zip of the repo. The CI decodes `KEYSTORE_BASE64` from GitHub secrets, which is the right pattern.

### L7. Store listing content is not in-repo
- No `fastlane/`, `metadata/`, `store/`, `playstore/` directories. Fine — just make sure the manually-managed Play Console listing has: Arabic + English descriptions, screenshots (phone + 7"/10" tablet), feature graphic, privacy policy URL, Data Safety form, content rating.

### L8. No automated UI/widget tests
- `test/` contains only `test/services/` (service-level tests). This is OK for a static review but there's no end-to-end confidence that the full app launches. Before uploading, do a manual smoke test on Android 14 + 15 + 16 covering: fresh install → onboarding → create business → create invoice → print/share PDF → activate license (after fixing B1/B2) → backup → restore → upgrade from previous MVP install (critical, see upgrade path below).

---

## Upgrade path from the published MVP

The MVP in production uses an earlier version of the SQLite schema. The current repo's schema is at version 11 and `_upgradeTables` handles each migration additively (verified: `database_helper.dart` lines 244-482; no destructive `DROP TABLE` or `DELETE FROM` on user data). This is good.

Specific checks to do on a real device **before** publishing:

1. Install the current Play Store MVP APK fresh.
2. Create 1 business, 2-3 customers, 2-3 products, 2-3 invoices (one paid, one partial, one unpaid).
3. Side-load the new release APK as an update (`adb install -r`). Confirm:
   - All invoice rows show the correct `status`, `paid`, `total`, and `currency_code`.
   - All contact rows have `email`, `notes`, `active` populated with sensible defaults.
   - The new `tax_profiles` and `payment_methods` tables exist and the migration from `SharedPreferences('payment_methods')` to the `payment_methods` table (`database_helper.dart` v11) actually copied the user's prior configuration.
   - The business logo path still resolves.
4. If any check fails, do **not** release the AAB — users will lose data irreversibly on auto-update.

The trial logic will reset the user to the "trial active" state on first launch of the new build only if `wq_trial_start` was never written. Users who were on the MVP (no license system) will see "14-day trial" from the moment of the update, which is reasonable, but **should be announced in the Play Store "What's new" release notes** so users don't feel surprised that previously-free features are becoming paid. This is a product/communication decision as much as a technical one.

---

## Play Console checklist (manual, outside this repo)

Do each of these in Play Console before pressing Publish. None of them can be done from code.

- [ ] **App content**
  - [ ] Privacy policy URL set to `https://almhdy24.com/products/waraqatak/privacy.html` (verify it loads and matches the actual data flows described in H2).
  - [ ] Ads declaration: "No, my app does not contain ads".
  - [ ] App access: provide credentials or a video walkthrough showing the paid flow (reviewers can't actually make a purchase otherwise).
  - [ ] Content rating questionnaire: answer honestly — expected result is "Everyone / 3+". No violence, UGC-to-strangers, gambling, drugs, or sexual content.
  - [ ] Target audience and content: "18+" or "all ages, not primarily targeting children" — the app is a business tool, so pick "not primarily directed to children" to stay out of the Families Policy scope.
  - [ ] Government apps / COVID / health / finance declarations: finance *may* apply because the app records invoices and tax IDs. Review the "Finance" category requirements if the app is categorized as Business or Finance.
  - [ ] News apps: no.
- [ ] **Data safety**
  - [ ] Fill out the form using the draft in H2.
  - [ ] Add the account/data deletion URL (requires H1 to be implemented first).
  - [ ] Confirm "Data is encrypted in transit" = Yes and "Data can be deleted" = Yes.
- [ ] **Payments profile**
  - [ ] If (B1) is resolved by switching to Play Billing: create a Payments Profile in Google Play Console → Monetize → Products → Subscriptions, define the 4 base plans with correct SDG prices (and multi-currency as needed), configure the free trial, add real-time developer notifications via Pub/Sub.
  - [ ] If pursuing Alternative Billing: apply for and complete enrollment *before* uploading; prepare the User-Choice-Billing disclosures.
- [ ] **Target API level**
  - [ ] Confirm the AAB targets API 36 (see B3).
- [ ] **Signing**
  - [ ] Confirm Play App Signing is enabled and the upload key fingerprint matches `waraqatak-upload-cert.pem`.
- [ ] **Release track**
  - [ ] Push the first release of the new code to **Closed testing** (internal + closed track with ~20 real testers) before Production. Do **not** overwrite the live MVP track directly. Monitor crash-free rate and ANR rate for at least a week.
  - [ ] After closed testing passes, do a **staged rollout** on Production (5% → 20% → 50% → 100%) so the migration from the MVP schema can be halted at the first sign of trouble.
- [ ] **Store listing**
  - [ ] Arabic (ar) and English (en) listings.
  - [ ] Phone + tablet screenshots.
  - [ ] Feature graphic (1024×500).
  - [ ] "What's new in this version" — explicitly mention the free vs. Pro tier and the 14-day trial so users aren't surprised.
- [ ] **In-app products**
  - [ ] Only applies if B1 is resolved via Play Billing. Create the 4 subscription plans with real local prices and attach them to the paywall.

---

## Appendix A — endpoints the app currently calls

| Endpoint | Verb | Called from | Data sent |
|---|---|---|---|
| `https://api.almhdy24.com/api/v1/pay/payment-methods` | GET | `subscription_service.dart:37` | — |
| `https://api.almhdy24.com/api/v1/pay/orders` | POST (json or multipart) | `subscription_service.dart:55` | `app_slug`, `payment_method_id`, `buyer_name`, `buyer_contact`, `amount`, `currency`, `proof_note?`, `proof_file?`, `idempotency_key` |
| `https://api.almhdy24.com/api/v1/pay/orders/{reference}` | GET | `subscription_service.dart:75` | `reference` |
| `https://api.almhdy24.com/api/v1/pay/licenses/activate` | POST | `subscription_service.dart:86` | `license_key`, `machine_id` |

All over HTTPS. No API keys hardcoded. No auth header on the public endpoints.

## Appendix B — security hygiene that is good as-is (no action needed)

- `upload-keystore.jks`, `upload-keystore.base64`, `waraqatak-upload-cert.pem`, `android/key.properties` are all git-ignored and verified never committed (`git log --all --diff-filter=A --name-only` is clean).
- No hardcoded API keys, Bearer tokens, Firebase config, or Sentry DSN anywhere in `lib/`, `packages/`, `android/`, or git history.
- No cleartext (`http://`) endpoints.
- No `badCertificateCallback` / `allowInvalidCertificates` TLS bypasses.
- `flutter_secure_storage` is used for everything sensitive (license key, device ID, trial start, idempotency key) with `AndroidOptions(resetOnError: false)` and EncryptedSharedPreferences on API 23+.
- No analytics / crash reporting / ads SDKs.
- Dependency versions in `pubspec.yaml` are current with no known CVEs.
- CI secrets handling in `.github/workflows/ci.yml` and `release.yml` is correct (shell-conditional guard around the base64 decode, no `echo` of secret values).

## Appendix C — what was not verified

- `flutter analyze` and `flutter test` — Flutter is not available in the current Termux shell. Both need to run in CI before shipping. The existing `.github/workflows/ci.yml` already runs them on push to `main`; confirm they pass on the release commit.
- End-to-end install on a real Android 16 device.
- Manual migration test from the published MVP → this build.
- Behavior of R8-shrunk release build (see M2).
- Whether `almhdy24.com/products/waraqatak/privacy.html` is live and accurately describes current data handling (reach the URL from a browser and compare against H2's draft Data Safety answers).

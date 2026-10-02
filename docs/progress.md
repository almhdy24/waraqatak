# Progress log — `play-compliance` branch

## Step 1 — Clean activation client

Changes

- `lib/services/activation_service.dart` reworked:
  - Introduces `enum ActivationOutcome { success, invalid, tooManyAttempts, serverUnreachable }`.
  - Normalizes the pasted key (strips ASCII whitespace, Unicode whitespace,
    newlines, and the zero-width characters `U+200B`, `U+200C`, `U+200D`,
    `U+2060`, `U+FEFF`) before sending. Casing, dashes, and all visible
    characters are preserved verbatim.
  - HTTPS base URL constant `https://api.almhdy24.com` + hard 15-second
    per-request timeout. No automatic retries.
  - Outcome mapping (via the typed Elmahdi Pay SDK exceptions):
    - 2xx → store the license, return `success`. Malformed/empty/non-JSON
      bodies on 2xx are swallowed (`catch (_)`) and still return `success`
      because the HTTP call itself succeeded — "never crash on malformed
      JSON".
    - 401 / 403 / 404 / 409 / 422 and any other 4xx that is not 429 → one
      `invalid` outcome. The server's own message is never surfaced.
    - 429 → `tooManyAttempts`.
    - Network error, timeout, 5xx → `serverUnreachable`. This is never
      shown as "invalid key" so a valid key is not maligned by a transport
      failure.
  - `debugOverrideClient` / `debugResetClient` test hooks let MockClient
    be injected without touching production call sites.
  - No `print` / `debugPrint` / `developer.log` of keys or responses.
- `lib/screens/activation_screen.dart` now switches on `ActivationOutcome`
  and renders one of the four messages below (`invalidOrExpiredKey`,
  `activationTooManyAttempts`, `activationServerUnreachable`, or the
  success state). The screen itself no longer catches typed SDK exceptions.
- `lib/localization/app_localizations.dart`: adds
  `activationTooManyAttempts` and `activationServerUnreachable` (AR + EN).
  Existing mandated copy is untouched.
- `pubspec.yaml`: adds `http: ^1.2.0` under **dev_dependencies**. `http`
  was already in the dependency graph transitively via
  `elmahdi_pay_flutter`; the direct dev-dep pin only makes
  `package:http/testing.dart` importable in test files. No new runtime
  dependency.
- `test/services/activation_service_test.dart`: MockClient-driven unit
  tests covering every outcome branch, request contract, normalization,
  the no-retry invariant, and the "never crash on malformed JSON" rule.

### On-the-wire contract (asserted in tests)

```
POST https://api.almhdy24.com/api/v1/pay/licenses/activate
Content-Type: application/json
Accept: application/json

{ "license_key": "<normalized>", "machine_id": "<per-install UUID v4>" }
```

The request body has **exactly two fields**. The test
`request targets HTTPS /api/v1/pay/licenses/activate with JSON body` fails
if either field is renamed, if a third field is added, if the method
changes, or if the base URL drops to HTTP.

### What is persisted on `success`

`LicenseService.storeLicense(licenseKey, expiresAt: null, isActive: true)`
writes three keys through `flutter_secure_storage`
(Android `EncryptedSharedPreferences`, Android Keystore, API 23+):

| Key                 | Value on success     |
|---------------------|----------------------|
| `wq_license_key`    | the normalized key   |
| `wq_license_expiry` | `''` (empty string)  |
| `wq_license_status` | `'active'`           |

Nothing else is written. The server's `activation_token` from the response
body is intentionally **not** stored — the current app does not perform
offline token verification; it decides entitlement purely from the three
keys above.

### Does the app re-contact the server after a successful activation?

**No.** `LicenseService._compute()` reads only the three secure-storage
keys to decide entitlement; it never makes a network call. The only code
path in the app that reaches `api.almhdy24.com` is the activate button on
`ActivationScreen`. After a successful activation the app does not call
the server again — not on launch, not on resume, not in the background.
This has been verified by static reading of `lib/services/`.

Caveat: because there is no server-side refresh, a license revoked
server-side will continue to grant Pro locally until the user re-attempts
activation or reinstalls. This is a deliberate consequence of the
Play "consumption-only" model — the server has no push channel to the
device.

## Step 2 — Honest status and error copy

- `lib/services/license_service.dart`: adds `clearLicense()` which
  deletes `wq_license_key`, `wq_license_expiry`, `wq_license_status`
  and invalidates the cache. Device-ID and trial markers are
  intentionally **not** touched.
- `lib/screens/license_screen.dart` (new): shows Status / Type /
  Expiry, a plain-language "What happens on expiry" block, an
  "Enter or change activation key" button, and a
  "Remove key from this device" action behind a confirmation.
- `lib/screens/settings_screen.dart`: Settings → License routes to
  the new screen (previously routed to `ActivationScreen`).
- Localization: `deviceAlreadyActivated` is retired; new keys cover
  license status, type, expiry, and the remove-key flow in AR + EN.
- Compliance guard: scope expanded to the License screen and its
  localization getters.
- `docs/play-compliance.md`: mandated-copy table updated.

## Step 3 — Transparency screen

- `lib/services/feature_access.dart`: `proFeatures` is now a public
  `const Set<Feature>`, and `freeFeatures` is derived as
  `Feature.values.toSet().difference(proFeatures)`. One source of
  truth for the free-vs-Pro split.
- `lib/screens/transparency_screen.dart` (new): renders both lists
  from `FeatureAccess` with Material 3 colours; no prices, no CTAs,
  no acquisition hints.
- Entry points: Settings → License → "See what is free vs Pro",
  `LockedFeatureScreen` info button, About → Transparency section.
- Localization: `transparencyXxx` + 12 `featureXxx` labels (AR + EN).
- Compliance guard: scope expanded to the Transparency screen and
  its localization getters.

## Step 4 — About page + hero icon

- `lib/core/constants/app_constants.dart`: outbound surface
  reduced to one email + three URLs
  (`privacy.html`, `terms.html`, `delete.html`). WhatsApp, Facebook,
  GitHub, root website, and product-page URLs removed.
- `lib/screens/about_screen.dart`:
  - Hero `Container` wrapped in `Semantics(label: appLogoLabel,
    image: true)` so a screen reader announces "Waraqatak logo"
    instead of silence.
  - Support section is email-only.
  - Developer section removed.
  - Three link tiles — Privacy, Terms, Delete-data — render under
    the Support section.
  - `showLicensePage` tile unchanged.
- Localization: adds `termsOfUse`, `termsDescription`,
  `deleteAccountData`, `deleteAccountDataDescription`,
  `appLogoLabel`. Removes orphan getters `contactWhatsApp`,
  `facebook`, `developer`, `visitWebsite`, `viewOnGitHub`,
  `waraqatakProductPage`.
- `test/screens/about_hero_contrast_test.dart` (new): pure-Dart WCAG
  contrast-ratio test that pulls `primary` and `tertiary` from the
  live `ColorScheme.fromSeed(...)` config and asserts ≥ 4.5:1 vs
  white. Tracks the theme automatically if the seed changes.

### Website URL verification — ALL THREE 404

`curl -sI` against each allowlisted URL on 2026-10-02 returned
`HTTP/2 404`:

| URL                                                           | Status |
|---------------------------------------------------------------|--------|
| `https://almhdy24.com/products/waraqatak/privacy.html`        | 404    |
| `https://almhdy24.com/products/waraqatak/terms.html`          | 404    |
| `https://almhdy24.com/products/waraqatak/delete.html`         | 404    |

The HTML files exist on the author's dev tree at
`~/almhdy24.com/products/waraqatak/*.html` but are not reachable
from the public site. **This blocks Play review** — a reviewer
tapping any of the three About-screen links will see a 404.
Carried forward to Step 5 as the top consistency finding; the fix is
server-side (deploy the three HTML files), not an app change.

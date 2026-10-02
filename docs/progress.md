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

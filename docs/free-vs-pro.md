# Free vs Pro — feature matrix

Source of truth: `lib/services/feature_access.dart`.
Any update there automatically changes the Transparency screen, the paywall,
and the locked-feature flow. Keep this document in sync — the compliance
guard (`tool/check_play_compliance.sh`) does not regenerate it, so a diff on
`FeatureAccess` without a diff here is a review flag.

## Model

- The app ships one build. There is no "Pro build" to buy on Google Play.
- Every user begins with a **14-day Pro trial** from first launch (set in
  `lib/services/license_service.dart`, constant `_trialDays`). During the
  trial, all features are unlocked.
- After day 14 the entitlement drops to **Free**. Free features remain
  fully accessible. Pro features show the locked-feature screen.
- Pro features are unlocked by entering a valid activation key under
  **Settings → License → Enter or change activation key**. The key is
  obtained outside the app; the app itself does not sell, price, or route
  the user to a seller.

## Free features

Always available: during trial, after trial expiry, with an activated
license, and with a revoked license. No gating, no CTA.

| Feature enum          | Description                                      |
|-----------------------|--------------------------------------------------|
| `invoices`            | Create, edit, number, and share invoices         |
| `quotations`          | Issue price quotations with their own numbering  |
| `vouchers`            | Receipt and payment vouchers linked to invoices  |
| `customDocuments`     | Freeform documents with custom fields            |
| `customers`           | Customer directory, balances, history            |
| `products`            | Product/service catalogue with units and taxes   |
| `barcode`             | Mobile-camera barcode scanner for product lookup |
| `basicReports`        | Daily/monthly summary reports                    |
| `backupRestore`       | Export and import the local database as `.waraq` |

## Pro features

Require an active trial or a stored activation key.

| Feature enum       | Description                                         |
|--------------------|-----------------------------------------------------|
| `purchases`        | Purchase orders, suppliers, and purchase history    |
| `inventory`        | Stock movements, reorder points, warehouse ledger   |
| `advancedReports`  | Purchases/supplier/inventory/product reports and accounting statements (income statement, balance sheet, trial balance, account ledger) |

## Entitlement outcomes

| State                | What the user sees                                   |
|----------------------|------------------------------------------------------|
| `trialActive`        | Everything unlocked; countdown shown in License card |
| `trialExpired`       | Free features unlocked; Pro features show paywall    |
| `licensed`           | Everything unlocked; expiry is not shown unless set  |
| `licenseExpired`     | Treated as `trialExpired` locally — no server push   |
| `licenseRevoked`     | Treated as `trialExpired` locally — no server push   |

Revocation and expiry are decided locally from secure-storage keys
(`wq_license_key`, `wq_license_status`, `wq_license_expiry`,
`wq_license_type`, `wq_last_seen`). The app does not re-contact
`api.almhdy24.com` after a successful activation, so a server-side
revocation takes effect only when the user next re-attempts activation.

The expiry comes from the signed key itself: keys are
`base64url(payload).base64url(signature)` and the payload carries
`app_slug`, `expires_at` (null for lifetime) and, on newer keys,
`license_type`. The signature is verified only by the server.

### Activation guard (1.1.1)

Before the server is contacted, and before anything is stored, activation
returns the generic invalid outcome when:

- the payload does not parse, or `expires_at` / `license_type` is present
  but unusable (for example an unparseable date);
- `app_slug` is not `com.elmahdi.waraqatak`, or `expires_at` has passed;
- `license_type` is anything other than `lifetime` and `expires_at` is
  missing, null, unparseable or in the past. This protects users and the
  publisher from a server issuance mistake that would otherwise grant
  unlimited access. Legacy keys without a `license_type` still activate.

Activation succeeds only when the server answered 2xx and the key payload
parsed. Network errors, timeouts and any unexpected exception return
`serverUnreachable` and store nothing.

### Expiry evaluation (1.1.1)

- License expiry is compared against `max(device clock, wq_last_seen)`.
  `wq_last_seen` is persisted in secure storage and only moves forward, so
  rewinding the device clock does not bring an expired license back.
  The trade-off: if the device clock is set far into the future while the
  app runs, Pro stays locked until real time catches up. Free features and
  all data are unaffected.
- A stored expiry that cannot be parsed counts as expired (Pro locked), not
  unlimited.
- The license type is stored at activation. A missing expiry is accepted
  only for a stored type of `lifetime`.
- Installs that activated before 1.1.1 have no stored type. They keep the
  earlier behaviour (no expiry = lifetime), so existing users are not
  locked out.
- The entitlement is re-evaluated when the app returns to the foreground
  and every time a Pro-gated screen is opened, so a running session cannot
  outlive expiry beyond the next navigation.

## Non-features (deliberate omissions)

The app does **not** have any of the following, by Play policy. Any
future PR adding one of these must also update `docs/play-compliance.md`:

- In-app purchase, in-app price, in-app ordering, or any Google Play
  Billing SKU.
- Links to a pricing page or a "contact to buy" page. Support links
  (email, WhatsApp, Facebook, website) exist only on the About screen,
  describe help and contact only, and never mention licences or keys (see
  "Support surface" in `docs/play-compliance.md`).
- Phone numbers for sales.
- "Buy Pro", "subscribe", "pay now", "checkout" wording in any
  reviewer-visible screen (see Pass 1 of the compliance guard).

## Pointers

- Code: `lib/services/feature_access.dart`
- Transparency screen: `lib/screens/transparency_screen.dart`
- Paywall: `lib/screens/locked_feature_screen.dart`
- License screen: `lib/screens/license_screen.dart`
- Compliance guard: `tool/check_play_compliance.sh`
- Mandated copy and server contract: `docs/play-compliance.md`

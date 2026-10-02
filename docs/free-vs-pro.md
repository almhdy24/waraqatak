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
| `advancedReports`  | Detailed profit, aging, and reconciliation reports  |

## Entitlement outcomes

| State                | What the user sees                                   |
|----------------------|------------------------------------------------------|
| `trialActive`        | Everything unlocked; countdown shown in License card |
| `trialExpired`       | Free features unlocked; Pro features show paywall    |
| `licensed`           | Everything unlocked; expiry is not shown unless set  |
| `licenseExpired`     | Treated as `trialExpired` locally — no server push   |
| `licenseRevoked`     | Treated as `trialExpired` locally — no server push   |

Revocation and expiry are decided locally from three secure-storage keys
(`wq_license_key`, `wq_license_status`, `wq_license_expiry`). The app does
not re-contact `api.almhdy24.com` after a successful activation, so a
server-side revocation takes effect only when the user next re-attempts
activation.

## Non-features (deliberate omissions)

The app does **not** have any of the following, by Play policy. Any
future PR adding one of these must also update `docs/play-compliance.md`:

- In-app purchase, in-app price, in-app ordering, or any Google Play
  Billing SKU.
- Links to a pricing page, a WhatsApp number, a Facebook page, or a
  "contact to buy" page.
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

# End-to-End Manual Testing Runbook

This runbook outlines end-to-end verification procedures to perform when deploying and testing Waraqatak on a real physical Android device.

---

## Prerequisites
- Physical Android phone with developer options enabled.
- App built from `feat/license-hardening` branch.
- API and Admin Panel deployed to staging/production.

---

## Test Scenario 1: Initial Launch & Trial Activation
1. **Fresh Install:** Install the app on the device.
2. **Observe Entitlement:**
   - Open drawer / settings -> Pro Status.
   - Verify device is on Free Trial with 14 days remaining.
   - Verify all Pro features (e.g. Invoicing with Wholesale pricing, Barcode scanner) are functional.
3. **Database Check:**
   - In API admin panel -> Trials, verify a trial row exists matching the device's anonymized `machine_id`.

---

## Test Scenario 2: License Activation (Crockford Key)
1. **Valid Key Entry:**
   - Open Activation screen.
   - Enter a valid 12-character Crockford Base32 key (e.g., lowercase with hyphens or spaces).
   - Tap "Activate".
2. **Verification:**
   - Key is normalized automatically (hyphens stripped, checksum verified).
   - Dialog confirms successful activation.
   - Entitlement screen transitions to "Activated (Lifetime)" or "Activated (Annual)".
   - Back on API admin panel -> Licenses, verify license status shows active and device is bound.

---

## Test Scenario 3: Invalid Key & Anti-Enumeration Support UX
1. **Invalid Key Entry:**
   - Enter an unissued or malformed Crockford key.
   - Tap "Activate".
2. **Verification:**
   - Screen displays neutral, non-leaking error message: "Invalid or expired activation key".
   - Underneath, a `SupportGuidanceCard` is displayed:
     - Text: *"If the problem continues, contact support from the About page."*
     - Button: *"Open About page"* -> navigates directly to `AboutScreen`.
     - Button: *"Copy support information"* -> copies diagnostic payload to clipboard.
3. **Clipboard Inspection:**
   - Paste clipboard into notes or messenger.
   - Verify the license key is strictly masked (e.g., `ABCD-****-EFGH`).
   - Verify `reference_id` (the server's `correlation_id` or client fallback) is present for admin lookup.

---

## Test Scenario 4: In-App Notifications & Targeting
1. **Create Notification in Panel:**
   - Go to Admin Panel -> In-App Notifications -> New Notification.
   - Set Title: *"Update Required"*, Audience: *"All Users"*, Min App Version: `1.1.5`, Max App Version: `1.2.0`, Language: `ar`.
2. **Device Sync:**
   - Open Notifications Inbox in the app.
   - Pull down to refresh.
   - Verify notification appears in the list.
3. **Targeting Verification:**
   - Create another notification in Panel with Min App Version: `2.0.0`.
   - Pull down to refresh in app.
   - Verify the second notification does **NOT** appear on the 1.1.5 device.

---

## Test Scenario 5: Inbox Swipe-to-Delete & Persistent Tombstones
1. **Swipe to Delete:**
   - On a dismissible notification in the inbox, swipe horizontally to dismiss.
   - Verify item is removed with an undo SnackBar.
2. **Persistent Tombstone Verification:**
   - Pull down to refresh or restart the app.
   - Verify the deleted notification does **NOT** return.
3. **Multi-Select & Bulk Delete:**
   - Long-press a notification to enter selection mode.
   - Select multiple items.
   - Tap Delete in the top app bar and confirm.
   - Pull to refresh; verify all deleted items remain gone.
4. **Critical Notification Protection:**
   - Send a notification with `is_dismissible: 0` (or `priority: critical`).
   - Verify a lock badge is shown and swipe/delete actions are disabled.

---

## Test Scenario 6: Google Play Consumption Compliance
1. **Inspect Reviewer-Visible Screens:**
   - Open `LockedFeatureScreen`, `ActivationScreen`, `LicenseScreen`, and `AboutScreen`.
   - Verify **ZERO** mentions of "buy", "purchase", "pricing", subscription plans, or external WhatsApp numbers on gating screens.
   - Verify support channels are strictly housed inside `AboutScreen`.

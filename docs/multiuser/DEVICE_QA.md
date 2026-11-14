# Waraqatak — On-Device QA Runbook: Multi-User & Permissions Hardening

## 1. Test Environment Specification
- **Hardware:** Real Android phone (ARM64, 4 GB RAM, Termux environment).
- **Target Branch:** `fix/multiuser-stabilization`
- **Database Engine:** SQLite (offline-first, schema v30 with Owner triggers and append-only audit trail).
- **Crypto Engine:** Pure-Dart PBKDF2-HMAC-SHA256 with hardware-calibrated iteration counts (20k–200k iterations).

---

## 2. Test Execution Matrix

### Test 1: Single-User Baseline Performance (Zero Overhead)
1. **Setup:** Install fresh database with `multi_user_enabled = '0'`.
2. **Action:** Launch the app, create invoices, register payments, and adjust stock.
3. **Expected Outcome:**
   - No login or PIN prompts appear at any point.
   - All actions proceed with instantaneous response.
   - `SessionManager.can()` returns `true` immediately via the cached boolean fast-path.
   - No background auto-lock timers or password checks fire.

### Test 2: Multi-User Setup Wizard & Credential Calibration
1. **Setup:** Navigate to Settings -> Multi-User Mode -> Enable Multi-User.
2. **Action:**
   - Enter Owner Password (min 6 chars, e.g. `OwnerPass123!`).
   - Test PIN field (confirm it is optional, enter 4–6 digits or leave blank).
   - Tap "Proceed" and observe crypto progress indicator.
3. **Expected Outcome:**
   - Progress bar indicates background KDF benchmarking (~300ms target).
   - Recovery code displayed in format `RC-XXXX-XXXX-XXXX` (12 characters, base-32 charset excluding ambiguous characters `0`, `1`, `O`, `I`).
   - Copy/Save confirmation checkbox required before proceeding.
   - Attempting to leave without confirming shows a warning snackbar (`recoveryLeaveBlocked`).
   - Real Owner session is loaded into memory and written to `app_settings` (`multi_user_enabled = '1'`).

### Test 3: Cashier Role Creation & User Provisioning
1. **Setup:** Logged in as Owner, open Roles screen (`RolesScreen`) and Users Management screen (`UsersListScreen`).
2. **Action:**
   - There is no seeded Cashier role. Create a custom role first named "Cashier" with permissions:
     - `sales.view`
     - `sales.create`
     - `sales.edit_discount`
     - `payments.record`
   - Open User Management and create Cashier user (`cashier1`) with the custom Cashier role and 4-digit PIN `1234`.
   - Attempt to grant `license.manage` or `backup.restore` to Cashier.
3. **Expected Outcome:**
   - Owner-only keys (`license.manage`, `system.repair`, `backup.restore`) are hidden or disabled in UI with localized explanation.
   - Cashier and Manager users saved with individual `kdf_iterations`.
   - `PermissionService.invalidateCache` invalidates in-memory permission cache immediately.
   - Audit trail records `role_created` and `user_created` events.

### Test 4: Cashier Daily POS Sales & Deny-by-Default Navigation
1. **Setup:** Log out of Owner; Cashier taps their avatar on PIN lock screen and enters PIN `1234`.
2. **Action:**
   - Create sales invoice, apply line discounts, record cash payment.
   - Tap navigation menu to open Settings, License, Financial Settings, or Database Diagnostics.
3. **Expected Outcome:**
   - Invoice creation, PDF preview, and payment recording succeed without hindrance.
   - All restricted Settings tiles (License, Diagnostics, Period Lock, User Management) are hidden or blocked by `ScreenAccessGate`.
   - Direct route navigation presents bilingual `AccessDeniedView` with localized explanation and back button.
   - Audit trail records `privilege_escalation_denied` for any blocked route entry.

### Test 5: Auto-Lock & 4–6 Digit PIN Unlock
1. **Setup:** Leave phone untouched for the configured auto-lock duration (or tap Lock in menu).
2. **Action:**
   - Screen pops to root and displays PIN lock overlay.
   - Attempt to press actions underneath the overlay.
   - Enter 4 digits of a 5-digit PIN and observe no premature auto-submit occurs.
   - Enter full PIN and tap explicit Confirm button.
3. **Expected Outcome:**
   - While locked, `SessionManager.can()` returns `false` for all permissions.
   - Explicit confirm button supports 4, 5, and 6 digit PINs without auto-submitting.
   - Correct PIN unlocks session and restores current user permissions.

### Test 6: In-Memory Device Throttle & Lockout Protection
1. **Setup:** Open PIN Lock screen.
2. **Action:**
   - Deliberately enter 5 consecutive wrong PINs across any accounts.
   - Observe device-level throttle. Note: The device throttle is maintained in-memory and resets on app restart.
   - Enter 5 more failed PINs (10 total failures).
3. **Expected Outcome:**
   - After 5 total device failures: 30-second throttle wait timer halts all entry across all accounts.
   - After 10 total device failures: 120-second throttle wait timer halts all entry across all accounts.
   - User account lockout duration escalates up to 15 minutes for non-owners, but strictly capped at 5 minutes (INV: max 300s) for Owner.
   - Countdown timer displays cleanly formatted mm:ss (`formatDurationMmSs`).
   - Dialog catches auth exceptions and displays localized error messages without crashing.

### Test 7: Background App Auto-Lock Verification
1. **Setup:** Configure auto-lock timeout to 1 minute.
2. **Action:**
   - Background the app (press Home button) for > 1 minute.
   - Resume the app.
3. **Expected Outcome:**
   - On resume, the app is immediately locked and presents `PinLockScreen`.
   - Access to underlying business data or screens is blocked until unlocked.

### Test 8: Unacknowledged Recovery Code Lifecycle (Kill App Protection)
1. **Setup:** Lock screen -> tap "Forgot Password / Recovery".
2. **Action:**
   - Enter valid recovery code, enter new Owner password and new PIN.
   - Tap "Recover Credentials". The new recovery code screen appears.
   - Immediately force-kill the app (swipe away from Android Recents).
   - Re-open the app.
3. **Expected Outcome:**
   - The unacknowledged recovery code screen is displayed again upon next Owner login/session.
   - The user is prevented from navigating away (`PopScope` blocked) until they check the confirmation box and tap "Unlock".
   - The `owner_recovery_code_unacknowledged` flag in `app_settings` is cleared only after explicit user acknowledgment.

### Test 9: Calibrated User Password Reset & Login (KDF Iteration Integrity)
1. **Setup:** Logged in as Owner. Open User Management -> Edit existing user who has custom calibrated iterations.
2. **Action:**
   - Reset the user's password from `UserFormScreen`.
   - Save changes.
   - Log out and log in as the edited user using their new password.
3. **Expected Outcome:**
   - User updates with preserved `kdf_iterations` (never resetting to default or zero).
   - Login succeeds smoothly with the new password.
   - Audit trail records `user_updated` with updated fields list.

### Test 10: Bilingual Denial UX & Screenshot Checklist
1. **Setup:** Log in as Cashier (limited permissions).
2. **Action:** Attempt to access each screen in the manifest:
   - `SettingsScreen`
   - `MultiUserWizardScreen`
   - `UsersListScreen`
   - `RolesScreen`
   - `AuditTrailScreen`
   - `PeriodClosingScreen`
   - `DatabaseDiagnosticScreen`
3. **Screenshot Checklist:**
   - [ ] Verify `AccessDeniedView` renders in Arabic (RTL, right-aligned icons, correct title & message).
   - [ ] Verify `AccessDeniedView` renders in English (LTR, left-aligned icons, correct title & message).
   - [ ] Confirm no raw permission keys (`sales.view`, `admin.roles`) appear anywhere in the UI text.
   - [ ] Confirm back button returns safely to the previous screen or root.

### Test 11: Language Toggle UI Parity Verification
1. **Setup:** Open Settings -> Language.
2. **Action:**
   - Toggle app language to English. Walk through all multi-user screens: PIN lock, user list, role editor, audit trail.
   - Toggle app language back to Arabic. Repeat walkthrough.
3. **Expected Outcome:**
   - Zero Arabic characters `[\u0600-\u06FF]` appear in the English UI.
   - Zero untranslated English sentences appear in the Arabic UI.
   - Western digits (`0-9`) remain LTR in PIN inputs and timestamps across both languages.

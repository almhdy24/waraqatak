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
   - Progress bar / spinner indicates background KDF benchmarking (~300ms target).
   - 16-character recovery code displayed in 4x4 format (e.g. `ABCD-1234-EFGH-5678`).
   - Copy/Save confirmation checkbox required before proceeding.
   - Real Owner session is loaded into memory and written to `app_settings` (`multi_user_enabled = '1'`).

### Test 3: Cashier & Manager Provisioning
1. **Setup:** Logged in as Owner, open Users Management screen (`UsersListScreen`).
2. **Action:**
   - Create Manager user (`manager1`) with Manager role.
   - Create Cashier user (`cashier1`) with Cashier role and 4-digit PIN `1234`.
   - Attempt to grant `license.manage` or `backup.restore` to Cashier.
3. **Expected Outcome:**
   - Owner-only keys (`license.manage`, `system.repair`, `backup.restore`) are hidden/disabled in UI.
   - Cashier and Manager users saved with individual `kdf_iterations`.
   - `PermissionService.invalidateCache` invalidates in-memory permission cache immediately.
   - Audit trail records `user_created` events.

### Test 4: Cashier Daily POS Sales & Deny-by-Default Navigation
1. **Setup:** Log out of Owner; Cashier taps their avatar and enters PIN `1234`.
2. **Action:**
   - Create sales invoice, apply line discounts, record cash payment.
   - Tap navigation menu to open Settings, License, Financial Settings, or Database Diagnostics.
3. **Expected Outcome:**
   - Invoice creation, PDF preview, and payment recording succeed without hindrance.
   - All restricted Settings tiles (License, Diagnostics, Period Lock, User Management) are hidden or blocked by `ScreenAccessGate`.
   - Direct route navigation throws friendly "Access Denied" snackbar/dialog.
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

### Test 6: Brute-Force & Owner Lockout-DoS Protection
1. **Setup:** Open PIN Lock screen.
2. **Action:**
   - Select Cashier and deliberately enter 5 consecutive wrong PINs.
   - Select Owner and deliberately enter 5 consecutive wrong PINs.
   - Observe device-level behavior.
3. **Expected Outcome:**
   - Cashier is locked out with escalating duration up to 15 minutes.
   - Owner lockout duration is strictly capped at 5 minutes (INV: max 300s).
   - After 5 and 10 device failures, device throttle halts all attempts across all accounts for 30s/120s.
   - Password modal catches auth exceptions and displays localized error message without crashing.

### Test 7: Sensitive-Action Password Re-Authentication
1. **Setup:** Logged in as Owner in multi-user mode.
2. **Action:**
   - Attempt to: (a) Restore database backup, (b) Set accounting period lock, (c) Run diagnostic repair, (d) Disable multi-user mode.
3. **Expected Outcome:**
   - `SensitiveActionGate` dialog prompts for Owner password.
   - Entering incorrect password rejects action and logs `reauth_failed` to audit log.
   - Entering correct password executes sensitive action and logs `reauth_success`.
   - Disabling multi-user mode requires Owner session; Cashier attempt is denied.

### Test 8: Disaster Recovery (Atomic Code Rotation)
1. **Setup:** Lock screen -> tap "Forgot Password / Recovery".
2. **Action:**
   - Enter invalid recovery code -> verify error message.
   - Enter valid recovery code, enter new Owner password, enter new PIN.
   - Tap "Recover Credentials".
3. **Expected Outcome:**
   - New recovery code is generated and displayed on screen with mandatory confirmation checkbox.
   - Session is NOT unlocked until user confirms they saved the new code.
   - Old recovery code is permanently deactivated. Attempting to reuse old code fails.
   - Owner can immediately log in with new password and new PIN.

### Test 9: Tamper-Evident Audit Trail Integrity
1. **Setup:** Open Audit Trail Screen (`AuditTrailScreen`).
2. **Action:**
   - Tap "Verify Audit Chain".
   - Inspect pagination and event list.
3. **Expected Outcome:**
   - Verification succeeds with "Audit Chain Valid: N events verified".
   - Memory usage remains constant during verification via keyset pagination (`LIMIT 100`).
   - All user creations, logins, lockouts, re-auths, and escalation denials are present.
   - Direct SQL modifications or deletions on `audit_log` are rejected by SQLite triggers.

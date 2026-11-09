# Multi-User & Permissions Hardening Audit (FIX_AUDIT.md)

**Project:** Waraqatak (ورقتك) Flutter  
**Branch:** `fix/multiuser-stabilization` (branched from `feat/analytics-hardcoded-key`, successor of `feat/multi-user`)  
**Date:** 2026-11-08  
**Scope:** Batch 1 Deep Code Audit against Threat Model & Real-Device Vulnerabilities  

---

## 1. Status of Known Defects (D1–D9, N1–N9, E1–E10)

All 28 known defects were inspected against code and verified. Every defect was confirmed with precise file and line evidence below.

### 1.1 Screens & Services Defects (D1–D9)

| ID | Title & Description | Status | File & Line Evidence | Impact / Real Behavior |
|---|---|---|---|---|
| **D1** | **`PinLockScreen` Auto-Submit at 4 Digits** | **CONFIRMED** | [lib/screens/access/pin_lock_screen.dart#L67-L70](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/pin_lock_screen.dart#L67-L70):<br>`if (_enteredPin.length >= 4 && _enteredPin.length == (_selectedUser?.isOwner == true ? 4 : _enteredPin.length))` | The second condition is a tautology (`length == length`) for non-owner users. At 4 digits, `_tryUnlock()` is triggered prematurely. PINs of 5 or 6 digits can never be entered, and every wrong attempt burns lockout limits. |
| **D2** | **Permission Override Effect Type Mismatch** | **CONFIRMED** | [lib/screens/access/user_form_screen.dart#L81, L142, L186](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/user_form_screen.dart#L81):<br>`'effect': entry.value == 'allow' ? 1 : 0`<br>`(row['effect'] as int) == 1 ? 'allow' : 'deny'`<br>vs [lib/services/access/permission_service.dart#L80](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/permission_service.dart#L80):<br>`final effect = row['effect'] as String;` | `access_dao.dart#L90` defines `effect TEXT NOT NULL`. Form writes integer `1`/`0`. When `PermissionService` loads overrides, `row['effect'] as String` throws a runtime `type 'int' is not a subtype of type 'String' in type cast`, crashing permission evaluation. |
| **D3** | **Cache Invalidation Never Called** | **CONFIRMED** | [lib/screens/access/user_form_screen.dart#L97-L205](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/user_form_screen.dart#L97-L205), [lib/screens/access/roles_screen.dart#L96-L157](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/roles_screen.dart#L96-L157) | Neither `UserFormScreen` nor `RolesScreen` calls `PermissionService.instance.invalidateCache()`. Modified roles and user overrides do not take effect until app process restart. |
| **D4** | **Non-Transactional Role/User Writes & Raw SQLite Errors** | **CONFIRMED** | [lib/screens/access/roles_screen.dart#L135-L145, L261-L264](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/roles_screen.dart#L135-L145):<br>Role save deletes `role_permissions` then inserts without a transaction. Role delete performs two separate deletes without verifying if users are assigned. [lib/screens/access/user_form_screen.dart#L221](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/user_form_screen.dart#L221):<br>Direct `db.delete('users')` with no check for creator references. Lines 196–204 show raw `e.toString()`. | Database corruption on partial failure; assigned users orphaned when role deleted; unique username collisions show ugly `DatabaseException` strings. |
| **D5** | **Admin Screens Missing Audit Events** | **CONFIRMED** | `lib/screens/access/user_form_screen.dart`, `roles_screen.dart`, `users_list_screen.dart`, `multi_user_wizard_screen.dart` | Zero calls to `AuditService.instance.logEvent()`. User creation, role changes, credential changes, and user deactivation leave no audit record. |
| **D6** | **`PinLockScreen` Password Dialog Masking & Leak** | **CONFIRMED** | [lib/screens/access/pin_lock_screen.dart#L134, L195-L202](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/pin_lock_screen.dart#L134):<br>`passwordCtrl` is never disposed. Line 195 catches `catch (e)` and displays `l10n.invalidCredentials`. | Memory leak of password controller on every dialog open. Masked `AuthException` hides remaining lockout duration and account disabled status from user. |
| **D7** | **Audit Chain Concurrency Fork & Unpaged Verification** | **CONFIRMED** | [lib/services/access/audit_service.dart#L182-L246, L250-L322](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/audit_service.dart#L182-L246):<br>`logEvent` reads last row, awaits async hash, inserts. `verifyChain` runs single unpaged `rawQuery` on entire table. | Concurrent logging calls outside single transaction/mutex read identical `prev_hash`, creating fork that breaks `verifyChain`. Loading tens of thousands of rows into RAM will crash low-memory 4GB devices. |
| **D8** | **PBKDF2 Overhead & Missing Recovery Iterations** | **CONFIRMED** | [lib/services/access/auth_service.dart#L39, L55](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/auth_service.dart#L39):<br>Fixed 100,000 iterations. [lib/services/access/recovery_service.dart#L38](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/recovery_service.dart#L38) does not store iteration count in `app_settings`. | Pure-Dart PBKDF2 runs slowly on low-end ARM devices. Multi-step operations run sequential hashes causing noticeable latency. Changing iterations later would invalidate recovery codes. |
| **D9** | **Wizard Mandatory Owner PIN & Sequential Crypto** | **CONFIRMED** | [lib/screens/access/multi_user_wizard_screen.dart#L56-L64, L196-L200](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/multi_user_wizard_screen.dart#L196-L200):<br>`validator: (v) { if (v == null || v.length < 4 || v.length > 6) return l10n.invalidPin; }` | Owner PIN is mandatory, contradicting product design where PIN is optional. Password, PIN, and recovery code hashes run sequentially without parallelization or step feedback. |

---

### 1.2 Session & Recovery Layer Defects (N1–N9)

| ID | Title & Description | Status | File & Line Evidence | Impact / Real Behavior |
|---|---|---|---|---|
| **N1** | **`SessionManager.init()` Fail-Open on Error** | **CONFIRMED** | [lib/services/access/session_manager.dart#L84-L89](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/session_manager.dart#L84-L89):<br>`catch (_) { _isMultiUserEnabled = false; _currentUser = _defaultOwner; _isLocked = false; }` | If reading `app_settings` fails during startup, the app silently degrades to single-user mode with an implicit Owner session, bypassing the lock screen completely (FATAL FAIL-OPEN). |
| **N2** | **`setMultiUserEnabled` In-Memory Inversion & Synthetic Session** | **CONFIRMED** | [lib/services/access/session_manager.dart#L93-L108](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/session_manager.dart#L93-L108):<br>`_isMultiUserEnabled = enabled;` before `db.rawInsert`. When enabling, does not load real Owner user row from database. | If DB write fails, memory state is corrupt. Enabling leaves synthetic `_defaultOwner` with empty cached permissions instead of real authenticated database user. |
| **N3** | **`SessionManager.can()` Ignores Locked State** | **CONFIRMED** | [lib/services/access/session_manager.dart#L51-L57](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/session_manager.dart#L51-L57):<br>`bool can(String key) { if (!_isMultiUserEnabled) return true; final user = _currentUser; if (user == null) return false; if (user.isOwner) return true; return _cachedPermissions.contains(key); }` | Does not check `_isLocked`. While lock overlay is active, background jobs or routes that invoke `AccessGuard.can()` evaluate to `true` as long as `_currentUser` is set. |
| **N4** | **Owner Attribution Fallback in Multi-User Mode** | **CONFIRMED** | [lib/services/access/access_context.dart#L12](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/access_context.dart#L12):<br>`_currentUser?.id ?? AccessDao.ownerUserId`<br>[lib/services/access/audit_service.dart#L208-L211](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/audit_service.dart#L208-L211):<br>`userId = AccessDao.ownerUserId; userName = 'المالك';` | When locked or unauthenticated in multi-user mode, all actions and audit events are attributed to the Owner, corrupting forensic accountability. |
| **N5** | **Disabling Multi-User Mode Missing Re-Auth & Audit** | **CONFIRMED** | [lib/screens/access/users_list_screen.dart#L92-L109](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/users_list_screen.dart#L92-L109):<br>`_toggleMultiUserMode()` only shows confirmation dialog. No password prompt. | Any user holding device can disable multi-user mode with 2 taps, erasing access controls without re-auth and leaving no audit trail. |
| **N6** | **Unwired Inactivity Timer, Re-Auth, and `recordActivity`** | **CONFIRMED** | [lib/services/access/auth_service.dart#L234](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/auth_service.dart#L234), [lib/services/access/session_manager.dart#L182](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/session_manager.dart#L182) | `verifyPassword` has 0 callers in entire project. `checkInactivityLock` has 0 callers. Foreground auto-lock timer is never evaluated while app is kept awake. |
| **N7** | **Non-Atomic Recovery, Pre-Confirmation Unlock, No Rate Limit** | **CONFIRMED** | [lib/screens/access/recovery_screen.dart#L50-L73, L87-L95](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/recovery_screen.dart#L50-L73):<br>Password reset, PIN update, and code rotation run in separate transactions. `unlock` called at line 71 before showing new code. No attempt rate limiting. | Failure during PIN or code display leaves old code invalidated and session unlocked. Code can be brute-forced without lockout. |
| **N8** | **`UserSessionScope.of()` Silent Fallback Without Dependency** | **CONFIRMED** | [lib/services/access/user_session_scope.dart#L13-L17](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/user_session_scope.dart#L13-L17):<br>`scope?.notifier ?? SessionManager.instance` | If called outside the scope hierarchy, returns singleton without registering `InheritedNotifier` dependency. Pushed sub-routes never rebuild on permission updates. |
| **N9** | **`AppUser.copyWith` Cannot Clear Nullable Fields** | **CONFIRMED** | [lib/models/app_user.dart#L140](file:///data/data/com.termux/files/home/projects/waraqatak/lib/models/app_user.dart#L140):<br>`lockedUntil: lockedUntil ?? this.lockedUntil` | Calling `user.copyWith(lockedUntil: null)` evaluates `null ?? this.lockedUntil`, keeping the old lockout timestamp. In-memory unlock fails to clear lockout. |

---

### 1.3 Privilege Escalation Holes (E1–E10)

| ID | Title & Description | Status | File & Line Evidence | Impact / Real Behavior |
|---|---|---|---|---|
| **E1** | **Owner Edit Path Bypasses All Permission Checks** | **CONFIRMED** | [lib/screens/access/user_form_screen.dart#L148-L150, L166-L173](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/user_form_screen.dart#L148-L150):<br>`if (!_isOwner) AccessGuard.require(PermissionRegistry.usersManage);` | If target is Owner, permission check is skipped entirely. Anyone who opens the form can rewrite Owner name, password, and PIN without authorization. |
| **E2** | **Ungated Row Tap on Users List Screen** | **CONFIRMED** | [lib/screens/access/users_list_screen.dart#L335-L343](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/users_list_screen.dart#L335-L343):<br>`onTap: () async => Navigator.push(..., UserFormScreen(user: user))` | Tapping any user row opens `UserFormScreen` with zero permission checks. Combined with E1, any user opening `UsersListScreen` can edit and hijack the Owner account. |
| **E3** | **Unguarded `AuthService.setPassword` & `setPin`** | **CONFIRMED** | [lib/services/access/auth_service.dart#L259-L315](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/auth_service.dart#L259-L315) | Methods require only `userId` and new secret. No actor verification, no current password requirement, no permission checks. Any caller can reset any user's credentials directly. |
| **E4** | **No Delegation Rules or Hierarchy Enforcement** | **CONFIRMED** | `lib/screens/access/user_form_screen.dart#L66-L67, L139-L145, L183-L189`, `roles_screen.dart` | A user with `users.manage` can edit managers/peers, assign any role, grant permissions they do not possess, edit their own role/permissions, and grant `system.repair` or `backup.restore`. |
| **E5** | **Ungated Auto-Lock Timeout Modification** | **CONFIRMED** | [lib/screens/access/users_list_screen.dart#L64-L90, L186-L195](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/access/users_list_screen.dart#L64-L90) | Auto-lock menu item is ungated. Any cashier can set `autoLockMinutes = 0`, permanently disabling screen lock across the device. |
| **E6** | **Unprotected Settings Surfaces & Sub-Screens** | **CONFIRMED** | [lib/screens/settings_screen.dart#L175-L182, L205-L263, L389-L520](file:///data/data/com.termux/files/home/projects/waraqatak/lib/screens/settings_screen.dart#L175-L182) | Cashiers can open `LicenseScreen`, `BusinessSetupScreen`, `FinancialSettingsScreen`, `PaymentMethodsScreen`, `TaxProfilesScreen`, `DatabaseDiagnosticScreen`, `GoogleDriveBackupScreen`, and trigger DB restore. |
| **E7** | **Owner Lockout DoS via PIN Brute-Force** | **CONFIRMED** | [lib/services/access/auth_service.dart#L317-L335](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/auth_service.dart#L317-L335), `lib/screens/access/pin_lock_screen.dart` | Any person holding phone can select Owner on lock screen, enter 10 incorrect PINs, and lock Owner out for 15 minutes repeatedly with no device-level throttle. |
| **E8** | **Missing SQLite Database Triggers for Owner Protection** | **CONFIRMED** | [lib/database/access_dao.dart#L258-L276](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/access_dao.dart#L258-L276) | Only triggers are on `audit_log`. No trigger prevents `UPDATE users SET is_owner = 0`, `UPDATE users SET is_active = 0`, `DELETE FROM users WHERE id = 'user-owner'`, or role deletion. |
| **E9** | **Mutating Services Lack `AccessGuard` Checks** | **CONFIRMED** | `lib/services/license_service.dart` (`storeLicense`, `clearLicense`), `activation_service.dart` (`activate`), `backup_service.dart` (`restoreBackup`), `database_repair_service.dart` (`repairIssue`), `bulk_pricing_service.dart` (`applyBatch`), `csv_service.dart` (`applyImport`) | Public mutating service methods perform zero permission validation, relying entirely on UI hiding. Any direct call or test bypasses access control. |
| **E10** | **Critical Admin Keys Offered as Ordinary Grantable Permissions** | **CONFIRMED** | [lib/services/access/permission_registry.dart#L109, L110, L120-L122](file:///data/data/com.termux/files/home/projects/waraqatak/lib/services/access/permission_registry.dart#L109):<br>`users.manage`, `roles.manage`, `license.manage`, `system.repair`, `backup.restore` | Registered as standard permissions with no `ownerOnly` flag. Role editor and user overrides sheet allow assigning them to any employee. |

---

## 2. Newly Discovered Vulnerabilities & Schema/Type Inconsistencies

1. **`N-NEW1`: Unguarded Stock Adjustments in Monolith:**  
   `DatabaseHelper.adjustStock()` ([lib/database/database_helper.dart#L3532](file:///data/data/com.termux/files/home/projects/waraqatak/lib/database/database_helper.dart#L3532)) asserts only `assertPeriodOpen()`, missing `AccessGuard.require(PermissionRegistry.stockAdjust)`. Any user or code path can adjust stock inventory without `stock.adjust` permission.
2. **`N-NEW2`: Non-Existent Column Insert in Overrides:**  
   `user_form_screen.dart#L144, L187` inserts `'created_at': now` into `user_permission_overrides`. However, `access_dao.dart#L87-L93` defines only `(user_id, permission_key, effect)`. SQLite queries fail if strict or silently ignore data.
3. **`N-NEW3`: Pushed Route Lock Bypass:**  
   In `main_shell.dart#L96-L99`, the lock screen check (`session.isLocked`) is placed inside `MainShell.build()`. Sub-screens pushed via `Navigator.push` remain on the navigation stack above `MainShell`. When the app locks due to background resume timeout, pushed screens (e.g. `SettingsScreen`, `ProductFormScreen`) remain interactable on top.
4. **`N-NEW4`: Missing Foreground Inactivity Timer:**  
   `SessionManager.checkInactivityLock()` exists but is never scheduled via a periodic timer while the app is in the foreground. If the unlocked phone is placed on a desk, it never locks.
5. **`N-NEW5`: Ungated Entry to 26 Sensitive Screens:**  
   Screens such as `AuditTrailScreen`, `AccountingScreen`, `FinancialSettingsScreen`, `LicenseScreen`, and `StocktakeScreen` have zero entry guards (`initState` / build check). Direct navigation bypasses UI hiding.
6. **`N-NEW6`: Unstored KDF Iterations on Recovery Code:**  
   `RecoveryService.saveRecoveryCode()` does not persist the iteration count used to hash the recovery code. Future KDF calibration would render existing recovery codes un-verifiable.

---

## 3. Comprehensive Entry-Point Matrix

Every screen, drawer item, settings tile, menu item, and public mutating service method was cataloged:

| Surface / Method | Type | Location | What It Does | Current Gating | Required Policy | Reachable Today by Cashier? |
|---|---|---|---|---|---|---|
| `MainShell` Inactivity Lock | Widget | `lib/screens/main_shell.dart` | Shell container | `session.isLocked` | Public / Shell | Yes (unlocked) |
| `PinLockScreen` | Screen | `lib/screens/access/pin_lock_screen.dart` | Unlock terminal / switch user | UI Keypad | Public / Auth | Yes |
| `RecoveryScreen` | Screen | `lib/screens/access/recovery_screen.dart` | Reset Owner credentials via code | Code verification | Public / Recovery | Yes |
| `MultiUserWizardScreen` | Screen | `lib/screens/access/multi_user_wizard_screen.dart` | Initial multi-user setup | UI flow | OWNER_ONLY | Yes (from Settings) |
| `UsersListScreen` | Screen | `lib/screens/access/users_list_screen.dart` | View/manage users | UI FAB only | `users.manage` | **YES (Vulnerable)** |
| `UserFormScreen` (New) | Screen | `lib/screens/access/user_form_screen.dart` | Create user | UI + Service | `users.manage` | No (if FAB gated) |
| `UserFormScreen` (Edit Owner) | Screen | `lib/screens/access/user_form_screen.dart` | Edit Owner name/pass/PIN | **NONE (Bypassed)** | OWNER_ONLY | **YES (FATAL E1)** |
| `UserFormScreen` (Edit User) | Screen | `lib/screens/access/user_form_screen.dart` | Edit user / overrides | UI-only check | `users.manage` + Hierarchy | **YES (via E2)** |
| `RolesScreen` | Screen | `lib/screens/access/roles_screen.dart` | Manage roles and matrix | UI Popup check | `roles.manage` | **YES (via direct push)** |
| `AuditTrailScreen` | Screen | `lib/screens/access/audit_trail_screen.dart` | View audit trail & verify chain | UI Popup check | `audit.view` | **YES (via direct push)** |
| Auto-Lock Dialog | Dialog | `lib/screens/access/users_list_screen.dart` | Change device auto-lock | **NONE** | OWNER_ONLY | **YES (Vulnerable E5)** |
| Multi-User Toggle | Action | `lib/screens/access/users_list_screen.dart` | Disable multi-user mode | Confirm dialog | OWNER_ONLY + Re-auth | **YES (Vulnerable N5)** |
| `LicenseScreen` | Screen | `lib/screens/license_screen.dart` | View/activate Pro license | **NONE** | OWNER_ONLY (view: Public) | **YES (Vulnerable E6)** |
| `ActivationScreen` | Screen | `lib/screens/activation_screen.dart` | Enter license key | **NONE** | OWNER_ONLY | **YES (Vulnerable E6)** |
| `BusinessSetupScreen` | Screen | `lib/screens/business_setup_screen.dart` | Change store name/logo/VAT | Service (`settingsManage`) | `settings.manage` | **YES (UI ungated)** |
| `FinancialSettingsScreen` | Screen | `lib/screens/financial_settings_screen.dart` | Period lock, currency lock | Service (`accountingPeriodLock` on lock) | `settings.manage` / `accounting.period_lock` | **YES (UI ungated)** |
| `ExchangeRatesScreen` | Screen | `lib/screens/exchange_rates_screen.dart` | Change exchange rates | Service (`pricingRates`) | `pricing.rates` | **YES (UI ungated)** |
| `PaymentMethodsScreen` | Screen | `lib/screens/payment_methods_screen.dart` | Add/edit payment methods | Service (`paymentMethodsManage`) | `payment_methods.manage` | **YES (UI ungated)** |
| `PdfCustomizeScreen` | Screen | `lib/screens/pdf_customize_screen.dart` | Change invoice template | **NONE** (SharedPrefs) | `settings.manage` | **YES (UI ungated)** |
| Wholesale Toggle | Switch | `lib/screens/settings_screen.dart` | Enable wholesale pricing | Service (`settingsManage`) | `settings.manage` | **YES (UI ungated)** |
| Local Backup Create | Action | `lib/screens/settings_screen.dart` | Export `.waraq` backup | **NONE** | `backup.create` | **YES (UI ungated)** |
| Local Backup Restore | Action | `lib/screens/settings_screen.dart` | Wipe and restore database | Confirm dialog | OWNER_ONLY + Re-auth | **YES (FATAL E6)** |
| `GoogleDriveBackupScreen` | Screen | `lib/screens/google_drive_backup_screen.dart` | Cloud backup & restore | **NONE** | OWNER_ONLY | **YES (Vulnerable E6)** |
| `DatabaseDiagnosticScreen` | Screen | `lib/screens/database_diagnostic_screen.dart` | Database repair & diagnostics | **NONE** | OWNER_ONLY | **YES (FATAL E6)** |
| Analytics Toggle | Switch | `lib/screens/settings_screen.dart` | Opt-in/out telemetry | PermissionGate (`settingsManage`) | `settings.manage` | No (if not held) |
| `AccountingScreen` | Screen | `lib/screens/reports/accounting_screen.dart` | P&L, Balance Sheet, GL | UI Filter in reports | `reports.view_financials` | **YES (via direct push)** |
| `SalesReportScreen` | Screen | `lib/screens/reports/sales_report_screen.dart` | Revenue, COGS, Margins | UI Filter in reports | `reports.view_sales` | **YES (via direct push)** |
| `PurchasesReportScreen` | Screen | `lib/screens/reports/purchases_report_screen.dart` | Supplier spending, debts | UI Filter in reports | `reports.view_purchases` | **YES (via direct push)** |
| `InventoryReportScreen` | Screen | `lib/screens/reports/inventory_report_screen.dart` | Stock cost valuation | UI Filter in reports | `reports.view_inventory_cost` | **YES (via direct push)** |
| `BulkPricingScreen` | Screen | `lib/screens/bulk_pricing_screen.dart` | Bulk change product prices | **NONE** in service | `pricing.manage` | **YES (Vulnerable)** |
| `CsvImportExportScreen` | Screen | `lib/screens/csv_import_export_screen.dart` | Import/export products CSV | **NONE** in service | `data.export_csv` / `data.import_csv` | **YES (Vulnerable)** |
| `StocktakeScreen` | Screen | `lib/screens/stocktake/stocktake_screen.dart` | Physical inventory count | Service (`stocktakeManage`) | `stocktake.manage` | **YES (UI ungated)** |
| `LicenseService.storeLicense` | Service | `lib/services/license_service.dart` | Write license key | **NONE** | OWNER_ONLY | Any code caller |
| `LicenseService.clearLicense` | Service | `lib/services/license_service.dart` | Deactivate license | **NONE** | OWNER_ONLY | Any code caller |
| `ActivationService.activate` | Service | `lib/services/activation_service.dart` | Activate device license | **NONE** | OWNER_ONLY | Any code caller |
| `BackupService.restoreBackup` | Service | `lib/services/backup_service.dart` | Wipe and restore database | **NONE** | OWNER_ONLY + Re-auth | Any code caller |
| `DatabaseRepairService.repairIssue` | Service | `lib/services/database_repair_service.dart` | Execute DB mutation repairs | **NONE** | OWNER_ONLY + Re-auth | Any code caller |
| `BulkPricingService.applyBatch` | Service | `lib/services/bulk_pricing_service.dart` | Batch update prices | **NONE** | `pricing.manage` | Any code caller |
| `CsvService.applyImport` | Service | `lib/services/csv_service.dart` | Insert/update CSV products | **NONE** | `data.import_csv` | Any code caller |
| `DatabaseHelper.adjustStock` | Monolith | `lib/database/database_helper.dart` | Manual stock adjustment | Period lock only | `stock.adjust` | Any code caller |

---

## 4. State Transition Traces

### 4.1 Multi-User Enable Wizard
1. **Initial State:** `multi_user_enabled = '0'`. `SessionManager` in single-user mode (`_currentUser = _defaultOwner`, `isLocked = false`).
2. **Action:** Owner opens `UsersListScreen`, clicks "Enable Multi-User", navigates to `MultiUserWizardScreen`.
3. **Inputs:** Owner enters password (min 6 chars), optional PIN (4–6 digits), views generated 16-character recovery code `RC-XXXX-XXXX-XXXX`.
4. **Execution (Harden Target):**
   - PBKDF2 hashes for password, PIN (if provided), and recovery code computed in isolate.
   - Atomic database transaction:
     - Updates `users` table row for `user-owner` (`password_hash`, `password_salt`, `pin_hash`, `pin_salt`, `setup_complete = 1`).
     - Inserts `owner_recovery_code_hash`, `owner_recovery_code_salt`, `kdf_iterations` into `app_settings`.
     - Writes `multi_user_enabled = '1'` into `app_settings`.
     - Logs `multi_user_enabled` audit event.
   - Updates `SessionManager`: loads real `AppUser` from `users` table into `_currentUser`, unlocks session without bouncing to lock screen.
5. **Final State:** Multi-user mode active; Owner logged in.

### 4.2 Cold Start with Multi-User Enabled
1. **Initial State:** Device powered off / process cold start.
2. **Action:** `main()` executes -> `SessionManager.instance.init()`.
3. **Execution (Harden Target):**
   - Reads `app_settings` for `multi_user_enabled`.
   - If read succeeds and equals `'1'`: sets `_isMultiUserEnabled = true`, `_currentUser = null`, `_cachedPermissions = {}`, `_isLocked = true`.
   - If read fails due to SQLite disk error: does NOT fail open to single-user; sets `_isMultiUserEnabled = true`, `_isLocked = true`, marks state `unverified`, prompts user with "Cannot verify security settings. Retry." button.
4. **Final State:** Lock screen shown (`PinLockScreen`); zero permissions available.

### 4.3 Inactivity Lock & App Lifecycle Resume
1. **Initial State:** User "Cashier" active and logged in.
2. **Foreground Inactivity:** Periodic timer fires every 30s. If `now - lastActivity >= autoLockMinutes`, calls `SessionManager.instance.lock()`.
3. **Background Resume:** Phone sleeps or app backgrounded. `didChangeAppLifecycleState(paused)` records timestamp. On `resumed`, if elapsed >= `autoLockMinutes`, calls `SessionManager.instance.lock()`.
4. **UI Response (Harden Target):** Navigation overlay or top-level gate presents `PinLockScreen`, covering any open sub-screens immediately.
5. **Permissions:** While locked, `SessionManager.can()` returns `false` unconditionally.

### 4.4 Attacker Goal Tracing (Threat Model Scenarios)

1. **Attacker attempts to edit/reset Owner credentials (E1, E2, E3):**  
   - *Attempt:* Cashier taps Owner row in `UsersListScreen` or calls `AuthService.setPassword('user-owner', ...)`.  
   - *Defense:* `UsersListScreen` entry requires `users.manage`. Tapping Owner row is disabled for non-Owners. `AccessPolicy.canEditUser` denies non-Owner. `AuthService.setPassword` checks caller actor and requires re-auth password. SQLite trigger `trg_users_owner_protect` aborts any update to Owner credentials from non-sanctioned path. Event logged as `privilege_escalation_denied`.
2. **Attacker attempts to disable multi-user mode (N5):**  
   - *Attempt:* Cashier taps "Disable Multi-User" in popup menu.  
   - *Defense:* SensitiveActionGate prompts for Owner password re-authentication. Non-Owner cannot re-authenticate. Operation denied and audited.
3. **Attacker attempts to set auto-lock to 0 (E5):**  
   - *Attempt:* Cashier selects auto-lock menu option.  
   - *Defense:* Auto-lock policy setting is designated `OWNER_ONLY`. Hidden from UI; service refuses with `PermissionDeniedException`.
4. **Attacker attempts Owner Lockout DoS (E7):**  
   - *Attempt:* Cashier repeatedly enters wrong PINs for Owner on lock screen.  
   - *Defense:* Device-level exponential delay slows attempts across all users. Per-account lockout for Owner capped at 5 minutes. Owner can bypass and clear lockout anytime via Recovery Code flow. Failed attempts on Owner trigger audit events.
5. **Attacker attempts Database Restore or Diagnostic Repair (E6):**  
   - *Attempt:* Cashier opens Settings -> Restore or Database Diagnostics.  
   - *Defense:* `ScreenAccessPolicy` blocks navigation to `DatabaseDiagnosticScreen`. Settings tile hidden. `BackupService.restoreBackup` and `DatabaseRepairService.repairIssue` enforce `AccessGuard.require(backup.restore)` / `system.repair` (OWNER_ONLY) and require Owner password re-auth.
6. **Attacker attempts to escalate privileges or grant permissions (E4):**  
   - *Attempt:* Cashier with delegated `users.manage` attempts to grant `backup.restore` or assign Manager role.  
   - *Defense:* `AccessPolicy` enforces strict delegation: cannot grant any permission the actor lacks; cannot assign roles with permissions exceeding actor's; cannot touch peers or superiors. Denials logged as `privilege_escalation_denied`.

---

## 5. Verification Checklist for Batch 1

- [x] Read every file in code map, services, database DAO, and screens.
- [x] Ran `flutter analyze` (clean, 0 warnings).
- [x] Ran targeted guard test `test/guards/access_guards_test.dart` (passed).
- [x] Confirmed D1–D9, N1–N9, E1–E10 with file and line references.
- [x] Cataloged all new defects, schema mismatches, and raw-SQL calls.
- [x] Completed comprehensive ENTRY-POINT MATRIX table.
- [x] Traced state transitions and threat model attacks.
- [x] Zero production code changed in Batch 1.

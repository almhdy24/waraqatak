# Multi-User Stabilization Progress
Last updated: 2026-11-08
Branch: fix/multiuser-stabilization

## Batches
| # | Title | Status (TODO/IN_PROGRESS/DONE/BLOCKED) | Commit | Tests run | Notes |
|---|-------|---|---|---|---|
| 1 | Audit & entry-point matrix | DONE | cde497f | flutter analyze, test/guards/access_guards_test.dart | Deep inspection completed; FIX_AUDIT.md and FIX_PROGRESS.md generated; all D/N/E defects confirmed with file/line evidence. |
| 2 | Session layer hardening | DONE | 614c1c1 | test/services/session_hardening_test.dart (20 passed), test/guards/access_guards_test.dart, architecture_guards_test.dart | Fail-closed init, DB-first enable, locked can() check, attribution fix, UserSessionScope assert, AppUser sentinel copyWith, auto-lock periodic check. |
| 3 | AccessPolicy, Owner protection & OWNER_ONLY keys | DONE | 743611b | test/services/access_policy_test.dart (15 passed), session_hardening_test.dart, access_guards_test.dart, architecture_guards_test.dart | access_policy.dart (H1-H4), OWNER_ONLY stripping in PermissionService, Schema v30 SQLite security triggers (H6), escalation audit (H7), AuthService guards (E3). |
| 4 | AccessAdminService | DONE | d176183 | test/services/access_admin_service_test.dart (5 passed), regression 50 passed | Move all writes out of screens into transactional AccessAdminService. Disable instead of delete. D2-D5, E1-E2 fixed. |
| 5 | Screen, route & Settings lockdown | DONE |  | test/guards/screen_policy_guard_test.dart (4 passed), access_guards_test.dart, architecture_guards_test.dart, access_policy_test.dart, access_admin_service_test.dart | ScreenAccessPolicy manifest covers all 50 screens (Deny-By-Default H5). ScreenAccessGate wraps screens, Settings tiles gated, service-level guards on adjustStock, licensing, backup, repair, pricing, csv. E5, E6, E9, N-NEW1, N-NEW5 fixed. |
| 6 | Login, PIN, wizard, recovery & lockout-DoS | TODO | | | Explicit PIN confirm, device throttle, atomic recovery with pre-unlock code display, optional Owner PIN. |
| 7 | Sensitive-action re-authentication | TODO | | | SensitiveActionGate with current user password prompt, applied to restore, period lock, repair, disable multi-user. |
| 8 | Crypto performance & audit chain safety | TODO | | | KDF calibration, isolate hashing, async mutex on logEvent, paged verifyChain. |
| 9 | Red-team & E2E flow tests | TODO | | | Automated threat model attacker tests, comprehensive multi-user flows. |
| 10 | Final verification & device QA | TODO | | | Full test suite run, DEVICE_QA.md checklist, documentation updates. |

## DEFECT LOG
| Defect | Status | Fixing Commit | Test Name | Notes |
|---|---|---|---|---|
| D1 | Confirmed | Batch 6 | Pending | `PinLockScreen` tautology `_enteredPin.length == ...` auto-submits at 4 digits |
| D2 | Fixed | Batch 4 | access_admin_service_test | Standardized override effect to TEXT 'allow'/'deny', tolerant reader in PermissionService |
| D3 | Fixed | Batch 4 | access_admin_service_test | `PermissionService.invalidateCache` called on every user/role mutation in AccessAdminService |
| D4 | Fixed | Batch 4 | access_admin_service_test | Atomic transactions for role/user writes, friendly AdminException instead of raw SQLite errors, role delete blocked if assigned |
| D5 | Fixed | Batch 4 | access_admin_service_test | Admin screens and service log audit events for all user/role creates, updates, and deletes |
| D6 | Confirmed | Batch 6 | Pending | Password dialog masks errors as `invalidCredentials`, leaks controller |
| D7 | Confirmed | Batch 8 | Pending | `AuditService.logEvent` concurrency chain fork, unpaged `verifyChain` |
| D8 | Confirmed | Batch 8 | Pending | Fixed 100k PBKDF2 iterations, no stored recovery iterations |
| D9 | Confirmed | Batch 6 | Pending | Owner PIN mandatory in wizard, sequential hashing |
| N1 | Fixed | Batch 2 | session_hardening_test | `SessionManager.init()` fails closed, setting isSecurityUnverified on error |
| N2 | Fixed | Batch 2 | session_hardening_test | `setMultiUserEnabled` writes DB first, loads real Owner and updates login |
| N3 | Fixed | Batch 2 | session_hardening_test | `SessionManager.can()` returns false when locked or unverified |
| N4 | Fixed | Batch 2 | session_hardening_test | `AccessContext` and `AuditService` attribute to unauthenticated when locked |
| N5 | Confirmed | Batch 7 | Pending | Disabling multi-user mode is unauthenticated confirm dialog |
| N6 | Fixed | Batch 2 | session_hardening_test | Inactivity periodic timer wired, pops to root on lock, unlock verifies status |
| N7 | Confirmed | Batch 6 | Pending | Non-atomic recovery, session unlocked before code shown, no rate limit |
| N8 | Fixed | Batch 2 | session_hardening_test | `UserSessionScope.of()` asserts in debug, installed in MaterialApp.builder |
| N9 | Fixed | Batch 2 | session_hardening_test | `AppUser.copyWith` uses sentinel pattern to allow clearing nullable fields |
| E1 | Fixed | Batch 4 | access_admin_service_test | Owner edit path in user_form_screen and service guarded; delegates cannot touch Owner |
| E2 | Fixed | Batch 4 | access_admin_service_test | Tapping user row in users_list_screen gated by users.manage and Owner immunity check |
| E3 | Fixed | Batch 3 | access_policy_test | `AuthService.setPassword` and `setPin` guard with AccessPolicy, audit privilege escalation |
| E4 | Fixed | Batch 3 | access_policy_test | Strict privilege hierarchy in `AccessPolicy`: delegates cannot touch peers/superiors or unheld permissions |
| E5 | Fixed | Batch 5 | screen_policy_guard_test | Auto-lock policy (menu and SessionManager.setAutoLockMinutes) gated strictly to Owner only |
| E6 | Fixed | Batch 5 | screen_policy_guard_test | Settings tiles gated with PermissionGate & owner-only constraints |
| E7 | Confirmed | Batch 6 | Pending | Owner lockout DoS: failed attempts on lock screen lock Owner out for 15 min |
| E8 | Fixed | Batch 3 | access_policy_test | Schema v30 SQLite triggers defend Owner row from delete, demote, rename, and system role tampering |
| E9 | Fixed | Batch 5 | screen_policy_guard_test | Mutating services (LicenseService, ActivationService, BackupService, DatabaseRepairService, BulkPricingService) gated |
| E10 | Fixed | Batch 3 | access_policy_test | OWNER_ONLY keys strictly stripped in `PermissionService` and blocked in `AccessPolicy` |
| N-NEW1 | Fixed | Batch 5 | access_guards_test | `DatabaseHelper.adjustStock` protected with `AccessGuard.require(stockAdjust)` |
| N-NEW2 | Confirmed | Batch 4 | Pending | `user_form_screen` inserts non-existent `'created_at'` into overrides table |
| N-NEW3 | Fixed | Batch 2, 5 | session_hardening_test | Routes popped to root on lock via SessionManager.navigatorKey |
| N-NEW4 | Fixed | Batch 2 | session_hardening_test | Foreground auto-lock periodic timer wired |
| N-NEW5 | Fixed | Batch 5 | screen_policy_guard_test | All 50 screen classes mapped in ScreenAccessPolicy with Deny-By-Default H5 and ScreenAccessGate |
| N-NEW6 | Confirmed | Batch 6, 8 | Pending | Recovery code iteration count not persisted in `app_settings` |

## ENTRY-POINT MATRIX STATUS
Total entry points cataloged: 40 surfaces & methods (see `docs/multiuser/FIX_AUDIT.md` Section 3).
Current status: Audited; hardening plan assigned to Batches 2–7.

## DECISIONS
- **F1:** All access-table writes go through `AccessAdminService` (guarded, policy-checked, transactional, audited, cache-invalidating).
- **F2:** Override effect stored as TEXT `allow`/`deny`, reader tolerant of legacy `1`/`0`.
- **F3:** Users are disabled (`is_active = 0`), not hard deleted.
- **F4:** PIN submit is explicit with confirm button for 4–6 digits.
- **F5:** KDF iterations calibrated per device and stored per secret.
- **F6:** Owner PIN optional in wizard and user form.
- **F7:** Session layer fails closed; no implicit Owner when multi-user is enabled or unreadable.
- **F8:** No Owner attribution fallback in multi-user mode.
- **F9:** Recovery is atomic and the new code is shown with mandatory confirmation before unlock.
- **F10:** Sensitive actions require password re-auth in multi-user mode.
- **H1:** OWNER_ONLY keys: `license.manage`, `system.repair`, `backup.restore`, enabling/disabling multi-user, auto-lock policy, recovery-code management, Owner account management. Stripped from all non-Owners.
- **H2:** The Owner account can be modified only by the Owner after password re-auth.
- **H3:** Delegation hierarchy: delegates cannot touch peers/superiors, cannot assign higher roles or grant permissions they lack.
- **H4:** Self-service: users may change own display name; password/PIN change requires current credentials.
- **H5:** Deny-by-default navigation: every screen declares policy in `ScreenAccessPolicy`.
- **H6:** SQLite triggers defend Owner row from deletion or role/username tampering.
- **H7:** Escalation attempts audited as `privilege_escalation_denied`.

## OPEN ISSUES
(None)

## RESUME NOTE
Batch 5 complete (Screen, route & Settings lockdown: ScreenAccessPolicy manifest with Deny-By-Default H5, ScreenAccessGate wrapping sensitive screens, Settings tiles gated with PermissionGate, mutating services guarded, auto-lock policy restricted to Owner only, screen policy guard test passed, flutter analyze clean). Resume with Batch 6 (Login, PIN, wizard, recovery & lockout-DoS: fix D1 auto-submit tautology, explicit confirm 4-6 digits, device throttle + Owner lockout capped at 5m, optional Owner PIN, atomic RecoveryService).

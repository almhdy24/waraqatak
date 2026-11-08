# Multi-User Stabilization Progress
Last updated: 2026-11-08
Branch: fix/multiuser-stabilization

## Batches
| # | Title | Status (TODO/IN_PROGRESS/DONE/BLOCKED) | Commit | Tests run | Notes |
|---|-------|---|---|---|---|
| 1 | Audit & entry-point matrix | DONE | Pending | flutter analyze, test/guards/access_guards_test.dart | Deep inspection completed; FIX_AUDIT.md and FIX_PROGRESS.md generated; all D/N/E defects confirmed with file/line evidence. |
| 2 | Session layer hardening | TODO | | | Fail-closed init, DB-first enable, locked can() check, attribution fix, UserSessionScope, copyWith fix. |
| 3 | AccessPolicy, Owner protection & OWNER_ONLY keys | TODO | | | access_policy.dart, OWNER_ONLY stripping, Owner triggers, escalation audit. |
| 4 | AccessAdminService | TODO | | | Move all writes out of screens into transactional AccessAdminService. Disable instead of delete. |
| 5 | Screen, route & Settings lockdown | TODO | | | ScreenAccessPolicy manifest, PermissionGate push & build checks, service guards on settings/repair/backup. |
| 6 | Login, PIN, wizard, recovery & lockout-DoS | TODO | | | Explicit PIN confirm, device throttle, atomic recovery with pre-unlock code display, optional Owner PIN. |
| 7 | Sensitive-action re-authentication | TODO | | | SensitiveActionGate with current user password prompt, applied to restore, period lock, repair, disable multi-user. |
| 8 | Crypto performance & audit chain safety | TODO | | | KDF calibration, isolate hashing, async mutex on logEvent, paged verifyChain. |
| 9 | Red-team & E2E flow tests | TODO | | | Automated threat model attacker tests, comprehensive multi-user flows. |
| 10 | Final verification & device QA | TODO | | | Full test suite run, DEVICE_QA.md checklist, documentation updates. |

## DEFECT LOG
| Defect | Status | Fixing Commit | Test Name | Notes |
|---|---|---|---|---|
| D1 | Confirmed | Batch 6 | Pending | `PinLockScreen` tautology `_enteredPin.length == ...` auto-submits at 4 digits |
| D2 | Confirmed | Batch 4 | Pending | `user_form_screen` effect 1/0 vs `PermissionService` String 'allow'/'deny' |
| D3 | Confirmed | Batch 4 | Pending | `invalidateCache` never called on user/role edit |
| D4 | Confirmed | Batch 4 | Pending | Non-transactional role/user writes, orphaned role delete, raw SQLite error strings |
| D5 | Confirmed | Batch 4 | Pending | Zero audit events from admin screens |
| D6 | Confirmed | Batch 6 | Pending | Password dialog masks errors as `invalidCredentials`, leaks controller |
| D7 | Confirmed | Batch 8 | Pending | `AuditService.logEvent` concurrency chain fork, unpaged `verifyChain` |
| D8 | Confirmed | Batch 8 | Pending | Fixed 100k PBKDF2 iterations, no stored recovery iterations |
| D9 | Confirmed | Batch 6 | Pending | Owner PIN mandatory in wizard, sequential hashing |
| N1 | Confirmed | Batch 2 | Pending | `SessionManager.init()` catch falls back to single-user mode (fail-open) |
| N2 | Confirmed | Batch 2 | Pending | `setMultiUserEnabled` in-memory set before DB write; keeps synthetic Owner |
| N3 | Confirmed | Batch 2 | Pending | `SessionManager.can()` returns true while locked |
| N4 | Confirmed | Batch 2 | Pending | `AccessContext` and `AuditService` attribute to Owner when unauthenticated/locked |
| N5 | Confirmed | Batch 7 | Pending | Disabling multi-user mode is unauthenticated confirm dialog |
| N6 | Confirmed | Batch 2 | Pending | `verifyPassword`, `checkInactivityLock`, `setSession` uncalled; timer unwired |
| N7 | Confirmed | Batch 6 | Pending | Non-atomic recovery, session unlocked before code shown, no rate limit |
| N8 | Confirmed | Batch 2 | Pending | `UserSessionScope.of()` silent fallback without InheritedWidget dependency |
| N9 | Confirmed | Batch 2 | Pending | `AppUser.copyWith` unable to clear nullable `lockedUntil` |
| E1 | Confirmed | Batch 3, 4 | Pending | Owner edit path in `user_form_screen` skips all permission checks |
| E2 | Confirmed | Batch 4, 5 | Pending | Tapping any user row in `users_list_screen` opens edit form without guard |
| E3 | Confirmed | Batch 3, 4 | Pending | `AuthService.setPassword` and `setPin` have no actor or permission guards |
| E4 | Confirmed | Batch 3 | Pending | No privilege hierarchy or delegation checks |
| E5 | Confirmed | Batch 5 | Pending | Auto-lock menu item ungated; any user can disable auto-lock |
| E6 | Confirmed | Batch 5 | Pending | Regular users can reach Settings, licensing, business info, diagnostics, restore |
| E7 | Confirmed | Batch 6 | Pending | Owner lockout DoS: failed attempts on lock screen lock Owner out for 15 min |
| E8 | Confirmed | Batch 3 | Pending | Owner row has no database triggers protecting against delete/update |
| E9 | Confirmed | Batch 5 | Pending | Mutating services (`LicenseService`, `BackupService`, `DatabaseRepairService`) lack guards |
| E10 | Confirmed | Batch 3 | Pending | Critical admin keys (`users.manage`, `backup.restore`, etc.) are grantable |
| N-NEW1 | Confirmed | Batch 5 | Pending | `DatabaseHelper.adjustStock` lacks `AccessGuard.require(stockAdjust)` |
| N-NEW2 | Confirmed | Batch 4 | Pending | `user_form_screen` inserts non-existent `'created_at'` into overrides table |
| N-NEW3 | Confirmed | Batch 2, 5 | Pending | Pushed routes remain active above `MainShell` during lock screen display |
| N-NEW4 | Confirmed | Batch 2 | Pending | Foreground auto-lock periodic timer missing |
| N-NEW5 | Confirmed | Batch 5 | Pending | 26 sensitive screens lack entry guards |
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
Batch 1 complete (audit and entry-point matrix recorded in `FIX_AUDIT.md` and `FIX_PROGRESS.md`). Resume with Batch 2 (Session layer hardening: `SessionManager`, `AccessContext`, `AuditService` attribution, `UserSessionScope`, `AppUser.copyWith`).

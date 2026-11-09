# Waraqatak Multi-User & Permissions Architecture

## Overview
Phase 1 implements an offline-first, local multi-user and Role-Based Access Control (RBAC) system for Waraqatak on a single device. The system is engineered to maintain **zero overhead and 100% backward compatibility** when multi-user mode is disabled, while providing enterprise-grade security and tamper evidence when enabled.

---

## Key Architectural Principles

1. **Zero-Disruption Single-User Mode:**
   - Single-user mode is governed by a cached in-memory boolean (`SessionManager.instance.isMultiUserEnabled`).
   - When disabled, all permission checks (`AccessGuard.can(...)`) return `true` immediately without touching SQLite.
   - The UI displays no login screens, PIN gates, or user switchers.

2. **Role-Based Access Control + Per-User Overrides:**
   - Default built-in template roles: **Owner**, **Manager**, **Accountant**, **Salesperson**, **Inventory Manager**.
   - Unlimited custom roles can be defined by the Owner.
   - Granular permission overrides per user: `ALLOW` or `DENY`.
   - **Precedence Rule:** `DENY` override > `ALLOW` override > Role permission.

3. **Owner Protection (Invariant):**
   - The Owner (`user-owner`) is a protected system account.
   - Cannot be deleted, deactivated, or demoted.
   - Holds all permissions unconditionally, including keys introduced in future versions.

4. **Dual Authentication & Recovery:**
   - **4–6 Digit PIN:** Fast user switching and daily terminal unlock.
   - **Password (PBKDF2-HMAC-SHA256, 100,000 iterations):** Sensitive operations and password login fallback.
   - **16-Character Recovery Code (`RC-XXXX-XXXX-XXXX`):** Cryptographically hashed with salt; allows resetting the Owner password if forgotten, immediately rotating to a fresh recovery code.

5. **Tamper-Evident Audit Trail:**
   - Append-only hash chain where each event computes:
     `hash = SHA256(prev_hash + id + action + entity_type + entity_id + timestamp + user_id + device_id + details)`
   - SQLite database triggers abort any `UPDATE` or `DELETE` attempt on `audit_log`.
   - Backup restore preserves local audit history and local credentials without foreign overwrites.

6. **Defense in Depth:**
   - Write paths enforced directly in `DatabaseHelper` mutators and service methods (not just hidden in the UI).
   - Sensitive read paths and exports (cost prices, wholesale margins, profit reports, CSV/PDF exports) redact columns and data according to user permissions.
   - Field-level pricing protections: manual line repricing and discount overrides are independently gated.

---

## Architecture Components

```
lib/
├── models/
│   ├── app_user.dart               # AppUser domain model (PIN & password hashes, lockouts)
│   └── role.dart                   # Role model (templates & custom roles)
├── database/
│   └── access_dao.dart             # Schema v29 DDL, seed constants, triggers
├── services/access/
│   ├── access_guard.dart           # Static choke point (can, require, runAsSystem)
│   ├── access_context.dart         # Current actor attribution context
│   ├── auth_service.dart           # PBKDF2 hashing, PIN & password authentication
│   ├── session_manager.dart        # Reactive user session, auto-lock inactivity timer
│   ├── permission_registry.dart    # 35 permission keys grouped into 12 functional areas
│   ├── permission_service.dart     # Effective permissions calculation engine & cache
│   ├── audit_service.dart          # Cryptographic SHA-256 tamper-evident audit writer & verifier
│   ├── recovery_service.dart       # Owner recovery code generation, hash verification & rotation
│   └── access_seeder.dart          # Idempotent seeder for template roles and initial Owner
├── widgets/access/
│   ├── permission_gate.dart        # Conditional UI widget gating
│   └── user_session_scope.dart     # Scoped InheritedNotifier for reactive rebuilds
└── screens/access/
    ├── pin_lock_screen.dart        # Fast keypad PIN unlock & user switching
    ├── multi_user_wizard_screen.dart # Enabling wizard & recovery code issuance
    ├── recovery_screen.dart        # Owner account recovery via 16-char code
    ├── users_list_screen.dart      # User management, auto-lock timeout configuration
    ├── user_form_screen.dart       # User creation/edit, PIN/password setup, overrides sheet
    ├── roles_screen.dart           # Role manager & permission matrix
    └── audit_trail_screen.dart     # Audit trail viewer with cryptographic integrity check
```

---

## Testing & Verification

Targeted tests ensure invariants remain strictly enforced:
- `test/database/migration_29_test.dart`
- `test/services/auth_service_test.dart`
- `test/services/permission_engine_test.dart`
- `test/services/audit_service_test.dart`
- `test/guards/access_guards_test.dart`
- `test/services/redaction_test.dart`
- `test/services/backup_access_interplay_test.dart`
- Core architectural guard tests (`architecture_guards_test.dart`, `single_stock_writer_guard_test.dart`, `document_edit_guard_test.dart`, `snackbar_guard_test.dart`).

# Release Notes — Waraqatak 1.2.0-beta.2

> **Pre-release Notice:** This is a pre-release beta build (`1.2.0-beta.2+24`) hardening the Multi-User & Permissions subsystem with a hostile non-owner threat model, deny-by-default navigation, sensitive action re-authentication, device-calibrated PBKDF2 cryptography, and disaster recovery.

## Overview / نظرة عامة
Waraqatak `1.2.0-beta.2` delivers a comprehensive security stabilization and hardening of the Multi-User & Access Control system. Built against a strict threat model (hostile cashier/non-owner device access), every screen, service mutation, database row, and credential path is hardened to prevent privilege escalation, lockout denial-of-service, and unauthorized data tampering while preserving single-user zero-overhead performance.

تأتي النسخة التجريبية `1.2.0-beta.2` باستقرار وتحصين أمني شامل لنظام تعدد المستخدمين والصلاحيات (Multi-User & Permissions)، مبنية وفق نموذج حماية صارم يمنع التصعيد غير المصرح به للأدوار، ويحمي حساب المالك على مستوى قاعدة البيانات وقفل الشاشات والخدمات، مع فرض إعادة التحقق بكلمة المرور للعمليات الحساسة، وتحسين أداء التشفير ليعمل بسلاسة على الهواتف منخفضة الموارد دون التأثير على نمط المستخدم الفردي.

---

## Key Highlights & Improvements / أبرز التحسينات

### 1. Hardened Privilege Hierarchy & Owner Protection (تحصين هرمية الصلاحيات وحماية المالك)
- **Database-Level Immutability (H6):** SQLite triggers protect the Owner record from deletion, demotion (`is_owner = 0`), role changes, and username modification from any application layer.
- **Owner-Only Keys (H1):** `license.manage`, `system.repair`, and `backup.restore` are strictly restricted to the Owner and stripped from all custom roles and overrides.
- **Delegation Rules (H3):** Delegates cannot modify, deactivate, or assign roles to superiors or peers, and cannot grant permissions they do not hold themselves.

### 2. Deny-by-Default Navigation Policy (سياسة حجب الشاشات الافتراضية)
- Authoritative manifest in `ScreenAccessPolicy` mapping all 50 application screens.
- Any unregistered route or screen is refused entry by default (H5).
- Single-user mode retains its zero-overhead fast-path cached boolean check.

### 3. Transactional Admin Service & Cache Invalidation (إدارة مركزية للمستخدمين وتحديث الصلاحيات)
- All user, role, and override writes route through `AccessAdminService`.
- Atomic transactions prevent orphaned or inconsistent permission states.
- User deactivation (`is_active = 0`) replaces unsafe hard deletes.
- Immediate in-memory cache invalidation ensures permission changes take effect instantly.

### 4. Sensitive-Action Password Re-Authentication (إعادة التحقق للعمليات الحساسة)
- `SensitiveActionGate` prompts for current password in multi-user mode before high-impact operations:
  - Backup restore.
  - Accounting period lock modifications.
  - Database repairs.
  - License deactivation.
  - Disabling multi-user mode.
- Re-authentication events are logged to the audit log (`reauth_success` / `reauth_failed`).

### 5. Brute-Force & Lockout-DoS Mitigation (حماية من هجمات التعطيل والتخمين)
- Explicit PIN confirm button supporting 4, 5, and 6 digit PINs without premature auto-submission.
- Owner account lockout is capped at 5 minutes (preventing 15-minute denial-of-service lockout).
- Device-level throttle halts all authentication attempts across all accounts for 30s/120s after 5 and 10 failures.

### 6. Atomic Disaster Recovery (منظومة استرداد حساب المالك المتسقة)
- Atomic credentials reset and recovery code rotation in a single SQLite transaction.
- New recovery code is displayed with mandatory confirmation before session unlock.
- Consumed recovery codes are immediately invalidated.

### 7. Device-Calibrated Cryptography & Audit Chain Serialization (معايرة التشفير وسلسلة التدقيق)
- Hardware-calibrated PBKDF2 iterations benchmarking ~300ms (clamped between 20k and 200k iterations).
- Serialized audit logging mutex queue preventing hash chain forks under concurrency.
- Keyset cursor pagination in audit chain verification for constant $O(1)$ memory usage.

---

## Version Metadata / بيانات الإصدار
- **Version:** `1.2.0-beta.2`
- **Build Number:** `24`
- **Application ID:** `com.elmahdi.waraqatak`
- **Tag:** `v1.2.0-beta.2`

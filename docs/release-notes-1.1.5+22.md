# Release Notes — Waraqatak 1.1.5+22

## Overview / نظرة عامة
Waraqatak `1.1.5+22` brings a complete redesign of the **License & Subscription** screen with state-specific layouts, a unified and secure **Activation Key** entry experience, robust Google Play in-app update management, and critical accounting integration stability.

تأتي النسخة `1.1.5+22` بإعادة تصميم شاملة لشاشة **الترخيص والاشتراك** مع واجهات مخصصة لكل حالة (مرخص، تجربة نشطة، منتهي)، وتوحيد كامل لآلية إدخال **مفتاح التفعيل** وفق أعلى معايير الأمان والتحقق، مع تحسين إدارة تحديثات التطبيق التلقائية داخل التطبيق وثبات المعالجات المحاسبية.

---

## Key Highlights & Improvements / أبرز التحسينات

### 1. License & Subscription Screen Redesign (إعادة تصميم شاشة الترخيص والاشتراك)
- **State-Specific Layouts:**
  - **Licensed:** Clean status card, collapsed device & license details tile, and secure key removal action. Key input is hidden to prevent confusion.
  - **Trial Active:** Prominent remaining trial days banner, quick activation key input, dedicated Help & Support card, collapsed Free vs Pro comparison, and collapsed device details.
  - **Expired / Revoked:** Clear status warning banner, activation key entry card first, followed by Help & Support and device details.
- **Dedicated Support Card:** Compact Help & Support card with direct email and WhatsApp contact actions without sales steering or external purchase links (fully Google Play compliant).
- **Network Resilience:** Full pull-to-refresh (`RefreshIndicator`) support and inline retry states for network failure handling.

### 2. Unified Activation Key Experience (توحيد وتأمين إدخال مفتاح التفعيل)
- **Single Source of Truth:** `ActivationKeyInputWidget` now centralizes all key validation, submission, and state management across `ActivationScreen` and `LicenseScreen`.
- **Fast Local Format Validation:** Instant Crockford checksum validation for 12-character keys (`ShortLicenseKey`) and signed payload structure validation before enabling submission.
- **Outcome Mapping & Security:**
  - Granular error messages and helpful tips for invalid keys, server unreachable, rate limits, device unavailable, and storage faults.
  - 30-second cooldown timer with live countdown on rate limiting (`tooManyAttempts`).
  - Read-only locking during verification, and automatic clipboard clearance on successful activation.
  - Delightful celebration checkmark animation and list of unlocked Pro features on success.

### 3. In-App Updates Hardening (تحسين إدارة تحديثات التطبيق)
- Resume in-progress immediate updates automatically on app startup and resume.
- Prioritized critical updates (`updatePriority >= 4` or critical staleness) with immediate flow triggers.
- Global `ScaffoldMessengerKey` prevents `BuildContext` leaks during update notifications.
- Intelligent 1-hour backoff on network failures and 3-day decline cooldown to avoid user disruption.
- Graceful non-Play fallback messaging for sideloaded installations.

---

## Verification & Quality Assurance / التحقق وضمان الجودة
- **License & Compliance Guard Tests:** `test/screens/license_redesign_test.dart` passing (100%).
- **Activation Widget & Outcomes:** `test/widgets/activation_key_input_widget_test.dart` passing.
- **In-App Update Service Test Suite:** `test/services/app_update_service_test.dart` passing.
- **Play Store Compliance Guard:** `bash tool/check_play_compliance.sh` verified.
- **Static Analysis:** `flutter analyze` — zero issues found.

---

## Version Metadata / بيانات الإصدار
- **Version:** `1.1.5`
- **Build Number:** `22`
- **Application ID:** `com.elmahdi.waraqatak`
- **Tag:** `v1.1.5+22`

# Release Notes — Waraqatak 1.2.0-beta.1

> **Pre-release Notice:** This is a pre-release beta build (`1.2.0-beta.1+23`) for testing telemetry, error reporting, and privacy controls prior to production rollout.

## Overview / نظرة عامة
Waraqatak `1.2.0-beta.1` introduces default-on privacy-first telemetry and error reporting backed by the AlmHdy Analytics SDK (v1.1.0), featuring two independent user toggles, a first-run privacy notice, robust PII sanitization, and a hard-coded write-only ingestion key.

تأتي النسخة التجريبية `1.2.0-beta.1` بنظام قياس وتحليل استخدام وتقارير أخطاء مفعل افتراضياً ومبني وفق أعلى معايير الخصوصية، مع فصل كامل لقنوات الاستخدام والأخطاء في خيارات مستقلة، وإشعار توضيحي يظهر لمرة واحدة عند أول تشغيل، وتشفير وتجريد كامل للبيانات الحساسة.

---

## Key Highlights & Improvements / أبرز التحسينات

### 1. AlmHdy Analytics Integration (تكامل نظام التحليلات المحدث)
- Upgraded AlmHdy Analytics Flutter SDK (v1.1.0) with configurable queue sizing (default: 500 events) and idle flush timer management to preserve battery.
- Configured a write-only hard-coded project ingestion key, eliminating `--dart-define` compilation parameters while preserving injectable empty-key safety for automated tests.

### 2. Dual Telemetry Channels & Settings Toggles (فصل خيارات الاستخدام وتقارير الأخطاء)
- Two independent opt-out toggles in Settings: "Anonymous usage statistics" and "Error reports".
- Immediate channel isolation: disabling either toggle purges queued events for that channel without affecting the other.
- Legacy migration: respects prior user opt-outs across both channels.
- Gated behind `settings.manage` permissions.

### 3. One-Time First-Run Notice (إشعار الخصوصية عند أول تشغيل)
- Non-blocking dialog on first launch post-unlock informing users about anonymous metrics with direct navigation to Settings.
- Flag persisted locally and never displayed again across app updates or sessions.

### 4. Privacy-Preserving Error Sanitizer (منظومة تنقية وتجريد بيانات الأخطاء)
- `ErrorSanitizer` deep scrubber redacting phone numbers, emails, monetary amounts, tokens, license keys, and file paths.
- Fingerprint deduplication and session cap at 20 errors per session.
- Global hooks for `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded`.

---

## Version Metadata / بيانات الإصدار
- **Version:** `1.2.0-beta.1`
- **Build Number:** `23`
- **Application ID:** `com.elmahdi.waraqatak`
- **Tag:** `v1.2.0-beta.1`

# Release Notes — Waraqatak 1.1.5+20

## Overview / نظرة عامة
Waraqatak `1.1.5+20` is a major hardening and production stabilization release for the **Accounting Backbone**. It introduces atomic savepoints for shadow posting isolation, bounded resumable backfill with checkpoint cursors, worker isolate execution for CPU-intensive ledger derivations, forced-safe backup restore policies, and mobile UX refinement with a 3-second SnackBar timer.

تعتبر النسخة `1.1.5+20` تحديثاً شاملاً لتثبيت وتحصين **العمود الفقري المحاسبي**؛ حيث تضمن عزل العمليات التشغيلية عن أي أخطاء جانبية للقيود اليومية عبر نقاط الحفظ (Savepoints)، وترحيل البيانات القديمة في دفعات مجزأة قابلة للاستئناف التلقائي باستخدام مؤشرات فحص (Cursor)، ونقل الحسابات الثقيلة إلى خيط معالجة منفصل (Worker Isolate)، مع تعزيز أمان استعادة النسخ الاحتياطية وتحسين استجابة الواجهة بتقليل مدة الإشعارات إلى 3 ثوانٍ.

---

## Key Highlights & Improvements / أبرز التحسينات

### 1. Isolated Shadow Posting with SQLite Savepoints (عزل قيود الظل بنقاط الحفظ)
- Operations (`postDocumentIssued`, `postPaymentRecorded`, `reverseDocument`, `postDraftIsolated`) are wrapped within dedicated SQLite `SAVEPOINT` transactions.
- Business transactions (sales, purchases, payments, receipts, cancellations) commit seamlessly even if an unexpected journal error occurs while journal reports are disabled.
- Standard period lock violations (`PeriodClosedException`) remain strictly authoritative and abort backdated tampering as designed.
- Added automatic journal shadow posting on `DatabaseHelper.issueDocument(id)`.

### 2. Resumable & Bounded Batched Backfill (ترحيل مجزأ وقابل للاستئناف)
- Legacy database backfilling processes entries in bounded, atomic batches of 100 entries (`defaultBatchSize = 100`).
- Each batch atomically commits entries and saves the checkpoint cursor (`journal_backfill_cursor`) in `app_settings`.
- If the application or device is interrupted or shut down mid-backfill, restarting resumes precisely from the checkpoint without duplicate `entry_no` collisions or missing records.
- 10ms compositor yields (`Future.delayed`) prevent frame drops on low-end mobile devices.
- Rigorous trial-balance parity verification is performed across all accounts before clearing the cursor and marking completion.

### 3. Worker Isolate Offload for Ledger Derivation (معالجة خارج مسار الواجهة)
- Ledger derivation calculations (`LedgerBuilder.build`) run asynchronously on a background Dart Isolate (`Isolate.run`), preventing UI thread jank.
- Zero SQLite connections cross isolate boundaries; all database reads happen safely on the host thread isolate.

### 4. Backup Restore Security & Forced-Safe Flag (أمان استعادة النسخ الاحتياطية)
- Restoring a backup unconditionally resets `journal_reports_enabled` to `false`.
- Parity is verified safely in a guarded block post-restore; any discrepancy is cleanly captured in audit logs and diagnostics without crashing or enabling unverified reports.

### 5. Snappier UX: 3-Second SnackBar Auto-Dismissal (تحسين مدة الإشعارات)
- `AppSnackBar.defaultDuration` updated from 5 seconds to 3 seconds for standard operations and actions with animated countdowns, providing a fast and responsive mobile experience.

---

## Verification & Quality Assurance / التحقق وضمان الجودة
- **Regression Suite:** 88 / 88 test files passing (1,022 total tests, 0 failures, 0 skipped).
- **Static Analysis:** `dart analyze` — zero warnings, zero errors.
- **Play Store Compliance:** `tool/check_play_compliance.sh` verified OK.
- **Synthetic Scalability Benchmarks:**
  - 5,000 documents (12,501 journal entries): 34.1s, RSS 110.5 MB, 100% exact parity.
  - 20,000 documents (50,001 journal entries): 124.4s, RSS 147.0 MB, 100% exact parity.

---

## Version Metadata / بيانات الإصدار
- **Version:** `1.1.5`
- **Build Number:** `20`
- **Application ID:** `com.elmahdi.waraqatak`
- **Tag:** `v1.1.5+20`

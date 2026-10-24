# Release notes — 1.1.4-alpha.2 (build 9)

Alpha pre-release with Google Drive sign-in diagnostics, error transparency, and authentication hardening.

## English (en-US)

- **Google Drive Authentication Diagnostics**: Added safe, detailed debug logging for Google Sign-In and Google Drive authorization steps without exposing sensitive credentials or tokens.
- **Error Transparency**: Proper error propagation and user-facing messages when Google Sign-In is cancelled or encounters OAuth client/certificate configuration mismatches.
- **UI State Recovery**: Prevented silent resets in the cloud backup screen when authentication is not completed.
- **Authentication Regressions**: Added test coverage verifying authentication success, cancellation propagation, configuration error handling, and authorization denial.

## العربية (ar)

- **تشخيص مصادقة Google Drive**: إضافة سجلات تشخيصية آمنة ومفصلة لخطوات تسجيل الدخول وتفويض Google Drive دون تسجيل أي بيانات حساسة أو رموز دخول.
- **شفافية الأخطاء للمستخدم**: معالجة سليمة للاستثناءات وعرض رسائل خطأ واضحة عند إلغاء تسجيل الدخول أو عند وجود عدم تطابق في إعدادات شهادة وتطبيق Google Cloud.
- **تحديث واجهة المستخدم**: منع الإغلاق الصامت في شاشة النسخ الاحتياطي السحابي عند عدم اكتمال تسجيل الدخول وعرض الحالة بوضوح.
- **اختبارات أمان وموثوقية المصادقة**: توسيع نطاق اختبارات الوحدة لتغطية حالات نجاح المصادقة، وإلغاء المستخدم، وأخطاء الإعداد، ورفض التفويض.

## Version

| | |
|---|---|
| Previous release | `1.1.4-alpha.1+8` |
| This release | `1.1.4-alpha.2+9` (`pubspec.yaml`) |

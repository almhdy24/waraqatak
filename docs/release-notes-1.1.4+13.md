# Release notes — 1.1.4 (build 13)

Production security hardening release delivering server-authoritative one-time free trials, fail-closed online license verification, hardware phone model metadata reporting, bilingual in-app licensing notifications, and cross-product licensing isolation.

## English (en-US)

• Server-Authoritative Free Trial: Transitioned trial eligibility from client-side storage to the central licensing server with atomic database transactions and uniqueness constraints (`UNIQUE(product_id, machine_id)`). Reinstalling or clearing data preserves the original trial window and prevents duplicate trial creation.
• Fail-Closed Online License Verification: Enhanced ongoing background verification so any explicit server rejection (`revoked`, `device_not_registered`, `device_mismatch`, `license_not_found`, `license_flagged`) immediately disables Pro features without waiting for local expiration, while preserving legitimate offline access during network failures.
• Physical Phone Model Reporting: Captured hardware phone manufacturer and model (e.g. `Samsung Galaxy A16`) via platform channel for user-friendly device identification in the licensing screen and admin panel. Treated strictly as informational metadata.
• Bilingual In-App Notification Center: Added dedicated notification dispatcher (`LicenseNotificationService`) supporting Arabic and English notices for trial starts, trial expiration warnings, license activations, server revocations, and connectivity statuses with read-state persistence and duplicate suppression.
• Strict Product Isolation: Enforced explicit `product: 'waraqatak'` in all activation requests, preventing cross-product key activation.
• Preserved Backward Compatibility: Kept existing stored machine identifiers intact on upgrade, guaranteeing zero lockout or extra slot consumption for existing customers.

## العربية (ar)

• حماية وإلزامية الفترة التجريبية من الخادم: نقل إدارة الفترة التجريبية لتكون مركزية وموثقة من الخادم مباشرة مع منع تكرار الحصول على التجربة المجانية عند مسح بيانات التطبيق أو إعادة تثبيته عبر قيود قواعد البيانات الذرية.
• التحقق اللحظي الصارم من التراخيص: تفعيل فحص التراخيص الدوري في الخلفية مع الإيقاف الفوري لميزات Pro عند إلغاء الترخيص أو نقله من قبل الإدارة، مع ضمان استمرار العمل أوفلاين دون انقطاع عند انقطاع الإنترنت للعملاء المصرح لهم.
• عرض طراز الهاتف الفعلي: إظهار اسم وطراز الجهاز (مثل `Samsung Galaxy A16`) في شاشة الترخيص ولوحة الإدارة لتمييز الأجهزة بسهولة وبشكل آمن كبيانات استرشادية.
• مركز إشعارات داخلي ثنائي اللغة: دعم كامل لإشعارات الترخيص والفترة التجريبية (بدء التجربة، اقتراب الانتهاء، انتهاء الصلاحية، إلغاء الترخيص، وتنبيهات الاتصال) باللغتين العربية والإنجليزية مع حفظ حالة القراءة ومنع تكرار التنبيهات.
• عزل كامل لمنتجات التراخيص: ضمان عدم تفعيل أي مفاتيح تخص تطبيقات أخرى على تطبيق ورقتك.
• التوافقية والأمان للعملاء الحاليين: الحفاظ الكامل على المعرفات والتراخيص المفعلة مسبقاً دون استهلاك خانات أجهزة جديدة أو إيقاف أي مستخدم حالي.

## Version

| | |
|---|---|
| Previous release | `1.1.4+12` |
| This release | `1.1.4+13` (`pubspec.yaml`) |

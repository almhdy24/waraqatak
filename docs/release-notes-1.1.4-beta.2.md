# Release notes — 1.1.4-beta.2 (build 11)

Beta release delivering comprehensive reliability, UX refinement, license activation experience upgrade, document list navigation fixes, responsive design improvements, and help center integration.

## English (en-US)

• Document List Navigation & Preview: Resolved issue where stock movements and payments reports displayed only raw IDs; now displaying full document numbers and types with direct tap-to-view navigation and deleted-document safety dialogs.
• Robust Machine Identifier: Integrated hardware-backed Android ID machine identification with SHA-256 derivation and stable UUID v8 mapping, preserving existing stored UUIDs and preventing transient license invalidations across reinstalls.
• License Activation & Device Transfer: Upgraded activation flow with clipboard paste support, strict text direction isolation, clear Arabic error categorization for device status, device ID display with copy action, and transfer guidance.
• Google Drive Backup UX: Enhanced responsive design across compact and wide viewports (320px–430px), eliminating button overflows, isolating file names and dates in LTR, and strengthening recovery confirmation.
• In-App Notifications & Navigation: Improved inbox navigation supporting internal destinations (Settings, Google Drive, License, Diagnostics, Help Center) with graceful fallbacks and persistent read states.
• Online Help Center Integration: Added direct external link to the official Waraqatak Help Center (`https://almhdy24.com/products/waraqatak/help/`) in Settings and About screens without embedded webviews.
• Advanced Database Repair Usability: Isolated raw technical identifiers in LTR chips, improved Arabic explanations for integrity findings, and ensured rollback safety guarantees.
• In-App Updates Cleanup: Streamlined flexible update download listeners and prevented redundant callbacks.

## العربية (ar)

• إصلاح قوائم المستندات والتنقل إليها: حل مشكلة عرض المعرّفات الأولية فقط في حركات المخزون وتقارير المدفوعات؛ حيث تظهر الآن أرقام المستندات وأنواعها بوضوح مع إمكانية النقر المباشر لفتح المستند ومعالجة آمنة للمستندات المحذوفة.
• هوية الجهاز والترخيص المستقر: اعتماد معرّف الجهاز المستند إلى Android ID المشفر بواسطة SHA-256 مع صيغة UUID v8 المستقرة، مع الحفاظ التام على المعرّفات المحفوظة مسبقاً لمنع فقدان التفعيل عند إعادة التثبيت.
• ترقية شاشات التفعيل والترخيص: تحسين تجربة إدخال مفتاح التفعيل بإضافة زر اللصق السريع، وتنسيق اتجاه النص (LTR)، ورسائل خطأ واضحة باللغة العربية، وعرض معرّف الجهاز مع زر النسخ وتوضيح سياسة نقل الترخيص.
• تحسين النسخ الاحتياطي على Google Drive: تصميم متجاوب لكافة الشاشات (من 320 وحتى 430 بكسل) يمنع تداخل الأزرار، مع ضبط اتجاه أسماء الملفات والتواريخ بالإنجليزية لتفادي تشوه النصوص في الواجهة العربية.
• الإشعارات الداخلية والتوجيه الذكي: دعم التوجيه التلقائي للوجهات الداخلية للتطبيق (الإعدادات، النسخ الاحتياطي، الترخيص، الفحص، مركز المساعدة) وحفظ حالة القراءة بشكل دائم وموثوق.
• رابط مركز المساعدة الإلكتروني: إضافة رابط خارجي مباشر لمركز مساعدة ورقتك الرسمي في شاشتي الإعدادات وحول التطبيق لتمكين المستخدمين من الوصول السريع للأدلة والشروحات.
• تعزيز أمان تشخيص وإصلاح البيانات: توضيح المشاكل المكتشفة بنصوص عربية مفهومة دون إظهار جداول أو استعلامات تقنية، مع ضمان التراجع التلقائي عن أي تعديل غير ناجح.
• تبسيط تحديثات التطبيق: تحسين مستمعي التنزيل في الخلفية لضمان استقرار استهلاك الذاكرة وتجربة مستخدم سلسة.

## Version

| | |
|---|---|
| Previous release | `1.1.4-beta.1+10` |
| This release | `1.1.4-beta.2+11` (`pubspec.yaml`) |

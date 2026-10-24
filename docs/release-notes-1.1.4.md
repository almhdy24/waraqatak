# Release notes — 1.1.4 (build 12)

Production stable release delivering clickable database diagnostic navigation, complete Arabic localization for diagnostic and repair reports, strict accounting integrity invariants, hardware-backed device identity, redesigned license activation, and full Play Store compliance.

## English (en-US)

• Clickable Diagnostic Records & Safe Navigation: Direct interactive chip and modal drawer navigation from database diagnostic findings and repair recommendations to affected documents (`DocumentDetailScreen`), products (`ProductFormScreen`), stock movements (`StockMovementsScreen`), and stocktakes (`StocktakeScreen`), with non-crashing safe alerts for previously deleted records.
• Multiple Affected Records Drawer: Added a structured bottom sheet listing affected records with document numbers, recipient names, types, and individual navigation targets when multiple records are impacted (`عرض السجلات المتأثرة`).
• 100% Arabic Localization of Diagnostics & Repair: Standardized the complete diagnostic and repair report flow in professional, accounting-grade Arabic. Eliminated raw SQL identifiers, internal enum keys, and English database column names from user-facing screens and exported plain-text reports.
• Accounting Data Safety & Manual Review Guarantees: Strictly enforced manual-review-only status for all payment mismatch discrepancies (`payment_records_exceed_document_paid`, `payment_records_less_than_document_paid`, `active_receipt_missing_payment_record`, `cancelled_document_payment_mismatch`). Automated repair is disabled for payment rows to guarantee that historical upfront payments, reversals, and legitimate financial records are never overwritten or deleted.
• Resilient Hardware Device Identity: Integrated Android ID with SHA-256 derivation and stable UUID v8 representation, ensuring device continuity across app reinstalls while preserving existing stored license identifiers.
• Enhanced License Activation Flow: Integrated quick-paste clipboard action, LTR text direction isolation for license keys, Arabic error categorizations, device ID display with copy action, and clear license transfer instructions.
• Responsive Google Drive Backup: Refined backup and restore screens across small and wide screen form factors (320px–430px) with LTR isolation for timestamps and filenames, eliminating layout overflows.
• Online Help Center Integration: Added direct links in Settings and About screens to the official Waraqatak Help Center (`https://almhdy24.com/products/waraqatak/help/`).
• Play Store Compliance: Verified adherence to Google Play Store policies and requirements.

## العربية (ar)

• النقر المباشر والتنقل الآمن لسجلات التشخيص: إمكانية النقر على أرقام السجلات المتأثرة مباشرة من تقارير الفحص والتشخيص للانتقال السريع إلى تفاصيل المستند، نموذج المنتج، شاشة حركات المخزون، أو الجرد الدوري، مع حوارات تنبيهية آمنة في حال كان السجل محذوفاً.
• نافذة استعراض السجلات المتأثرة: إضافة قائمة سفلية منظمة تعرض السجلات المتأثرة مع أرقامها، وأنواعها، وأسماء العملاء/الموردين عند وجود عدة سجلات متأثرة (`عرض السجلات المتأثرة`).
• تعريب شامل وتخصصي لتقارير التشخيص والإصلاح: تعريب كافة الفحوصات والتقارير بنسبة 100% بلغة محاسبية عربية دقيقة، وإلغاء كافة الرموز البرمجية، وأسماء الحقول والجداول الإنجليزية من الواجهة والتقارير النصية المصدرة.
• حماية السلامة المحاسبية والتدقيق اليدوي للمدفوعات: فرض المراجعة اليدوية الإلزامية ومنع الإصلاح الآلي التلقائي لجميع حالات اختلاف المدفوعات حفظاً لأموال وسجلات المستخدمين ومنعاً لتعديل أي مدفوعات تاريخية أو سندات قبض سابقة.
• هوية مستقرة للأجهزة والتراخيص: تحسين نظام ربط التراخيص عبر معرّف الجهاز المستند إلى Android ID بتشفير SHA-256 وصيغة UUID v8 المستقرة، مع الحفاظ الكامل على المعرّفات المخزنة مسبقاً.
• ترقية شاشة التفعيل ونقل الترخيص: دعم اللصق السريع، وتنسيق مفاتيح التفعيل باتجاه LTR، ورسائل خطأ توضيحية باللغة العربية، ونسخ معرّف الجهاز بلمسة واحدة.
• تحسين النسخ الاحتياطي على Google Drive: واجهات متجاوبة ومطورة تعمل بسلاسة على الشاشات الصغيرة والعريضة (من 320 حتى 430 بكسل) مع الحفاظ على اتجاه أسماء الملفات والتواريخ.
• رابط مركز المساعدة الإلكتروني: توفير وصول فوري لمركز مساعدة ورقتك الرسمي من شاشتي الإعدادات ومعلومات التطبيق.
• التوافق التام مع متطلبات Google Play: التحقق الكامل من التوافقية والسلامة لمتجر التطبيقات.

## Version

| | |
|---|---|
| Previous release | `1.1.4-beta.2+11` |
| This release | `1.1.4+12` (`pubspec.yaml`) |

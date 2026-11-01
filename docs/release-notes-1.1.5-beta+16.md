# Release notes — 1.1.5-beta+16

Beta pre-release delivering comprehensive UI/UX modernization, complete Arabic (RTL) localization quality overhaul, wholesale and custom units defect resolutions with hard architectural guards, licensing and trial security hardening, in-app notification inbox upgrades with client tombstones and version targeting, and Google Play consumption-only compliance.

---

## English (en-US)

### What Changed
• **Design System & Accessible UI/UX Overhaul:**
  - Standardized 8dp grid system, uniform card radii, and WCAG AA-compliant contrast ratios (>= 4.5:1 text, >= 3.0:1 UI graphics).
  - Minimum 48x48dp touch targets across all buttons and icon actions.
  - Reusable component suite (`AppConfirmDialog`, `AppErrorState`, `AppLoadingView`, `AppAmountText`, `StatusBadge`).
  - Native RTL icon mirroring (`AppIcons.chevronForward`, `AppIcons.arrowBack`) eliminating scattered ternary conditionals.
  - Form unsaved changes protection dialogs, sticky document item totals, sectioned contact details, and scrollable wide reports.
• **Localization & Linguistic Quality Polish:**
  - Approved terminology normalization and Arabic punctuation standardization.
  - Parameterized messages and complete Arabic plural forms (zero, one, two, few, many, other).
  - Format centralization in `FormatUtils` with Western digits for numeric clarity.
  - Android native string resources configured for bilingual OS app naming.
  - Strict exclusion of Unicode Bidi isolates from PDF print output to guarantee clean thermal and desktop rendering.
  - Automated 10-point localization quality test suite.
• **Units & Wholesale Pricing Defect Fixes & Hard Invariants:**
  - Authoritative multi-line stock deduction validator (`DatabaseHelper._assertSaleStockAvailable`) preventing overselling across duplicate product lines (BUG-1).
  - Centralized line repricing pipeline (`DocumentService.resolveLinePrice`) preserving custom sales units and conversion factors across contact changes (BUG-2).
  - Complete wholesale pricing and custom packaging unit parity in Quotations (BUG-3 / GAP-1).
  - Document detail visual line badges for custom sales units and applied wholesale tiers (GAP-2).
  - Bulk pricing custom unit warning banners (GAP-3) and product form duplicate unit name guards (GAP-4).
  - Hard architectural boundaries and randomized invariant testing (INV-1..INV-9) permanently enforced.
• **Licensing, Activation & Trial Hardening:**
  - Unified canonical application identifier to `com.elmahdi.waraqatak` with legacy backward-compatibility.
  - Authoritative offline evaluation of server-issued `expired` status in `LicenseService._compute` (F4).
  - Monotonic hardware ID trial claiming preventing duplicate or stray trial records on licensed devices (F7, F8).
  - Anti-enumeration defense strictly preserved; API correlation IDs captured as anonymous support reference IDs.
  - Inline Crockford Base32 normalization and checksum validation.
  - Diagnostic information export with strict secret masking (`XXXX-****-YYYY`).
• **In-App Notifications & Inbox Upgrades:**
  - Dynamic client version and build targeting (`1.1.5+16`) eliminating stale hardcoded version queries.
  - Cross-repo SemVer matcher validating inclusive `min_app_version` and `max_app_version` bounds.
  - RTL-safe swipe-to-dismiss with immediate Undo SnackBar.
  - Multi-select long-press selection mode with bulk delete and confirmation safeguards.
  - Persistent SharedPreferences tombstones preventing deleted notifications from returning on subsequent syncs, with automatic server reconciliation.
  - Non-dismissible critical notification lock badges.
• **Google Play Compliance & Compliant Support Guidance:**
  - Zero digital purchase, checkout, or subscription vocabulary in user-facing copy.
  - Gating screens completely free of website URLs, phone numbers, or WhatsApp purchase links.
  - Support guidance strictly standardized: *"If the problem continues, contact support from the About page"*, routing internally to `AboutScreen`.

### What Did NOT Change
• **Inventory Costing & Valuation Math:** WAC/FIFO costing calculations and historical costing replay (v20) remain untouched.
• **Database Schema:** No modifications to SQLite tables, column structures, or database schema version.
• **Cryptographic Security & Key Formats:** RSA-2048/SHA-256 license signatures, Crockford Base32 12-character format, and legacy signed payloads remain completely stable.

### Known Limitations
• Purchases do not support custom sales packaging units (purchases remain strictly base-unit tracked).
• Physical Android device verification checklists pending per `docs/E2E_RUNBOOK.md`.

### Upgrade Notes
• This build is 100% backward-compatible with the current live API.
• The enhanced notification targeting features (version range and dismissibility filtering) require the accompanying API and SQL migration deployment (detailed in the API repository's `DEPLOY_NOTES.md`), which will be deployed separately.

---

## العربية (ar)

### أبرز التغييرات
• **تطوير واجهة المستخدم وتجربة الاستخدام (UI/UX):**
  - اعتماد شبكة تصميم قياسية (8dp) مع تباين لوني معتمد وفق معايير إمكانية الوصول العالمية (WCAG AA).
  - توسيع مساحات اللمس لجميع الأزرار لتكون 48×48dp على الأقل لسهولة الاستخدام بيد واحدة.
  - مكتبة عناصر موحدة تشمل مربعات الحوار التوكيدية، وحالات التحميل والخطأ، وبطاقات المجاميع المثبتة.
  - دعم كامل للغة العربية والاتجاه من اليمين لليسار (RTL) مع تصحيح اتجاهات الأيقونات تلقائياً.
  - حماية النماذج من فقدان البيانات غير المحفوظة، وتسهيل تصفح التقارير المالية العريضة.
• **تحسينات التعريب واللغة:**
  - توحيد المصطلحات المحاسبية وفق المعجم المعتمد، وضبط علامات الترقيم والتراكيب اللغوية.
  - دعم كامل لصيغ الجموع في اللغة العربية (المفرد، المثنى، الجمع، إلخ).
  - توحيد تنسيق التواريخ والأرقام عبر `FormatUtils` باستخدام الأرقام العالمية لتفادي أخطاء الطباعة.
  - منع تسرب محارف عزل النصوص (Bidi isolates) إلى فواتير PDF لضمان طباعة حرارية فائقة الدقة.
  - منظومة فحص آلي لجودة التعريب مكونة من 10 اختبارات قياسية.
• **معالجة عيوب أسعار الجملة ووحدات البيع وقواعد الأمان:**
  - معالجة التحقق الصارم من توفر المخزون (`DatabaseHelper._assertSaleStockAvailable`) ومنع بيع كميات سالبة عند تكرار الصنف في بنود الفاتورة (BUG-1).
  - توحيد مسار إعادة التسعير (`DocumentService.resolveLinePrice`) والحفاظ على وحدات البيع عند تغيير العميل (BUG-2).
  - دعم وحدات البيع وأسعار الجملة في شاشة عروض الأسعار (BUG-3).
  - إظهار شارات وحدات البيع وفئات الأسعار في تفاصيل المستندات، والتحذير من تكرار أسماء الوحدات.
  - فرض 9 قواعد أمان محاسبية صارمة (INV-1..INV-9) تمنع حدوث أي خلل في المخزون أو الأسعار مستقبلاً.
• **تعزيز أمان التراخيص وتجربة التنشيط:**
  - توحيد المعرف البرمجي للتطبيق إلى `com.elmahdi.waraqatak` مع التوافق التام مع التراخيص السابقة.
  - التحقق الدقيق من حالة انتهاء الترخيص أوفلاين استناداً إلى رد الخادم المخزن (F4).
  - منع تكرار طلب الفترات التجريبية للأجهزة المفعلة بترخيص رسمي (F8).
  - حماية واجهة التنشيط من التخمين، واستخراج معرف مرجعي آمن للدعم الفني.
  - تصدير بيانات تشخيصية مشفرة ومقنعة لحماية خصوصية المفاتيح (`XXXX-****-YYYY`).
• **ترقية صندوق الإشعارات والاستهداف الدقيق:**
  - استهداف الإعلانات وفق رقم الإصدار والبناء الفعلي للجهاز (`1.1.5+16`).
  - دعم كامل للتحقق من نطاق الإصدارات المتوافقة (الحد الأدنى والأقصى).
  - حذف الإشعارات بالسحب لليمين/اليسار مع إمكانية التراجع الفوري (Undo).
  - وضع التحديد المتعدد للحذف الجماعي مع رسالة تأكيد.
  - حفظ شواهد الحذف محلياً لمنع عودة الإشعارات المحذوفة عند المزامنة القادمة، مع التوفيق التلقائي مع الخادم.
  - شارات حماية خاصة تمنع حذف الإشعارات الحرجة والتنبيهات الإلزامية.
• **الامتثال لسياسات متجر Google Play:**
  - خلو شاشات الترقية تماماً من أي ألفاظ شراء أو اشتراكات رقمية أو روابط شراء خارجية أو أرقام واتساب تجارية.
  - توجيه طلبات المساعدة الفنية حصرياً إلى شاشة "حول التطبيق" بزر نسخ آمن للمعلومات التشخيصية.

---

## Version

| | |
|---|---|
| Previous release | `1.1.5-alpha+15` |
| This release | `1.1.5-beta+16` (`pubspec.yaml`) |
| Git Tag | `v1.1.5-beta+16` |
| Release Classification | Pre-release (Beta) |

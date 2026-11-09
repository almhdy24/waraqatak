# AlmHdy Analytics & Error Reporting: Privacy Policy Disclosure Text

**For use on:** `https://almhdy24.com/privacy` and app store disclosures.  
**Applications:** Waraqatak (ورقتك) & Cashirak (كاشيرك)  
**Date:** 2026-11-08  

---

## 1. Arabic Disclosure (النص العربي المقترح لصفحة الخصوصية)

### إحصائيات الاستخدام وتشخيص الأعطال (AlmHdy Analytics)

يلتزم تطبيق **ورقتك (Waraqatak)** بحماية خصوصية بياناتك التجارية والتزام مبدأ العمل دون اتصال بالإنترنت أولاً (Offline-First). للمساعدة في تحسين أداء واستقرار التطبيق وسرعة معالجة الأخطاء البرمجية، يتضمن التطبيق قناتين تشغيليتين منفصلتين ومجهولتي الهوية بالكامل:

#### أولاً: قناتا جمع البيانات (مفعلتان افتراضياً وقابلتان للإيقاف المستقل):
1. **قناة إحصائيات الاستخدام (Usage Analytics):**
   - **ما يتم جمعه:** أحداث تشغيلية عامة ومجردة (مثل: فتح التطبيق، التنقل بين الشاشات الرئيسية، فئة نوع المستند المنشأ، تصنيف تقريبي لعدد البنود كفئات مثل "1" أو "2-5" أو "6-20"، نجاح النسخ الاحتياطي، وإصدار الترقية).
   - **ما لا يتم جمعه إطلاقاً:** لا يجمع النظام أي مبالغ مالية، أسعار، تكاليف، أرباح، أسماء عملاء أو موردين، أرقام هواتف، أسماء منتجات، أو محتويات الفواتير.
2. **قناة تقارير الأعطال وتشخيص الأخطاء (Error & Crash Reporting):**
   - **ما يتم جمعه:** نوع الاستثناء البرمجي (Exception Type)، رسالة الخطأ بعد تجريدها وتطهيرها بالكامل، تتبع المكدس البرمجي (Stack Trace) بعد إزالة مسارات ملفات المستخدم، إصدار التطبيق، ونظام التشغيل.
   - **تطهير البيانات الصارم (Deep Sanitization):** تخضع جميع رسائل الأعطال لنظام تنقية آلي صارم يزيل فوراً:
     - أرقام الهواتف (المحلية والدولية وأي سلاسل رقمية من 6 أرقام فأكثر).
     - عناوين البريد الإلكتروني.
     - المبالغ المالية ورموز العملات (SDG, USD, EUR, SAR, ج.س، إلخ).
     - مسارات الملفات والمجلدات الشخصية للجهاز.
     - الرموز السرية ومفاتيح التراخيص وكلمات المرور.
   - **حدود الاستهلاك:** يتم إرسال حد أقصى لا يتجاوز 20 تقريراً لكل جلسة تشغيل، مع منع تكرار الأخطاء المتطابقة تلقائياً لتوفير طاقة البطارية والبيانات.

#### ثانياً: الضمانات والتحكم:
- **حظر جمع المعرفات الشخصية:** يتم إنشاء معرّف عشوائي مجهول للهوية عند تثبيت التطبيق (`installation_id`) دون ربطه بالجهاز أو رقم الهوية أو أي حساب مستخدم.
- **حظر تسجيل عناوين الإنترنت (IP Hashing):** لا تسجل عناوين IP بصيغة صريحة؛ بل تُشفر فوراً عبر تجزئة متغيرة يومياً (HMAC-SHA256).
- **التحكم وحرية الإيقاف المستقل (Opt-Out):** كِلا الخيارين مفعلان افتراضياً لتسهيل الدعم، ويمكن للمستخدم إيقاف أي منهما أو كليهما بشكل مستقل في أي وقت عبر:
  **الإعدادات > الدعم والمعلومات > إحصائيات الاستخدام المجهولة** أو **تقارير الأخطاء والأعطال**.
  إيقاف أي خيار يوقف إرسال بيانات تلك القناة فوراً ويمسح سجلاتها المؤقتة.

---

## 2. English Disclosure (Proposed Website Privacy Policy Text)

### Operational Telemetry & Error Reporting (AlmHdy Analytics)

**Waraqatak** is engineered with an offline-first architecture prioritizing complete privacy and sovereign control over business financial data. To continuously enhance application stability and promptly resolve software bugs, the application provides two distinct, independent anonymous channels:

#### 1. Data Collection Channels (Default ON, Independently Managed):
1. **Anonymous Usage Statistics Channel:**
   - **What is collected:** Coarse operational lifecycle events (e.g., app opened, screen views, document type created, item count brackets such as "1", "2–5", "6–20", "21+", successful backup, database migration status).
   - **Strictly Excluded:** Monetary amounts, prices, costs, invoice contents, customer names, supplier names, contact phone numbers, product names, or notes. All business accounting records remain strictly on your device.
2. **Crash & Diagnostic Error Reports Channel:**
   - **What is collected:** Exception type, deeply sanitized short error message, package-level stack trace, app version, platform, and OS version.
   - **Deep Sanitization Guarantees:** All error reports pass through an automated privacy sanitizer that irreversibly redacts:
     - Telephone numbers (international and local, and numeric runs of 6+ digits).
     - Email addresses.
     - Monetary amounts and currency symbols (SDG, USD, EUR, SAR, $, €, etc.).
     - User filesystem paths and absolute storage directories.
     - Bearer tokens, secrets, passwords, and license keys.
   - **Session Limits:** Error reporting is capped at a maximum of 20 reports per session and automatically deduplicates identical repeated errors to preserve device battery and data.

#### 2. Guarantees & User Control:
- **Zero Personal Identifiers:** Metrics rely strictly on an ephemeral random UUIDv4 installation identifier. Hardware serial numbers, Android IDs, IMEI, and user profiles are never gathered.
- **Zero Plaintext IP Logging:** Client IP addresses are hashed using a daily rotating HMAC-SHA256 salt at the gateway level.
- **Independent Opt-Out Controls:** Both channels are enabled by default and can be turned off independently at any time in:
  **Settings > Support & Info > Anonymous usage statistics** or **Error reports**.
  Disabling either channel terminates transmission for that channel immediately.

---

## 3. Google Play Data Safety Guidance

When filling out the Google Play Console Data Safety form for Waraqatak:

| Category | Data Type | Purpose | Collected? | Shared? | Ephemeral / Opt-Out? |
|---|---|---|---|---|---|
| **App info and performance** | **Crash logs** | App functionality, Analytics | Yes (Anonymous, sanitized) | No | Optional / Default-on with in-app toggle |
| **App info and performance** | **Diagnostics** | App functionality, Performance | Yes (Anonymous, sanitized) | No | Optional / Default-on with in-app toggle |
| **App activity** | **App interactions** | Analytics | Yes (Anonymous coarse events) | No | Optional / Default-on with in-app toggle |
| **Personal info** | Name, Email, Phone | N/A | **NO** | No | Never collected |
| **Financial info** | Purchase history, Amounts | N/A | **NO** | No | Never collected |

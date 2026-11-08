# AlmHdy Analytics: Privacy Policy Disclosure Text

**For use on:** `https://almhdy24.com/privacy` and app store disclosures.  
**Applications:** Waraqatak (ورقتك) & Cashirak (كاشيرك)  
**Date:** 2026-11-08  

---

## 1. Arabic Disclosure (النص العربي المقترح لصفحة الخصوصية)

### إحصائيات الاستخدام والتحسين التشغيلي (AlmHdy Analytics)

يلتزم تطبيق **ورقتك (Waraqatak)** بحماية خصوصية بياناتك التجارية والتزام مبدأ العمل دون اتصال بالإنترنت أولاً (Offline-First). للمساعدة في تحسين أداء واستقرار التطبيق وفهم الميزات الأكثر استخداماً، يتضمن التطبيق نظام قياس تشغيلي مجهول الهوية بالكامل يتبع المعايير الصارمة التالية:

1. **حظر البيانات المالية والشخصية تماماً:**
   لا يجمع نظام التحليلات إطلاقاً أي أسعار، تكاليف شراء، هوامش ربح، مبالغ إجمالية، أسماء عملاء أو موردين، أرقام هواتف، أسماء منتجات، أو محتويات المستندات والفواتير. جميع هذه البيانات تخزن محلياً فقط على جهاز المستخدم ولا تغادره.

2. **بيانات مجهولة ومجمعة (Bucketed Telemetry):**
   تقتصر البيانات المجمعة على أحداث تشغيلية عامة (مثل: إنشاء مستند مع تصنيف حجم البنود تقريبياً كفئات، فتح شاشة تقرير، إتمام عملية نسخ احتياطي، أو نجاح تفعيل الترخيص). يتم إنشاء معرّف عشوائي مجهول للهوية عند تثبيت التطبيق (`installation_id`) دون ربطه بأي معرّفات للجهاز أو أرقام تسلسلية (Hardware IDs) أو عناوين بريد إلكتروني.

3. **حماية عنوان البروتوكول (IP Protection):**
   لا تُخزّن عناوين الإنترنت (IP Addresses) في خوادمنا بصيغتها الصريحة مطلقاً؛ حيث يتم تشفيرها فوراً عبر تجزئة أمنية متغيرة يومياً (Rotating HMAC-SHA256) لمنع أي تتبع زمني أو مكاني.

4. **حق إلغاء الاشتراك الكامل (Opt-Out):**
   تفعيل إحصائيات الاستخدام اختياري ومتاح لراحة المستخدم؛ حيث يمكنك في أي وقت إيقاف جمع هذه الإحصائيات بالكامل من داخل التطبيق عبر: **الإعدادات > الدعم والمعلومات > إحصائيات الاستخدام المجهولة**. عند إيقاف هذا الخيار، يتم مسح سجل الأحداث المؤقت فوراً ويتوقف التطبيق عن إرسال أي بيانات مستقبلية.

---

## 2. English Disclosure (Proposed Website Privacy Policy Text)

### Operational Telemetry & Anonymous Analytics (AlmHdy Analytics)

**Waraqatak** is engineered with an offline-first architecture prioritizing complete privacy and sovereign control over business financial data. To continuously enhance application stability, verify upgrade migrations, and understand general feature adoption, the application integrates an anonymous telemetry subsystem governed by the following strict guarantees:

1. **Strict Exclusion of Financial & Personal Data:**
   The analytics system strictly never collects monetary amounts, product purchase costs, profit margins, selling prices, invoice totals, contact names, customer/supplier telephone numbers, barcodes, or document notes. All business accounting records remain strictly confidential and stored exclusively within the local SQLite database on your device.

2. **Categorized & Bucketed Telemetry:**
   Collected metrics are limited to coarse operational lifecycle events (e.g., document creation with generalized item count brackets such as "2–5 items", screen views, successful backup creation, or software upgrade outcomes). An anonymous UUIDv4 installation identifier is randomly generated locally; hardware serials, Android IDs, IMEI, and user identities are never accessed or transmitted.

3. **Zero Plaintext IP Address Logging:**
   Client IP addresses are never persisted in plaintext. Incoming requests are hashed using a daily rotating HMAC-SHA256 salt at the gateway level, preventing persistent cross-session network tracking.

4. **Unconditional Opt-Out Right:**
   You maintain full control over telemetry. You can completely disable usage statistics at any time within the application via: **Settings > Support & Info > Anonymous Usage Statistics**. Disabling this toggle immediately flushes local queued events, informs the ingestion servers of your opt-out preference, and terminates all telemetry transmissions.

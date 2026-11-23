# Waraqatak 1.3.0 (1.3.0+31)

## Production Release

### Arabic
ما الجديد في الإصدار 1.3.0 (بناء 31):
• **تقارير وإحصائيات متطورة للأعمال:**
  - **تقرير الإغلاق اليومي:** تسوية ومطابقة درج النقدية اليومي بدقة مع فصل مبيعات اليوم النقدية عن تحصيلات ديون المبيعات الآجلة، وعرض فوري للفارق النقدي (متوازن / فائض / عجز).
  - **تقرير أعمار الديون والالتزامات:** تصنيف ديون العملاء والتزامات الموردين حسب فترات التأخير (0–30، 31–60، 61–90، 90+ يوماً) مع إرسال تذكيرات مباشرة بالسداد عبر واتساب بنقرة واحدة وتطبيع أرقام الهواتف السودانية تلقائياً.
  - **تقرير ملخص الضرائب والخصومات:** متابعة دقيقة لضريبة المبيعات المحصلة وضريبة المشتريات والخصومات الممنوحة والمستلمة مع صافي الالتزام الضريبي.
  - **تقرير المنتجات قاربت على النفاد:** تقرير مخصص ومستقل يتيح للكاشير وأمناء المخازن متابعة حدود إعادة الطلب ونواقص البضائع دون كشف تكاليف الشراء أو تقييم رأس مال المخزون.
  - **تحليل التدفقات النقدية:** عرض إجمالي المقبوضات والمدفوعات مصنفة حسب طريقة الدفع (نقد / بنكك / محفظة إلكترونية) مع إمكانية استعراض تفاصيل سندات الصرف والقبض مباشرة.
• **تصدير ومشاركة شاملة واحترافية:**
  - **تصدير CSV معتمد:** تصدير كافة جداول التقارير بصيغة CSV المتوافقة قياسياً مع RFC 4180 وترميز UTF-8 BOM المباشر لبرنامج Microsoft Excel، مع الحفاظ على الأرقام السالبة وأرقام الهواتف وتحصينها ضد هجمات صيغ الجداول.
  - **طباعة الإيصالات الحرارية (80 مم):** خيار طباعة وتصدير مخصص لطابعات البلوتوث والفواتير الحرارية قياس 80 مم بجانب مقاس A4 المعتاد.
  - **نافذة تصدير موحدة وصلاحيات صارمة:** قائمة تصدير موحدة تتحقق من صلاحيات المستخدم وتمنع العمليات غير المصرح بها للكاشير والمستخدمين المحدودين.
• **تحسينات تجربة المستخدم والأداء وسلاسة التنقل:**
  - **حفظ نطاق التاريخ:** احتفاظ التطبيق بنطاق التاريخ النشط أثناء التنقل بين كافة شاشات التقارير دون إعادة تحديده.
  - **بحث وترتيب فوري:** إضافة حقل بحث فوري مع تأخير ذكي (300 مللي ثانية) وخيار ترتيب حسب المبلغ أو التاريخ في تقارير المبيعات والمشتريات.
  - **حماية التزامن السريع:** حماية تحميل البيانات من التداخل عند التبديل السريع بين فترات التاريخ.
  - **استقرار التكاليف:** تسريع استعلامات تقارير المبيعات والتكاليف بحذف استعلامات N+1 واستبدالها بالاستعلام الدفعي المجمع.

### English
What's new in version 1.3.0 (build 31):
• **Advanced Business Intelligence & Reporting:**
  - **Daily Closing Report:** Accurate cash drawer reconciliation segregating day cash sales from debt collections on previous credit sales, with real-time drawer variance feedback (balanced / surplus / shortage).
  - **Debt Aging Report:** Receivables and payables aging analysis across standard delay buckets (0–30, 31–60, 61–90, 90+ days) with 1-tap direct WhatsApp payment reminders and automated Sudanese phone number normalization.
  - **Taxes & Discounts Summary:** Comprehensive tax ledger tracking sales tax collected, purchase tax paid, discounts granted/received, and net tax liability.
  - **Dedicated Low Stock Report:** Independent replenishment monitor enabling cashiers and stockkeepers to track stock thresholds and shortages without exposing confidential item purchase costs or total inventory valuation.
  - **Payment Methods Cash Flow:** Segregated inflows, outflows, and net balances across Cash, Bankak, and e-wallets, with direct drilldown into standalone expense and receipt vouchers.
• **Enterprise Export & Sharing Architecture:**
  - **Standard RFC 4180 CSV Export:** Direct UTF-8 BOM CSV engine compatible with Microsoft Excel, properly preserving negative balances and phone numbers while strictly neutralizing spreadsheet formula injection vectors.
  - **80mm Thermal Receipt Roll Printing:** Native support for 80mm POS thermal roll format alongside standard A4 PDF reports.
  - **Unified Export Action Menu:** Role-based export menu gating Print/PDF actions on `reports.export_pdf` and CSV on `data.export_csv`.
• **UX, Fluidity & Concurrency Improvements:**
  - **Cross-Report Date Range Persistence:** Session-scoped date selection seamlessly preserved across all 16 report screens.
  - **Interactive Search & Sort:** Instant debounced search (300ms) and sort toggles (by amount or date) on Sales and Purchases reports.
  - **Async Concurrency Guards:** Sequence counters eliminating race conditions when toggling date filters or search queries rapidly.
  - **N+1 Costing Elimination:** High-performance chunked `IN (...)` queries replacing per-document database loops in sales costing.

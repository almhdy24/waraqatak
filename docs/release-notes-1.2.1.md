# Waraqatak 1.2.1 (1.2.1+30)

## Production Release

### Arabic
ما الجديد في الإصدار 1.2.1 (بناء 30):
• **تحسينات محاسبية شاملة:**
  - معالجة دقيقة لضريبة القيمة المضافة وتكلفة الشراء في سجل المخزون.
  - توجيه سندات القبض غير المخصصة كالتزام لحساب الدفعات المقدمة من العملاء (الحساب 2130).
  - إثبات قيود رأس مال المخزون الافتتاحي بدقة عند تسوية التكاليف.
  - إدراج سندات القبض والصرف المستقلة في ملخص الفترة وكشوف الحسابات.
  - منع الإلغاء والحذف غير الآمن للسندات المخصصة وحماية توازن القيود المحاسبية.
• **تحسينات تجربة المستخدم والواجهات (UX):**
  - دعم التمرير الكامل في شاشة قفل رمز المرور (PIN) لتفادي التداخل في الوضع الأفقي وعلى الشاشات الصغيرة.
  - تحسين استجابة وتحديث شاشة تفاصيل العميل بعد التعديل دون الخروج المفاجئ.
  - إدارة سليمة لدورة حياة حقول الإدخال في نوافذ طرق الدفع المخصصة وسندات الصرف.
  - تأمين التراجع السلس لشريط التنبيهات (SnackBar) عند تحديث الأسعار الجماعي.
  - استجابة مرنة للأزرار مع أحجام الخطوط الكبيرة وإمكانية الوصول (Accessibility).
  - منع تكرار نوافذ التأكيد عند العمليات الحساسة وإيضاح أثر إلغاء الفواتير على المخزون.
• **تنقيح الترجمة واللغة:**
  - تدقيق شامل وتوحيد للترجمة العربية والإنجليزية للمصطلحات التجارية والمحاسبية.
  - توحيد قاعدة رمز PIN في كامل التطبيق لتكون مطابقة للقاعدة الصارمة (4 إلى 6 أرقام).

### English
What's new in version 1.2.1 (build 30):
• **Core Accounting & Ledger Hardening:**
  - Accurate VAT and net unit cost tracking in stock ledger for purchases.
  - Correct posting of unallocated customer payment receipts to Customer Deposits liability (Account 2130).
  - Automatic inventory opening equity journal entries upon cost reconciliation.
  - Comprehensive inclusion of standalone receipt and expense vouchers in period summaries and customer statements.
  - Safety guards preventing accidental deletion of allocated vouchers while preserving double-entry balance.
• **User Experience & Interface Refinements:**
  - Scrollable PIN lock screen layout preventing overflows in landscape mode and on compact screens.
  - Seamless customer detail screen updates without unnecessary screen popping upon edit.
  - Robust lifecycle management for controllers in custom payment method sheets and payment flows.
  - Preserved undo SnackBar functionality during bulk price updates.
  - Flexible button constraints properly accommodating large accessibility font scaling.
  - Elimination of duplicate confirmation dialogs and clearer notices on document cancellation inventory effects.
• **Localization & Consistency Polish:**
  - Thorough Arabic and English translation refinement across business and accounting features.
  - Unified PIN validation copy aligning strictly with enforced rules (4 to 6 digits).

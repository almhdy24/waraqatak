# Help Guide Sentences to Update & Technical Follow-ups
# جمل دليل المساعدة المطلوب تحديثها ومتابعات التطوير

This document lists:
1. Every help-guide entry on the help portal (`almhdy24.com/products/waraqatak/help/`) that needs updating after the release of `fix/cancel-paid-invoice`.
2. Explicit technical follow-up items identified during the investigation and implementation phases.

---

## Part 1: Help Guide Sentences to Update (`almhdy24.com/products/waraqatak/help/`)

### 1. File: `help/invoices/cancellation.html` (إلغاء الفواتير)

#### Current Text (النص الحالي):
> عند إلغاء فاتورة، يتم استرجاع كميات المخزون وتتغير حالة الفاتورة إلى "ملغاة"، وتختفي الفاتورة من تقارير المبيعات والدفعات.

#### Updated Text (النص بعد التحديث):
> **إلغاء الفواتير غير المسددة:**
> عند إلغاء فاتورة غير مسددة، يُسترجع المخزون تلقائياً إلى المستودع وتتحول حالة الفاتورة إلى "ملغاة" وتُستبعد من تقارير المبيعات والأرباح.
>
> **إلغاء الفواتير المسددة كلياً أو جزئياً (دفعة مقدمة):**
> إذا كانت الفاتورة تتضمن دفعة نقدية مسددة:
> 1. سيظهر لك تنبيه تأكيدي يوضح المبلغ المسدد الذي تم استلامه من العميل.
> 2. يُطلب منك تأكيد حالة رد المبلغ للعميل ("تم رد المبلغ" أو "لم يُرد بعد").
> 3. تُستبعد الفاتورة ومقبوضاتها تلقائياً من تقارير المبيعات، تقارير المقبوضات، كشف حساب العميل، ودفتر الحسابات؛ لضمان عدم احتساب مبيعات ملغاة.
> 4. **تنبيه محاسبي حاسم:** لا تقم إطلاقاً بإنشاء "سند صرف" لرد المبلغ للعميل؛ لأن دفعة الفاتورة تم خصمها واستبعادها تلقائياً من الصندوق عند الإلغاء، وتسجيل سند صرف إضافي سيؤدي إلى عجز دفتري وخصم المبلغ مرتين من صندوق المحل.
> 5. يمكنك في أي وقت مراجعة وتعديل حالة رد أموال العميل من بطاقة "حالة أموال المستند الملغى" أعلى شاشة تفاصيل الفاتورة.

---

### 2. File: `help/faq/what-if.html` (قسم "ماذا لو؟" والأسئلة الشائعة)

#### New FAQ Entry to Add (إضافة جديدة):
> **س: ماذا لو ألغيت فاتورة استلمت قيمتها نقداً من العميل؟ أين ذهبت أموالي في التقارير؟**
> **ج:** بمجرد إلغاء الفاتورة، يُستبعد مبلغ الفاتورة ومقبوضاتها فوراً من تقارير المبيعات وتقارير الدفعات والصندوق لتجنب تضخيم الإيرادات بمبيعات لم تتم. يجب عليك تسليم المبلغ نقداً للعميل خارج التطبيق. لا تسجل سند صرف لهذا الرد لتجنب الخصم المزدوج. يمكنك تتبع حالة تسليم المبلغ وتعديلها في أي وقت من شاشة الفاتورة الملغاة.

> **Q: What happens if I cancel an invoice that was already paid?**
> **A:** Cancelling the invoice automatically excludes its sales total and payment from your sales reports, payment reports, customer statements, and cash reports. You must hand the refund back to the customer in cash outside the app. **Do NOT record an expense voucher for this refund**, as that would deduct the money from your cash records a second time. You can view and update the refund status at any time from the top of the cancelled invoice's details screen.

---

### 3. File: `help/purchases/cancellation.html` (إلغاء فواتير الشراء)

#### Updated Text (النص بعد التحديث):
> عند إلغاء فاتورة شراء مسددة للمورد:
> 1. يُخصم المخزون المسترد للمورد، وتتحول حالة الفاتورة إلى ملغاة.
> 2. تُستبعد دفعة الشراء من تقارير المشتريات والصندوق.
> 3. يجب استرداد المبلغ نقداً من المورد خارج التطبيق دون تسجيل "سند قبض" تعويضي حتى لا يُحسب الدخل مرتين.
> 4. تظهر بطاقة توثيق حالة استرداد المبلغ من المورد أعلى شاشة تفاصيل فاتورة الشراء الملغاة.

---

## Part 2: Technical Follow-Ups (متابعات فنية مستقبلية لا تُنفذ في هذا الفرع)

1. **تصفير الدفعة عند تعديل الفاتورة يحذف سجل الدفعة دون أثر تدقيقي (Edit Paid to 0 Deletes Payment Record Without Audit):**
   - **الموقع:** `lib/database/database_helper.dart:3497-3503`
   - **المشكلة:** عند تعديل فاتورة مسددة بدفعة مقدمة وخفض حقل المدفوع إلى `0`، يقوم الكود بتنفيذ:
     `await txn.delete('document_payments', where: 'id = ?', whereArgs: [upfrontRows.first['id']]);`
     مما يحذف سجل الدفعة الأصلي كلياً دون إنشاء سجل تدقيق أو توثيق لسبب الحذف، ويحول الفاتورة إلى غير مسددة ويطالب العميل بكامل المبلغ.
   - **المطلوب مستقبلاً:** استبدال الحذف الفيزيائي بسجل تسوية أو قيد عكسي مع توثيق تدقيقي في `audit_log`.

2. **حذف جهة الاتصال يُخفي الديون المتبقية للعملاء والموردين (deleteContact Hides Remaining Debt):**
   - **الموقع:** `lib/database/database_helper.dart:1838-1856`
   - **المشكلة:** دالة `deleteContact` لا تفحص ما إذا كان العميل أو المورد يمتلك رصيداً متبقياً (`outstanding > 0` أو `remaining > 0`)، وعند حذفه تنفصل فواتيره أو تصبح دون جهة اتصال نشطة، مما يُخفي المديونيات من تقرير أرصدة العملاء والموردين.
   - **المطلوب مستقبلاً:** إضافة حماية تمنع حذف أي جهة اتصال لديها معاملات غير مسددة (`outstanding > 0`).

3. **نطاق المشتريات والموردين (Purchases Scope):**
   - تم في هذا الإصدار شمول فواتير الشراء المسددة بحوار الإلغاء التحذيري وتوثيق حالة رد أموال المورد في `audit_log` وبطاقة تفاصيل المستند.
   - **المطلوب مستقبلاً:** بناء خدمة كشف حساب مخصصة للموردين (`SupplierStatementService`) على غرار `CustomerStatementService`.

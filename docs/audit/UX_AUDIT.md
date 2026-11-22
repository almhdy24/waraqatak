# Waraqatak (ورقتك) — Comprehensive Mobile UX & Accessibility Audit

**Audit Date:** November 21, 2026  
**Application:** Waraqatak (ورقتك) — Offline-first Flutter Business & Invoicing App (Arabic-first RTL)  
**Target Release:** 1.2.0+  
**Scope:** Exhaustive, code-verified UX, accessibility, RTL, responsiveness, and interaction audit across `lib/screens/`, `lib/widgets/`, `lib/localization/`, and `lib/theme.dart`.  
**Rules Compliance:** Read-only inspection; no application or test code modified.

---

## 1. Executive Summary Table

All 24 findings are concrete, verified in code, and sorted by severity.

| ID | Severity | File:Line Reference | Title & Short Summary |
|---|---|---|---|
| **UX-01** | **Critical** | `lib/screens/access/pin_lock_screen.dart:495-675` | Unscrollable PIN lock screen overflows and cuts off keypad in landscape / small phones (< 550dp) |
| **UX-02** | **High** | `lib/screens/customer_detail_screen.dart:95-103` | Editing contact prematurely pops entire customer detail screen back to list |
| **UX-03** | **High** | `lib/screens/payment_methods_screen.dart:147-151, 222-226` | `TextEditingController` disposed before reading text in custom payment method dialogs |
| **UX-04** | **High** | `lib/screens/bulk_pricing_screen.dart:214-225` | Immediate snackbar overwrite cancels and destroys Undo affordance on bulk price updates |
| **UX-05** | **High** | `lib/screens/home_screen.dart:409-445` | Fixed height `SizedBox(52)` causes vertical `RenderFlex` overflow under accessibility font scaling |
| **UX-06** | **High** | `lib/screens/activation_screen.dart:18-20, 135-220, 690-740` | "Enter Activation Key" action lands on long marketing/pricing page with key input hidden at bottom |
| **UX-07** | **High** | `lib/screens/document_detail_screen.dart:550-605` | Record payment bottom sheet lacks in-flight submit lock and leaks raw exception strings |
| **UX-08** | **High** | `lib/screens/exchange_rates_screen.dart:700-730, 836, 842` | Misleading price error on currency validation, hardcoded English helper, and wrong name label |
| **UX-09** | **Medium** | `lib/widgets/access/access_denied_view.dart:36-40, 115` | Technical Dart class name leaked in Arabic copy and unmirrored back button in RTL |
| **UX-10** | **Medium** | `lib/screens/access/roles_screen.dart:361`, `user_form_screen.dart:542`, `users_list_screen.dart:586` | Hardcoded `Icons.chevron_right` in Multi-User screens points backward in RTL |
| **UX-11** | **Medium** | `lib/screens/business_setup_screen.dart:120-220`, `bulk_pricing_screen.dart:45-140` | Missing `PopScope` unsaved dirty changes warning guards on major setup and pricing forms |
| **UX-12** | **Medium** | `lib/screens/business_setup_screen.dart:440`, `exchange_rates_screen.dart:189, 603, 816` | Currency names hardcoded to Arabic (`nameAr`) in dropdowns and tiles, ignoring English locale |
| **UX-13** | **Medium** | `lib/screens/reports/customer_report_screen.dart:185-215` (and 4 other report screens) | Raw loading, empty, and error state widgets bypass standardized `AppLoadingView` / `AppEmptyState` / `AppErrorState` |
| **UX-14** | **Medium** | `lib/screens/settings_screen.dart:245-265`, `google_drive_backup_screen.dart:325-355`, `period_closing_screen.dart:65-95` | Redundant duplicate back-to-back confirmation dialogs in destructive and sensitive operations |
| **UX-15** | **Medium** | `lib/screens/document_detail_screen.dart:260-282` | Cancellation dialog for unpaid documents lacks explanation of inventory return and journal reversal |
| **UX-16** | **Medium** | `lib/screens/edit_document_screen.dart:689` | Missing `TextInputType.phone` on contact phone field forces standard QWERTY keyboard |
| **UX-17** | **Low** | `lib/widgets/document_item_form.dart:487, 504, 518, 553, 572` | Wholesale/Retail pricing tier choice chips undersized below 48x48dp touch target (~24dp height) |
| **UX-18** | **Low** | `lib/screens/pdf_customize_screen.dart:1145-1152` | PDF accent color swatch pickers undersized at 40x40dp touch target |
| **UX-19** | **Low** | `lib/screens/access/user_form_screen.dart:464, 488`, `multi_user_wizard_screen.dart:229, 256`, `customer_statement_dialog.dart:260` | Icon-only password visibility and dialog close buttons lack tooltips and accessibility semantics |
| **UX-20** | **Low** | `lib/screens/inventory_screen.dart:977` | Asymmetric padding `EdgeInsets.fromLTRB(14, 12, 8, 12)` ignores RTL layout direction |
| **UX-21** | **Low** | `lib/screens/home_screen.dart:374-385` | Unread notifications badge counter omitted from screen reader accessibility announcement |
| **UX-22** | **Low** | `lib/screens/contact_form_screen.dart:190-250`, `business_setup_screen.dart:240-300`, `product_form_screen.dart:1365-1420` | Missing `textInputAction: TextInputAction.next` interrupts seamless thumb-driven form flow |
| **UX-23** | **Low** | `lib/widgets/app_metric_card.dart:67-76` | Financial metric KPI values truncate with ellipsis (`1,250,00...`) instead of scale-down |
| **UX-24** | **Low** | `lib/screens/purchase_screen.dart:358`, `lib/screens/invoice_screen.dart:421` | Sticky bottom bar total amount lacks `FittedBox` scale-down protection on narrow screens (< 360dp) |

---

## 2. Detailed Findings

---

### UX-01: Unscrollable PIN Lock Screen Overflows and Blocks Keypad in Landscape and Small Phones

- **Severity:** Critical
- **File:Line:** `lib/screens/access/pin_lock_screen.dart:495-675`
- **What is wrong:**  
  `PinLockScreen` places the user selector badge, lockout countdown banner, direction-safe PIN dots, `const Spacer()`, and `PinKeypad` inside an unscrollable `Column` (`body: SafeArea(child: ResponsiveCenter(child: Padding(child: Column(...))))`). `PinKeypad` requires at least 324dp of vertical height (4 rows of 72dp + 3 gaps of 12dp). When the viewport height is under ~550dp (e.g. landscape orientation on any mobile device, split-screen multitasking, or compact 4-inch to 5-inch budget phones), the `Spacer()` cannot expand, causing an immediate vertical `RenderFlex overflowed by 120-180 pixels on the bottom`. The bottom row of the keypad (digits 0, confirm checkmark button, and backspace) is pushed completely off-screen, locking the user out of the app.
- **Concrete Failing Scenario:**
  1. Business owner configures Multi-User mode with Owner and Cashier PINs.
  2. The device locks (either on app launch or inactivity lock).
  3. The phone is mounted in landscape orientation on a retail counter or rotated sideways (typical viewport height ~360dp to 390dp).
  4. The lock screen appears.
  5. The UI crashes with a red/yellow striped `RenderFlex overflow` error at the bottom.
  6. The digit 0, the confirmation checkmark button, and the backspace button are out of bounds and cannot be tapped.
  7. The cashier cannot enter any PIN containing a zero or confirm their PIN, completely halting sales operations.
- **Suggested Fix:**  
  Wrap the `Column` inside a `LayoutBuilder` and `SingleChildScrollView(physics: const BouncingScrollPhysics())`. In `LayoutBuilder`, calculate whether `constraints.maxHeight >= 580`. Only provide vertical flex space when height is sufficient; on compact or landscape heights, use fixed compact spacing (e.g. `const SizedBox(height: 12)`) so the entire keypad remains fully accessible via gentle scrolling.

---

### UX-02: Editing Contact Prematurely Pops Entire Customer Detail Screen

- **Severity:** High
- **File:Line:** `lib/screens/customer_detail_screen.dart:95-103`
- **What is wrong:**  
  When an existing customer or supplier is edited from `CustomerDetailScreen`, the code calls `_load(); Navigator.pop(context, true);`. This pops `CustomerDetailScreen` entirely, dumping the merchant back to the 500+ customer directory list instead of keeping them on the customer profile with refreshed contact details.
- **Concrete Failing Scenario:**
  1. Merchant opens Customers tab and searches for "شركة النيل للتجارة".
  2. Taps on the customer to open `CustomerDetailScreen` and review transactions and balance.
  3. Merchant taps "تعديل" (Edit) to update the supplier's new phone number or address.
  4. `ContactFormScreen` opens; merchant enters the phone number and taps "حفظ" (Save).
  5. `ContactFormScreen` pops back to `CustomerDetailScreen` with `result == true`.
  6. Line 100 executes: `Navigator.pop(context, true);`.
  7. The `CustomerDetailScreen` disappears instantly, throwing the merchant back to the main customer list.
  8. The merchant has lost their context and must search again for "شركة النيل للتجارة" and tap it again to verify the update or make a phone call.
- **Suggested Fix:**  
  Remove `Navigator.pop(context, true);` from `_editContact()`. Hold the `Contact` object in mutable state (`late Contact _contact`), update it after the edit via `DatabaseHelper.instance.getContactById(widget.contact.id!)`, call `setState(() {})`, and return `true` to the caller only when the merchant taps the app bar back button.

---

### UX-03: `TextEditingController` Disposed Before Reading Text in Custom Payment Method Dialogs

- **Severity:** High
- **File:Line:** `lib/screens/payment_methods_screen.dart:147-151, 222-226`
- **What is wrong:**  
  In both `_addCustom()` and `_editCustom()`, `arCtrl.dispose()` and `enCtrl.dispose()` are called immediately after the dialog awaits (`await showDialog`), and *then* lines 149-150 read `final ar = arCtrl.text.trim(); final en = enCtrl.text.trim();`. Reading `.text` from a disposed `TextEditingController` violates the `ChangeNotifier` contract, triggers `_debugAssertNotDisposed()` assertions in debug/test modes, and risks unstable state in release mode.
- **Concrete Failing Scenario:**
  1. Merchant opens Settings -> Payment Methods.
  2. Taps "إضافة طريقة دفع مخصصة" (Add Custom Method).
  3. Enters Arabic name "بنكك" and English name "Bankak", then taps "حفظ" (Save).
  4. The dialog dismisses with `true`.
  5. The method immediately disposes `arCtrl` and `enCtrl`.
  6. In the very next line, it reads `arCtrl.text.trim()`.
  7. On Flutter debug and profile harnesses, this throws an assertion error (`A TextEditingController was used after being disposed`). In release builds, if garbage collection or platform channel tear-down runs, it risks accessing invalid memory or empty text.
- **Suggested Fix:**  
  Return the `(String ar, String en)` record or map directly from `Navigator.pop(ctx, (ar, en))` inside the dialog actions, or read `arCtrl.text.trim()` *before* calling `.dispose()`, then dispose the controllers inside a `finally` block or let them dispose cleanly.

---

### UX-04: Immediate SnackBar Overwrite Cancels and Destroys Undo Affordance on Bulk Price Updates

- **Severity:** High
- **File:Line:** `lib/screens/bulk_pricing_screen.dart:214-225`
- **What is wrong:**  
  In `_applyChanges()`, when a batch price update succeeds and some items were skipped (e.g. products tied to reference currency rates), the code calls `AppSnackBar.showUndo(...)` and immediately executes `if (result.skippedCount > 0) AppSnackBar.show(l10n.bulkSkippedReference(...))`. Because `AppSnackBar.show` automatically clears any existing visual SnackBars, the informative notice instantly dismisses the Undo SnackBar, permanently depriving the user of the 5-second window to revert the batch update.
- **Concrete Failing Scenario:**
  1. Merchant selects 25 products to apply a +15% price increase.
  2. 3 of those products are locked to US Dollar reference pricing.
  3. Merchant taps "تطبيق التعديلات" (Apply Changes) and confirms.
  4. The batch update completes: 22 products updated, 3 skipped.
  5. `AppSnackBar.showUndo` is invoked with a 5-second countdown timer.
  6. Microseconds later, `if (result.skippedCount > 0)` triggers `AppSnackBar.show`.
  7. The Undo SnackBar vanishes in a flash without the merchant ever being able to see or tap "تراجع" (Undo).
  8. If the merchant made a mistake (+150% instead of +15%), they cannot undo the operation and must manually recalculate and edit all 22 products one by one.
- **Suggested Fix:**  
  Combine the skipped warning directly into the undo notification string (e.g. `${l10n.pricesUpdatedSuccess} · ${l10n.bulkSkippedReference(result.skippedCount)}`), or show the informative snackbar only after the undo window expires (`onActionExpired`).

---

### UX-05: Fixed Height `SizedBox(52)` Causes Vertical `RenderFlex` Overflow Under Accessibility Font Scaling

- **Severity:** High
- **File:Line:** `lib/screens/home_screen.dart:409-445`
- **What is wrong:**  
  On `HomeScreen`, the two primary quick action buttons ("نقطة البيع السريعة" / Quick Sale POS and "فاتورة جديدة" / Create Invoice) are wrapped in a rigid `SizedBox(height: 52, child: Row(...))` with fixed `fontSize: 16`. When elderly or visually impaired users enable standard Android OS Accessibility text scaling (1.3x to 2.0x), the 16pt Arabic text scales up to 21pt-32pt. It wraps to two lines inside the half-width buttons, exceeding the 52dp constraint and triggering a bottom `RenderFlex` overflow.
- **Concrete Failing Scenario:**
  1. User enables 1.4x font size in Android system settings.
  2. Opens Waraqatak home dashboard on a 360dp phone.
  3. The quick action row has 280dp available width (~140dp per button).
  4. "نقطة البيع السريعة" at 22pt cannot fit on one line with the icon and button padding; it wraps to two lines.
  5. Two lines of 22pt text + 24pt icon + vertical padding requires ~72dp height.
  6. `SizedBox(height: 52)` violently clips the content, displaying a yellow-and-black striped overflow bar across the two primary action buttons on the dashboard.
- **Suggested Fix:**  
  Replace `SizedBox(height: 52)` with `ConstrainedBox(constraints: const BoxConstraints(minHeight: 52))`. When `MediaQuery.textScalerOf(context).scale(16) > 18` or screen width < 360dp, stack the two buttons vertically using a `Wrap` or `Column` so text never clips or overflows.

---

### UX-06: "Enter Activation Key" Action Lands on Long Marketing/Pricing Page with Key Input Hidden at Bottom

- **Severity:** High
- **File:Line:** `lib/screens/activation_screen.dart:18-20, 135-220, 690-740`
- **What is wrong:**  
  When a user taps "إدخال مفتاح التفعيل" (Enter Activation Key) on a locked Pro feature or from `LockedFeatureScreen`, the app routes them to `ActivationScreen()`. Instead of immediately presenting an activation key input field, the screen presents a full-page subscription marketing landing page with 4 plan pricing cards in SDG, savings badges, and WhatsApp subscribe buttons. The actual `ActivationKeyInputWidget` is placed at the very bottom under an "Already Have Key?" header, requiring ~1500px of scrolling.
- **Concrete Failing Scenario:**
  1. A merchant purchases a Pro key from a local distributor or online support outside the app.
  2. They open Inventory, see the locked feature banner, and tap the prominent button: "إدخال مفتاح التفعيل" (Enter Activation Key).
  3. They expect a modal dialog or text field to paste the 16-character key.
  4. Instead, they are confronted with a full marketing page showing prices ("باقة السنة: 120,000 ج.س", "اشترك الآن عبر واتساب").
  5. The merchant assumes they were misrouted to a purchase page, does not realize they need to scroll all the way past the 4 pricing cards, and leaves the screen frustrated.
- **Suggested Fix:**  
  Support a boolean argument `ActivationScreen(focusKeyInput: true)`. When `focusKeyInput` is true, either automatically scroll to `ActivationKeyInputWidget` on build, or present `ActivationKeyInputWidget` at the top of the screen (or in a dedicated modal sheet as done on `LicenseScreen`), displaying the marketing plans below it as alternative options.

---

### UX-07: Record Payment Bottom Sheet Lacks In-Flight Submit Lock and Leaks Raw Exception Strings

- **Severity:** High
- **File:Line:** `lib/screens/document_detail_screen.dart:550-605`
- **What is wrong:**  
  In `_showRecordPaymentSheet()`:  
  1. The "تسجيل الدفعة" (Record Payment) `FilledButton` has no `_isSubmitting` guard and does not disable itself or show a spinner while `DocumentService.recordPayment` executes. Double-tapping the button in rapid succession can trigger concurrent payment records.  
  2. In the `catch (e)` block at line 604, the app displays: `AppSnackBar.show(context, '${l10n.operationFailed}: $e', severity: AppSnackBarSeverity.error)`. This leaks raw technical SQLite, database constraint, or Dart exception messages directly to the end user.
- **Concrete Failing Scenario:**
  1. Merchant records a payment on an invoice with a slow SQLite disk write.
  2. Merchant taps "تسجيل الدفعة" twice quickly.
  3. If a period closing lock or constraint triggers an error, the screen displays: `فشلت العملية: SqliteException(1): UNIQUE constraint failed: document_payments.id`.
  4. The merchant sees internal technical database syntax instead of a calm, friendly Arabic message.
- **Suggested Fix:**  
  Introduce local `bool _submitting = false` within the sheet's `StatefulBuilder`. Disable the button and display a 20dp `CircularProgressIndicator` while saving. Route errors through `ErrorUtils.toFriendlyMessage(e, l10n)` instead of raw string concatenation.

---

### UX-08: Misleading Price Error on Currency Validation, Hardcoded English Helper, and Wrong Name Label

- **Severity:** High
- **File:Line:** `lib/screens/exchange_rates_screen.dart:700-730, 836, 842`
- **What is wrong:**  
  In `_AddCurrencySheet`:  
  1. Line 718: When validation fails for the currency code, name, or symbol, the app shows `l10n.refErrInvalidPrice` ("السعر المرجعي يجب أن يكون رقماً موجباً وبما لا يتجاوز 4 خانات عشرية." / "Reference price must be positive with up to 4 decimal places"). The user is scolded about a reference price when they were simply entering a currency code!  
  2. Line 836: `helperText: 'e.g. USD, EUR (2-5 letters)'` is hardcoded English with no localization.  
  3. Line 842: `labelText: l10n.methodLabelAr` ("الاسم بالعربية" / "Arabic Name") reuses a payment method string rather than a currency name string.  
  4. Line 698: `_submit()` has no in-flight debounce/saving guard, allowing duplicate entries on fast double-taps.
- **Concrete Failing Scenario:**
  1. Merchant in Sudan wants to add "QAR" (Qatari Riyal).
  2. Taps "عملة مخصصة" (Custom Currency).
  3. Leaves the currency code as 1 letter ("Q") or leaves symbol blank, then taps "حفظ" (Save).
  4. A red SnackBar appears stating: "السعر المرجعي يجب أن يكون رقماً موجباً وبما لا يتجاوز 4 خانات عشرية."
  5. The merchant checks their rate field, sees it is valid (e.g. 500), and cannot understand why the app claims their price is invalid.
- **Suggested Fix:**  
  Add `l10n.currencyCodeInvalid` ("رمز العملة يجب أن يتكون من 2 إلى 5 أحرف إنجليزية") and `l10n.currencyNameRequired`, display inline `errorText` on the fields, localize the helper text, and use `l10n.currencyName` for the label.

---

### UX-09: Technical Dart Class Name Leaked in Arabic Copy and Unmirrored Back Button in RTL

- **Severity:** Medium
- **File:Line:** `lib/widgets/access/access_denied_view.dart:36-40, 115`
- **What is wrong:**  
  When an employee attempts to open an unauthorized screen, line 38 invokes: `l10n.accessDeniedScreenBody(screenType.toString())`. In Arabic, this produces: `"لا تملك الصلاحية اللازمة لفتح هذه الشاشة (InventoryScreen)"` or `(SalesReportScreen)`. Leaking raw Flutter/Dart code class names looks unprofessional and confuses non-technical users. Additionally, line 115 hardcodes `const Icon(Icons.arrow_back)`, which in RTL points forward/right instead of backwards.
- **Concrete Failing Scenario:**
  1. A cashier taps on the Inventory report.
  2. Access denied view appears.
  3. The body text states: "لا تملك الصلاحية اللازمة لفتح هذه الشاشة (InventoryReportScreen)."
  4. The back button shows an arrow pointing right (into the screen) instead of left (back to safety).
- **Suggested Fix:**  
  Provide a screen title resolver that maps known screen types to localized titles (e.g. `InventoryScreen` -> `l10n.inventory`, `SalesReportScreen` -> `l10n.salesReport`), falling back gracefully to `l10n.accessGenericScreen`. Replace `Icons.arrow_back` with `AppIcons.arrowBack(context)`.

---

### UX-10: Hardcoded `Icons.chevron_right` in Multi-User Screens Points Backward in RTL

- **Severity:** Medium
- **File:Line:** `lib/screens/access/roles_screen.dart:361`, `lib/screens/access/user_form_screen.dart:542`, `lib/screens/access/users_list_screen.dart:586`
- **What is wrong:**  
  In `roles_screen.dart`, `user_form_screen.dart`, and `users_list_screen.dart`, list item trailing drill-in affordances are hardcoded as `const Icon(Icons.chevron_right)`. In Arabic RTL, forward navigation into sub-screens or detail sheets proceeds to the LEFT. A right-pointing chevron points backward toward the start of the layout, violating RTL affordance standards.
- **Concrete Failing Scenario:**
  1. Merchant opens Settings in Arabic locale and enters "المستخدمون والأدوار" (Users & Roles).
  2. Looking down the list of staff members and roles, every row has an arrow pointing to the right edge of the phone (backward), while all other screens in Waraqatak use left-pointing chevrons (`AppIcons.chevronForward`).
- **Suggested Fix:**  
  Replace `const Icon(Icons.chevron_right)` with `AppIcons.chevronForward(context)` across all three files.

---

### UX-11: Missing `PopScope` Unsaved Dirty Changes Warning Guards on Major Forms

- **Severity:** Medium
- **File:Line:** `lib/screens/business_setup_screen.dart:120-220`, `lib/screens/bulk_pricing_screen.dart:45-140`, `lib/screens/pdf_customize_screen.dart:350-450`
- **What is wrong:**  
  Unlike `InvoiceScreen`, `ProductFormScreen`, and `ContactFormScreen` which protect user data via `PopScope`, `BusinessSetupScreen`, `BulkPricingScreen`, and `PdfCustomizeScreen` have no unsaved changes protection. If a user spends several minutes configuring details and accidentally triggers an Android edge-swipe back gesture, the screens pop immediately, discarding all input without confirmation.
- **Concrete Failing Scenario:**
  1. A merchant setting up their store in `BusinessSetupScreen` enters business name, owner name, phone number, address, email, and tax registration number.
  2. While reaching for the logo button, their thumb grazes the phone's curved display edge, triggering the Android back gesture.
  3. The screen instantly closes without a prompt.
  4. All typed text is erased, forcing the user to re-enter everything.
- **Suggested Fix:**  
  Track `_isDirty` on text controller changes, wrap each screen in `PopScope(canPop: !_isDirty || _saving)`, and display `AppConfirmDialog.show` (`unsavedChangesTitle` / `unsavedChangesMessage`) before allowing dismissal.

---

### UX-12: Currency Names Hardcoded to Arabic in Dropdowns and Tiles, Ignoring English Locale

- **Severity:** Medium
- **File:Line:** `lib/screens/business_setup_screen.dart:440`, `lib/screens/exchange_rates_screen.dart:189, 603, 816`
- **What is wrong:**  
  In `business_setup_screen.dart:440`, the currency dropdown item label is hardcoded as `'${currency.nameAr} (${currency.symbol})'`. In `exchange_rates_screen.dart`, edit dialogs and list tiles similarly hardcode `${entry.nameAr}` and `${item.nameAr}`. When the application language is set to English, currency names continue to display in Arabic script instead of using the available `Currency.nameEn` property.
- **Concrete Failing Scenario:**
  1. An English-speaking merchant in Dubai or Nairobi opens Waraqatak with language set to English.
  2. Opens Business Setup or Exchange Rates.
  3. The currency dropdown displays: `الجنيه السوداني (ج.س)`, `الريال السعودي (ر.س)`, `الدولار الأمريكي ($)`.
  4. The user cannot read Arabic and struggles to identify the correct currency.
- **Suggested Fix:**  
  Use `l10n.isArabic ? currency.nameAr : currency.nameEn` (or `entry.name(l10n.langCode)`).

---

### UX-13: Raw Loading, Empty, and Error State Widgets Bypass Standardized Component Suite Across 5 Reports

- **Severity:** Medium
- **File:Line:** `lib/screens/reports/customer_report_screen.dart:185-215`, `supplier_report_screen.dart:185-215`, `payments_report_screen.dart:190-220`, `product_report_screen.dart:455-485`, `advanced_inventory_analytics_screen.dart:240-270`
- **What is wrong:**  
  While `SalesReportScreen` and `PurchasesReportScreen` properly use `AppLoadingView`, `AppEmptyState`, and `AppErrorState`, the remaining 5 report screens still use copy-pasted raw widgets: bare unstyled `Center(child: CircularProgressIndicator())`, unstyled `Center(child: Column(children: [Text(l10n.operationFailed), FilledButton.tonal(...)]))`, and custom empty columns. This creates inconsistent typography, missing retry styling, and lack of accessible loading status across financial reporting.
- **Concrete Failing Scenario:**
  1. Merchant opens Customer Report with poor or heavy SQLite load.
  2. A plain spinner appears with no explanatory message.
  3. If no invoices exist in the date range, an unstyled empty state with unformatted text appears.
  4. Switching to Sales Report shows a polished, branded `AppEmptyState` with an actionable icon and card styling.
  5. The visual discord diminishes the professional feel of the app.
- **Suggested Fix:**  
  Replace the raw widgets with `AppLoadingView(message: l10n.loadingReport)`, `AppEmptyState(icon: ..., title: ...)`, and `AppErrorState(error: _error, onRetry: _load)` across all 5 report screens.

---

### UX-14: Redundant Duplicate Confirmation Dialogs in Destructive and Sensitive Operations

- **Severity:** Medium
- **File:Line:** `lib/screens/settings_screen.dart:245-265`, `google_drive_backup_screen.dart:325-355`, `period_closing_screen.dart:65-95`
- **What is wrong:**  
  When initiating sensitive operations (such as restoring a backup or clearing a period lock), the code displays `AppConfirmDialog.show` with the warning message. As soon as the user taps "تأكيد" (Confirm), the code immediately invokes `SensitiveActionGate.reauthenticate`, which presents a *second* full-screen dialog containing the *exact same* title and warning message along with the PIN/password prompt.
- **Concrete Failing Scenario:**
  1. Merchant taps "استعادة نسخة احتياطية" (Restore Backup) in Settings.
  2. Dialog 1 pops up: "تأكيد الاستعادة: سيتم استبدال جميع البيانات الحالية بالبيانات المستعادة... هل تريد المتابعة؟"
  3. Merchant taps "استعادة".
  4. Instantly, Dialog 2 pops up with the identical title and warning text: "تأكيد الاستعادة: سيتم استبدال جميع البيانات الحالية بالبيانات المستعادة...", this time with a password field.
  5. The merchant wonders if the app glitched or asked them twice because of an error.
- **Suggested Fix:**  
  Rely on `SensitiveActionGate.reauthenticate` as the sole confirmation barrier when authentication is required, removing the preceding redundant `AppConfirmDialog.show`.

---

### UX-15: Cancellation Dialog for Unpaid Documents Lacks Explanation of Inventory Return and Accounting Reversal

- **Severity:** Medium
- **File:Line:** `lib/screens/document_detail_screen.dart:260-282`
- **What is wrong:**  
  While paid documents trigger `CancelPaidDocumentDialog` (which explains refunds and voucher rules), cancelling an unpaid invoice or purchase bill opens a generic dialog with `cancelDocumentMessage`: `"هل تريد إلغاء هذا المستند؟ لا يمكن التراجع عن هذا الإجراء."` ("Cancel this document? This cannot be undone."). It fails to explain that for sales invoices, inventory will be returned to stock and Cost of Goods Sold / Revenue journal entries will be reversed.
- **Concrete Failing Scenario:**
  1. Cashier is asked by a customer to cancel an unpaid issued invoice for 5 cartons of milk.
  2. Cashier taps "إلغاء المستند".
  3. The dialog says only: "Cancel this document? This cannot be undone."
  4. The cashier hesitates: Will canceling return the 5 cartons to the stock count in Waraqatak, or does the cashier need to make a manual inventory adjustment?
  5. Lacking clarity, the cashier cancels the document AND performs a manual stock adjustment, inadvertently doubling the inventory count!
- **Suggested Fix:**  
  Enhance the cancellation dialog content to state explicitly:  
  - For sales invoices: `l10n.cancelInvoiceInventoryNotice` ("سيتم إعادة الأصناف تلقائياً إلى المخزون وعكس القيود المحاسبية.").  
  - For purchase bills: `l10n.cancelPurchaseInventoryNotice` ("سيتم خصم الأصناف من المخزون وعكس حساب المورد.").

---

### UX-16: Missing `TextInputType.phone` on Contact Phone Field Forces Standard QWERTY Keyboard

- **Severity:** Medium
- **File:Line:** `lib/screens/edit_document_screen.dart:689`
- **What is wrong:**  
  In `EditDocumentScreen`, the phone input field `_phoneController` has no `keyboardType` attribute (unlike `ContactFormScreen` and `BusinessSetupScreen` which correctly set `TextInputType.phone`). When editing recipient contact details on a document, tapping the phone field displays the full alphabetical QWERTY keyboard.
- **Concrete Failing Scenario:**
  1. User edits an invoice and needs to add or update the client's phone number.
  2. Taps into the Phone field.
  3. The keyboard pops up showing Arabic/English letters instead of a numeric phone keypad.
  4. User has to tap `?123` or mode-switch on the keyboard, increasing friction and chance of typos.
- **Suggested Fix:**  
  Add `keyboardType: TextInputType.phone` to `TextFormField` at line 689 of `edit_document_screen.dart`.

---

### UX-17: Wholesale/Retail Pricing Tier Choice Chips Undersized Below 48x48dp Touch Target (~24dp Height)

- **Severity:** Low
- **File:Line:** `lib/widgets/document_item_form.dart:487, 504, 518, 553, 572`
- **What is wrong:**  
  In document item lines, the `ChoiceChip` widgets for toggling price tiers ("قطاعي" / Retail vs "جملة" / Wholesale) and selecting sales units apply `visualDensity: VisualDensity.compact` and `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` with `fontSize: 11`. This reduces the touch height to ~24-28dp, far below the standard 48x48dp touch target prescribed by Material 3 and accessibility specifications.
- **Concrete Failing Scenario:**
  1. Cashier on a 6-inch phone wants to change an item line from Retail to Wholesale tier during checkout.
  2. The chip is only 26dp tall and packed tightly above the unit dropdown.
  3. Cashier taps with their thumb; the touch registers slightly low and opens the unit dropdown instead of switching the price tier.
  4. Cashier must dismiss the dropdown and attempt a precise, frustrating tap.
- **Suggested Fix:**  
  Remove `MaterialTapTargetSize.shrinkWrap` and `VisualDensity.compact` from interactive `ChoiceChip`s, or wrap them in a container that guarantees at least 44-48dp vertical hit test area.

---

### UX-18: PDF Accent Color Swatch Pickers Undersized at 40x40dp Touch Target

- **Severity:** Low
- **File:Line:** `lib/screens/pdf_customize_screen.dart:1145-1152`
- **What is wrong:**  
  In the PDF template customization screen, the theme color swatch circles are sized at `width: 40, height: 40` wrapped directly inside an `InkWell`. This falls below the minimum 48x48dp touch target size.
- **Concrete Failing Scenario:**
  1. User customizes their invoice PDF theme.
  2. A row of small 40x40dp colored circles is displayed.
  3. Users with larger fingers or motor tremor tap between swatches and frequently activate the adjacent color.
- **Suggested Fix:**  
  Increase the interactive touch area to 48x48dp using outer padding or `ConstrainedBox`, keeping the inner visual circle at 40x40dp.

---

### UX-19: Icon-Only Password Visibility and Dialog Close Buttons Lack Tooltips and Accessibility Semantics

- **Severity:** Low
- **File:Line:** `lib/screens/access/user_form_screen.dart:464, 488`, `multi_user_wizard_screen.dart:229, 256`, `recovery_screen.dart:295, 318`, `customer_statement_dialog.dart:260`, `backup_password_dialog.dart:192, 217, 461`
- **What is wrong:**  
  Password obscure/reveal toggles (`IconButton(icon: Icon(_obscure ? ...))`) and the customer statement dialog close button (`IconButton(icon: Icon(Icons.close))`) have neither `tooltip` nor `semanticLabel`.
- **Concrete Failing Scenario:**
  1. A visually impaired merchant uses Android TalkBack to manage staff users or view a customer statement.
  2. The TalkBack focus lands on the password visibility toggle.
  3. TalkBack reads: "Button, unlabelled. Double tap to activate."
  4. The user has no way of knowing what the button does or whether the password is currently hidden or revealed.
- **Suggested Fix:**  
  Add `tooltip: _obscure ? l10n.showPassword : l10n.hidePassword` to password toggles and `tooltip: l10n.close` to close buttons.

---

### UX-20: Asymmetric Padding `EdgeInsets.fromLTRB(14, 12, 8, 12)` Ignores RTL Layout Direction

- **Severity:** Low
- **File:Line:** `lib/screens/inventory_screen.dart:977`
- **What is wrong:**  
  In `inventory_screen.dart`, stock item cards use `padding: const EdgeInsets.fromLTRB(14, 12, 8, 12)`. In RTL mode, 14dp is applied to the left (trailing edge) and 8dp to the right (leading edge), reversing the intentional asymmetry where leading content has more breathing room than trailing action icons.
- **Concrete Failing Scenario:**
  1. In Arabic locale, the product name and stock count on inventory cards have only 8dp padding from the right border, while the trailing status chips have 14dp padding from the left border, looking unbalanced.
- **Suggested Fix:**  
  Replace with `EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12)`.

---

### UX-21: Unread Notifications Badge Counter Omitted from Screen Reader Accessibility Announcement

- **Severity:** Low
- **File:Line:** `lib/screens/home_screen.dart:374-385`
- **What is wrong:**  
  On `HomeScreen`, the notification action button wraps `Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notifications_outlined))` inside an `IconButton(tooltip: l10n.inboxTitle)`. Flutter's `Badge` does not automatically append the counter to the `IconButton` tooltip semantics.
- **Concrete Failing Scenario:**
  1. A blind merchant navigates the Home appbar using TalkBack.
  2. TalkBack announces: "صندوق الإشعارات، زر" (Notifications Inbox, button).
  3. It fails to announce that there are 3 unread critical notifications (e.g. low stock alerts or license expiration).
- **Suggested Fix:**  
  Provide a dynamic tooltip/semantics label: `tooltip: unread > 0 ? '${l10n.inboxTitle} (${l10n.unreadCount(unread)})' : l10n.inboxTitle`.

---

### UX-22: Missing `TextInputAction.next` Interrupts Seamless Thumb-Driven Form Flow

- **Severity:** Low
- **File:Line:** `lib/screens/contact_form_screen.dart:190-250`, `business_setup_screen.dart:240-300`, `product_form_screen.dart:1365-1420`
- **What is wrong:**  
  None of the standard form fields in `ContactFormScreen`, `BusinessSetupScreen`, or `ProductFormScreen` set `textInputAction: TextInputAction.next`. The soft keyboard defaults to showing "Done" or a newline return key instead of "Next", breaking single-thumb navigation from field to field.
- **Concrete Failing Scenario:**
  1. Merchant adds a customer, types the Name, and reaches down with their right thumb to hit the keyboard action key to jump to Phone.
  2. The keyboard action key says "Done" and closes the soft keyboard.
  3. The merchant has to tap the next field manually, wait for the keyboard to slide up again, and type, adding friction across every field.
- **Suggested Fix:**  
  Add `textInputAction: TextInputAction.next` to all intermediate form fields and `TextInputAction.done` on the final field.

---

### UX-23: Financial Metric KPI Values Truncate with Ellipsis (`1,250,00...`) Instead of Scale-Down

- **Severity:** Low
- **File:Line:** `lib/widgets/app_metric_card.dart:67-76`
- **What is wrong:**  
  `AppMetricCard` displays metric numbers with `maxLines: 1, overflow: TextOverflow.ellipsis`. When numbers are large (e.g. Sudanese Pound sales in the tens or hundreds of millions: `250,000,000 ج.س`), the value truncates into `250,00...`. In a financial app, truncating digits obscures the magnitude of the business's revenue and debt.
- **Concrete Failing Scenario:**
  1. A wholesaler with 150,000,000 SDG in monthly revenue opens the dashboard.
  2. The KPI card displays: `150,00...`.
  3. The owner cannot tell at a glance whether today's revenue was 150 thousand or 150 million without clicking into the report.
- **Suggested Fix:**  
  Wrap the value text in `FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart)` so large figures dynamically scale down their font size rather than cutting off significant digits.

---

### UX-24: Sticky Bottom Bar Total Amount Lacks `FittedBox` Scale-Down Protection on Narrow Screens (< 360dp)

- **Severity:** Low
- **File:Line:** `lib/screens/purchase_screen.dart:358`, `lib/screens/invoice_screen.dart:421`
- **What is wrong:**  
  In `quotation_screen.dart:350`, `AppAmountText` was wrapped in `FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart)` to prevent text overflow on narrow devices. However, this fix was omitted from `invoice_screen.dart` and `purchase_screen.dart`, where `AppAmountText` sits unwrapped in the bottom navigation bar row beside "حفظ كمسودة" and "حفظ الفاتورة".
- **Concrete Failing Scenario:**
  1. User on a narrow device (< 360dp width) creates an invoice with a total over 10,000,000 SDG.
  2. The large amount text pushes against the two action buttons, causing horizontal text clipping or a minor flex overflow.
- **Suggested Fix:**  
  Wrap `AppAmountText` in `FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart)` in both `invoice_screen.dart` and `purchase_screen.dart`.

---

## 3. Top 10 Fixes in Recommended Order

| Priority | ID | Title | Effort Estimate | Impact Summary |
|---|---|---|---|---|
| **1** | **UX-01** | Make `PinLockScreen` scrollable with `SingleChildScrollView` | **S** (< 1 hour) | Prevents fatal lock-out / RenderFlex crash in landscape and on budget smartphones. |
| **2** | **UX-02** | Prevent premature pop in `CustomerDetailScreen._editContact` | **S** (< 30 min) | Eliminates disorienting screen dismissal when saving contact edits. |
| **3** | **UX-03** | Fix controller dispose timing in `PaymentMethodsScreen` | **S** (< 30 min) | Resolves `ChangeNotifier` memory lifecycle assertion failure in custom payment methods. |
| **4** | **UX-04** | Prevent immediate snackbar overwrite in `BulkPricingScreen` | **S** (< 30 min) | Restores critical 5-second Undo capability after batch product price updates. |
| **5** | **UX-05** | Make quick action buttons flexible in `HomeScreen` | **S** (< 45 min) | Fixes 100% reproducible RenderFlex overflow for users with accessibility text scaling. |
| **6** | **UX-06** | Add direct focus/route to `ActivationKeyInputWidget` | **M** (1-2 hours) | Eliminates user confusion when entering pre-purchased Pro activation keys. |
| **7** | **UX-07** | Add in-flight submit lock & friendly error in record payment sheet | **S** (< 45 min) | Prevents duplicate payments and hides raw database syntax errors from users. |
| **8** | **UX-08** | Correct error message & labels in Custom Currency sheet | **S** (< 45 min) | Eliminates misleading "invalid reference price" error when validating currency code/name. |
| **9** | **UX-09** | Localize screen titles & mirror back arrow in `AccessDeniedView` | **S** (< 45 min) | Replaces raw Dart class names with Arabic titles and fixes RTL navigation arrow. |
| **10** | **UX-11** | Add `PopScope` unsaved dirty changes guards to setup & pricing | **M** (1-2 hours) | Protects users from accidental data loss on back swipe across configuration flows. |

*Effort Scale: **S** = Small (< 1 hour), **M** = Medium (1–3 hours), **L** = Large (> 3 hours).*

---

## 4. "Looks Correct" — Verified and Found Sound

During this exhaustive audit, numerous areas of Waraqatak were rigorously verified and found to exhibit exceptional engineering quality, adherence to hard invariants, and thoughtful UX polish:

1. **Hard Invariants Preservation:**
   - Single stock movement writer invariant (INV-16) is strictly maintained across all sales, purchases, and adjustments; stock mutations consistently route through `StockLedger`.
   - Double-entry balance invariance (INV-14) is enforced; all persisted journal drafts balance to the minor unit.
   - Authoritative stock check resides strictly in `DatabaseHelper._assertSaleStockAvailable`.

2. **Invoice & Document Line Item State Persistence:**
   - Quotation, Invoice, and Purchase screens properly utilize `AutomaticKeepAliveClientMixin` on `ContactAutocompleteField` and `ProductAutocompleteField`, ensuring unlisted custom product names and recipient details are not wiped when scrolled offscreen.
   - Stable `ObjectKey`s on item forms prevent state corruption when removing or reordering line items.
   - Delete confirmation dialogs (`AppConfirmDialog`) protect against accidental line item deletion when line content exists.

3. **POS / Quick Sale Register Ergonomics:**
   - Ephemeral cart state (`PosCart`) and sticky bottom portrait cart bar provide instantaneous price calculations.
   - Dynamic grid tile height calculation via `MediaQuery.textScalerOf(context)` prevents product tile text clipping at large accessibility font scales.
   - `_QtyStepper` touch targets are generously sized at `>= 48dp`.
   - Post-sale receipt modal allows printing or sharing while keeping the transaction open, followed by a clean one-tap "بيعة جديدة" (New Sale) reset.

4. **Monetary Formatting & RTL Directionality (`AppAmountText`):**
   - The central `AppAmountText` widget enforces strict LTR numeric formatting with `FontFeature.tabularFigures()`, preventing numeral transposition while keeping Arabic currency symbols properly aligned.
   - Encapsulated `Semantics` container ensures screen readers announce the full currency and amount as a cohesive phrase.

5. **Accessibility Design Tokens & Button Baseline:**
   - `AppDesignTokens` enforces WCAG AA compliant contrast ratios across primary, neutral, error, warning, and success color schemes.
   - `ThemeData` globally configures `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, and `IconButton` with standard `AppDesignTokens.minTouchTarget` (48x48dp).

6. **List Pagination & Memory Efficiency:**
   - All high-volume list screens (`ProductsScreen`, `DocumentsScreen`, `CustomersScreen`, `StockMovementsScreen`, `AuditHistoryScreen`, `AuditTrailScreen`) implement strict limit-offset pagination, avoiding heavy synchronous SQLite memory spikes on large databases.

7. **Google Play Billing Compliance:**
   - Pro feature gating copy across `LockedFeatureScreen` and `ProUpgradeSheet` strictly complies with Play Store consumption-only policies: zero in-app purchase links, zero checkout buttons, and zero misleading pricing claims on gating barriers.

---

## 5. Top UX Issues Most Likely to Cause User Friction, Erroneous Entries, or Data Loss

1. **Complete App Lockout in Landscape Multitasking (UX-01):**
   - The unscrollable `PinLockScreen` column overflow prevents retail cashiers from entering PINs when their tablet or terminal is docked in landscape orientation.
2. **Data Loss / Screen Dismissal Friction (UX-02 & UX-11):**
   - The abrupt popping of `CustomerDetailScreen` upon saving contact edits forces merchants to repeatedly search and navigate back to customer profiles.
   - The absence of `PopScope` on `BusinessSetupScreen` risks complete loss of extensive business and tax configuration upon an accidental swipe.
3. **Accidental Duplicate Transactions (UX-07 & UX-08):**
   - Lack of submit debouncing on the invoice payment sheet and custom currency sheet allows double-tapping to trigger duplicate records before the async route transition finishes.
4. **Permanent Loss of Reversibility (UX-04):**
   - In Bulk Pricing, showing an immediate informative notice cancels the Undo snackbar. A merchant who made a catastrophic percentage pricing mistake on dozens of products loses the one-tap undo safety net.

# Waraqatak UX/UI Comprehensive Audit Report

**Date:** October 31, 2026  
**Target Branch:** `ux/ui-polish`  
**Application:** Waraqatak (ورقتك) — Offline-first Flutter Business & Invoicing App (Arabic-first RTL)  
**Scope:** UI/UX & Design System Polish across all screens without modifying business logic, database schema, or costing/pricing algorithms.

---

## A. Screen & Major Widget Inventory

The Waraqatak codebase contains 50 distinct screens and a collection of shared widgets in `lib/`:

| Module / Domain | Screen / Major Widget File | Description & Key UI Roles |
|---|---|---|
| **Shell & Dashboard** | `lib/screens/main_shell.dart` | Root shell with adaptive navigation (BottomNavigationBar on phone, NavigationRail on tablet/landscape). |
| | `lib/screens/home_screen.dart` | Main dashboard displaying metrics (today's sales, invoices, outstanding), date range filter, quick action shortcuts, recent documents list. |
| | `lib/screens/splash_screen.dart` | Startup branding screen with logo, app title, and entitlement cache pre-warming. |
| **Sales & Documents** | `lib/screens/invoice_screen.dart` | Form to create sales invoices with customer autocomplete, dynamic items, wholesale/retail pricing tiers, sales units, tax calculation, discount, payments, and totals. |
| | `lib/screens/documents_screen.dart` | Searchable, filterable list of all documents (invoices, quotations, receipts, vouchers) with status badges and action menus. |
| | `lib/screens/document_detail_screen.dart` | Document view with line items, tax breakdown, payment records, PDF generation, print/share actions, and cancellation flow. |
| | `lib/screens/edit_document_screen.dart` | Modification flow for draft or editable documents. |
| | `lib/screens/quotation_screen.dart` | Quotation/estimate builder with conversion to invoice. |
| | `lib/screens/purchase_screen.dart` | Purchase bill builder with supplier autocomplete, line items, and payment recording. |
| | `lib/screens/custom_document_screen.dart` | Creation flow for customized document types. |
| | `lib/widgets/document_item_form.dart` | Reusable form card for document line items (product lookup, barcode scan, quantity, price, unit selection, tier selection, tax toggle). |
| **POS / Quick Sale** | `lib/screens/quick_sale_screen.dart` | High-speed POS register for retail: product grid, barcode lookup, quick cart, payment method selector, receipt printing modal. |
| | `lib/services/pos_cart.dart` | Ephemeral cart state for POS register. |
| **Products & Inventory**| `lib/screens/products_screen.dart` | Searchable product catalog with category chips, type filters (products vs services), stock badges, and action menus. |
| | `lib/screens/product_form_screen.dart` | Add/edit product and service form with pricing, wholesale tiers, units conversion, barcode scanning, min stock, and tax profile assignment. |
| | `lib/screens/bulk_pricing_screen.dart` | Batch price editing interface for multiple products. |
| | `lib/screens/inventory_screen.dart` | Stock level tracking and stock adjustment interface. |
| | `lib/screens/stock_movements_screen.dart` | Chronological audit log of inventory movements (sales, purchases, adjustments, opening stock) with summary totals. |
| | `lib/screens/stocktake/stocktake_screen.dart` | Physical inventory count counting flow with barcode verification and variance tracking. |
| | `lib/screens/stocktake/stocktake_history_screen.dart` | History of finalized stocktake sessions. |
| **Contacts** | `lib/screens/customers_screen.dart` | Directory of customers and suppliers with search, filtering, and balance overview. |
| | `lib/screens/contact_form_screen.dart` | Add/edit customer or supplier form with pricing category selection. |
| | `lib/screens/customer_detail_screen.dart` | Profile view with contact details, financial summary (invoiced, paid, remaining balance), statement generator, and transaction history. |
| **Vouchers & Payments**| `lib/screens/voucher_screen.dart` | Form for creating payment receipts (قبض) and expense vouchers (صرف). |
| | `lib/screens/payment_methods_screen.dart` | Configuration of enabled payment methods (cash, card, bank transfer, mobile money). |
| **Reports & Financials**| `lib/screens/reports_screen.dart` | Hub for all operational and financial reports. |
| | `lib/screens/reports/sales_report_screen.dart` | Sales volume, revenue, profitability, and multi-currency sales analysis. |
| | `lib/screens/reports/purchases_report_screen.dart` | Purchase volume, expenditure, and supplier payments breakdown. |
| | `lib/screens/reports/customer_report_screen.dart` | Customer sales rankings, balances, and statement summaries. |
| | `lib/screens/reports/supplier_report_screen.dart` | Supplier purchase rankings and outstanding liabilities. |
| | `lib/screens/reports/product_report_screen.dart` | Product sales performance, turnover, and gross profit margins. |
| | `lib/screens/reports/inventory_report_screen.dart` | Stock valuations at average cost, low-stock warnings, and shortage reports. |
| | `lib/screens/reports/payments_report_screen.dart` | Cash inflows and outflows breakdown by payment method and currency. |
| | `lib/screens/reports/accounting_screen.dart` | Double-entry ledger reports: Income Statement (الأرباح والخسائر), Balance Sheet (الميزانية العمومية), Trial Balance (ميزان المراجعة), and Chart of Accounts. |
| | `lib/screens/reports/advanced_inventory_analytics_screen.dart` | Stock velocity, runway days, and automated reorder recommendations. |
| | `lib/screens/reports/report_date_filter.dart` | Unified date period filter bar for report screens. |
| **Settings & Utility** | `lib/screens/settings_screen.dart` | Root settings view with business, appearance, data, and system navigation. |
| | `lib/screens/business_setup_screen.dart` | Company identity, logo, address, contact numbers, base currency selection and currency locking. |
| | `lib/screens/financial_settings_screen.dart` | Tax enablement, prices include tax toggle, default tax profile, invoice footer, and wholesale toggle. |
| | `lib/screens/tax_profiles_screen.dart` | Management of multiple VAT/tax percentage profiles. |
| | `lib/screens/pdf_customize_screen.dart` | Document customization (paper size, font size, primary color, QR code display, business logo visibility). |
| | `lib/screens/google_drive_backup_screen.dart`| Cloud backup interface for Google Drive sync, upload, listing, and restore. |
| | `lib/screens/database_diagnostic_screen.dart`| Database integrity scanner, orphaned records detector, schema inspection, and automated repair tools. |
| | `lib/screens/audit_history_screen.dart` | System operational audit history log viewer. |
| | `lib/screens/csv_import_export_screen.dart` | CSV import and export for products, customers, and invoices. |
| | `lib/screens/barcode_scanner_screen.dart`| Fullscreen camera scanner with camera overlay and manual code entry. |
| | `lib/screens/about_screen.dart` | App version, legal documentation links, support contacts, and technical credits. |
| | `lib/screens/activation_screen.dart` | Offline/online Pro key activation screen. |
| | `lib/screens/license_screen.dart` | Entitlement status screen showing active license/trial details. |
| | `lib/screens/locked_feature_screen.dart` | Feature gate fallback screen for non-Pro users. |
| | `lib/screens/notifications_inbox_screen.dart`| In-app notification center for alerts and updates. |
| | `lib/screens/transparency_screen.dart` | Offline architecture and zero-tracking privacy guarantee. |
| **Shared UI Widgets** | `lib/widgets/app_design_tokens.dart` | Central design tokens for spacing, radii, elevations, and semantic colors. |
| | `lib/widgets/app_empty_state.dart` | Empty state placeholder with icon, title, description, and primary action. |
| | `lib/widgets/app_metric_card.dart` | Dashboard metric card for financial KPIs. |
| | `lib/widgets/app_search_bar.dart` | Standardized search input with debouncing and clear action. |
| | `lib/widgets/app_section_header.dart`| Section header with title, badge count, and optional action button. |
| | `lib/widgets/app_totals_card.dart` | Reusable financial summary card (subtotal, discount, tax, total, paid, balance). |
| | `lib/widgets/contact_autocomplete_field.dart`| Autocomplete selector for customers and suppliers. |
| | `lib/widgets/product_autocomplete_field.dart`| Autocomplete selector for products. |
| | `lib/widgets/status_badge.dart` | Status chip for document states (draft, issued, paid, cancelled, etc.). |
| | `lib/widgets/pro_upgrade_sheet.dart` | Bottom sheet explaining Pro capabilities when encountering gated features. |
| | `lib/widgets/responsive.dart` | Responsive layout constraints and navigation breakpoints. |

---

## B. Design System Status

### 1. Theme Definition & Component Coverage
- **Theme Location:** Defined in `lib/theme.dart` (`AppTheme.lightTheme` and `AppTheme.darkTheme`) using `ThemeData(useMaterial3: true)`. Design tokens exist in `lib/widgets/app_design_tokens.dart`.
- **Strengths:** Consistent primary teal brand palette (`Color(0xFF155E63)`), `Tajawal` font family, rounded cards (14dp), clean floating `SnackBarThemeData`.
- **Gaps:**
  - Component themes are missing explicit defaults for `TextButtonThemeData`, `PopupMenuThemeData`, `ProgressIndicatorThemeData`, `DataTableThemeData`, `DividerThemeData` (only partial), `SwitchThemeData`, `TabBarThemeData`.
  - Component themes for buttons set `minimumSize: const Size(64, 44)` instead of the accessibility-compliant minimum of 48dp height.
  - Dark mode surfaces and outlines (`darkSurface = Color(0xFF17211F)`, `darkBorder = Color(0xFF2A3634)`) lack tokenized elevation layers (`surfaceContainer`, `surfaceContainerHigh`), resulting in high visual contrast jumps when screens use ad-hoc background colors.

### 2. Hardcoded Values Scattered Across Screens
- **Hardcoded Colors:** **390+ instances** of hardcoded colors across `lib/screens/`. Examples:
  - `Colors.green`, `Colors.green.shade600`, `Colors.green.shade700` used directly for "paid", "in-stock", "total in", or positive values instead of `AppDesignTokens.success` or `colorScheme`.
  - `Colors.red`, `Colors.red.shade600`, `Colors.red.shade700`, `Colors.red.shade300` used for "cancelled", "overdue", "out of stock", or error icons.
  - `Colors.grey`, `Colors.grey.shade400`, `Colors.grey.shade500`, `Colors.grey.shade700` used for subtitles and borders. In dark mode, `Colors.grey.shade700` on a dark card is virtually illegible (fails WCAG AA 4.5:1).
  - Brand hex literals like `Color(0xFF155E63)` or `Color(0xFF25D366)` hardcoded inside widgets instead of accessing `theme.colorScheme`.
- **Hardcoded Border Radii:** Repeated inline instantiation of `BorderRadius.circular(12)` on almost every `OutlineInputBorder` in forms (`product_form_screen.dart`, `contact_form_screen.dart`, `document_item_form.dart`) instead of inheriting from `inputDecorationTheme`.
- **Hardcoded Spacers & Padding:** Inconsistent margin and padding values (e.g. `const EdgeInsets.all(10)`, `const EdgeInsets.fromLTRB(12, 4, 12, 100)`, `const EdgeInsets.only(bottom: 8)`) bypassing the 4/8/12/16/24/32 spacing scale.

### 3. Duplicated UI Components Needing Consolidation
- **Error States:** At least 6 screens (`products_screen.dart`, `stock_movements_screen.dart`, `customer_detail_screen.dart`, `accounting_screen.dart`, `home_screen.dart`, `google_drive_backup_screen.dart`) create their own inline `Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline), Text(...), FilledButton(...)])`. A unified `AppErrorState` widget is needed.
- **Empty States:** Several screens use the shared `AppEmptyState`, but others (`stock_movements_screen.dart`, `home_screen.dart` initial business setup, `quick_sale_screen.dart`) construct ad-hoc empty placeholders with hardcoded grey text and icons.
- **Destructive Confirmation Dialogs:** Every screen that deletes or restores data (`settings_screen.dart`, `google_drive_backup_screen.dart`, `business_setup_screen.dart`, `products_screen.dart`, `document_detail_screen.dart`) constructs a separate `showDialog` with varying button orders, colors, and phrasing. A unified `AppConfirmDialog` with destructive styling is required.
- **Status Badges:** `StatusBadge` only supports document statuses. Products, inventory movements, and backup screens reinvent inline chip styling for active/inactive, in-stock/out-of-stock, and debit/credit.

---

## C. RTL and Localization Issues

### 1. Hardcoded Left/Right Directionality
While most of the app uses symmetric padding, several screens have directional layout violations:
- `lib/screens/reports/payments_report_screen.dart:182`: `alignment: Alignment.centerRight` hardcodes Western right alignment for amounts, failing RTL alignment.
- `lib/screens/reports/report_date_filter.dart:31`: `padding: const EdgeInsets.only(right: 6)` does not mirror in RTL (causes incorrect spacing between the calendar icon and date label in Arabic).
- `lib/screens/barcode_scanner_screen.dart:76-77`: `Positioned(left: 0, right: 0, bottom: 40)` should use `PositionedDirectional` or symmetric constraints.
- `lib/screens/notifications_inbox_screen.dart:81-82`: `Positioned(left: 20, right: 20)` should use directional positioning.

### 2. Icon Mirroring
- **Unmirrored Navigation Icons:**
  - `lib/screens/barcode_scanner_screen.dart:130`: `icon: const Icon(Icons.arrow_back)` does not mirror in RTL. On an Arabic device, a back button pointing left points to "forward".
  - `lib/screens/notifications_inbox_screen.dart:122`: `icon: const Icon(Icons.arrow_forward)` used as back/navigation without RTL check.
  - `lib/screens/notifications_inbox_screen.dart:365`: `trailing: const Icon(Icons.chevron_left)` hardcoded chevron.
- **Duplicated Directional Ternary Checks:**
  In over 10 locations (`about_screen.dart`, `business_setup_screen.dart`, `customer_detail_screen.dart`, `document_detail_screen.dart`, `home_screen.dart`, `reports_screen.dart`, `settings_screen.dart`, `stocktake_screen.dart`, `database_diagnostic_screen.dart`), developers wrote:
  `l10n.isArabic ? Icons.chevron_left : Icons.chevron_right`
  This should be centralized into a reusable helper or icon widget (`AppIcons.chevronForward(context)`).

### 3. Numbers, Currency, and Dates
- **Number & Currency Formatting Inconsistency:**
  - Some screens use `FormatUtils.formatCurrency(amount, currencySymbol)`.
  - Other screens (`customer_detail_screen.dart:745`, `document_item_form.dart:589`, `quick_sale_screen.dart:51`) construct ad-hoc `NumberFormat('#,##0.00')` or raw string interpolation `'${total.toStringAsFixed(2)} $currency'`.
  - In Arabic RTL, concatenating currency symbols manually without directional markers causes numbers and Latin currency codes (e.g., "SDG", "USD") to flip unexpectedly.
- **Date Formatting:** Multiple formats coexist without user preference: `dd/MM/yyyy`, `dd/MM/yy`, `yyyy-MM-dd`.

### 4. Text Overflow & Truncation Risks
- Long Arabic names (e.g., compound business or customer names like "شركة النور للمقاولات العامة والتجارة المحدودة") overflow in:
  - `document_detail_screen.dart` header cards.
  - `quick_sale_screen.dart` product tiles (fixed 112dp height grid tile clips names longer than 2 lines).
  - `reports/accounting_screen.dart` Trial Balance rows where fixed 44dp + 96dp + 96dp leaves minimal room for account titles.

---

## D. Accessibility Issues

### 1. Touch Targets Below 48x48dp
- `document_item_form.dart:597`: `IconButton(icon: Icon(Icons.delete_outline), visualDensity: VisualDensity.compact)` produces a touch target around ~36x36dp.
- `document_item_form.dart:355`: Clear product `InkWell` has `padding: EdgeInsets.all(4)` with `Icon(Icons.close, size: 16)`, resulting in a 24x24dp touch target.
- `quick_sale_screen.dart:366`: Search bar clear button with compact density.
- `products_screen.dart` & `stock_movements_screen.dart`: Horizontal filter chips with `visualDensity: VisualDensity.compact` and `MaterialTapTargetSize.shrinkWrap` reduce heights below 32dp.

### 2. Contrast & Color-Only Information
- **Low Contrast in Dark Theme:**
  - Hardcoded `Colors.grey.shade700` used for inactive badges and secondary text provides insufficient contrast against dark card surfaces (`Color(0xFF17211F)`).
  - Hardcoded `Colors.black54` overlays in barcode scanner.
- **Color-Only Status Indicators:**
  - In `stock_movements_screen.dart` and `reports/payments_report_screen.dart`, some movement types and amounts rely solely on green vs red text without an accompanying directional icon or textual descriptor (debit/credit or in/out).
  - `StatusBadge` in `lib/widgets/status_badge.dart` only renders text with a colored background, missing a semantic icon.

### 3. Font Scaling Resilience (textScaleFactor 1.3 to 2.0)
- In `product_picker` grid in `quick_sale_screen.dart`: `mainAxisExtent: 112` is hardcoded. When text scale exceeds 1.3, the product title, price, and cart badge overflow with yellow/black striping.
- Fixed height action bars (`SizedBox(height: 52)`) in `invoice_screen.dart` and `home_screen.dart` clip when font sizes are enlarged.
- Trial balance table in `accounting_screen.dart` uses a rigid horizontal `Row` with fixed `SizedBox` columns that wrap or truncate at 1.5x font scale.

---

## E. UX Flow Problems, Per Flow

### 1. Create Invoice Flow (`invoice_screen.dart`)
- **Tap Count to Add Item & Save:** 9-12 taps on average.
- **Pain Points:**
  - Form is one continuous vertical `ListView`. As lines increase, the financial summary card and "Save" button scroll far out of sight. The user cannot see the running total while adjusting quantities.
  - Number inputs (`quantityController`, `priceController`) do not auto-select content on focus; typing requires tapping backspace to clear the default "1" or "0".
  - Soft keyboard hides the active input because `DocumentItemForm` lacks automatic scroll-into-view behavior.
  - Deleting an item row happens immediately upon tapping the trash icon without confirmation or undo snackbar.
  - Back navigation drops the entire draft with zero warning (`PopScope` missing).

### 2. Quick Sale / POS Flow (`quick_sale_screen.dart`)
- **Tap Count for a 2-item Cash Sale:** 6-8 taps.
- **Pain Points:**
  - On phone screens in portrait mode, the cart is hidden behind a bottom sheet triggered by `posViewCart`. The cashier cannot see added items without extra taps.
  - Editing line item unit or pricing tier requires opening a modal bottom sheet, then tapping a line to open a nested `AlertDialog`, editing, closing the dialog, and returning to the sheet.
  - No quick quantity steppers (+ / -) directly on the product grid tiles.

### 3. Add/Edit Product Flow (`product_form_screen.dart`)
- **Pain Points:**
  - The form is over 1,000 lines and presents an overwhelming monolithic list of inputs (Basic, Barcode, Pricing, Wholesale, Stock, Min Stock, Tax Profile, Category, Notes).
  - No collapsible sections or visual accordion: wholesale pricing and custom units occupy screen space even when not immediately relevant.
  - If a user spends 5 minutes filling in detailed specifications and accidentally swipes back, everything is discarded without an unsaved changes alert.

### 4. Add/Edit Contact Flow (`contact_form_screen.dart` & `customer_detail_screen.dart`)
- **Pain Points:**
  - Phone and email in `customer_detail_screen.dart` are wrapped in static visual `_InfoChip` widgets that do not respond to taps, despite `UrlLauncherUtils` being present in the app.
  - Contact form lacks unsaved changes warning on pop.

### 5. Purchases & Stock Flow (`purchase_screen.dart` & `stock_movements_screen.dart`)
- **Pain Points:**
  - `purchase_screen.dart` duplicates the UX shortcomings of `invoice_screen.dart` (non-sticky totals, no select-all on focus, no back-confirmation).
  - `stock_movements_screen.dart` uses custom inline cards, ad-hoc green/red badges, and ad-hoc empty states instead of reusable components.

### 6. Payments & Expense Vouchers (`voucher_screen.dart`)
- **Pain Points:**
  - Vouchers lack a prominent summary card.
  - Radio/toggle between payment receipt (قبض) and expense voucher (صرف) is subtle and easy to submit incorrectly without explicit visual distinction.

### 7. Reports & Ledger Flow (`reports_screen.dart` & `accounting_screen.dart`)
- **Pain Points:**
  - Reports lack sticky date filter bars; scrolling down tables scrolls the filter header out of sight.
  - Large tabular data (Balance Sheet, Trial Balance) has no horizontal scroll indicator or card fallback on 360dp phone screens.
  - Export PDF actions lack inline loading feedback; long reports appear frozen during generation.

### 8. Settings Flow (`settings_screen.dart` & `financial_settings_screen.dart`)
- **Pain Points:**
  - Risky toggles like "Wholesale Pricing" (`SwitchListTile`) toggle immediately with no confirmation or explanation of how it impacts active invoices and customer pricing tiers.
  - No search or keyword filtering in settings.

### 9. Backup & Restore Flow (`settings_screen.dart` & `google_drive_backup_screen.dart`)
- **Pain Points:**
  - Restore action from local storage presents a generic alert dialog and restores without showing a progress indicator, file metadata (date, size, record count), or safety checkpoint.
  - In `google_drive_backup_screen.dart`, network failure feedback is presented via transient SnackBars that easily go unnoticed.

### 10. First-Run & Activation Experience (`splash_screen.dart` & `activation_screen.dart`)
- **Pain Points:**
  - First-run dashboard when `_business == null` presents a bare grey icon and generic text ("Welcome, please set up business") instead of an engaging onboarding illustration and structured guided setup.
  - Invalid key submission on activation displays a generic error message with no retry guidance.

---

## F. State Handling Gaps

| Screen | Loading State | Empty State | Error State (with Retry) | Unsaved Changes Guard (`PopScope`) | Double-Submit Protection |
|---|---|---|---|---|---|
| `invoice_screen.dart` | N/A (local form) | N/A | Inline validation | **MISSING** | Partially present (`_saving` flag) |
| `purchase_screen.dart` | N/A (local form) | N/A | Inline validation | **MISSING** | Partially present (`_saving` flag) |
| `quick_sale_screen.dart` | Spinner | Text placeholder | SnackBar toast | **MISSING** | Present (`_saving` flag) |
| `product_form_screen.dart` | Spinner (tax/cat) | N/A | Inline validation | **MISSING** | Present (`_saving` flag) |
| `products_screen.dart` | Spinner | `AppEmptyState` | Present with retry | N/A | N/A |
| `contact_form_screen.dart` | N/A | N/A | Inline validation | **MISSING** | Present (`_saving` flag) |
| `customer_detail_screen.dart` | Spinner | Inline text | Custom `_ErrorView` | N/A | N/A |
| `customers_screen.dart` | Spinner | `AppEmptyState` | Present with retry | N/A | N/A |
| `documents_screen.dart` | Spinner | `AppEmptyState` | Present with retry | N/A | N/A |
| `stock_movements_screen.dart` | Spinner | Ad-hoc Column | Ad-hoc with retry | N/A | N/A |
| `accounting_screen.dart` | Spinner | Ad-hoc text | Ad-hoc with retry | N/A | N/A |
| `sales_report_screen.dart` | Spinner | Ad-hoc text | SnackBar error | N/A | N/A |
| `google_drive_backup_screen.dart`| Spinner overlay | Ad-hoc Card | Text banner | N/A | Button disabled |
| `business_setup_screen.dart` | Spinner | N/A | SnackBar error | **MISSING** | Present (`_saving` flag) |
| `financial_settings_screen.dart`| Spinner | N/A | SnackBar error | **MISSING** | Present (`_saving` flag) |

---

## G. Performance & Tree Architecture UI Issues

1. **Unindexed `ListView` in Long Forms:**
   - In `product_form_screen.dart`, `business_setup_screen.dart`, and `invoice_screen.dart`, full forms are placed inside `ListView(children: [...])`. While suitable for forms under 10 fields, `product_form_screen.dart` contains dozens of nested controllers and builders. Using structured Slivers or sectioned cards prevents unnecessary layout passes.
2. **Expensive Rebuilds on Text Changes:**
   - In `invoice_screen.dart:59-60`:
     `_discountController.addListener(() => setState(() {}));`
     `_paidController.addListener(() => setState(() {}));`
     Every keystroke rebuilds the entire widget tree, including all line items and autocomplete fields.
3. **Missing `const` Constructors:**
   - Scattered throughout `lib/screens/`, hundreds of widgets, decorations, and padding insets omit `const`, causing unnecessary reallocations during frame rendering.

---

## H. Prioritized Backlog

| ID | Issue Description | Severity | Effort | Risk to Logic | Affected Files | Proposed Batch |
|---|---|---|---|---|---|---|
| **B1-01** | Missing component theme configs & button min sizes (<48dp) | High | M | None | `lib/theme.dart`, `lib/widgets/app_design_tokens.dart` | **Batch 1** |
| **B1-02** | Dark mode contrast & elevation token gaps | High | S | None | `lib/theme.dart`, `lib/widgets/app_design_tokens.dart` | **Batch 1** |
| **B2-01** | Fragmented error states across 6+ screens | Medium | M | None | `lib/widgets/app_error_state.dart`, screens | **Batch 2** |
| **B2-02** | Ad-hoc destructive confirmation dialogs | High | M | None | `lib/widgets/app_confirm_dialog.dart`, screens | **Batch 2** |
| **B2-03** | StatusBadge lacks semantic icons & universal status support | Medium | S | None | `lib/widgets/status_badge.dart` | **Batch 2** |
| **B2-04** | Inconsistent currency/amount formatting widgets | Medium | M | None | `lib/widgets/app_amount_text.dart`, screens | **Batch 2** |
| **B3-01** | Hardcoded left/right alignments & padding | High | M | None | `payments_report_screen.dart`, `report_date_filter.dart`, `barcode_scanner_screen.dart` | **Batch 3** |
| **B3-02** | Unmirrored back/forward icons & duplicated chevron ternaries | High | S | None | `barcode_scanner_screen.dart`, `notifications_inbox_screen.dart`, 10+ screens | **Batch 3** |
| **B3-03** | Number, currency, and date formatting discrepancies | Medium | M | None | FormatUtils usage across screens | **Batch 3** |
| **B3-04** | Text overflow risks on narrow screens & large font scale | High | M | None | `accounting_screen.dart`, `quick_sale_screen.dart`, `customer_detail_screen.dart` | **Batch 3** |
| **B4-01** | Form loss on back navigation (Missing `PopScope`) | High | M | None | `invoice_screen.dart`, `purchase_screen.dart`, `quotation_screen.dart` | **Batch 4** |
| **B4-02** | Non-sticky totals summary & deep scrolling in Invoice | High | M | None | `invoice_screen.dart`, `purchase_screen.dart` | **Batch 4** |
| **B4-03** | Number fields lack auto select-all on focus | Medium | S | None | `document_item_form.dart`, `invoice_screen.dart` | **Batch 4** |
| **B4-04** | Accidental item line deletion without confirmation/undo | Medium | S | None | `document_item_form.dart`, `invoice_screen.dart` | **Batch 4** |
| **B5-01** | POS portrait mode hides cart behind modal sheet | High | L | None | `quick_sale_screen.dart` | **Batch 5** |
| **B5-02** | Nested dialogs for line item unit and price tier changes | Medium | M | None | `quick_sale_screen.dart` | **Batch 5** |
| **B5-03** | Product grid tiles clip at large font scale | High | M | None | `quick_sale_screen.dart` | **Batch 5** |
| **B6-01** | Monolithic 1000-line product form lacks collapsible sections | High | L | None | `product_form_screen.dart` | **Batch 6** |
| **B6-02** | Contact details phone & email lack tap-to-call/open | Medium | S | None | `customer_detail_screen.dart` | **Batch 6** |
| **B6-03** | Missing `PopScope` on product and contact forms | High | S | None | `product_form_screen.dart`, `contact_form_screen.dart` | **Batch 6** |
| **B7-01** | Report tables clip/overflow on narrow phone screens | High | L | None | `accounting_screen.dart`, reports screens | **Batch 7** |
| **B7-02** | Date filter bar scrolls away instead of sticking | Medium | M | None | `report_date_filter.dart`, reports screens | **Batch 7** |
| **B7-03** | Ledger entries rely solely on color for debit vs credit | Medium | S | None | `accounting_screen.dart` | **Batch 7** |
| **B8-01** | Risky settings toggles (wholesale) lack confirmation | High | S | None | `settings_screen.dart`, `financial_settings_screen.dart` | **Batch 8** |
| **B8-02** | Restore from backup lacks progress indicator & metadata | High | M | None | `settings_screen.dart`, `google_drive_backup_screen.dart` | **Batch 8** |
| **B8-03** | Empty first-run setup lacks visual guidance and warmth | Medium | M | None | `home_screen.dart` | **Batch 8** |
| **B9-01** | Compact buttons below 48x48dp touch targets | High | M | None | All screens | **Batch 9** |
| **B9-02** | Icon buttons missing Tooltips / Semantics labels | Medium | M | None | All screens | **Batch 9** |
| **B9-03** | Missing `const` constructors causing frame drops | Low | M | None | All screens | **Batch 9** |

---

## Proposed Implementation Roadmap

- **Batch 1: Design Foundation** (Theme, Tokens, Typography, Component Themes, WCAG contrast).
- **Batch 2: Shared Reusable Widgets** (`AppConfirmDialog`, `AppErrorState`, `AppStatusBadge`, `AppAmountText`, `AppLoadingView`).
- **Batch 3: RTL & Localization Cleanup** (Directional padding/alignment, icon mirroring helpers, number/date formatting, overflow safety).
- **Batch 4: Invoice & Document Flows** (`PopScope`, sticky bottom totals bar, focus select-all, delete confirmation, double-submit protection).
- **Batch 5: Quick Sale / POS Polish** (Cart visibility, responsive thumb-friendly layout, resilient font scale grid, unit/tier shortcuts).
- **Batch 6: Products & Contacts Polish** (Collapsible sections in product form, tap-to-action on contact info, unsaved changes guards).
- **Batch 7: Reports, Ledger & Dashboard Polish** (Sticky filters, horizontally scrolling data tables with readable columns, debit/credit clarity).
- **Batch 8: Settings, Backup & Onboarding Polish** (Step-by-step restore feedback, warning dialogs on wholesale toggle, friendly first-run setup).
- **Batch 9: Accessibility & Polish Pass** (48dp touch targets, semantic tooltips, contrast verification, const constructor cleanup).

---
*Report saved to `docs/ux_audit.md`. Awaiting user review and approval before beginning Batch 1.*

# Waraqatak Reports — Manual Test Checklist

This checklist is designed for physical on-device QA testing on an Android device running Waraqatak.

---

## 1. Security & Permissions (RBAC)

- [ ] **Owner / Admin Role:**
  - [ ] Can access all report tiles from Reports hub.
  - [ ] Can open Daily Closing, Sales, Purchases, Customer, Supplier, Aging, Taxes & Discounts, Payments, Inventory, Product Performance, and Accounting reports.
- [ ] **Cashier Role:**
  - [ ] Can see and open Sales Report and Daily Closing Report.
  - [ ] Payments Report tile is hidden; direct navigation triggers `ScreenAccessGate` access denied view.
  - [ ] Accounting and Advanced Inventory tiles are hidden.
- [ ] **Salesperson Role:**
  - [ ] Can see and open Sales Report, Daily Closing Report, Customer Report, and Aging Report.
  - [ ] Cannot open Accounting or Inventory Valuation screens.
- [ ] **Stockkeeper Role:**
  - [ ] Can see and open Stock Movements and Purchases Report.
  - [ ] Cannot view Financial Payments or Accounting screens.

---

## 2. Date Filtering & Persistence

- [ ] Select **This Month** in Sales Report.
- [ ] Navigate back to Reports hub and open **Purchases Report**.
  - [ ] Verify active filter preset is still **This Month** without re-selecting.
- [ ] Select **Custom Range** with specific start and end dates.
  - [ ] Verify both dates format correctly in Western numerals (`0-9`) in Arabic and English locales.
- [ ] Test quick chip buttons with finger: touch targets are comfortable and easy to tap (>= 48 dp).

---

## 3. Daily Closing & Cash Drawer Reconciliation

- [ ] Open **Daily Closing Report**.
- [ ] Verify cash sales and customer debt collections are segregated into separate metric cards.
- [ ] In the Cash Drawer Reconciliation card:
  - [ ] Enter an actual cash amount equal to expected cash: card highlights **Balanced (Green)**.
  - [ ] Enter an amount higher than expected: card displays **Surplus (Blue)** with correct difference.
  - [ ] Enter an amount lower than expected: card displays **Shortage (Red)** with correct difference.
- [ ] Export 80mm POS receipt and verify preview displays cleanly.

---

## 4. Debt Aging Report

- [ ] Open **Aging Report**.
- [ ] Switch between **Customers (Receivables)** and **Suppliers (Payables)** tabs.
- [ ] Verify top 4 bucket cards display totals: `0–30 Days`, `31–60 Days`, `61–90 Days`, `90+ Days`.
- [ ] On Free tier: buckets show total balances.
- [ ] On Pro tier: customer/supplier list displays breakdown with a working **Send Reminder** WhatsApp button.

---

## 5. Taxes & Discounts Summary

- [ ] Open **Taxes & Discounts Report**.
- [ ] Verify Sales Tax Collected, Purchase Tax Paid, and Net Tax cards render accurate values.
- [ ] Verify Discounts Given, Discounts Received, and Net Discounts render accurate values.
- [ ] Tap on a document in the breakdown list: verifies navigation into `DocumentDetailScreen`.

---

## 6. Payments Cash Flow & Voucher Drilldown

- [ ] Open **Payments Report**.
- [ ] Verify the horizontal payment methods flow chips show In, Out, and Net amounts for Cash and Bankak.
- [ ] Verify the `AppPercentageBar` visualizes the distribution of payment methods.
- [ ] Tap on a standalone expense voucher: opens `DocumentDetailScreen` without errors.

---

## 7. Export & Sharing Verification

- [ ] **PDF Export (A4):** Open export menu -> Print / PDF Preview. Verify Arabic text is correctly shaped and right-to-left.
- [ ] **PDF Export (80mm):** Open export menu on Daily Closing or Sales report -> Print 80mm. Verify compact POS layout.
- [ ] **CSV Export:** Export table as CSV -> Open in Excel / Sheets. Verify columns align properly, Arabic characters display correctly (UTF-8 BOM), and formulas are not executed.
- [ ] **WhatsApp Sharing:** Tap Share WhatsApp -> verify formatted text summary opens in the sharing sheet.

---

## 8. Low-Memory & Edge Conditions

- [ ] Test pull-to-refresh (`RefreshIndicator`) on Sales, Purchases, Customers, Suppliers, and Products lists.
- [ ] In Customer/Supplier report, type in search field rapidly: verify no lag, debounced 300ms, and search results match accurately.
- [ ] Verify app functions smoothly with no crashes under low RAM conditions.

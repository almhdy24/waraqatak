# Perpetual Moving Weighted-Average Inventory Costing & Profit Accounting Policy

## 1. Overview
Waraqatak (ورقتك) uses the **Perpetual Moving Weighted-Average Cost** method for inventory valuation and Cost of Goods Sold (COGS) accounting. This policy ensures strict auditability, deterministic valuation, and accurate financial reporting in an offline-first SQLite architecture.

---

## 2. Core Accounting Principles

### 2.1 Perpetual Moving Weighted-Average Formula
Whenever incoming stock arrives (via an approved purchase or opening stock with a known cost basis), the unit cost basis of the product is updated dynamically:

$$\text{New Average Cost} = \frac{(\text{Current Stock} \times \text{Current Average Cost}) + (\text{Incoming Quantity} \times \text{Incoming Unit Cost})}{\text{Current Stock} + \text{Incoming Quantity}}$$

- **Zero or Negative Prior Stock**: If current stock is $\le 0$, the incoming purchase directly establishes the new average cost basis:
  $$\text{New Average Cost} = \text{Incoming Unit Cost}$$
- **Sales Consumption**: When an invoice is issued, inventory is consumed at the unit average cost applicable **immediately before the sale**. The average unit cost of remaining stock does not change when a sale occurs.
- **Selling Price vs. Cost**: Selling price and purchase cost are completely separate. Revenue is recognized from the actual sale price (net of line/document discounts and excluding sales tax); COGS is recognized from the snapshot cost recorded for the physical quantities deducted.

### 2.2 Preservation of Historical Snapshots
- Changing a product's editable metadata (`products.purchase_price` or `products.sale_price`) in the product catalog **never** rewrites the historical unit cost of past stock movements, historical invoices, or completed purchase items.
- Every `stock_movements` record retains immutable `unit_cost`, `total_cost`, `cost_status`, and `provenance` snapshots.
- Every `document_items` record for sales invoices snapshots `unit_cost` and `total_cost` at document issuance.

---

## 3. Costing Status & Provenance
To ensure financial honesty and prevent manufacturing artificial certainty:
1. **Known (`known`)**: The cost was definitively established at the time of transaction (e.g. from an issued purchase invoice or an explicit opening cost basis).
2. **Reconstructed (`reconstructed`)**: The cost was deterministically recovered from historical evidence (e.g. legacy purchase document items linked to stock movements). Provenance notes the exact source (`purchase_document_item`).
3. **Unknown (`unknown`)**: No reliable historical cost basis exists (e.g. legacy opening stock where no price was recorded, or sales occurring against unvalued inventory). **Unknown costs are NEVER silently converted to zero.** In reports, transactions with unknown cost are explicitly highlighted as incomplete/unresolved.

---

## 4. Lifecycle Operations & Valuation Rules

| Event | Stock Impact | Cost Basis Impact | Movement Recorded |
| :--- | :--- | :--- | :--- |
| **Product Creation with Opening Stock** | $+\Delta Q$ | If purchase price provided, sets initial average cost (`known`). If zero/omitted, marked `unknown`. | `type: opening` with unit & total cost. |
| **Purchase Document Issued** | $+\Delta Q$ | Recomputes moving average cost with incoming item cost. | `type: purchase` with item unit price. |
| **Sales Invoice Issued** | $-\Delta Q$ | Consumes stock at current average cost. Average cost of remaining stock remains unchanged. | `type: sale` with unit cost snapshot. |
| **Sale Cancellation / Reversal** | $+\Delta Q$ | Restores stock at the original sale's unit cost. | `type: cancellation` restoring original unit cost. |
| **Purchase Cancellation / Reversal** | $-\Delta Q$ | Reverses incoming stock and re-evaluates average cost on remaining inventory. Rejected if stock consumed. | `type: cancellation` with original purchase unit cost. |
| **Inventory Adjustment (+)** | $+\Delta Q$ | Valued at current average cost (if known), maintaining cost basis. | `type: adjustment` with mandatory reason. |
| **Inventory Adjustment (-)** | $-\Delta Q$ | Depletes stock at current average cost. | `type: adjustment` with mandatory reason. |
| **Manual Cost Reconciliation** | No change to $Q$ | Sets audited average cost basis for products with unknown cost. Records audit log entry. | Audit event logged (`cost_reconciled`). |

---

## 5. Gross Profit Recognition & Date-Range Reporting
- **Recognized Sales Revenue**: Net revenue from issued invoices (excluding tax, net of discounts) within the specified period. Excludes cancelled or draft documents.
- **Cost of Goods Sold (COGS)**: Sum of snapshot costs for items sold in issued invoices during the period.
- **Gross Profit**: $\text{Recognized Revenue} - \text{COGS}$.
- **Incomplete Disclosures**: If any transaction in a date range includes items with `unknown` cost, the report displays the partial profit alongside an explicit disclosure badge and count of unresolved transactions. Partial profit is never disguised as complete profit.

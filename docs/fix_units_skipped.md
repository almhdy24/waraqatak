# Skipped Items Log: Units & Wholesale Fixes

| Item ID | Description | Why Skipped | What Would Be Needed |
|---|---|---|---|
| GAP-3 | Updating `product_units` in `BulkPricingService` | Needs product decision: automatic adjustment could distort intentional volume pricing or break packaging margins; UI warning added instead. | Product specification determining whether secondary units should scale proportionally with base price, keep fixed multipliers, or have separate bulk rules. |

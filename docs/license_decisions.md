# Licensing & Notification Architectural Decisions

| ID | Date | Decision | Alternatives Considered | Rationale / Safety | Reversal Path |
|---|---|---|---|---|---|
| D-001 | 2026-11-01 | Support Legacy Slug `waraqatak` via Read-Only Mapping | Reject `waraqatak` immediately | Published production build `1.1.4+13` sends `product: 'waraqatak'`. Rejecting it immediately would lock out active users. Read-only mapping maps request to canonical ID without ever storing old slug. | Remove alias mapping in `ProductResolver.php` after all active installs migrate past 1.1.4+13. |
| D-002 | 2026-11-01 | Restrict Notification Actions to Safe Internal Targets | Allow arbitrary HTTPS URLs | Consumption-only Play compliance prohibits arbitrary URLs that could link to external payment/store pages. Only `none`, `open_about`, `open_license`, and `open_store_listing` are allowed. | Re-enable `action_url` column in API if policy allows external URLs in future. |

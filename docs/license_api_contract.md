# License Server Authoritative Verification Contract

**API Version:** `v1`  
**Endpoint:** `POST /api/v1/pay/licenses/verify`

## 1. Specification Overview

When an application calls `/api/v1/pay/licenses/verify` to authoritatively verify an activated license, the licensing server returns either:
- **HTTP 200** with `{"success": true, "valid": true, "data": {...}}`
- **HTTP 401** with `{"success": false, "valid": false, "error": "<reason_string>", "message": "..."}`

## 2. Server Reason Vocabulary & Client Outcome Mapping

| Server Reason Code (`error`) | Classification | App Action (`verifyLicenseOnline`) | App Entitlement Outcome |
|---|---|---|---|
| `license_expired` | Terminal Expiration | Writes `wq_license_status = 'expired'`, triggers `onLicenseExpired()` | `EntitlementStatus.licenseExpired` |
| `license_revoked` | Terminal Revocation | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `license_refunded` | Terminal Revocation | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `license_flagged` | Terminal Revocation | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `device_not_registered` | Terminal Hardware Unlink | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `device_revoked` | Terminal Hardware Revocation | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `device_deactivated` | Terminal Hardware Deactivation | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `device_mismatch` | Terminal Replay Rejection | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `product_mismatch` | Terminal Isolation Rejection | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `license_not_found` | Terminal Rejection | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `invalid_signature_or_payload`| Terminal Integrity Rejection | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| `invalid_machine_id` | Terminal Rejection | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |
| *Unknown 4xx Error* | Fail-Closed Safety | Writes `wq_license_status = 'revoked'`, triggers `onLicenseRevoked(reason)` | `EntitlementStatus.licenseRevoked` |

## 3. Transient & Network Failures (Preserve Offline Access)

| Error Condition | Client Handling | App Entitlement Outcome |
|---|---|---|
| HTTP 429 Too Many Requests | Catches exception, aborts check | **No change** (remains active offline) |
| HTTP 500 / 502 / 503 / 504 | Catches exception, aborts check | **No change** (remains active offline) |
| Connection Timeout / Socket Error | Catches exception, aborts check | **No change** (remains active offline) |

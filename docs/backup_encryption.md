# Backup Encryption Specification

This document details the optional password encryption architecture for Waraqatak backup files (`.waraq` files and Google Drive cloud backups).

---

## 1. Cryptographic Architecture

- **Cipher**: AES-256-GCM (Authenticated Encryption with Associated Data).
- **Key Derivation Function (KDF)**: PBKDF2 with HMAC-SHA256.
- **Iteration Count**: 600,000 iterations (OWASP recommendation for PBKDF2-HMAC-SHA256 against GPU brute-forcing). Stored in the file header to allow future tuning without breaking backward compatibility.
- **Salt**: 16 cryptographically secure random bytes generated via `Random.secure()`.
- **Nonce (IV)**: 12 cryptographically secure random bytes (96-bit standard for GCM).
- **Tag**: 16-byte MAC authentication tag produced by AES-GCM for tamper detection.
- **Engine**: `package:cryptography` with `package:cryptography_flutter` for native Android platform acceleration (`SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")`). Runs off the UI thread without blocking the Flutter rendering loop.

---

## 2. Binary File Header Layout (40 Bytes)

Encrypted backups use a fixed 40-byte binary header followed by ciphertext and authentication tag:

| Offset (Bytes) | Field | Type | Description |
|---|---|---|---|
| `0..5` | Magic Header | ASCII `WRQENC` | `[0x57, 0x52, 0x51, 0x45, 0x4E, 0x43]` |
| `6` | Format Version | `uint8` | `0x01` (Version 1) |
| `7` | KDF Algorithm ID | `uint8` | `0x01` (PBKDF2-HMAC-SHA256) |
| `8..11` | KDF Iterations | `uint32` (Big-Endian) | `600,000` (`0x000927C0`) |
| `12..27` | Salt | 16 bytes | Cryptographically secure random salt |
| `28..39` | Nonce / IV | 12 bytes | Cryptographically secure random nonce |
| `40..N-16` | Ciphertext | Variable | AES-256-GCM encrypted UTF-8 JSON |
| `N-16..N` | Auth Tag (MAC) | 16 bytes | AES-GCM integrity and authenticity tag |

**Minimum valid encrypted file size**: 56 bytes (40 header + 16 MAC tag).

---

## 3. Backward Compatibility & Plain Backups

1. **Auto-Detection**: On restore, the app inspects the first 6 bytes.
   - If bytes match `WRQENC`, the file is treated as an encrypted backup and prompts for the password.
   - If bytes do NOT match, the file is treated as a legacy plain UTF-8 JSON backup and restores immediately without a password prompt.
2. **Older App Compatibility**: Older app versions attempting to open a `WRQENC` file encounter a UTF-8 / JSON parsing exception and safely reject the file without modifying the database.
3. **Future Versions**: If a backup with format version > 1 is encountered by this app, it throws `BackupUnsupportedVersionException`, displaying a localized update message: *"حدّث التطبيق لفتح هذه النسخة"* / *"Update the app to open this backup"*.
4. **Audit Log Null Safety**: Decrypted JSON payloads lacking an `audit_log` key are parsed and imported null-safely.

---

## 4. Unattended & Automatic Safety Backups

Automatic safety backups (`BackupService.createSafetyBackup()` called prior to database restore or repair operations) remain **unencrypted plain JSON**. They do not prompt the user for passwords and are never stored with credentials.

---

## 5. Security & Privacy Invariants

- **No Password Storage**: Passwords, derived encryption keys, and plaintext decrypted payloads are never stored, cached, or written to `SharedPreferences`, `FlutterSecureStorage`, or logs.
- **No Password Recovery**: By design, if a user loses their password, the data is mathematically unrecoverable. Users are warned with plain Arabic and English text before setting a password.
- **Pre-Save Round-Trip Self-Verification**: Every encrypted backup is decrypted in memory and verified against the source JSON before the file is finalized and saved/uploaded. If verification fails, the file is discarded and an error is shown.
- **Zero Database Changes on Decryption Failure**: The local database is never touched, and no safety backup is triggered, until the decrypted JSON is completely parsed and verified.
